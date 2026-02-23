import Foundation
import Supabase

// MARK: - Supabase Client Singleton

enum SupabaseManager {

    static let client: SupabaseClient = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("SUPABASE_URL oder SUPABASE_ANON_KEY fehlt in Info.plist")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: .init(
                auth: .init(
                    storage: KeychainAuthLocalStorage(),
                    flowType: .pkce
                )
            )
        )
    }()
}
