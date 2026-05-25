# Hot Takes 🔥

A Jackbox-style NSFW party game for 4–10 players, all physically in the same room on the same WiFi. Each player uses their own iPhone. No TV screen required — every phone is a full equal participant.

**Age rating: 17+ — explicitly NSFW adult game. No content moderation by design.**

---

## How to Play

1. One player creates a room and becomes the **host**. A 4-letter room code is generated.
2. Other players join by entering the code on their own iPhones.
3. The **host defines 3 categories** — these are the 3 rounds of the game. Categories can be edited freely until the host taps "Lock In & Start Round."
4. In each round, every player submits **2 hot takes** on the category within 90 seconds.
5. Takes are randomly paired off. The room votes on which take is hotter — **anonymously** (the submitter is hidden during voting).
6. After voting closes, the submitter is revealed. If someone submitted a blank take, they are **publicly shamed**.
7. After all pairs in a round are revealed, the **leaderboard** shows current standings with rank movement (↑↓).
8. After 3 rounds, a **final winner screen** is shown. The room is then deleted — no data persists.

### Scoring

| Outcome | Points |
|---|---|
| Unanimous win (all eligible voters picked your take) | 100 pts |
| Split win (more votes than opponent) | 50 pts |
| Tie | 25 pts each |
| Win against a blank take | 100 pts automatic |
| Submit a blank / don't submit | 0 pts + shame |

---

## Architecture

### Why Firebase over P2P

All game state lives in **Firebase Realtime Database** as a single room document. Every phone subscribes to the same document via a live listener (~100ms propagation). No device acts as a server.

```
[iPhone A]    [iPhone B]    [iPhone C]    [iPhone D]
     |              |             |             |
     └──────────────┴─────────────┴─────────────┘
                          |
               Firebase Realtime Database
               rooms/XKCD  ← single source of truth
```

Alternatives considered:
- **Local P2P (Multipeer Connectivity):** rejected — complex reconnect handling, no server-side scoring enforcement, clients could diverge or cheat
- **Game engine (Unity/Godot):** rejected — overkill for a card/prompt game; SwiftUI handles UI cleanly with tighter Firebase SDK integration

### Phase Machine

The game advances through a strict phase sequence. Every phone reacts to the same `phase` field in Firebase.

```
joining → categories → submitting → pairing_requested
                                          ↓
                              voting → revealing → [next pair…]
                                                 → round_leaderboard
                                          [repeat rounds 2, 3]
                                                 → final_leaderboard
```

