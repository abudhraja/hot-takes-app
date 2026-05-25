import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";

admin.initializeApp();
const db = admin.database();

// ─── Types ───────────────────────────────────────────────────────────────────

interface Take {
  playerId: string;
  text: string;
  isBlank: boolean;
}

interface Pair {
  id: string;
  take1Id: string;
  take2Id: string;
  hasBlank: boolean;
  votes: Record<string, string>;
  winnerId: string | null;
  loserWasBlank: boolean;
  pointsAwarded: number | null;
  revealed: boolean;
}

interface Player {
  nickname: string;
  totalScore: number;
  roundScores: Record<string, number>;
  roundRanks: Record<string, number>;
  submittedTakes: boolean;
  hasVoted: boolean;
  connected: boolean;
}

interface Room {
  code: string;
  phase: string;
  currentRound: number;
  currentPairIndex: number;
  hostId: string;
  categoriesLocked: boolean;
  timerEndsAt: number;
  categories: Record<string, string>;
  players: Record<string, Player>;
  takes: Record<string, Record<string, Take>>;
  pairs: Record<string, Record<string, Pair>>;
}

// ─── fillBlanksAndPair ───────────────────────────────────────────────────────
// Triggered when host writes phase = "pairing_requested".
// Fills blank takes for non-submitters, generates pairs, sets phase = "voting".

export const fillBlanksAndPair = onValueWritten(
  { ref: "/rooms/{roomId}/phase", region: "us-central1" },
  async (event) => {
    const newPhase = event.data.after.val() as string;
    if (newPhase !== "pairing_requested") return;

    const roomId = event.params.roomId;
    const roomRef = db.ref(`rooms/${roomId}`);
    const snap = await roomRef.get();
    const room = snap.val() as Room;
    if (!room) return;

    const round = room.currentRound;
    const roundKey = `round-${round}`;

    // Fill in blanks for any player who hasn't submitted
    const updates: Record<string, unknown> = {};
    for (const [playerId, player] of Object.entries(room.players)) {
      if (!player.submittedTakes) {
        const t1 = db.ref().push().key!;
        const t2 = db.ref().push().key!;
        updates[`takes/${roundKey}/${t1}`] = { playerId, text: "", isBlank: true };
        updates[`takes/${roundKey}/${t2}`] = { playerId, text: "", isBlank: true };
        updates[`players/${playerId}/submittedTakes`] = true;
      }
    }
    if (Object.keys(updates).length > 0) {
      await roomRef.update(updates);
    }

    // Re-fetch takes after filling blanks
    const takesSnap = await roomRef.child(`takes/${roundKey}`).get();
    const takes = (takesSnap.val() ?? {}) as Record<string, Take>;
    const takeIds = Object.keys(takes);

    // Generate pairs
    const pairs = generatePairs(takeIds, takes);

    // Write pairs and advance phase
    const pairsData: Record<string, unknown> = {};
    pairs.forEach((pair, idx) => {
      pairsData[`pairs/${roundKey}/${idx}`] = {
        id: String(idx),
        take1Id: pair[0],
        take2Id: pair[1],
        hasBlank: takes[pair[0]].isBlank || takes[pair[1]].isBlank,
        votes: {},
        winnerId: null,
        loserWasBlank: false,
        pointsAwarded: null,
        revealed: false,
      };
    });

    const timerEndsAt = Date.now() + 20_000;
    await roomRef.update({
      ...pairsData,
      phase: "voting",
      currentPairIndex: 0,
      timerEndsAt,
    });
  }
);

// ─── onVoteWrite ─────────────────────────────────────────────────────────────
// Triggered whenever a vote is cast. Checks if all eligible voters have voted;
// if so, tallies immediately (don't wait for timer).

