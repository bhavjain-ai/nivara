'use client';

import { useState, useEffect } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { VitalsCards } from '@/components/patient/VitalsCards';
import { VitalsChart } from '@/components/patient/VitalsChart';
import { AIInsights } from '@/components/patient/AIInsights';
import { AlertHistory } from '@/components/patient/AlertHistory';
import { MedicationPanel } from '@/components/patient/MedicationPanel';
import { CoachingPanel } from '@/components/patient/CoachingPanel';
import { Badge } from '@/components/ui/Badge';
import { getPatientById } from '@/lib/mock-data';
import { AlertStatus, Patient, VitalReading } from '@/types';
import { MapPin, Phone, Calendar, User, ArrowLeft, Wifi } from 'lucide-react';
import Link from 'next/link';

interface PageProps {
  params: { id: string };
}

const conditionColors: Record<string, string> = {
  Hypertension: 'bg-purple-50 text-purple-700',
  Diabetes: 'bg-orange-50 text-orange-700',
};

function statusLabel(s: AlertStatus): string {
  if (s === 'critical') return 'Critical';
  if (s === 'warning') return 'Warning';
  return 'Stable';
}

export default function PatientDetailPage({ params }: PageProps) {
  const { id } = params;
  const basePatient = getPatientById(id);
  const [patient, setPatient] = useState<Patient | null>(basePatient ?? null);
  const [hasLiveData, setHasLiveData] = useState(false);

  useEffect(() => {
    async function fetchLive() {
      try {
        const res = await fetch('/api/patients/live');
        if (!res.ok) return;
        const data = await res.json();
        const liveRecord = (data.patients ?? []).find((p: { id: string }) => p.id === id);
        if (!liveRecord) return;

        setHasLiveData(true);

        if (basePatient) {
          const liveVitals: VitalReading[] = (liveRecord.liveReadings ?? []).map((r: {
            systolic: number; diastolic: number; timestamp: string;
          }) => ({
            date: r.timestamp.split('T')[0],
            systolic: r.systolic,
            diastolic: r.diastolic,
          }));
          const existingDates = new Set(basePatient.vitals.map((v: VitalReading) => v.date));
          const newVitals = liveVitals.filter(v => !existingDates.has(v.date));
          setPatient({
            ...basePatient,
            vitals: [...newVitals, ...basePatient.vitals],
            lastReadingTime: liveRecord.lastReadingTime,
          });
        } else {
          const liveVitals: VitalReading[] = (liveRecord.liveReadings ?? []).map((r: {
            systolic: number; diastolic: number; timestamp: string;
          }) => ({
            date: r.timestamp.split('T')[0],
            systolic: r.systolic,
            diastolic: r.diastolic,
          }));
          setPatient({
            id: liveRecord.id,
            name: liveRecord.name,
            age: liveRecord.age ?? 0,
            gender: 'Male',
            conditions: ['Hypertension'],
            comorbidities: [],
            city: '—',
            phoneNumber: '—',
            physicianName: 'Unassigned',
            enrollmentDate: liveRecord.enrollmentDate ?? new Date().toISOString().split('T')[0],
            htnStep: 1,
            diabetesStep: null,
            hba1cTier: null,
            hba1cReadings: [],
            medications: [],
            alerts: [],
            alertStatus: liveRecord.alertStatus as AlertStatus,
            lastReadingTime: liveRecord.lastReadingTime,
            vitals: liveVitals,
            coachingTier: 'Maintenance-touch',
            coachingCallsCompleted: 0,
            coachingCallsTarget: 5,
            outreachLog: [],
            smartGoals: [],
          });
        }
      } catch {
        // keep showing mock/null patient
      }
    }
    fetchLive();
    const interval = setInterval(fetchLive, 30_000);
    return () => clearInterval(interval);
  }, [id]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!patient) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gray-50">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Patient not found</h2>
          <Link href="/dashboard" className="text-[#1e3a5f] underline">Back to Dashboard</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header title={patient.name} subtitle={`Patient ID: ${patient.id} · ${patient.conditions.join(' + ')}`} />
        <main className="flex-1 p-6 space-y-6">
          {/* Back + Patient Header */}
          <div>
            <Link
              href="/dashboard"
              className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 mb-4"
            >
              <ArrowLeft className="w-4 h-4" />
              Back to Dashboard
            </Link>

            <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-6">
              <div className="flex items-start justify-between flex-wrap gap-4">
                <div className="flex items-center gap-4">
                  <div className="w-14 h-14 rounded-xl bg-[#1e3a5f]/10 flex items-center justify-center text-[#1e3a5f] font-bold text-lg">
                    {patient.name
                      .split(' ')
                      .map((n) => n[0])
                      .slice(0, 2)
                      .join('')}
                  </div>
                  <div>
                    <div className="flex items-center gap-3 mb-1 flex-wrap">
                      <h1 className="text-xl font-bold text-gray-900">{patient.name}</h1>
                      {hasLiveData && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-100 text-green-700 text-xs font-medium border border-green-200">
                          <Wifi className="w-3 h-3" /> Live
                        </span>
                      )}
                      <Badge variant={patient.alertStatus === 'normal' ? 'stable' : patient.alertStatus}>
                        {statusLabel(patient.alertStatus)}
                      </Badge>
                      {patient.conditions.map((c) => (
                        <span
                          key={c}
                          className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${conditionColors[c]}`}
                        >
                          {c}
                        </span>
                      ))}
                    </div>
                    <div className="flex items-center gap-4 text-sm text-gray-500 flex-wrap">
                      <span className="flex items-center gap-1.5">
                        <User className="w-3.5 h-3.5" />
                        {patient.age} years · {patient.gender}
                      </span>
                      <span className="flex items-center gap-1.5">
                        <MapPin className="w-3.5 h-3.5" />
                        {patient.city}
                      </span>
                      <span className="flex items-center gap-1.5">
                        <Phone className="w-3.5 h-3.5" />
                        {patient.phoneNumber}
                      </span>
                      <span className="flex items-center gap-1.5">
                        <Calendar className="w-3.5 h-3.5" />
                        Enrolled: {new Date(patient.enrollmentDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-sm text-gray-500">Physician</div>
                  <div className="font-medium text-gray-900">{patient.physicianName}</div>
                  <div className="text-xs text-gray-400 mt-0.5">Last reading: {patient.lastReadingTime}</div>
                </div>
              </div>
            </div>
          </div>

          {/* Live readings from Nivara Sync (Android app) */}
          {hasLiveData && patient.vitals.some(v => v.systolic) && (
            <section>
              <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3 flex items-center gap-2">
                <Wifi className="w-3.5 h-3.5 text-green-600" />
                Live Readings from Nivara Sync
              </h2>
              <div className="bg-white rounded-xl border border-green-200 shadow-sm overflow-hidden">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-green-50 border-b border-green-100">
                      <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Timestamp</th>
                      <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Systolic</th>
                      <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Diastolic</th>
                      <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Classification</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {patient.vitals
                      .filter(v => v.systolic && v.diastolic)
                      .slice(0, 10)
                      .map((v, i) => {
                        const sys = v.systolic!;
                        const dia = v.diastolic!;
                        const cls = sys >= 180 || dia >= 120 ? { label: 'Crisis', color: 'text-red-700 bg-red-50' }
                          : dia >= 110 ? { label: 'Severe (Stage III)', color: 'text-red-600 bg-red-50' }
                          : sys >= 160 || dia >= 100 ? { label: 'Moderate (Stage II)', color: 'text-amber-700 bg-amber-50' }
                          : sys >= 140 || dia >= 90 ? { label: 'Mild (Stage I)', color: 'text-yellow-700 bg-yellow-50' }
                          : { label: 'Normal', color: 'text-green-700 bg-green-50' };
                        return (
                          <tr key={i} className="hover:bg-gray-50">
                            <td className="px-4 py-2.5 text-gray-600 text-xs">{new Date(v.date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}</td>
                            <td className="px-4 py-2.5 font-semibold text-gray-900">{sys} mmHg</td>
                            <td className="px-4 py-2.5 font-semibold text-gray-900">{dia} mmHg</td>
                            <td className="px-4 py-2.5">
                              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${cls.color}`}>{cls.label}</span>
                            </td>
                          </tr>
                        );
                      })}
                  </tbody>
                </table>
              </div>
            </section>
          )}

          {/* Vitals Cards */}
          <section>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
              Latest Vitals
            </h2>
            <VitalsCards patient={patient} />
          </section>

          {/* Medication Regimen & Titration */}
          <section>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
              Medications &amp; Titration Ladder
            </h2>
            <MedicationPanel patient={patient} />
          </section>

          {/* Vitals Charts */}
          <section>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
              Trend Charts
            </h2>
            <VitalsChart patient={patient} />
          </section>

          {/* Care Coordinator Outreach */}
          <section>
            <CoachingPanel patient={patient} />
          </section>

          {/* AI Insights */}
          <section>
            <AIInsights patient={patient} />
          </section>

          {/* Alert History */}
          <section>
            <AlertHistory alerts={patient.alerts} />
          </section>
        </main>

        <footer className="px-6 py-3 border-t border-gray-200 bg-white text-xs text-gray-400 flex items-center justify-between">
          <span>Nivara RPM Platform — India Pilot</span>
          <span>Guidelines: IGH-V (2025–2026) · RSSDI 2022/2024 · ADA Standards of Care 2026</span>
        </footer>
      </div>
    </div>
  );
}
