'use client';

import { useState, useEffect, useCallback } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Info, User, Bell, AlertTriangle, Check, KeyRound, Copy, RefreshCw } from 'lucide-react';

interface ClinicJoinCode {
  id: string;
  name: string;
  join_code: string | null;
}

/// Unlike the rest of this page, this card is wired for real — it reads
/// and rotates the actual join_code column via
/// /api/clinic/join-code (see supabase/migrations/0005_clinic_join_codes.sql).
/// A patient enters this code during iOS onboarding to resolve which
/// clinic they're joining; it's the gate that keeps App Store signups
/// limited to patients an actual clinic gave the code to.
function ClinicJoinCodeCard() {
  const [clinics, setClinics] = useState<ClinicJoinCode[]>([]);
  const [loading, setLoading] = useState(true);
  const [rotatingId, setRotatingId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const fetchCodes = useCallback(async () => {
    try {
      const res = await fetch('/api/clinic/join-code');
      if (!res.ok) return;
      const data = await res.json();
      setClinics(data.clinics ?? []);
    } catch {
      // leave whatever was already shown
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchCodes();
  }, [fetchCodes]);

  async function handleRotate(clinicId: string) {
    if (!window.confirm('Generate a new code for this clinic? The current code will stop working immediately.')) return;
    setRotatingId(clinicId);
    try {
      const res = await fetch('/api/clinic/join-code', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ clinicId }),
      });
      if (res.ok) {
        await fetchCodes();
      } else {
        const body = await res.json().catch(() => ({}));
        alert(body.error || 'Failed to generate a new code.');
      }
    } catch {
      alert('Failed to generate a new code — check your connection.');
    } finally {
      setRotatingId(null);
    }
  }

  function handleCopy(clinicId: string, code: string) {
    navigator.clipboard.writeText(code).then(() => {
      setCopiedId(clinicId);
      setTimeout(() => setCopiedId(null), 1500);
    });
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <KeyRound className="w-4 h-4 text-gray-500" />
          <h2 className="text-base font-semibold text-gray-900">Clinic Join Code</h2>
        </div>
      </CardHeader>
      <CardContent>
        <p className="text-xs text-gray-400 mb-4">
          Give this code to patients you&apos;ve certified for the pilot — they enter it once during account setup in the Nivara app. Rotating it immediately invalidates the old code.
        </p>
        {loading ? (
          <p className="text-sm text-gray-400">Loading…</p>
        ) : clinics.length === 0 ? (
          <p className="text-sm text-gray-400 italic">No clinic associated with this account.</p>
        ) : (
          <div className="space-y-3">
            {clinics.map((clinic) => (
              <div key={clinic.id} className="flex items-center justify-between gap-3 flex-wrap rounded-lg border border-gray-100 px-3 py-2.5">
                <div>
                  {clinics.length > 1 && <p className="text-xs text-gray-400">{clinic.name}</p>}
                  <p className="font-mono text-base font-semibold tracking-wide text-gray-900">
                    {clinic.join_code ?? '—'}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {clinic.join_code && (
                    <button
                      onClick={() => handleCopy(clinic.id, clinic.join_code!)}
                      className="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium text-gray-600 hover:text-[#1e3a5f] border border-gray-200 rounded-lg transition-colors"
                    >
                      <Copy className="w-3.5 h-3.5" />
                      {copiedId === clinic.id ? 'Copied' : 'Copy'}
                    </button>
                  )}
                  <button
                    onClick={() => handleRotate(clinic.id)}
                    disabled={rotatingId === clinic.id}
                    className="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-medium text-gray-600 hover:text-[#1e3a5f] border border-gray-200 rounded-lg transition-colors disabled:opacity-50"
                  >
                    <RefreshCw className={`w-3.5 h-3.5 ${rotatingId === clinic.id ? 'animate-spin' : ''}`} />
                    {clinic.join_code ? 'Regenerate' : 'Generate'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function Toggle({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <label className="flex items-center justify-between py-2.5 cursor-pointer">
      <span className="text-sm text-gray-700">{label}</span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
          checked ? 'bg-[#1e3a5f]' : 'bg-gray-300'
        }`}
      >
        <span
          className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
            checked ? 'translate-x-4.5' : 'translate-x-1'
          }`}
          style={{ transform: checked ? 'translateX(18px)' : 'translateX(2px)' }}
        />
      </button>
    </label>
  );
}

export default function SettingsPage() {
  const [name, setName] = useState('Dr. Anita Desai');
  const [specialty, setSpecialty] = useState('Internal Medicine');
  const [phone, setPhone] = useState('+91-98100-00000');

  const [notifyCritical, setNotifyCritical] = useState(true);
  const [notifyWarning, setNotifyWarning] = useState(true);
  const [notifyNewPatient, setNotifyNewPatient] = useState(true);
  const [notifyDailyDigest, setNotifyDailyDigest] = useState(false);

  const [bpCriticalSys, setBpCriticalSys] = useState(180);
  const [bpCriticalDia, setBpCriticalDia] = useState(120);
  const [glucoseCriticalHigh, setGlucoseCriticalHigh] = useState(300);

  const [saved, setSaved] = useState(false);

  function handleSave() {
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header title="Settings" subtitle="Account, notifications & alert thresholds" />
        <main className="flex-1 p-6 space-y-6 max-w-3xl">
          <div className="flex items-start gap-2 text-xs text-blue-700 bg-blue-50 border border-blue-200 rounded-lg px-3 py-2.5">
            <Info className="w-4 h-4 flex-shrink-0 mt-0.5" />
            <span>
              This page isn&apos;t wired to a backend yet — there&apos;s no staff login or settings table in Supabase.
              Changes here are for preview only and reset on reload; nothing is sent or saved anywhere.
            </span>
          </div>

          {/* Physician profile */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <User className="w-4 h-4 text-gray-500" />
                <h2 className="text-base font-semibold text-gray-900">Physician Profile</h2>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Name</label>
                  <input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Specialty</label>
                  <input
                    value={specialty}
                    onChange={(e) => setSpecialty(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Phone</label>
                  <input
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          <ClinicJoinCodeCard />

          {/* Notifications */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Bell className="w-4 h-4 text-gray-500" />
                <h2 className="text-base font-semibold text-gray-900">Notifications</h2>
              </div>
            </CardHeader>
            <CardContent className="divide-y divide-gray-50">
              <Toggle checked={notifyCritical} onChange={setNotifyCritical} label="Critical alerts" />
              <Toggle checked={notifyWarning} onChange={setNotifyWarning} label="Warning alerts" />
              <Toggle checked={notifyNewPatient} onChange={setNotifyNewPatient} label="New patient enrolled" />
              <Toggle checked={notifyDailyDigest} onChange={setNotifyDailyDigest} label="Daily summary digest" />
            </CardContent>
          </Card>

          {/* Alert thresholds */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-gray-500" />
                <h2 className="text-base font-semibold text-gray-900">Critical Alert Thresholds</h2>
              </div>
            </CardHeader>
            <CardContent>
              <p className="text-xs text-gray-400 mb-4">
                Per-patient targets still follow the IGH-V/RSSDI/ADA guideline logic — these are the population-wide crisis cutoffs used for the red &quot;Critical&quot; badge.
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">BP Systolic ≥ (mmHg)</label>
                  <input
                    type="number"
                    value={bpCriticalSys}
                    onChange={(e) => setBpCriticalSys(Number(e.target.value))}
                    className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">BP Diastolic ≥ (mmHg)</label>
                  <input
                    type="number"
                    value={bpCriticalDia}
                    onChange={(e) => setBpCriticalDia(Number(e.target.value))}
                    className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Glucose ≥ (mg/dL)</label>
                  <input
                    type="number"
                    value={glucoseCriticalHigh}
                    onChange={(e) => setGlucoseCriticalHigh(Number(e.target.value))}
                    className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="flex items-center gap-3">
            <Button onClick={handleSave}>Save Changes</Button>
            {saved && (
              <span className="inline-flex items-center gap-1.5 text-sm text-green-700">
                <Check className="w-4 h-4" /> Saved (preview only)
              </span>
            )}
          </div>
        </main>

        <footer className="px-6 py-3 border-t border-gray-200 bg-white text-xs text-gray-400 flex items-center justify-between">
          <span>Nivara RPM Platform — India Pilot</span>
          <span>Guidelines: IGH-V (2025–2026) · RSSDI 2022/2024 · ADA Standards of Care 2026</span>
        </footer>
      </div>
    </div>
  );
}
