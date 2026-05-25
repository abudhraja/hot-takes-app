struct PlayerModel: Identifiable, Sendable {
    let id: String
    var nickname: String
    var totalScore: Int
    var roundScores: [String: Int]
    var roundRanks: [String: Int]
    var submittedTakes: Bool
    var hasVoted: Bool
    var connected: Bool

    init(id: String, dict: [String: Any]) {
        self.id = id
        nickname = dict["nickname"] as? String ?? "?"
        totalScore = dict["totalScore"] as? Int ?? 0
        roundScores = dict["roundScores"] as? [String: Int] ?? [:]
        roundRanks = dict["roundRanks"] as? [String: Int] ?? [:]
        submittedTakes = dict["submittedTakes"] as? Bool ?? false
        hasVoted = dict["hasVoted"] as? Bool ?? false
        connected = dict["connected"] as? Bool ?? true
    }

    /// Positive = moved up, negative = moved down, 0 = same.
    func rankMovement(afterRound round: Int) -> Int {
        let prev = roundRanks[String(round - 1)] ?? 1
        let curr = roundRanks[String(round)] ?? 1
        return prev - curr
    }
}
