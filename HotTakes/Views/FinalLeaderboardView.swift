import SwiftUI

struct FinalLeaderboardView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var appeared = false

    private var winner: PlayerModel? { vm.sortedPlayers.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 30)

                VStack(spacing: 10) {
                    Text("🏆")
                        .font(.system(size: 70))
                        .scaleEffect(appeared ? 1 : 0.3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

                    if let w = winner {
                        Text(w.nickname)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(Color.htGold)
                        Text("wins with \(w.totalScore) pts")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Divider().background(.white.opacity(0.15)).padding(.horizontal, 24)

                VStack(spacing: 10) {
                    Text("FINAL STANDINGS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)

                    ForEach(Array(vm.sortedPlayers.enumerated()), id: \.element.id) { rank, player in
                        FinalRow(player: player, rank: rank + 1)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.3 + Double(rank) * 0.07), value: appeared)
                    }
                }
                .padding(.horizontal, 24)

                Divider().background(.white.opacity(0.15)).padding(.horizontal, 24)

                // Round-by-round breakdown
                VStack(spacing: 8) {
                    Text("BY ROUND")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)

                    HStack {
                        Text("Player").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        ForEach(1...3, id: \.self) { r in
                            Text("R\(r)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).frame(width: 40, alignment: .center)
                        }
                        Text("Total").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).frame(width: 50, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)

                    ForEach(vm.sortedPlayers) { player in
                        HStack {
                            Text(player.nickname).font(.system(size: 14, weight: .medium)).lineLimit(1)
                            Spacer()
                            ForEach(1...3, id: \.self) { r in
                                Text("\(player.roundScores[String(r)] ?? 0)")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 40, alignment: .center)
                            }
                            Text("\(player.totalScore)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(Color.htGold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(20)
                .background(Color.htCard)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)

                if vm.isHost {
                    Button("End Game") { Task { await vm.closeGame() } }
                        .buttonStyle(HTButtonStyle(color: Color.htCard))
                        .padding(.horizontal, 24)
                }

                Button("Leave") { vm.leaveRoom() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

private struct FinalRow: View {
    let player: PlayerModel
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(rank <= 3 ? ["🥇","🥈","🥉"][rank - 1] : "\(rank).")
                .font(.system(size: 20))
                .frame(width: 32)
            Text(player.nickname)
                .font(.system(size: 17, weight: .bold))
            Spacer()
            Text("\(player.totalScore) pts")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.htGold)
        }
        .padding(14)
        .background(rank == 1 ? Color.htGold.opacity(0.1) : Color.htCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
