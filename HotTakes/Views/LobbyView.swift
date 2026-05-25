import SwiftUI

struct LobbyView: View {
    @Environment(GameViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            VStack(spacing: 6) {
                Text("WAITING ROOM")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
                HStack(spacing: 10) {
                    Text(vm.roomCode)
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.htAccent)
                    Button {
                        UIPasteboard.general.string = vm.roomCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Text("Share this code with your friends")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("\(vm.playerCount) PLAYER\(vm.playerCount == 1 ? "" : "S") JOINED")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)

                ForEach(Array(vm.players.values).sorted(by: { $0.nickname < $1.nickname })) { player in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(player.connected ? Color.htGreen : Color.white.opacity(0.2))
                            .frame(width: 10, height: 10)
                        Text(player.nickname)
                            .font(.system(size: 18, weight: .semibold))
                        if player.id == vm.hostId {
                            Text("HOST")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.htAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.htAccent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.htCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                if vm.isHost {
                    Button("Start Game") { Task { await vm.startGame() } }
                        .buttonStyle(HTButtonStyle())
                        .disabled(vm.playerCount < 2)
                        .padding(.horizontal, 24)

                    if vm.playerCount < 2 {
                        Text("Need at least 2 players")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    Text("Waiting for host to start...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Button("Leave Room") { vm.leaveRoom() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 20)
            }
        }
    }
}
