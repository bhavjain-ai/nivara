'use client';

import { useState, useEffect } from 'react';
import { Patient, Medication } from '@/types';
import { getEscalationRecommendation } from '@/lib/htn-titration';
import { getDiabetesEscalationRecommendation } from '@/lib/diabetes-titration';
import { DIABETES_DRUG_CLASSES } from '@/lib/medication-classify';
import { COMMON_MEDICATIONS } from '@/lib/common-medications';
import { AlertTriangle, ShieldAlert, Info, BookOpen, Pill, Clock, Syringe, Plus, Pencil, Trash2, Check, X } from 'lucide-react';

interface MedicationPanelProps {
  patient: Patient;
  /** True for a real (Supabase-backed) patient — edits call the API and
   * persist. False (or omitted, for backward compat) for a mock/demo
   * patient — edits only update local component state, explained in the UI. */
  isLive?: boolean;
  /** Called after a successful live save/delete so the parent can refetch
   * and pass back the server's version of this patient's medications. */
  onSaved?: () => void;
}

const HTN_DRUG_CLASSES = ['ACE', 'ARB', 'CCB', 'Diuretic', 'BetaBlocker', 'MRA', 'AlphaBlocker', 'Central', 'ARNI', 'Other'];

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
  Biguanide: 'bg-sky-100 text-sky-700 border-sky-200',
  SGLT2i: 'bg-emerald-100 text-emerald-700 border-emerald-200',
  GLP1: 'bg-lime-100 text-lime-700 border-lime-200',
  DPP4i: 'bg-cyan-100 text-cyan-700 border-cyan-200',
  Sulfonylurea: 'bg-yellow-100 text-yellow-700 border-yellow-200',
  TZD: 'bg-fuchsia-100 text-fuchsia-700 border-fuchsia-200',
  Insulin: 'bg-red-100 text-red-700 border-red-200',
  Other: 'bg-gray-100 text-gray-600 border-gray-200',
};

const htnStepLabels: Record<number, string> = {
  1: 'Low-dose Dual Combination',
  2: 'Low-dose Triple Combination',
  3: 'Maximally Tolerated Triple',
  4: 'Resistant HTN — Add MRA',
  5: 'Refractory — Add Alpha-blocker/Central',
  6: 'Renal Denervation Referral',
};

const urgencyStyles = {
  immediate: { badge: 'bg-red-600 text-white', border: 'border-red-300 bg-red-50', icon: ShieldAlert, label: 'Immediate' },
  urgent: { badge: 'bg-orange-500 text-white', border: 'border-orange-300 bg-orange-50', icon: AlertTriangle, label: 'Urgent' },
  routine: { badge: 'bg-yellow-500 text-white', border: 'border-yellow-300 bg-yellow-50', icon: Info, label: 'Routine' },
};

const reasonLabels: Record<string, string> = {
  crisis: 'Hypertensive crisis detected',
  consecutive_severe: 'consecutive severe readings above target',
  consecutive_elevated: 'consecutive elevated readings above target',
};

interface MedFormInput {
  name: string;
  drugClass: string;
  dose: string;
  frequency: string;
  startDate: string;
  description: string;
}

function emptyMedForm(defaultClass: string): MedFormInput {
  return { name: '', drugClass: defaultClass, dose: '', frequency: '', startDate: new Date().toISOString().split('T')[0], description: '' };
}

