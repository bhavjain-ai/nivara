'use client';

import { Patient, Medication } from '@/types';
import { getEscalationRecommendation } from '@/lib/escalation';
import { AlertTriangle, ShieldAlert, Info, BookOpen, Pill } from 'lucide-react';

interface MedicationPanelProps {
  patient: Patient;
}

const drugClassColors: Record<string, string> = {
  ACE: 'bg-blue-100 text-blue-700 border-blue-200',
  ARB: 'bg-indigo-100 text-indigo-700 border-indigo-200',
  CCB: 'bg-purple-100 text-purple-700 border-purple-200',
  Diuretic: 'bg-teal-100 text-teal-700 border-teal-200',
  BetaBlocker: 'bg-orange-100 text-orange-700 border-orange-200',
  MRA: 'bg-amber-100 text-amber-700 border-amber-200',
  AlphaBlocker: 'bg-rose-100 text-rose-700 border-rose-200',
  Central: 'bg-pink-100 text-pink-700 border-pink-200',
  ARNI: 'bg-violet-100 text-violet-700 border-violet-200',
  Other: 'bg-gray-100 text-gray-600 border-gray-200',
};

const stepLabels: Record<number, string> = {
  1: 'Dual Combination',
  2: 'Triple Combination',
  3: 'Max Tolerated Triple',
  4: 'Resistant HTN — Add MRA',
  5: 'Refractory — Add Alpha-blocker/Central',
  6: 'Renal Denervation Referral',
};

const urgencyStyles = {
  immediate: {
    badge: 'bg-red-600 text-white',
    border: 'border-red-300 bg-red-50',
    icon: ShieldAlert,
    label: 'Immediate',
  },
  urgent: {
    badge: 'bg-orange-500 text-white',
    border: 'border-orange-300 bg-orange-50',
    icon: AlertTriangle,
    label: 'Urgent',
  },
  routine: {
    badge: 'bg-yellow-500 text-white',
    border: 'border-yellow-300 bg-yellow-50',
    icon: Info,
    label: 'Routine',
  },
};

const reasonLabels: Record<string, string> = {
  crisis: 'Hypertensive crisis detected',
  consecutive_severe: 'consecutive severe readings (BP ≥160/100)',
  consecutive_elevated: 'consecutive elevated readings (BP ≥140/90)',
};