export const onVoteWrite = onValueWritten(
  { ref: "/rooms/{roomId}/pairs/{round}/{pairIdx}/votes/{voterId}", region: "us-central1" },
  async (event) => {
    if (!event.data.after.exists()) return; // vote removed — ignore

    const { roomId, round, pairIdx } = event.params;
    const roomRef = db.ref(`rooms/${roomId}`);
    const snap = await roomRef.get();
    const room = snap.val() as Room;
    if (!room || room.phase !== "voting") return;
    if (String(room.currentPairIndex) !== pairIdx) return; // stale trigger

    const pair = room.pairs[round]?.[pairIdx];
    if (!pair || pair.revealed) return;

    const playerCount = Object.keys(room.players).length;
    const t1 = room.takes[round]?.[pair.take1Id];
    const t2 = room.takes[round]?.[pair.take2Id];
    const submitterIds = new Set([t1?.playerId, t2?.playerId].filter(Boolean));
    const eligibleCount = playerCount - submitterIds.size;

    const voteCount = Object.keys(pair.votes ?? {}).length;
    if (eligibleCount > 0 && voteCount < eligibleCount) return; // still waiting

    await tallyAndReveal(roomRef, room, round, parseInt(pairIdx));
  }
);

// ─── onTallyTrigger ──────────────────────────────────────────────────────────
// Triggered by host writing tallyTrigger when voting timer expires.

export const onTallyTrigger = onValueWritten(
  { ref: "/rooms/{roomId}/tallyTrigger", region: "us-central1" },
  async (event) => {
    if (!event.data.after.exists()) return;

    const roomId = event.params.roomId;
    const roomRef = db.ref(`rooms/${roomId}`);
    const snap = await roomRef.get();
    const room = snap.val() as Room;
    if (!room || room.phase !== "voting") return;

    const round = `round-${room.currentRound}`;
    await tallyAndReveal(roomRef, room, round, room.currentPairIndex);
  }
);

// ─── onComputeLeaderboard ────────────────────────────────────────────────────
// Triggered when host writes computeLeaderboardTrigger after the last reveal.

export const onComputeLeaderboard = onValueWritten(
  { ref: "/rooms/{roomId}/computeLeaderboardTrigger", region: "us-central1" },
  async (event) => {
    if (!event.data.after.exists()) return;

    const roomId = event.params.roomId;
    const roomRef = db.ref(`rooms/${roomId}`);
    const snap = await roomRef.get();
    const room = snap.val() as Room;
    if (!room) return;

    await computeRoundLeaderboard(roomRef, room);
  }
);

// ─── onCloseRequested ────────────────────────────────────────────────────────
// Triggered when host writes closeRequested = true. Deletes the room.

export const onCloseRequested = onValueWritten(
  { ref: "/rooms/{roomId}/closeRequested", region: "us-central1" },
  async (event) => {
    if (!event.data.after.val()) return;
    const roomId = event.params.roomId;
    await db.ref(`rooms/${roomId}`).remove();
  }
);

// ─── Shared logic ────────────────────────────────────────────────────────────

