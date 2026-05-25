import SwiftUI

struct VotingView: View {
    @Environment(GameViewModel.self) private var vm

    private let timerTotal = 20

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            VStack(spacing: 4) {
                Text("ROUND \(vm.currentRound) · PAIR \(vm.currentPairIndex + 1)/\(vm.pairsForRound.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(2)
                Text(vm.currentCategory)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            TimerBar(remaining: vm.timeRemaining, total: timerTotal)
                .padding(.horizontal, 24)

            if vm.hasVoted || !vm.canVoteOnCurrentPair {
                WaitingForVotesView()
            } else {
                VoteCardsView()
            }

            Spacer()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if vm.isHost && vm.phase == .voting && vm.timeRemaining == 0 {
                    await vm.requestTally()
                    break
                }
            }
        }
    }
}

private struct VoteCardsView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var selected: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("TAP TO VOTE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(3)

            if let t1 = vm.take1ForCurrentPair {
                VoteCard(take: t1, isSelected: selected == t1.id) {
                    selected = t1.id
                    Task { await vm.vote(for: t1.id) }
                }
            }

            Text("VS")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.htAccent)

            if let t2 = vm.take2ForCurrentPair {
                VoteCard(take: t2, isSelected: selected == t2.id) {
                    selected = t2.id
                    Task { await vm.vote(for: t2.id) }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct VoteCard: View {
    let take: TakeModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.htAccent : Color.htCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.htAccent : Color.clear, lineWidth: 2)
                    )

                if take.isBlank {
                    VStack(spacing: 8) {
                        Text("🦗")
                            .font(.system(size: 40))
                        Text("(crickets)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(28)
                } else {
                    Text(take.text)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(28)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private struct WaitingForVotesView: View {
    @Environment(GameViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 20) {
            if !vm.canVoteOnCurrentPair && !(vm.players[vm.playerId]?.hasVoted ?? false) {
                // This player is a submitter
                Text("You're in this one — no voting for you!")
                    .font(.system(size: 18, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.htGreen)
                Text("Vote cast!")
                    .font(.system(size: 22, weight: .bold))
            }

            let voted = vm.players.values.filter { $0.hasVoted || !vm.canVote(player: $0) }.count
            Text("\(voted)/\(vm.playerCount) done")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.htAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

extension GameViewModel {
    func canVote(player: PlayerModel) -> Bool {
        guard let pair = currentPair else { return false }
        let s1 = takesForRound[pair.take1Id]?.playerId
        let s2 = takesForRound[pair.take2Id]?.playerId
        return player.id != s1 && player.id != s2
    }
}
