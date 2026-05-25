struct PairModel: Identifiable, Sendable {
    let id: String        // string index "0", "1", etc.
    let take1Id: String
    let take2Id: String
    var hasBlank: Bool
    var votes: [String: String]   // voterId → takeId
    var winnerId: String?
    var loserWasBlank: Bool
    var pointsAwarded: Int?
    var revealed: Bool

    init(id: String, dict: [String: Any]) {
        self.id = id
        take1Id = dict["take1Id"] as? String ?? ""
        take2Id = dict["take2Id"] as? String ?? ""
        hasBlank = dict["hasBlank"] as? Bool ?? false
        votes = dict["votes"] as? [String: String] ?? [:]
        winnerId = dict["winnerId"] as? String
        loserWasBlank = dict["loserWasBlank"] as? Bool ?? false
        pointsAwarded = dict["pointsAwarded"] as? Int
        revealed = dict["revealed"] as? Bool ?? false
    }

    func voteCount(for takeId: String) -> Int {
        votes.values.filter { $0 == takeId }.count
    }
}
