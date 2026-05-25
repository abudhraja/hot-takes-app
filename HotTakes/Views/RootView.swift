import SwiftUI

struct RootView: View {
    @State private var vm = GameViewModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.htBackground.ignoresSafeArea()

            Group {
                if !vm.isInRoom {
                    HomeView()
                } else {
                    switch vm.phase {
                    case .joining:
                        LobbyView()
                    case .categories:
                        CategoriesView()
                    case .submitting, .pairingRequested:
                        SubmitView()
                    case .voting:
                        VotingView()
                    case .revealing:
                        RevealView()
                    case .roundLeaderboard:
                        RoundLeaderboardView()
                    case .finalLeaderboard:
                        FinalLeaderboardView()
                    }
                }
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.3)))

            if vm.isInRoom {
                RoomCodeChip(code: vm.roomCode)
                    .padding(.top, 56)
                    .padding(.trailing, 16)
            }
        }
        .environment(vm)
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
