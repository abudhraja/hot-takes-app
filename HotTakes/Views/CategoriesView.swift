import SwiftUI

struct CategoriesView: View {
    @Environment(GameViewModel.self) private var vm
    @State private var cat1 = ""
    @State private var cat2 = ""
    @State private var cat3 = ""

    private var allFilled: Bool {
        !cat1.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cat2.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cat3.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                VStack(spacing: 6) {
                    Text("ROUND CATEGORIES")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(3)
                    Text(vm.isHost ? "Set the topics" : "Host is setting up...")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }

                if vm.isHost {
                    VStack(spacing: 16) {
                        ForEach(Array(zip([cat1, cat2, cat3].indices, ["🔥 Round 1", "💀 Round 2", "🤯 Round 3"])), id: \.0) { idx, label in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(label)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .tracking(2)
                                TextField(examplePrompt(for: idx), text: binding(for: idx))
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(16)
                                    .background(Color.htCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .autocorrectionDisabled()
                                    .onChange(of: binding(for: idx).wrappedValue) { _, new in
                                        Task { await vm.updateCategory(new, forSlot: idx + 1) }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Button("Lock In & Start Round 1") {
                        Task {
                            await vm.updateCategory(cat1, forSlot: 1)
                            await vm.updateCategory(cat2, forSlot: 2)
                            await vm.updateCategory(cat3, forSlot: 3)
                            await vm.lockInCategories()
                        }
                    }
                    .buttonStyle(HTButtonStyle())
                    .padding(.horizontal, 24)
                    .disabled(!allFilled)
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(Color.htAccent)
                            .scaleEffect(1.5)
                        Text("The host is picking your fate...")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }

                Spacer(minLength: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            cat1 = vm.categories["1"] ?? ""
            cat2 = vm.categories["2"] ?? ""
            cat3 = vm.categories["3"] ?? ""
        }
        .onChange(of: vm.categories) { _, new in
            if !vm.isHost {
                cat1 = new["1"] ?? ""
                cat2 = new["2"] ?? ""
                cat3 = new["3"] ?? ""
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        switch index {
        case 0: return $cat1
        case 1: return $cat2
        default: return $cat3
        }
    }

    private func examplePrompt(for index: Int) -> String {
        ["Most controversial political hot take",
         "Most overrated actor/actress",
         "Best unpopular food opinion"][index]
    }
}
