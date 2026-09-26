import Foundation

/// This file IS committed, but only ever with these placeholder values —
/// that's deliberate: `NivaraPatient.xcodeproj` references it as a real
/// source file, so a fresh checkout (or Xcode Cloud, which clones fresh
/// from git with no local setup step) needs *something* here to compile
/// at all, and the placeholder values below make `isConfigured` false,
/// which is exactly the documented "no Supabase project configured"
/// fallback the rest of the app already handles gracefully.
///
/// To point your local checkout at a real Supabase project, fill in your
/// project's values from Project Settings → API in the Supabase
/// dashboard, then immediately run:
///   `git update-index --skip-worktree ios/NivaraPatient/NivaraPatient/Services/SupabaseConfig.swift`
/// That tells git to stop tracking further changes to this file, so your
/// real keys never show up in `git status`/`git add` and can't get
/// committed by accident. `git update-index --no-skip-worktree ...` (same
/// path) undoes that if you ever need to intentionally change the
/// committed placeholder itself.
///
/// The anon (publishable) key is safe to ship in the app binary — it's
/// meant to be public and relies entirely on the Row Level Security
/// policies in supabase/migrations/0001_init.sql to restrict what it can
/// actually read or write. Never put a service role key here; that one
/// bypasses RLS and belongs only in the web app's server-side env vars
/// (see .env.local.example at the repo root).
enum SupabaseConfig {
    static let urlString = "https://your-project-ref.supabase.co"
    static let anonKey = "your-anon-key"

    /// False until both values above are actually filled in — every call in
    /// SupabaseService checks this and no-ops rather than crashing, so the
    /// app keeps working entirely on local/demo data with no Supabase
    /// project configured at all (a fresh checkout, or CI).
    static var isConfigured: Bool {
        !urlString.contains("your-project-ref") && !anonKey.contains("your-anon-key")
    }

    static var url: URL {
        URL(string: urlString)!
    }
}
