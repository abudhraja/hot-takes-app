import SwiftUI

struct RevealView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var appeared = false

    private var pair: PairModel? { vm.currentPair }
    private var winnerTake: TakeModel? {
        guard let p = pair, let wId = p.winnerId else { return nil }
        return vm.takesForRound[wId]
    }
    private var loserTake: TakeModel? {
        guard let p = pair, let wId = p.winnerId else { return nil }
        let loserId = p.take1Id == wId ? p.take2Id : p.take1Id
        return vm.takesForRound[loserId]
    }
    private var winnerPlayer: PlayerModel? {
        winnerTake.flatMap { vm.players[$0.playerId] }
    }
    private var loserPlayer: PlayerModel? {
        loserTake.flatMap { vm.players[$0.playerId] }
    }
    private var points: Int { pair?.pointsAwarded ?? 0 }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            Text("THE PEOPLE HAVE SPOKEN")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(3)

            // Winner
            if let winner = winnerPlayer, let take = winnerTake {
                VStack(spacing: 14) {
                    Text("🏆 WINNER")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.htGold)
                        .tracking(3)

                    VStack(spacing: 10) {
                        Text(take.isBlank ? "(submitted nothing — opponent's default win)" : take.text)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text("— \(winner.nickname)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.htGold)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color.htGold.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.htGold, lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    Text("+\(points) pts")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color.htGold)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
            }

            // Loser / shame
            if let loser = loserPlayer, let take = loserTake {
                VStack(spacing: 10) {
                    if take.isBlank || (pair?.loserWasBlank ?? false) {
                        Text("💀 HALL OF SHAME")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.htDanger)
                            .tracking(3)
                        Text("\(loser.nickname) submitted nothing.")
                            .font(.system(size: 17, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text("Absolutely disgraceful.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("— \(loser.nickname): \"\(take.text)\"")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.6), value: appeared)
            }

            Spacer()

            if vm.isHost {
                Text("Advancing in 4 seconds...")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                appeared = true
            }
        }
        .task {
            guard vm.isHost else { return }
            try? await Task.sleep(for: .seconds(4))
            await vm.advancePairReveal()
        }
    }
}
