import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL = URL(string: "https://pejwdqcfbdridzioblwq.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_0LwHrv_C4Aj5-ntXIy6oGQ_L2oK1CDo"
    static let deepLinkScheme = "episign"
    static let deepLinkRedirect = URL(string: "episign://login-callback")!
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
