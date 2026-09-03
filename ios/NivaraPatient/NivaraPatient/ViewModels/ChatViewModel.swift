import Foundation
import Supabase

/// Backs one Care Team chat thread (patient ⟷ one coordinator role), reading
/// and writing the `messages` table directly and listening for new rows via
/// Supabase Realtime. One instance per open CareTeamConversationView.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draft: String = ""
    /// True once a patient row was found and history loaded — gates the
    /// composer, since there's nothing to send to/from until then (no
    /// Supabase project configured, registration hasn't happened yet, or
    /// the network is unreachable).
    @Published private(set) var isAvailable = false

    let role: CoordinatorRole

    private var patientId: UUID?
    private var realtimeTask: Task<Void, Never>?

    init(role: CoordinatorRole) {
        self.role = role
    }

    func start() async {
        do {
            guard let id = try await SupabaseService.fetchMyPatientId() else {
                isAvailable = false
                return
            }
            patientId = id
            await loadHistory(patientId: id)
            subscribeToNewMessages(patientId: id)
            isAvailable = true
        } catch {
            print("ChatViewModel.start failed: \(error)")
            isAvailable = false
        }
    }

    /// Cancels the Realtime subscription — call from the view's
    /// `.onDisappear` so an open thread doesn't keep listening (and
    /// publishing to a torn-down view) after the sheet is dismissed.
    func stop() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func send() async {
        guard let client = SupabaseService.client, let patientId else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        do {
            try await client
                .from("messages")
                .insert(NewChatMessage(
                    patientId: patientId,
                    coordinatorRole: role.rawValue,
                    senderType: "patient",
                    senderName: "You",
                    body: text
                ))
                .execute()
        } catch {
            print("ChatViewModel.send failed: \(error)")
            draft = text // don't lose what they typed
        }
    }

    private func loadHistory(patientId: UUID) async {
        guard let client = SupabaseService.client else { return }
        do {
            let rows: [ChatMessage] = try await client
                .from("messages")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .eq("coordinator_role", value: role.rawValue)
                .order("created_at")
                .execute()
                .value
            messages = rows
        } catch {
            print("ChatViewModel.loadHistory failed: \(error)")
        }
    }

    /// Subscribes to every INSERT on `messages` (RLS already limits what a
    /// patient's session can see to their own rows) and filters down to
    /// this thread client-side, rather than depending on the Realtime
    /// filter parameter's exact value-type support.
    private func subscribeToNewMessages(patientId: UUID) {
        guard let client = SupabaseService.client else { return }
        realtimeTask = Task { [weak self] in
            let channel = await client.channel("messages-\(patientId.uuidString)")
            let changes = await channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
            await channel.subscribe()
            for await change in changes {
                guard let self else { return }
                guard let message = try? change.decodeRecord(as: ChatMessage.self, decoder: JSONDecoder()) else { continue }
                guard message.patientId == patientId, message.coordinatorRole == role.rawValue else { continue }
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            }
        }
    }
}