function MedFormRow({
  form,
  setForm,
  drugClassOptions,
  saving,
  onCancel,
  onSubmit,
}: {
  form: MedFormInput;
  setForm: (f: MedFormInput) => void;
  drugClassOptions: string[];
  saving: boolean;
  onCancel: () => void;
  onSubmit: () => void;
}) {
  const commonNames = COMMON_MEDICATIONS[form.drugClass] ?? [];
  const [useCustomName, setUseCustomName] = useState(() => form.name !== '' && !commonNames.includes(form.name));

  return (
    <tr className="bg-blue-50/40">
      <td className="py-2 pr-2">
        {useCustomName ? (
          <div className="flex items-center gap-1.5">
            <input
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Medication name"
              className="w-full px-2 py-1 text-sm border border-gray-200 rounded"
              autoFocus
            />
            {commonNames.length > 0 && (
              <button
                type="button"
                onClick={() => {
                  setUseCustomName(false);
                  setForm({ ...form, name: '' });
                }}
                className="text-xs text-gray-400 hover:text-[#1e3a5f] underline shrink-0"
              >
                list
              </button>
            )}
          </div>
        ) : (
          <select
            value={form.name}
            onChange={(e) => {
              if (e.target.value === '__other__') {
                setUseCustomName(true);
                setForm({ ...form, name: '' });
              } else {
                setForm({ ...form, name: e.target.value });
              }
            }}
            className="w-full px-2 py-1 text-sm border border-gray-200 rounded"
          >
            <option value="" disabled>Select...</option>
            {commonNames.map((n) => (
              <option key={n} value={n}>{n}</option>
            ))}
            <option value="__other__">Other (type manually)</option>
          </select>
        )}
      </td>
      <td className="py-2 pr-2">
        <select
          value={form.drugClass}
          onChange={(e) => setForm({ ...form, drugClass: e.target.value })}
          className="w-full px-2 py-1 text-sm border border-gray-200 rounded"
        >
          {drugClassOptions.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      </td>
      <td className="py-2 pr-2">
        <input
          value={form.dose}
          onChange={(e) => setForm({ ...form, dose: e.target.value })}
          placeholder="Dose"
          className="w-full px-2 py-1 text-sm border border-gray-200 rounded"
        />
      </td>
      <td className="py-2 pr-2">
        <input
          value={form.frequency}
          onChange={(e) => setForm({ ...form, frequency: e.target.value })}
          placeholder="Frequency"
          className="w-full px-2 py-1 text-sm border border-gray-200 rounded"
        />
      </td>
      <td className="py-2 pr-2">
        <input
          type="date"
          value={form.startDate}
          onChange={(e) => setForm({ ...form, startDate: e.target.value })}
          className="w-full px-2 py-1 text-sm border border-gray-200 rounded"
        />
      </td>
      <td className="py-2">
        <div className="flex items-center gap-1">
          <button onClick={onSubmit} disabled={saving} className="p-1 text-green-600 hover:bg-green-50 rounded disabled:opacity-50" aria-label="Save">
            <Check className="w-4 h-4" />
          </button>
          <button onClick={onCancel} disabled={saving} className="p-1 text-gray-400 hover:bg-gray-100 rounded disabled:opacity-50" aria-label="Cancel">
            <X className="w-4 h-4" />
          </button>
        </div>
      </td>
    </tr>
  );
}

function EditableMedTable({
  meds,
  drugClassOptions,
  isLive,
  onAdd,
  onEdit,
  onDelete,
}: {
  meds: Medication[];
  drugClassOptions: string[];
  isLive: boolean;
  onAdd: (input: MedFormInput) => Promise<void> | void;
  onEdit: (id: string, input: MedFormInput) => Promise<void> | void;
  onDelete: (med: Medication) => Promise<void> | void;
}) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState<MedFormInput>(emptyMedForm(drugClassOptions[0]));
  const [adding, setAdding] = useState(false);
  const [addForm, setAddForm] = useState<MedFormInput>(emptyMedForm(drugClassOptions[0]));
  const [saving, setSaving] = useState(false);

  function startEdit(med: Medication) {
    setEditingId(med.id ?? med.name);
    setEditForm({
      name: med.name,
      drugClass: med.drugClass,
      dose: med.dose,
      frequency: med.frequency,
      startDate: med.startDate.split('T')[0],
      description: '',
    });
  }

  async function submitEdit() {
    if (!editingId) return;
    setSaving(true);
    await onEdit(editingId, editForm);
    setSaving(false);
    setEditingId(null);
  }

  async function submitAdd() {
    if (!addForm.name.trim() || !addForm.dose.trim() || !addForm.frequency.trim()) return;
    setSaving(true);
    await onAdd(addForm);
    setSaving(false);
    setAdding(false);
    setAddForm(emptyMedForm(drugClassOptions[0]));
  }

  async function handleDeleteClick(med: Medication) {
    if (!window.confirm(`Discontinue ${med.name}?`)) return;
    await onDelete(med);
  }

  return (
    <div>
      {meds.length === 0 && !adding && <p className="text-sm text-gray-400 italic mb-2">No medications recorded.</p>}
      {(meds.length > 0 || adding) && (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Medication</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Class</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Dose</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Frequency</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2 pr-4">Since</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide pb-2"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {meds.map((med) => {
                const rowId = med.id ?? med.name;
                if (editingId === rowId) {
                  return (
                    <MedFormRow
                      key={rowId}
                      form={editForm}
                      setForm={setEditForm}
                      drugClassOptions={drugClassOptions}
                      saving={saving}
                      onCancel={() => setEditingId(null)}
                      onSubmit={submitEdit}
                    />
                  );
                }
                return (
                  <tr key={rowId} className="hover:bg-gray-50/60 transition-colors group">
                    <td className="py-2.5 pr-4 font-medium text-gray-900">{med.name}</td>
                    <td className="py-2.5 pr-4">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded border text-xs font-medium ${drugClassColors[med.drugClass] ?? drugClassColors.Other}`}>
                        {med.drugClass}
                      </span>
                    </td>
                    <td className="py-2.5 pr-4 text-gray-700">{med.dose}</td>
                    <td className="py-2.5 pr-4 text-gray-600">{med.frequency}</td>
                    <td className="py-2.5 pr-4 text-gray-400 text-xs">
                      {new Date(med.startDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                    </td>
                    <td className="py-2.5">
                      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => startEdit(med)} className="p-1 text-gray-400 hover:text-[#1e3a5f] rounded" aria-label="Edit">
                          <Pencil className="w-3.5 h-3.5" />
                        </button>
                        <button onClick={() => handleDeleteClick(med)} className="p-1 text-gray-400 hover:text-red-600 rounded" aria-label="Delete">
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
              {adding && (
                <MedFormRow
                  form={addForm}
                  setForm={setAddForm}
                  drugClassOptions={drugClassOptions}
                  saving={saving}
                  onCancel={() => setAdding(false)}
                  onSubmit={submitAdd}
                />
              )}
            </tbody>
          </table>
        </div>
      )}
      {!adding && (
        <button
          onClick={() => {
            setAddForm(emptyMedForm(drugClassOptions[0]));
            setAdding(true);
          }}
          className="mt-3 inline-flex items-center gap-1.5 text-xs font-medium text-[#1e3a5f] hover:underline"
        >
          <Plus className="w-3.5 h-3.5" /> Add medication
        </button>
      )}
      {!isLive && (meds.length > 0 || adding) && (
        <p className="mt-2 text-xs text-gray-400 italic">Demo patient — changes here are local to this browser tab only, not saved.</p>
      )}
    </div>
  );
}

function HoldBanner() {
  return (
    <div className="flex items-center gap-2 rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-xs text-blue-700">
      <Clock className="w-3.5 h-3.5 shrink-0" />
      Post-titration hold — a medication change was made within the last 2 weeks. Escalation logic is suspended until steady-state assessment.
    </div>
  );
}

interface ConditionPanelProps {
  patient: Patient;
  isLive: boolean;
  onAdd: (input: MedFormInput) => Promise<void> | void;
  onEdit: (id: string, input: MedFormInput) => Promise<void> | void;
  onDelete: (med: Medication) => Promise<void> | void;
}

function HTNPanel({ patient, isLive, onAdd, onEdit, onDelete }: ConditionPanelProps) {
  const rec = getEscalationRecommendation(patient);

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-2.5">
          <Pill className="w-5 h-5 text-[#1e3a5f]" />
          <h3 className="text-base font-semibold text-gray-900">Hypertension Regimen</h3>
        </div>
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#1e3a5f]/10 text-[#1e3a5f] text-xs font-semibold">
          IGH-V Step {rec.currentStep} — {htnStepLabels[rec.currentStep] ?? 'Unknown'}
        </span>
      </div>

      <div className="p-6 space-y-4">
        <EditableMedTable
          meds={patient.medications.filter((m) => !DIABETES_DRUG_CLASSES.includes(m.drugClass))}
          drugClassOptions={HTN_DRUG_CLASSES}
          isLive={isLive}
          onAdd={onAdd}
          onEdit={onEdit}
          onDelete={onDelete}
        />

        {rec.onPostTitrationHold && <HoldBanner />}

        {rec.shouldEscalate && (() => {
          const styles = urgencyStyles[rec.urgency];
          const UrgencyIcon = styles.icon;
          return (
            <div className={`rounded-xl border-2 ${styles.border} p-4 space-y-3`}>
              <div className="flex items-center gap-3 flex-wrap">
                <UrgencyIcon className="w-5 h-5 text-current shrink-0" />
                <span className="font-semibold text-gray-900">Escalation Recommended</span>
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold ${styles.badge}`}>{styles.label}</span>
              </div>

              <div>
                <p className="text-sm text-gray-700 mb-2">
                  {rec.reason === 'crisis' ? (
                    <span className="font-medium text-red-700">Hypertensive crisis detected — immediate action required</span>
                  ) : (
                    <>
                      <span className="font-semibold">{rec.consecutiveElevatedCount}</span> {reasonLabels[rec.reason]} within a 5-day window (threshold: {rec.escalationThreshold})
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
                                : r.diastolic >= 110
                                ? '🟠 Severe (Stage III)'
                                : r.systolic >= 160 || r.diastolic >= 100
                                ? '🟠 Moderate (Stage II)'
                                : '🟡 Mild (Stage I)'}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              <div className="flex items-center gap-2 text-sm">
                <span className="px-2.5 py-0.5 rounded bg-gray-200 text-gray-700 font-medium text-xs">Step {rec.currentStep}</span>
                <span className="text-gray-400">→</span>
                <span className="px-2.5 py-0.5 rounded bg-[#1e3a5f] text-white font-medium text-xs">Step {rec.nextStep}</span>
              </div>

              <div className="bg-white rounded-lg border border-current/20 p-3">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Recommended Addition</p>
                <p className="text-sm font-medium text-gray-900">{rec.recommendedAddition}</p>
              </div>

              {rec.titrationTarget && (
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 space-y-1.5">
                  <p className="text-xs font-semibold text-blue-700 uppercase tracking-wide">One Drug at a Time — IGH-V Principle</p>
                  <div className="flex items-center gap-3 text-sm flex-wrap">
                    <span className="font-medium text-gray-900">{rec.titrationTarget.drugName}</span>
                    <span className="text-gray-400">current:</span>
                    <span className="font-mono bg-white border border-gray-200 px-2 py-0.5 rounded text-gray-700">{rec.titrationTarget.currentDose}</span>
                    <span className="text-gray-400">→</span>
                    <span className="font-mono bg-blue-600 text-white px-2 py-0.5 rounded">{rec.titrationTarget.targetDose}</span>
                  </div>
                  <p className="text-xs text-blue-700">{rec.titrationTarget.note}</p>
                </div>
              )}

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

              {rec.contraindications.length > 0 && (
                <div>
                  <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Contraindications / Cautions</p>
                  <div className="flex flex-wrap gap-2">
                    {rec.contraindications.map((c, i) => (
                      <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-red-50 border border-red-200 text-red-700 text-xs">
                        <AlertTriangle className="w-3 h-3 shrink-0" />
                        {c}
                      </span>
                    ))}
                  </div>
                </div>
              )}

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

function DiabetesPanel({ patient, isLive, onAdd, onEdit, onDelete }: ConditionPanelProps) {
  const rec = getDiabetesEscalationRecommendation(patient);

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-2.5">
          <Syringe className="w-5 h-5 text-[#1e3a5f]" />
          <h3 className="text-base font-semibold text-gray-900">Diabetes Regimen</h3>
        </div>
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#1e3a5f]/10 text-[#1e3a5f] text-xs font-semibold">
          {rec.currentStepLabel}
        </span>
      </div>

      <div className="p-6 space-y-4">
        <EditableMedTable
          meds={patient.medications.filter((m) => DIABETES_DRUG_CLASSES.includes(m.drugClass))}
          drugClassOptions={DIABETES_DRUG_CLASSES}
          isLive={isLive}
          onAdd={onAdd}
          onEdit={onEdit}
          onDelete={onDelete}
        />

        {patient.hba1cTier && (
          <div className="text-xs text-gray-500 bg-gray-50 border border-gray-100 rounded-lg px-3 py-2">
            HbA1c Tier {patient.hba1cTier.tier} — individualized target {patient.hba1cTier.target}
          </div>
        )}

        {rec.onPostTitrationHold && <HoldBanner />}

        {rec.insulinTrigger && (
          <div className="rounded-xl border-2 border-red-300 bg-red-50 p-4 flex items-start gap-2.5">
            <ShieldAlert className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
            <div>
              <p className="font-semibold text-red-800 text-sm">Insulin Initiation Trigger</p>
              <p className="text-sm text-red-700 mt-0.5">{rec.insulinTrigger}</p>
            </div>
          </div>
        )}

        {rec.shouldEscalate && !rec.insulinTrigger && (
          <div className="rounded-xl border-2 border-orange-300 bg-orange-50 p-4 space-y-2">
            <div className="flex items-center gap-3 flex-wrap">
              <AlertTriangle className="w-5 h-5 text-orange-600 shrink-0" />
              <span className="font-semibold text-gray-900">Escalation Recommended</span>
            </div>
            <p className="text-sm text-gray-700">
              <span className="font-semibold">{rec.glucoseReadingsTriggering.length}</span> sustained fasting readings above target within a 5-day window
            </p>
            {rec.glucoseReadingsTriggering.length > 0 && (
              <div className="rounded-lg overflow-hidden border border-orange-200">
                <table className="w-full text-xs">
                  <thead>
                    <tr className="bg-black/5 text-gray-600">
                      <th className="text-left px-3 py-1.5 font-medium">Date</th>
                      <th className="text-left px-3 py-1.5 font-medium">Fasting Glucose</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-orange-100 bg-white/60">
                    {rec.glucoseReadingsTriggering.map((r, i) => (
                      <tr key={i}>
                        <td className="px-3 py-1.5 text-gray-700">
                          {new Date(r.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                        </td>
                        <td className="px-3 py-1.5 font-semibold text-orange-700">{r.glucose} mg/dL</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {(rec.shouldEscalate || rec.insulinTrigger) && (
          <div className="bg-white rounded-lg border border-gray-200 p-3">
            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Recommended Next Step</p>
            <p className="text-sm font-medium text-gray-900">{rec.recommendedAddition}</p>
          </div>
        )}

        {rec.contraindications.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {rec.contraindications.map((c, i) => (
              <span key={i} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-md bg-red-50 border border-red-200 text-red-700 text-xs">
                <AlertTriangle className="w-3 h-3 shrink-0" />
                {c}
              </span>
            ))}
          </div>
        )}

        <div className="flex items-start gap-1.5 pt-1 border-t border-gray-100">
          <BookOpen className="w-3.5 h-3.5 text-gray-400 mt-0.5 shrink-0" />
          <p className="text-xs text-gray-400">{rec.guidelineReference}</p>
        </div>
      </div>
    </div>
  );
}

export function MedicationPanel({ patient, isLive = false, onSaved }: MedicationPanelProps) {
  // Local draft of the medications list — for a live patient this is kept
  // in sync with the server via `onSaved` triggering a parent refetch
  // (patient.medications then updates, and the effect below picks it up).
  // For a mock/demo patient, this IS the only copy: edits never leave the
  // browser tab, there's nothing in Supabase to persist them to.
  const [medications, setMedications] = useState<Medication[]>(
    () => patient.medications.map((m, i) => ({ ...m, id: m.id ?? `mock-${i}` }))
  );

  useEffect(() => {
    setMedications(patient.medications.map((m, i) => ({ ...m, id: m.id ?? `mock-${i}` })));
  }, [patient.medications]);

  async function handleAdd(input: MedFormInput) {
    if (isLive) {
      try {
        const res = await fetch(`/api/patients/${patient.id}/medications`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(input),
        });
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          alert(body.error || 'Failed to add medication.');
          return;
        }
        onSaved?.();
      } catch {
        alert('Failed to add medication — check your connection.');
      }
      return;
    }
    setMedications((prev) => [...prev, { ...input, id: `local-${Date.now()}`, genericName: input.name } as Medication]);
  }

  async function handleEdit(id: string, input: MedFormInput) {
    if (isLive) {
      try {
        const res = await fetch(`/api/patients/${patient.id}/medications/${id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(input),
        });
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          alert(body.error || 'Failed to update medication.');
          return;
        }
        onSaved?.();
      } catch {
        alert('Failed to update medication — check your connection.');
      }
      return;
    }
    setMedications((prev) => prev.map((m) => (m.id === id ? ({ ...m, ...input, genericName: input.name } as Medication) : m)));
  }

  async function handleDelete(med: Medication) {
    if (isLive && med.id) {
      try {
        const res = await fetch(`/api/patients/${patient.id}/medications/${med.id}`, {
          method: 'DELETE',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ description: `Discontinued ${med.name}` }),
        });
        if (!res.ok) {
          const body = await res.json().catch(() => ({}));
          alert(body.error || 'Failed to discontinue medication.');
          return;
        }
        onSaved?.();
      } catch {
        alert('Failed to discontinue medication — check your connection.');
      }
      return;
    }
    setMedications((prev) => prev.filter((m) => m.id !== med.id));
  }

  const effectivePatient: Patient = { ...patient, medications };

  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-5">
      {patient.conditions.includes('Hypertension') && (
        <HTNPanel patient={effectivePatient} isLive={isLive} onAdd={handleAdd} onEdit={handleEdit} onDelete={handleDelete} />
      )}
      {patient.conditions.includes('Diabetes') && (
        <DiabetesPanel patient={effectivePatient} isLive={isLive} onAdd={handleAdd} onEdit={handleEdit} onDelete={handleDelete} />
      )}
    </div>
  );
}
