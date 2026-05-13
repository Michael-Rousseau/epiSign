import LocalAuthentication
import SwiftUI

@Observable
final class BiometricAuthManager {
    var isUnlocked = false
    var isEvaluating = false

    func authenticate() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            await MainActor.run { isUnlocked = true }
            return
        }

        await MainActor.run { isEvaluating = true }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Déverrouillez EpiSign"
            )
            await MainActor.run {
                isUnlocked = success
                isEvaluating = false
            }
        } catch {
            await MainActor.run { isEvaluating = false }
        }
    }
}