export function MedicationPanel({ patient }: MedicationPanelProps) {
  const meds = patient.medications ?? [];
  const step = patient.treatmentStep ?? 1;

  // Escalation logic only applies to HTN patients (and COPD/HF patients who have BP tracked with HTN-like thresholds)
  const isHTNRelevant = patient.condition === 'Hypertension' || patient.condition === 'COPD' || patient.condition === 'Heart Failure';
  const rec = isHTNRelevant ? getEscalationRecommendation(patient) : null;

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      {/* Header */}
      <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <Pill className="w-5 h-5 text-[#1e3a5f]" />
          <h3 className="text-base font-semibold text-gray-900">Current Medication Regimen</h3>
        </div>
        {/* Step badge */}
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">IGH V Step</span>
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#1e3a5f]/10 text-[#1e3a5f] text-xs font-semibold">
            Step {step} — {stepLabels[step] ?? 'Unknown'}
          </span>
        </div>
      </div>

      <div className="p-6 space-y-5">
        {/* Medication table */}
        {meds.length === 0 ? (
          <p className="text-sm text-gray-400 italic">No medications recorded.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100">
                  <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Medication</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Class</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Dose</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Frequency</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2">Since</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {meds.map((med: Medication, idx: number) => (
                  <tr key={idx} className="hover:bg-gray-50/60 transition-colors">
                    <td className="py-2.5 pr-4 font-medium text-gray-900">{med.name}</td>
                    <td className="py-2.5 pr-4">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded border text-xs font-medium ${drugClassColors[med.drugClass] ?? drugClassColors.Other}`}
                      >
                        {med.drugClass}
                      </span>
                    </td>
                    <td className="py-2.5 pr-4 text-gray-700">{med.dose}</td>
                    <td className="py-2.5 pr-4 text-gray-600">{med.frequency}</td>
                    <td className="py-2.5 text-gray-400 text-xs">
                      {new Date(med.startDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Escalation alert */}
        {rec && rec.shouldEscalate && (() => {
          const styles = urgencyStyles[rec.urgency];
          const UrgencyIcon = styles.icon;
          return (
            <div className={`rounded-xl border-2 ${styles.border} p-4 space-y-3`}>
              {/* Urgency header */}
              <div className="flex items-center gap-3 flex-wrap">
                <UrgencyIcon className="w-5 h-5 text-current shrink-0" />
                <span className="font-semibold text-gray-900">Escalation Recommended</span>
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold ${styles.badge}`}>
                  {styles.label}
                </span>
              </div>

              {/* Reason + readings table */}
              <div>
                <p className="text-sm text-gray-700 mb-2">
                  {rec.reason === 'crisis' ? (
                    <span className="font-medium text-red-700">Hypertensive crisis detected — immediate action required</span>
                  ) : (
                    <>
                      <span className="font-semibold">{rec.consecutiveElevatedCount}</span>{' '}
                      {reasonLabels[rec.reason]} (threshold: {rec.escalationThreshold})
                    </>
                  )}
                </p>
                {rec.elevatedReadings.length > 0 && (
                  <div className="rounded-lg overflow-hidden border border-current/20">
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="bg-black/5 text-gray-600">
                          <th className="text-left px-3 py-1.5 font-medium">Date</th>
                          <th className="text-left px-3 py-1.5 font-medium">Systolic</th>
                          <th className="text-left px-3 py-1.5 font-medium">Diastolic</th>
                          <th className="text-left px-3 py-1.5 font-medium">Classification</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-current/10 bg-white/60">
                        {rec.elevatedReadings.map((r, i) => (
                          <tr key={i}>
                            <td className="px-3 py-1.5 text-gray-700">
                              {new Date(r.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                            </td>
                            <td className="px-3 py-1.5 font-semibold text-red-700">{r.systolic} mmHg</td>
                            <td className="px-3 py-1.5 font-semibold text-red-700">{r.diastolic} mmHg</td>
                            <td className="px-3 py-1.5 text-gray-600">
                              {r.systolic >= 180 || r.diastolic >= 120
                                ? '🔴 Crisis'
                                : r.systolic >= 160 || r.diastolic >= 100
                                ? '🟠 Severe (Stage 2+)'
                                : '🟡 Elevated (Stage 2)'}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              {/* Step transition */}
              <div className="flex items-center gap-2 text-sm">
                <span className="px-2.5 py-0.5 rounded bg-gray-200 text-gray-700 font-medium text-xs">Step {rec.currentStep}</span>
                <span className="text-gray-400">→</span>
                <span className="px-2.5 py-0.5 rounded bg-[#1e3a5f] text-white font-medium text-xs">Step {rec.nextStep}</span>
              </div>

              {/* Recommended addition */}
              <div className="bg-white rounded-lg border border-current/20 p-3">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Recommended Addition</p>
                <p className="text-sm font-medium text-gray-900">{rec.recommendedAddition}</p>
              </div>

              {/* Titration detail for Step 3 */}
              {rec.titrationTarget && (
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 space-y-1.5">
                  <p className="text-xs font-semibold text-blue-700 uppercase tracking-wide">One Drug at a Time — IGH V Principle</p>
                  <div className="flex items-center gap-3 text-sm">
                    <span className="font-medium text-gray-900">{rec.titrationTarget.drugName}</span>
                    <span className="text-gray-400">current:</span>
                    <span className="font-mono bg-white border border-gray-200 px-2 py-0.5 rounded text-gray-700">{rec.titrationTarget.currentDose}</span>
                    <span className="text-gray-400">→</span>
                    <span className="font-mono bg-blue-600 text-white px-2 py-0.5 rounded">{rec.titrationTarget.targetDose}</span>
                    <span className="text-xs text-blue-600">(IGH V Table 24 max)</span>
                  </div>
                  <p className="text-xs text-blue-700">{rec.titrationTarget.note}</p>
                </div>
              )}

              {/* Full next-step regimen */}
              <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Next-Step Regimen</p>
                <ul className="space-y-1">
                  {rec.recommendedRegimen.map((r, i) => (
                    <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                      <span className="mt-1 w-1.5 h-1.5 rounded-full bg-[#1e3a5f]/60 shrink-0" />
                      {r}
                    </li>
                  ))}
                </ul>
              </div>

              {/* Contraindications */}
              {rec.contraindications.length > 0 && (
                <div>
                  <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Contraindications / Cautions</p>
                  <div className="flex flex-wrap gap-2">
                    {rec.contraindications.map((c, i) => (
                      <span
                        key={i}
                        className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-red-50 border border-red-200 text-red-700 text-xs"
                      >
                        <AlertTriangle className="w-3 h-3 shrink-0" />
                        {c}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Guideline reference */}
              <div className="flex items-start gap-1.5 pt-1 border-t border-current/10">
                <BookOpen className="w-3.5 h-3.5 text-gray-400 mt-0.5 shrink-0" />
                <p className="text-xs text-gray-400">{rec.guidelineReference}</p>
              </div>
            </div>
          );
        })()}
      </div>
    </div>
  );
}
