import { Patient, CoachingTier, SmartGoalStatus } from '@/types';
import { HeartHandshake, Target, PhoneCall, User, Stethoscope } from 'lucide-react';

interface CoachingPanelProps {
  patient: Patient;
}

const tierStyles: Record<CoachingTier, { badge: string; cadence: string }> = {
  'High-touch': { badge: 'bg-red-100 text-red-700 border-red-200', cadence: 'Weekly calls' },
  'Moderate-touch': { badge: 'bg-amber-100 text-amber-700 border-amber-200', cadence: 'Biweekly calls' },
  'Maintenance-touch': { badge: 'bg-green-100 text-green-700 border-green-200', cadence: 'Monthly calls' },
};

const goalStatusStyles: Record<SmartGoalStatus, string> = {
  Met: 'bg-green-100 text-green-700 border-green-200',
  'On Track': 'bg-blue-100 text-blue-700 border-blue-200',
  'Partially Met': 'bg-amber-100 text-amber-700 border-amber-200',
  'At Risk': 'bg-orange-100 text-orange-700 border-orange-200',
  'Not Met': 'bg-red-100 text-red-700 border-red-200',
};

function formatDate(d: string): string {
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function CoachingPanel({ patient }: CoachingPanelProps) {
  const tier = tierStyles[patient.coachingTier];
  const pct = Math.min(100, Math.round((patient.coachingCallsCompleted / patient.coachingCallsTarget) * 100));

  const nurseCalls = patient.outreachLog.filter((c) => c.coordinatorRole === 'Nurse').length;
  const coachCalls = patient.outreachLog.filter((c) => c.coordinatorRole === 'Lifestyle Coach').length;

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-2.5">
          <HeartHandshake className="w-5 h-5 text-[#1e3a5f]" />
          <h3 className="text-base font-semibold text-gray-900">Care Coordinator Outreach</h3>
        </div>
        <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold border ${tier.badge}`}>
          {patient.coachingTier} · {tier.cadence}
        </span>
      </div>

      <div className="p-6 space-y-6">
        {/* Call progress */}
        <div>
          <div className="flex items-center justify-between mb-1.5">
            <span className="text-sm font-medium text-gray-700">Coaching calls completed</span>
            <span className="text-sm text-gray-500">
              {patient.coachingCallsCompleted} / {patient.coachingCallsTarget}
            </span>
          </div>
          <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
            <div className="h-full bg-[#1e3a5f] rounded-full transition-all" style={{ width: `${pct}%` }} />
          </div>
          <div className="flex items-center gap-4 mt-2 text-xs text-gray-500">
            <span className="flex items-center gap-1.5">
              <User className="w-3.5 h-3.5" /> Lifestyle Coach: {coachCalls} call{coachCalls === 1 ? '' : 's'} logged
            </span>
            <span className="flex items-center gap-1.5">
              <Stethoscope className="w-3.5 h-3.5" /> Nurse: {nurseCalls} call{nurseCalls === 1 ? '' : 's'} logged
            </span>
          </div>
        </div>

        {/* Call log */}
        <div>
          <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 flex items-center gap-1.5">
            <PhoneCall className="w-3.5 h-3.5" /> Recent Outreach Log
          </h4>
          {patient.outreachLog.length === 0 ? (
            <p className="text-sm text-gray-400 italic">No outreach calls logged yet.</p>
          ) : (
            <div className="space-y-3">
              {patient.outreachLog.map((call) => (
                <div key={call.id} className="rounded-lg border border-gray-200 p-3">
                  <div className="flex items-center justify-between flex-wrap gap-1.5 mb-1.5">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium text-gray-900">{call.coordinatorName}</span>
                      <span className="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">{call.coordinatorRole}</span>
                      <span className="text-xs text-gray-400">· {call.callType}</span>
                    </div>
                    <span className="text-xs text-gray-400">
                      {formatDate(call.date)} · {call.durationMin} min
                    </span>
                  </div>
                  <div className="flex flex-wrap gap-1 mb-2">
                    {call.topics.map((t) => (
                      <span key={t} className="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-100">
                        {t}
                      </span>
                    ))}
                  </div>
                  <p className="text-sm text-gray-700 mb-1.5">{call.summary}</p>
                  <div className="space-y-1 text-xs text-gray-500">
                    {call.dietNotes && (
                      <p>
                        <span className="font-medium text-gray-600">Diet: </span>
                        {call.dietNotes}
                      </p>
                    )}
                    {call.exerciseNotes && (
                      <p>
                        <span className="font-medium text-gray-600">Exercise: </span>
                        {call.exerciseNotes}
                      </p>
                    )}
                    {call.medAdherenceNotes && (
                      <p>
                        <span className="font-medium text-gray-600">Medication adherence: </span>
                        {call.medAdherenceNotes}
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* SMART goals */}
        <div>
          <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2 flex items-center gap-1.5">
            <Target className="w-3.5 h-3.5" /> SMART Goals
          </h4>
          {patient.smartGoals.length === 0 ? (
            <p className="text-sm text-gray-400 italic">No goals set yet.</p>
          ) : (
            <div className="space-y-2">
              {patient.smartGoals.map((goal) => (
                <div key={goal.id} className="flex items-start justify-between gap-3 rounded-lg border border-gray-200 p-3">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">{goal.category}</span>
                      <span className="text-xs text-gray-400">
                        {formatDate(goal.setDate)} → {formatDate(goal.targetDate)}
                      </span>
                    </div>
                    <p className="text-sm text-gray-800">{goal.description}</p>
                    {goal.progressNote && <p className="text-xs text-gray-500 mt-1">{goal.progressNote}</p>}
                  </div>
                  <span className={`shrink-0 text-xs px-2.5 py-1 rounded-full border font-medium ${goalStatusStyles[goal.status]}`}>
                    {goal.status}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
