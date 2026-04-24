import Foundation
import SwiftUI
import Supabase
import Auth
import PostgREST
import SwiftData

@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = true
    var errorMessage: String?

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        defer { isLoading = false }
        if let session = try? await supabase.auth.session {
            currentUser = session.user
            isAuthenticated = true
        }

        // Listen for auth state changes
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn, .tokenRefreshed:
                    currentUser = session?.user
                    isAuthenticated = true
                case .signedOut:
                    currentUser = nil
                    isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    func signInWithMagicLink(email: String) async {
        errorMessage = nil
        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: AppConfig.deepLinkRedirect
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            currentUser = response.user
            isAuthenticated = response.session != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleDeepLink(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ensureStudentProfile(context: ModelContext) async {
        guard let user = currentUser else { return }
        // Register device_id on first launch
        let descriptor = FetchDescriptor<DeviceInfo>()
        let existing = try? context.fetch(descriptor)
        if existing?.isEmpty ?? true {
            let info = DeviceInfo(deviceId: UUID().uuidString, userId: user.id.uuidString)
            context.insert(info)
            try? context.save()

            // Upsert student record in Supabase
            try? await supabase
                .from("students")
                .upsert(StudentRecord(
                    id: user.id.uuidString,
                    email: user.email ?? "",
                    name: user.email?.components(separatedBy: "@").first ?? "",
                    device_id: info.deviceId
                ))
                .execute()
        }
    }
}

struct StudentRecord: Encodable {
    let id: String
    let email: String
    let name: String
    let device_id: String
}
