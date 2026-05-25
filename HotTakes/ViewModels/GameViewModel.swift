import Foundation
import FirebaseAuth
import FirebaseDatabase

enum GameError: LocalizedError {
    case notAuthenticated
    case roomNotFound
    case gameAlreadyStarted

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "Still signing in — please try again."
        case .roomNotFound:        return "Room not found. Check the code and try again."
        case .gameAlreadyStarted:  return "This game has already started."
        }
    }
}

@MainActor
@Observable
final class GameViewModel {

    // MARK: - Navigation
    var isInRoom = false
    var roomCode = ""
    var errorMessage: String?
    var isLoading = false

    // MARK: - Auth
    private(set) var playerId = ""

    // MARK: - Room state (live from Firebase)
    private(set) var phase: GamePhase = .joining
    private(set) var hostId = ""
    private(set) var currentRound = 1
    private(set) var currentPairIndex = 0
    private(set) var categoriesLocked = false
    private(set) var timerEndsAt: Double = 0
    private(set) var categories: [String: String] = [:]
    private(set) var players: [String: PlayerModel] = [:]
    private(set) var takesForRound: [String: TakeModel] = [:]
    private(set) var pairsForRound: [String: PairModel] = [:]  // "0","1",… → PairModel

    // MARK: - Computed
    var isHost: Bool { hostId == playerId }
    var currentPlayer: PlayerModel? { players[playerId] }
    var currentCategory: String { categories[String(currentRound)] ?? "" }
    var hasSubmittedTakes: Bool { players[playerId]?.submittedTakes ?? false }
    var hasVoted: Bool { players[playerId]?.hasVoted ?? false }
    var allPlayersSubmitted: Bool { !players.isEmpty && players.values.allSatisfy { $0.submittedTakes } }
    var playerCount: Int { players.count }

    var sortedPlayers: [PlayerModel] {
        players.values.sorted { $0.totalScore > $1.totalScore }
    }

    var currentPair: PairModel? {
        pairsForRound[String(currentPairIndex)]
    }

    var timeRemaining: Int {
        guard timerEndsAt > 0 else { return 0 }
        let ms = timerEndsAt - Date().timeIntervalSince1970 * 1000
        return max(0, Int(ms / 1000))
    }

    var canVoteOnCurrentPair: Bool {
        guard let pair = currentPair else { return false }
        let submitters = [takesForRound[pair.take1Id]?.playerId,
                          takesForRound[pair.take2Id]?.playerId].compactMap { $0 }
        return !submitters.contains(playerId) && !hasVoted
    }

    var take1ForCurrentPair: TakeModel? {
        currentPair.flatMap { takesForRound[$0.take1Id] }
    }

    var take2ForCurrentPair: TakeModel? {
        currentPair.flatMap { takesForRound[$0.take2Id] }
    }

    // MARK: - Firebase refs
    private let db = Database.database().reference()
    private var roomHandle: DatabaseHandle?
    private var roomRef: DatabaseReference?

    // MARK: - Init
    init() {
        Task { await signInAnonymously() }
    }

    // MARK: - Auth

    private func signInAnonymously() async {
        if let uid = Auth.auth().currentUser?.uid {
            playerId = uid
            return
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            playerId = result.user.uid
        } catch {
            errorMessage = "Authentication failed — please restart the app."
        }
    }

    // MARK: - Room lifecycle

