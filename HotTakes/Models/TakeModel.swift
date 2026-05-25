struct TakeModel: Identifiable, Sendable {
    let id: String
    let playerId: String
    var text: String
    var isBlank: Bool

    init(id: String, dict: [String: Any]) {
        self.id = id
        playerId = dict["playerId"] as? String ?? ""
        text = dict["text"] as? String ?? ""
        isBlank = dict["isBlank"] as? Bool ?? false
    }
}
