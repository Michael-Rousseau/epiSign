import SwiftUI
import SwiftData

@main
struct EpiSignApp: App {
    @State private var auth = AuthManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Course.self,
            Signature.self,
            DeviceInfo.self,
            LocalSignatureDraft.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else if auth.isAuthenticated {
                    MainTabView()
                        .onAppear { seedIfNeeded() }
                } else {
                    LoginView()
                }
            }
            .environment(auth)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                Task { await auth.handleDeepLink(url) }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedIfNeeded() {
        let context = sharedModelContainer.mainContext
        MockData.seed(context: context)

        // Sync from Supabase in background
        Task {
            let service = CourseService()
            try? await service.syncToLocal(context: context)
        }

        // Ensure student profile exists
        Task {
            await auth.ensureStudentProfile(context: context)
        }

        // Retry offline drafts
        Task {
            await retryOfflineDrafts(context: context)
        }
    }

    private func retryOfflineDrafts(context: ModelContext) async {
        let descriptor = FetchDescriptor<LocalSignatureDraft>()
        guard let drafts = try? context.fetch(descriptor), !drafts.isEmpty else { return }

        let service = SigningService()
        for draft in drafts {
            if draft.expiresAt < .now {
                context.delete(draft)
                continue
            }
            try? await service.submitOfflineDraft(draft: draft, context: context)
        }
    }
}