async function tallyAndReveal(
  roomRef: admin.database.Reference,
  room: Room,
  round: string,
  pairIdx: number
): Promise<void> {
  const pair = room.pairs[round]?.[String(pairIdx)];
  if (!pair || pair.revealed) return;

  const playerCount = Object.keys(room.players).length;
  const t1 = room.takes[round]?.[pair.take1Id];
  const t2 = room.takes[round]?.[pair.take2Id];
  const submitterIds = new Set([t1?.playerId, t2?.playerId].filter(Boolean));
  const eligibleCount = playerCount - submitterIds.size;

  let winnerId: string | null = null;
  let loserWasBlank = false;
  let points = 0;

  if (pair.hasBlank) {
    // Blank pair: non-blank take wins automatically
    if (t1 && !t1.isBlank) {
      winnerId = pair.take1Id;
      loserWasBlank = t2?.isBlank ?? false;
    } else {
      winnerId = pair.take2Id;
      loserWasBlank = t1?.isBlank ?? false;
    }
    points = 100;
  } else {
    const v1 = Object.values(pair.votes ?? {}).filter((v) => v === pair.take1Id).length;
    const v2 = Object.values(pair.votes ?? {}).filter((v) => v === pair.take2Id).length;

    if (eligibleCount === 0 || v1 === v2) {
      // Tie (or no voters)
      winnerId = null;
      points = 25;
    } else if (v1 > v2) {
      winnerId = pair.take1Id;
      points = v1 === eligibleCount ? 100 : 50;
    } else {
      winnerId = pair.take2Id;
      points = v2 === eligibleCount ? 100 : 50;
    }
  }

  const updates: Record<string, unknown> = {
    [`pairs/${round}/${pairIdx}/winnerId`]: winnerId,
    [`pairs/${round}/${pairIdx}/loserWasBlank`]: loserWasBlank,
    [`pairs/${round}/${pairIdx}/pointsAwarded`]: points,
    [`pairs/${round}/${pairIdx}/revealed`]: true,
  };

  // Award points
  const winnerPlayerId = winnerId ? room.takes[round]?.[winnerId]?.playerId : null;
  const loserTakeId = winnerId
    ? pair.take1Id === winnerId ? pair.take2Id : pair.take1Id
    : null;
  const loserPlayerId = loserTakeId ? room.takes[round]?.[loserTakeId]?.playerId : null;

  if (winnerId && winnerPlayerId) {
    const prev = room.players[winnerPlayerId]?.totalScore ?? 0;
    const prevRound = room.players[winnerPlayerId]?.roundScores?.[String(room.currentRound)] ?? 0;
    updates[`players/${winnerPlayerId}/totalScore`] = prev + points;
    updates[`players/${winnerPlayerId}/roundScores/${room.currentRound}`] = prevRound + points;
  } else if (!winnerId) {
    // Tie — award both
    for (const tId of [pair.take1Id, pair.take2Id]) {
      const pId = room.takes[round]?.[tId]?.playerId;
      if (pId) {
        const prev = room.players[pId]?.totalScore ?? 0;
        const prevRound = room.players[pId]?.roundScores?.[String(room.currentRound)] ?? 0;
        updates[`players/${pId}/totalScore`] = prev + 25;
        updates[`players/${pId}/roundScores/${room.currentRound}`] = prevRound + 25;
      }
    }
  }
  if (loserWasBlank && loserPlayerId) {
    // Loser gets 0 (no update needed — already 0)
  }

  updates["phase"] = "revealing";

  await roomRef.update(updates);
}

async function computeRoundLeaderboard(
  roomRef: admin.database.Reference,
  room: Room
): Promise<void> {
  // Sort players by totalScore descending, write their rank for this round
  const sorted = Object.entries(room.players).sort(
    ([, a], [, b]) => b.totalScore - a.totalScore
  );

  const updates: Record<string, unknown> = {};
  sorted.forEach(([playerId], idx) => {
    updates[`players/${playerId}/roundRanks/${room.currentRound}`] = idx + 1;
  });

  await roomRef.update(updates);
}

// ─── Pairing algorithm ───────────────────────────────────────────────────────

function generatePairs(
  takeIds: string[],
  takes: Record<string, Take>
): [string, string][] {
  for (let attempt = 0; attempt < 20; attempt++) {
    const shuffled = [...takeIds].sort(() => Math.random() - 0.5);
    const pairs: [string, string][] = [];
    let valid = true;

    for (let i = 0; i < shuffled.length - 1; i += 2) {
      const a = shuffled[i];
      const b = shuffled[i + 1];
      if (takes[a].playerId === takes[b].playerId) {
        valid = false;
        break;
      }
      pairs.push([a, b]);
    }

    if (!valid) continue;

    // Reorder to avoid back-to-back same player matchup
    for (let i = 0; i < pairs.length - 1; i++) {
      const currPlayers = new Set([takes[pairs[i][0]].playerId, takes[pairs[i][1]].playerId]);
      const nextPlayers = new Set([takes[pairs[i + 1][0]].playerId, takes[pairs[i + 1][1]].playerId]);
      const overlap = [...currPlayers].some((p) => nextPlayers.has(p));
      if (overlap && i + 2 < pairs.length) {
        [pairs[i + 1], pairs[i + 2]] = [pairs[i + 2], pairs[i + 1]];
      }
    }

    return pairs;
  }

  // Fallback: just pair without constraint (shouldn't happen with reasonable player counts)
  const fallback: [string, string][] = [];
  for (let i = 0; i < takeIds.length - 1; i += 2) {
    fallback.push([takeIds[i], takeIds[i + 1]]);
  }
  return fallback;
}
