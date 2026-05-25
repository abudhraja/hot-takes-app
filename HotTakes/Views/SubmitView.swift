import SwiftUI

struct SubmitView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var take1 = ""
    @State private var take2 = ""

    private let timerTotal = 90

    private var canSubmit: Bool {
        !take1.trimmingCharacters(in: .whitespaces).isEmpty &&
        !take2.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                VStack(spacing: 6) {
                    Text("ROUND \(vm.currentRound) OF 3")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                    Text(vm.currentCategory)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                TimerBar(remaining: vm.timeRemaining, total: timerTotal)
                    .padding(.horizontal, 24)

                if vm.hasSubmittedTakes {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.htGreen)
                        Text("Takes submitted!")
                            .font(.system(size: 22, weight: .bold))
                        Text("Waiting for others...")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.5))

                        let submitted = vm.players.values.filter { $0.submittedTakes }.count
                        Text("\(submitted)/\(vm.playerCount) submitted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.htAccent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    VStack(spacing: 16) {
                        Text("Drop your two hottest takes 🌶️")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.55))

                        VStack(spacing: 12) {
                            TakeInputField(text: $take1, label: "Take #1")
                            TakeInputField(text: $take2, label: "Take #2")
                        }
                        .padding(.horizontal, 24)

                        Button("Submit Takes") {
                            Task { await vm.submitTakes(take1: take1, take2: take2) }
                        }
                        .buttonStyle(HTButtonStyle())
                        .padding(.horizontal, 24)
                        .disabled(!canSubmit)
                    }
                }

                Spacer(minLength: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            // Host triggers pairing when timer hits 0 or everyone submits
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if vm.isHost && vm.phase == .submitting {
                    if vm.allPlayersSubmitted || vm.timeRemaining == 0 {
                        await vm.requestPairing()
                        break
                    }
                }
            }
        }
    }
}

private struct TakeInputField: View {
    @Binding var text: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(2)
            TextField("Your hot take...", text: $text, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(Color.htCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
