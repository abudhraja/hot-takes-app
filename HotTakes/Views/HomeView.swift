import SwiftUI

struct HomeView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var nickname = ""
    @State private var roomCodeInput = ""
    @State private var showJoin = false

    var canProceed: Bool { nickname.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                VStack(spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 80))
                    Text("HOT TAKES")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Color.htAccent)
                    Text("The NSFW opinion battle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NAME")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                    TextField("Nickname", text: $nickname)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(16)
                        .background(Color.htCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    Button("Create Room") {
                        Task { await vm.createRoom(nickname: nickname.trimmingCharacters(in: .whitespaces)) }
                    }
                    .buttonStyle(HTButtonStyle())
                    .disabled(!canProceed || vm.isLoading)

                    Button("Join Room") { showJoin.toggle() }
                        .buttonStyle(HTButtonStyle(color: Color.htCard))
                        .disabled(!canProceed)
                }
                .padding(.horizontal, 24)

                if showJoin {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROOM CODE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(2)
                        HStack(spacing: 12) {
                            TextField("XKCD", text: $roomCodeInput)
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .background(Color.htCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .onChange(of: roomCodeInput) { _, new in
                                    roomCodeInput = String(new.uppercased().filter { $0.isLetter }.prefix(4))
                                }

                            Button("Join") {
                                Task {
                                    await vm.joinRoom(
                                        code: roomCodeInput,
                                        nickname: nickname.trimmingCharacters(in: .whitespaces)
                                    )
                                }
                            }
                            .buttonStyle(HTButtonStyle(color: .htAccent, fullWidth: false))
                            .disabled(roomCodeInput.count < 4 || vm.isLoading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if vm.isLoading {
                    ProgressView().tint(.htAccent)
                }

                Spacer(minLength: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
