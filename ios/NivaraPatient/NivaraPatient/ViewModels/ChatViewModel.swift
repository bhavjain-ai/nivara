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

    /// Appends the sent message to `messages` immediately rather than
    /// waiting for it to come back over the Realtime subscription — that
    /// round trip isn't instant, and depending on it alone meant a patient
    /// who just sent something briefly (or indefinitely, if the socket
    /// hiccups) saw it simply vanish after the composer cleared. The id is
    /// generated here rather than left to the table default specifically so
    /// this optimistic row and the later Realtime echo of the same insert
    /// share one id — subscribeToNewMessages's existing dedup check
    /// (`messages.contains(where: { $0.id == message.id })`) then quietly
    /// drops the echo instead of appending a second copy.
    func send() async {
        guard let client = SupabaseService.client, let patientId else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

        let messageId = UUID()
        let optimisticMessage = ChatMessage(
            id: messageId,
            patientId: patientId,
            coordinatorRole: role.rawValue,
            senderType: "patient",
            senderName: "You",
            body: text,
            readAt: nil,
            createdAt: SupabaseDate.nowString()
        )
        messages.append(optimisticMessage)

        do {
            try await client
                .from("messages")
                .insert(NewChatMessage(
                    id: messageId,
                    patientId: patientId,
                    coordinatorRole: role.rawValue,
                    senderType: "patient",
                    senderName: "You",
                    body: text
                ))
                .execute()
        } catch {
            print("ChatViewModel.send failed: \(error)")
            messages.removeAll { $0.id == messageId }
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
