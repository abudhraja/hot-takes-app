import SwiftUI

struct RoundLeaderboardView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var appeared = false

    private var isLastRound: Bool { vm.currentRound >= 3 }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            VStack(spacing: 6) {
                Text("ROUND \(vm.currentRound) COMPLETE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                Text("Leaderboard")
                    .font(.system(size: 34, weight: .black, design: .rounded))
            }

            VStack(spacing: 10) {
                ForEach(Array(vm.sortedPlayers.enumerated()), id: \.element.id) { rank, player in
                    LeaderboardRow(player: player, rank: rank + 1, round: vm.currentRound)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(rank) * 0.08), value: appeared)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            if vm.isHost {
                VStack(spacing: 12) {
                    if isLastRound {
                        Button("See Final Results 🏆") { Task { await vm.advanceToFinalLeaderboard() } }
                            .buttonStyle(HTButtonStyle(color: .htGold))
                    } else {
                        Button("Start Round \(vm.currentRound + 1)") { Task { await vm.startNextRound() } }
                            .buttonStyle(HTButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else {
                Text("Waiting for host...")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

private struct LeaderboardRow: View {
    let player: PlayerModel
    let rank: Int
    let round: Int

    private var movement: Int { player.rankMovement(afterRound: round) }
    private var movementIcon: String {
        if movement > 0 { return "arrow.up" }
        if movement < 0 { return "arrow.down" }
        return "minus"
    }
    private var movementColor: Color {
        if movement > 0 { return .htGreen }
        if movement < 0 { return .htDanger }
        return .white.opacity(0.3)
    }
    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)."
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(rankEmoji)
                .font(.system(size: 22))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.nickname)
                    .font(.system(size: 17, weight: .bold))
                Text("+\(player.roundScores[String(round)] ?? 0) this round")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: movementIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(movementColor)

                Text("\(player.totalScore)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.htGold)
            }
        }
        .padding(16)
        .background(rank == 1 ? Color.htGold.opacity(0.1) : Color.htCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(rank == 1 ? Color.htGold.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