| Phase | Who acts | What happens |
|---|---|---|
| `joining` | Anyone | Lobby shows room code + player list |
| `categories` | Host only | Host edits 3 category prompts; others see waiting screen |
| `submitting` | All players | Category label + 2 text inputs; 90s timer |
| `pairing_requested` | Cloud Function | Sentinel written by host; CF fills blanks and generates pairs |
| `voting` | All players (except pair's submitters) | Two anonymous takes; 20s timer |
| `revealing` | Passive | Winner + submitter nickname + points; shame message for blanks |
| `round_leaderboard` | Host | Full leaderboard + ↑↓ rank movement |
| `final_leaderboard` | Passive | Final standings, winner crowned |

**Timer design:** `timerEndsAt` is stored as an absolute Unix millisecond timestamp in Firebase. Each client computes `remaining = timerEndsAt - Date.now()` locally — no clock drift between devices.

**Room code persistence:** The 4-letter room code is shown as a persistent overlay chip on every in-game screen so players who disconnect can get the code from a neighbor's phone.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | SwiftUI, iOS 17+ |
| State management | `@Observable` + `@MainActor` (Swift 5.9 Observation framework) |
| Realtime sync | Firebase Realtime Database |
| Auth | Firebase Anonymous Auth |
| Server logic | Firebase Cloud Functions v2 (Node.js 22, TypeScript) |
| Crash + analytics | Firebase Crashlytics + Analytics |
| Project generation | xcodegen (`project.yml`) |
| Monthly hosting cost | $0 (Firebase free tier) |

---

## Project Structure

```
hot-takes-game/
├── project.yml                    # xcodegen spec (bundle ID, team, dependencies)
├── firebase.json                  # Firebase deployment config
├── database.rules.json            # Realtime Database security rules
├── .firebaserc                    # Firebase project link (hot-takes-app-c5bc0)
│
├── functions/
│   ├── src/index.ts               # All 5 Cloud Functions
│   ├── lib/index.js               # Compiled output (committed)
│   ├── package.json               # Node 22, firebase-admin + firebase-functions
│   └── tsconfig.json
│
└── HotTakes/
    ├── HotTakesApp.swift          # App entry; AppDelegate for Firebase Crashlytics
    ├── GoogleService-Info.plist   # Firebase config (bundle ID: com.architb17.hottakes)
    │
    ├── Models/
    │   ├── GamePhase.swift        # Phase enum (rawValue = Firebase string)
    │   ├── PlayerModel.swift      # Player struct; rankMovement() helper
    │   ├── TakeModel.swift        # Take struct
    │   └── PairModel.swift        # Pair struct; voteCount() helper
    │
    ├── ViewModels/
    │   └── GameViewModel.swift    # @MainActor @Observable; all Firebase reads/writes
    │
    ├── Views/
    │   ├── RootView.swift         # Phase router + RoomCodeChip overlay
    │   ├── HomeView.swift         # Create / join room
    │   ├── LobbyView.swift        # Waiting room
    │   ├── CategoriesView.swift   # Host sets 3 categories
    │   ├── SubmitView.swift       # Submit 2 takes (90s timer)
    │   ├── VotingView.swift       # Vote on pair (20s timer)
    │   ├── RevealView.swift       # Winner + shame reveal
    │   ├── RoundLeaderboardView.swift
    │   ├── FinalLeaderboardView.swift
    │   └── Components/
    │       ├── Theme.swift        # Color palette + HTButtonStyle + HTCardStyle
    │       ├── RoomCodeChip.swift # Persistent room code overlay
    │       └── TimerBar.swift     # Countdown progress bar
    │
    └── Assets.xcassets/
        └── AppIcon.appiconset/
            └── AppIcon-1024.png   # H🔥T monogram on navy-purple gradient (fire doubles as the "O")
```

---

## Firebase Database Schema

```json
{
  "rooms": {
    "XKCD": {
      "code": "XKCD",
      "phase": "voting",
      "currentRound": 1,
      "currentPairIndex": 2,
      "hostId": "anon-uid-abc",
      "categoriesLocked": true,
      "timerEndsAt": 1716144020000,
      "categories": {
        "1": "Most controversial political hot take",
        "2": "Most overrated celebrity",
        "3": "Best unpopular food opinion"
      },
      "players": {
        "anon-uid-abc": {
          "nickname": "ArchitB",
          "totalScore": 150,
          "roundScores": { "1": 150, "2": 0, "3": 0 },
          "roundRanks": { "0": 1, "1": 1, "2": 0, "3": 0 },
          "submittedTakes": true,
          "hasVoted": false,
          "connected": true
        }
      },
      "takes": {
        "round-1": {
          "take-uuid-1": { "playerId": "anon-uid-abc", "text": "Term limits are bad", "isBlank": false },
          "take-uuid-2": { "playerId": "anon-uid-abc", "text": "Two-party system is fine", "isBlank": false }
        }
      },
      "pairs": {
        "round-1": {
          "0": {
            "id": "0",
            "take1Id": "take-uuid-1",
            "take2Id": "take-uuid-3",
            "hasBlank": false,
            "votes": { "anon-uid-xyz": "take-uuid-1" },
            "winnerId": "take-uuid-1",
            "loserWasBlank": false,
            "pointsAwarded": 50,
            "revealed": true
          }
        }
      }
    }
  }
}
```

**Key schema notes:**
- Pairs are stored under string numeric keys (`"0"`, `"1"`, …) so `currentPairIndex` maps directly
- `playerId` on takes is readable only when `phase` is `revealing`, `round_leaderboard`, or `final_leaderboard` (enforced by security rules — anonymous voting enforcement)
- `roundRanks["0"]` = all tied at rank 1 before any round, ensuring round 1 leaderboard always shows "—" movement

---

## Cloud Functions

All 5 functions use `onValueWritten` triggers (Firebase Functions v2, Gen 2).

### `fillBlanksAndPair`
**Trigger:** `phase` written to `"pairing_requested"`

1. Finds all players where `submittedTakes == false` and writes 2 blank takes for each
2. Shuffles all takes and greedily pairs them
3. Validates: no player's 2 takes face each other (up to 20 shuffle attempts)
4. Reorders pairs to avoid back-to-back same-player matchups
5. Writes `pairs/round-N` and advances `phase → voting`, resets `timerEndsAt`

### `onVoteWrite`
**Trigger:** Any vote written to `pairs/{round}/{pairIdx}/votes/{voterId}`

Checks if all eligible voters have voted (total players − 2 submitters). If yes, immediately calls `tallyAndReveal` without waiting for the timer.

### `onTallyTrigger`
**Trigger:** Host writes `tallyTrigger` (when voting timer expires)

Calls `tallyAndReveal` with whatever votes have been cast so far.

### `onComputeLeaderboard`
**Trigger:** Host writes `computeLeaderboardTrigger` (after last pair reveal)

Sorts players by `totalScore`, writes `roundRanks[N]` for all players.

### `onCloseRequested`
**Trigger:** Host writes `closeRequested: true` (final leaderboard screen)

Deletes the entire `rooms/{roomId}` node. Zero data retained post-session.

---

## Pairing Algorithm

```typescript
for (let attempt = 0; attempt < 20; attempt++) {
  shuffle(takeIds)
  pair adjacently: [0,1], [2,3], [4,5]...
  if any pair has same playerId → retry
  reorder to avoid back-to-back same matchup
  return pairs
}
// fallback: pair without constraint (theoretical edge case only)
```

**Constraints enforced:**
1. A player's own 2 takes are never paired against each other
2. No two consecutive pairs in the same round involve the exact same player matchup

---

## Blank Take Handling

When the 90s submission timer expires, the host client writes `phase = "pairing_requested"`. The `fillBlanksAndPair` Cloud Function then:

- Writes 2 blank takes (`isBlank: true`, `text: ""`) for every non-submitter
- Blank takes get paired like any other take
- Any pair with `hasBlank: true` skips voting entirely — the non-blank take wins automatically for 100 pts
- On the reveal screen, blank submitters are shown with a shame message instead of their take text

---

## Security Rules

```json
{
  "rooms/$roomId": {
    ".read": "auth != null",
    ".write": "auth != null",
    "players/$playerId": {
      ".write": "auth.uid == $playerId || hostId == auth.uid"
    },
    "categories": {
      ".write": "hostId == auth.uid"
    },
    "takes/$round/$takeId/playerId": {
      ".read": "phase == 'revealing' || phase == 'round_leaderboard' || phase == 'final_leaderboard'"
    }
  }
}
```

The `playerId` field on takes is unreadable during `voting` phase — clients can only see `text` and `isBlank`. This enforces voting anonymity at the database level.

---

## Disconnect & Rejoin

- Firebase `onDisconnect()` handler sets `players/{uid}/connected = false` automatically when a phone drops
- Disconnected players show as grayed out in lobby/leaderboard
- Firebase Anonymous Auth UUID is generated once per device and persists across app launches
- To rejoin: enter the room code (always visible on-screen) → if the UUID matches an existing player, session is restored; `connected` is set back to `true`
- If the player reinstalled (lost UUID), they rejoin as a new player; the ghost entry remains until the room is deleted

---

## Development Setup

### Prerequisites

- Xcode 15+ (iOS 17 SDK)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools`
- Node.js 22+
- Firebase project on the **Blaze** (pay-as-you-go) plan (required for Cloud Functions)

### First-Time Setup

```bash
# 1. Generate Xcode project
xcodegen generate

# 2. Install Cloud Functions dependencies
cd functions && npm install

# 3. Log in to Firebase
firebase login

# 4. Deploy security rules + functions
npm run build
cd .. && firebase deploy
```

Then open `HotTakes.xcodeproj` in Xcode, connect your iPhone via USB, select your device, and build (⌘R).

> **Note:** Free Apple Developer accounts have a 7-day signing certificate expiry. You'll need to rebuild and reinstall on the device every 7 days. A paid Apple Developer account ($99/yr) removes this limitation and enables App Store distribution.

### Regenerate Xcode Project (after changing `project.yml`)

```bash
xcodegen generate
```

### Deploy Cloud Functions Only

```bash
cd functions && npm run build && cd .. && firebase deploy --only functions
```

### Deploy Security Rules Only

```bash
firebase deploy --only database
```

---

## Firebase Config

| Setting | Value |
|---|---|
| Project ID | `hot-takes-app-c5bc0` |
| Bundle ID | `com.architb17.hottakes` |
| Apple Team ID | `RB6R63JK2B` |
| Functions region | `us-central1` |
| Node runtime | 22 (Gen 2) |
| Monthly cost | $0 (Firebase free tier) |

---

## App Store Submission Checklist

When ready to distribute:

- [ ] Set age rating to **17+** in App Store Connect
- [ ] Enable "Frequent/Intense Mature/Suggestive Themes" in content rating questionnaire
- [ ] App description must clearly state "Adults only — contains adult humor and mature content"
- [ ] Add a privacy policy URL (Firebase Anonymous Auth collects a device-scoped identifier)
- [ ] Upgrade to paid Apple Developer account ($99/yr) before TestFlight/App Store submission
- [ ] Test on at minimum 3 physical devices simultaneously
- [ ] Verify Cloud Functions handle concurrent rooms without collision

---

## Multiplayer Test Checklist

- [ ] Room create + join flow from 2+ separate devices
- [ ] Room code visible persistently on all in-game screens
- [ ] Category editing: host can edit freely; "Lock In" advances phase; non-hosts see waiting state
- [ ] Takes submission: 90s timer counts down identically on all devices
- [ ] Blank take: timer expiry → blank fill → voting skipped → 100 pts auto-awarded → shame UI on reveal
- [ ] Voting: submitters cannot vote on their own pair; vote hidden from UI before reveal
- [ ] Scoring: 50/100/25 pts correct for split/unanimous/tied; 100 pts for blank
- [ ] Rank movement arrows correct after each round (↑↓—)
- [ ] Disconnect: player shows as grayed out; can rejoin with room code and restore session
- [ ] Full 3-round game completes without errors
- [ ] Room node deleted from Firebase after final leaderboard confirmed
