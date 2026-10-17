'use client';

import { useState, useEffect, useCallback } from 'react';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { MessageCircle, Send, Stethoscope, Apple, Users } from 'lucide-react';

type CoordinatorRole = 'Physician' | 'Dietician' | 'Coach';

interface Message {
  id: string;
  coordinator_role: CoordinatorRole;
  sender_type: 'patient' | 'care_team' | 'ai_agent';
  sender_name: string;
  body: string;
  read_at: string | null;
  created_at: string;
}

const ROLES: { role: CoordinatorRole; icon: typeof Stethoscope }[] = [
  { role: 'Physician', icon: Stethoscope },
  { role: 'Dietician', icon: Apple },
  { role: 'Coach', icon: Users },
];

export function MessagePanel({ patientId }: { patientId: string }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [activeRole, setActiveRole] = useState<CoordinatorRole>('Physician');
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);

  const fetchMessages = useCallback(async () => {
    try {
      const res = await fetch(`/api/patients/${patientId}/messages`);
      if (!res.ok) return;
      const data = await res.json();
      setMessages(data.messages ?? []);
    } catch {
      // silently keep showing whatever we had
    }
  }, [patientId]);

  useEffect(() => {
    fetchMessages();
    const interval = setInterval(fetchMessages, 15_000);
    return () => clearInterval(interval);
  }, [fetchMessages]);

  // Mark this thread's patient messages read whenever it's the active tab
  // and has anything unread — matches "staff opened it, so they've seen it."
  useEffect(() => {
    const hasUnread = messages.some((m) => m.coordinator_role === activeRole && m.sender_type === 'patient' && !m.read_at);
    if (!hasUnread) return;
    fetch(`/api/patients/${patientId}/messages/mark-read`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ coordinatorRole: activeRole }),
    })
      .then(() => fetchMessages())
      .catch(() => {});
  }, [activeRole, messages, patientId, fetchMessages]);

  async function handleSend() {
    if (!draft.trim()) return;
    setSending(true);
    try {
      const res = await fetch('/api/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ patient_id: patientId, coordinator_role: activeRole, message_body: draft.trim() }),
      });
      if (res.ok) {
        setDraft('');
        await fetchMessages();
      } else {
        const body = await res.json().catch(() => ({}));
        alert(body.error || 'Failed to send message.');
      }
    } catch {
      alert('Failed to send message — check your connection.');
    } finally {
      setSending(false);
    }
  }

  const threadMessages = messages.filter((m) => m.coordinator_role === activeRole);
  const unreadByRole = (role: CoordinatorRole) =>
    messages.filter((m) => m.coordinator_role === role && m.sender_type === 'patient' && !m.read_at).length;

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            <MessageCircle className="w-4 h-4 text-gray-500" />
            <h2 className="text-base font-semibold text-gray-900">Care Team Chat</h2>
          </div>
          <div className="flex items-center gap-1 bg-gray-100 p-1 rounded-lg w-fit">
            {ROLES.map(({ role, icon: Icon }) => {
              const unread = unreadByRole(role);
              return (
                <button
                  key={role}
                  onClick={() => setActiveRole(role)}
                  className={`relative inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                    activeRole === role ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  {role}
                  {unread > 0 && (
                    <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center">
                      {unread}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="max-h-80 overflow-y-auto space-y-3 mb-4 pr-1">
          {threadMessages.length === 0 ? (
            <p className="text-sm text-gray-400 italic text-center py-6">No messages in this thread yet.</p>
          ) : (
            threadMessages.map((m) => {
              const isPatient = m.sender_type === 'patient';
              return (
                <div key={m.id} className={`flex ${isPatient ? 'justify-start' : 'justify-end'}`}>
                  <div
                    className={`max-w-[75%] rounded-xl px-3.5 py-2.5 ${
                      isPatient ? 'bg-gray-100 text-gray-900' : 'bg-[#1e3a5f] text-white'
                    }`}
                  >
                    <div className={`text-xs mb-0.5 ${isPatient ? 'text-gray-500' : 'text-blue-200'}`}>
                      {m.sender_name} · {new Date(m.created_at).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}
                    </div>
                    <div className="text-sm whitespace-pre-wrap">{m.body}</div>
                  </div>
                </div>
              );
            })
          )}
        </div>

        <div className="flex items-end gap-2">
          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
            }}
            placeholder={`Message as ${activeRole}...`}
            rows={2}
            className="flex-1 px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
          />
          <button
            onClick={handleSend}
            disabled={sending || !draft.trim()}
            className="p-2.5 bg-[#1e3a5f] text-white rounded-lg hover:bg-[#2a4d7f] transition-colors disabled:opacity-50"
            aria-label="Send"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
      </CardContent>
    </Card>
  );
}
