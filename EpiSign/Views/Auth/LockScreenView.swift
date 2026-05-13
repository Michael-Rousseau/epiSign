import SwiftUI

struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var biometric = BiometricAuthManager()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.6))

            Text("EpiSign")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Authentifiez-vous pour continuer")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            Button {
                Task { await authenticate() }
            } label: {
                Text("Déverrouiller")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.white))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await authenticate()
        }
    }

    private func authenticate() async {
        await biometric.authenticate()
        if biometric.isUnlocked {
            onUnlock()
        }
    }
}