    func createRoom(nickname: String) async {
        guard !playerId.isEmpty else { errorMessage = GameError.notAuthenticated.errorDescription; return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let code = generateRoomCode()
        let ref = db.child("rooms/\(code)")
        do {
            let existing = try await ref.getData()
            if existing.exists() { await createRoom(nickname: nickname); return }

            try await ref.setValue(initialRoomData(code: code, nickname: nickname))
            _ = try? await ref.child("players/\(playerId)/connected").onDisconnectSetValue(false)
            activate(code: code)
        } catch {
            errorMessage = "Could not create room: \(error.localizedDescription)"
        }
    }

    func joinRoom(code: String, nickname: String) async {
        guard !playerId.isEmpty else { errorMessage = GameError.notAuthenticated.errorDescription; return }
        let upper = code.uppercased().trimmingCharacters(in: .whitespaces)
        guard upper.count == 4 else { errorMessage = "Room code must be 4 letters."; return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let ref = db.child("rooms/\(upper)")
        do {
            let snapshot = try await ref.getData()
            guard snapshot.exists(), let dict = snapshot.value as? [String: Any] else {
                errorMessage = GameError.roomNotFound.errorDescription; return
            }

            let existingPlayers = dict["players"] as? [String: Any] ?? [:]
            if existingPlayers[playerId] != nil {
                try await ref.child("players/\(playerId)/connected").setValue(true)
            } else {
                guard dict["phase"] as? String == GamePhase.joining.rawValue else {
                    errorMessage = GameError.gameAlreadyStarted.errorDescription; return
                }
                try await ref.child("players/\(playerId)").setValue(blankPlayerData(nickname: nickname))
            }

            _ = try? await ref.child("players/\(playerId)/connected").onDisconnectSetValue(false)
            activate(code: upper)
        } catch {
            errorMessage = "Could not join room: \(error.localizedDescription)"
        }
    }

    func leaveRoom() {
        stopListening()
        isInRoom = false
        roomCode = ""
        resetLocalState()
    }

    // MARK: - Host actions

    func startGame() async {
        guard isHost else { return }
        _ = try? await db.child("rooms/\(roomCode)/phase").setValue(GamePhase.categories.rawValue)
    }

    func updateCategory(_ text: String, forSlot slot: Int) async {
        guard isHost else { return }
        _ = try? await db.child("rooms/\(roomCode)/categories/\(slot)").setValue(text)
    }

    func lockInCategories() async {
        guard isHost else { return }
        let timerEnd = (Date().timeIntervalSince1970 + 90) * 1000
        var updates: [String: Any] = [
            "categoriesLocked": true,
            "phase": GamePhase.submitting.rawValue,
            "timerEndsAt": timerEnd
        ]
        for id in players.keys {
            updates["players/\(id)/submittedTakes"] = false
            updates["players/\(id)/hasVoted"] = false
        }
        _ = try? await db.child("rooms/\(roomCode)").updateChildValues(updates)
    }

    /// Called by host when submission timer fires or all players have submitted.
    /// Writes a sentinel that triggers the Cloud Function to fill blanks and generate pairs.
    func requestPairing() async {
        guard isHost else { return }
        _ = try? await db.child("rooms/\(roomCode)/phase").setValue(GamePhase.pairingRequested.rawValue)
    }

    /// Called by host when voting timer fires. Triggers Cloud Function to tally with current votes.
    func requestTally() async {
        guard isHost else { return }
        _ = try? await db.child("rooms/\(roomCode)/tallyTrigger").setValue(ServerValue.timestamp())
    }

    func startNextRound() async {
        guard isHost else { return }
        let next = currentRound + 1
        let timerEnd = (Date().timeIntervalSince1970 + 90) * 1000
        var updates: [String: Any] = [
            "currentRound": next,
            "currentPairIndex": 0,
            "phase": GamePhase.submitting.rawValue,
            "timerEndsAt": timerEnd
        ]
        for id in players.keys {
            updates["players/\(id)/submittedTakes"] = false
            updates["players/\(id)/hasVoted"] = false
        }
        _ = try? await db.child("rooms/\(roomCode)").updateChildValues(updates)
    }

    /// Host calls 4 seconds after a reveal to advance to next pair or leaderboard phase.
    func advancePairReveal() async {
        guard isHost else { return }
        let nextIndex = currentPairIndex + 1
        if nextIndex >= pairsForRound.count {
            // All pairs done — compute leaderboard (Cloud Function handles rank writing)
            let phase: GamePhase = currentRound >= 3 ? .finalLeaderboard : .roundLeaderboard
            _ = try? await db.child("rooms/\(roomCode)").updateChildValues([
                "phase": phase.rawValue,
                "computeLeaderboardTrigger": ServerValue.timestamp()
            ])
        } else {
            let timerEnd = (Date().timeIntervalSince1970 + 20) * 1000
            var updates: [String: Any] = [
                "currentPairIndex": nextIndex,
                "phase": GamePhase.voting.rawValue,
                "timerEndsAt": timerEnd
            ]
            for id in players.keys { updates["players/\(id)/hasVoted"] = false }
            _ = try? await db.child("rooms/\(roomCode)").updateChildValues(updates)
        }
    }

    /// Host advances directly to final leaderboard from round leaderboard screen.
    func advanceToFinalLeaderboard() async {
        guard isHost else { return }
        _ = try? await db.child("rooms/\(roomCode)/phase").setValue(GamePhase.finalLeaderboard.rawValue)
    }

    func closeGame() async {
        guard isHost else { return }
        _ = try? await db.child("rooms/\(roomCode)/closeRequested").setValue(true)
    }

    // MARK: - Player actions

    func submitTakes(take1: String, take2: String) async {
        let roundKey = "round-\(currentRound)"
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        let updates: [String: Any] = [
            "takes/\(roundKey)/\(id1)": takePayload(text: take1),
            "takes/\(roundKey)/\(id2)": takePayload(text: take2),
            "players/\(playerId)/submittedTakes": true
        ]
        _ = try? await db.child("rooms/\(roomCode)").updateChildValues(updates)
    }

    func vote(for takeId: String) async {
        guard canVoteOnCurrentPair else { return }
        let pairPath = "rooms/\(roomCode)/pairs/round-\(currentRound)/\(currentPairIndex)"
        _ = try? await db.child("\(pairPath)/votes/\(playerId)").setValue(takeId)
        _ = try? await db.child("rooms/\(roomCode)/players/\(playerId)/hasVoted").setValue(true)
    }

    // MARK: - Firebase listener

    private func activate(code: String) {
        roomCode = code
        isInRoom = true
        startListening(to: code)
    }

    private func startListening(to code: String) {
        let ref = db.child("rooms/\(code)")
        roomRef = ref
        roomHandle = ref.observe(.value) { [weak self] snapshot in
            let raw = snapshot.value as? [String: Any] ?? [:]
            Task { @MainActor [weak self] in self?.parseRoom(raw) }
        } withCancel: { [weak self] error in
            Task { @MainActor [weak self] in
                self?.errorMessage = "Connection lost: \(error.localizedDescription)"
            }
        }
    }

    private func stopListening() {
        if let h = roomHandle, let ref = roomRef { ref.removeObserver(withHandle: h) }
        roomHandle = nil
        roomRef = nil
    }

    private func parseRoom(_ dict: [String: Any]) {
        phase = GamePhase(rawValue: dict["phase"] as? String ?? "") ?? .joining
        hostId = dict["hostId"] as? String ?? ""
        currentRound = dict["currentRound"] as? Int ?? 1
        currentPairIndex = dict["currentPairIndex"] as? Int ?? 0
        categoriesLocked = dict["categoriesLocked"] as? Bool ?? false
        timerEndsAt = dict["timerEndsAt"] as? Double ?? 0

        categories = dict["categories"] as? [String: String] ?? [:]

        var parsedPlayers: [String: PlayerModel] = [:]
        for (id, val) in (dict["players"] as? [String: Any] ?? [:]) {
            if let d = val as? [String: Any] { parsedPlayers[id] = PlayerModel(id: id, dict: d) }
        }
        players = parsedPlayers

        let roundKey = "round-\(currentRound)"

        var parsedTakes: [String: TakeModel] = [:]
        let roundTakes = (dict["takes"] as? [String: Any] ?? [:])[roundKey] as? [String: Any] ?? [:]
        for (id, val) in roundTakes {
            if let d = val as? [String: Any] { parsedTakes[id] = TakeModel(id: id, dict: d) }
        }
        takesForRound = parsedTakes

        var parsedPairs: [String: PairModel] = [:]
        let roundPairs = (dict["pairs"] as? [String: Any] ?? [:])[roundKey] as? [String: Any] ?? [:]
        for (idxStr, val) in roundPairs {
            if let d = val as? [String: Any] { parsedPairs[idxStr] = PairModel(id: idxStr, dict: d) }
        }
        pairsForRound = parsedPairs
    }

    private func resetLocalState() {
        phase = .joining; hostId = ""; currentRound = 1; currentPairIndex = 0
        categoriesLocked = false; timerEndsAt = 0; categories = [:]
        players = [:]; takesForRound = [:]; pairsForRound = [:]
    }

    // MARK: - Data helpers

    private func initialRoomData(code: String, nickname: String) -> [String: Any] {
        [
            "code": code,
            "phase": GamePhase.joining.rawValue,
            "currentRound": 1,
            "currentPairIndex": 0,
            "hostId": playerId,
            "categoriesLocked": false,
            "timerEndsAt": 0,
            "categories": ["1": "", "2": "", "3": ""],
            "players": [playerId: blankPlayerData(nickname: nickname)],
            "takes": [:] as [String: Any],
            "pairs": [:] as [String: Any]
        ]
    }

    private func blankPlayerData(nickname: String) -> [String: Any] {
        [
            "nickname": nickname,
            "totalScore": 0,
            "roundScores": ["1": 0, "2": 0, "3": 0],
            "roundRanks": ["0": 1, "1": 0, "2": 0, "3": 0],
            "submittedTakes": false,
            "hasVoted": false,
            "connected": true
        ]
    }

    private func takePayload(text: String) -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["playerId": playerId, "text": trimmed, "isBlank": trimmed.isEmpty]
    }

    private func generateRoomCode() -> String {
        let chars = Array("BCDFGHJKLMNPQRSTVWXYZ")
        return String((0..<4).map { _ in chars.randomElement()! })
    }
}
