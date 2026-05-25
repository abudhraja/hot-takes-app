enum GamePhase: String, Sendable, Equatable {
    case joining
    case categories
    case submitting
    case pairingRequested = "pairing_requested"
    case voting
    case revealing
    case roundLeaderboard = "round_leaderboard"
    case finalLeaderboard = "final_leaderboard"
}
