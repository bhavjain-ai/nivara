'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { Card, CardContent } from '@/components/ui/Card';
import { mockPatients } from '@/lib/mock-data';
import { useLivePatients } from '@/lib/live-patients';
import { useCurrentStaff } from '@/components/providers/CurrentStaffProvider';
import { Activity, Droplets } from 'lucide-react';
import Link from 'next/link';

type TypeFilter = 'All' | 'BP' | 'Glucose';

interface ReadingRow {
  patientId: string;
  patientName: string;
  date: string;
  systolic?: number;
  diastolic?: number;
  glucose?: number;
  glucoseType?: 'fasting' | 'post-meal';
  isLive: boolean;
}

function classifyBP(sys: number, dia: number): { label: string; color: string } {
  if (sys >= 180 || dia >= 120) return { label: 'Crisis', color: 'text-red-700 bg-red-50' };
  if (dia >= 110) return { label: 'Severe (Stage III)', color: 'text-red-600 bg-red-50' };
  if (sys >= 160 || dia >= 100) return { label: 'Moderate (Stage II)', color: 'text-amber-700 bg-amber-50' };
  if (sys >= 140 || dia >= 90) return { label: 'Mild (Stage I)', color: 'text-yellow-700 bg-yellow-50' };
  return { label: 'Normal', color: 'text-green-700 bg-green-50' };
}

function classifyGlucose(mgDl: number, type: 'fasting' | 'post-meal'): { label: string; color: string } {
  if (mgDl < 70) return { label: 'Low', color: 'text-blue-700 bg-blue-50' };
  const highCutoff = type === 'post-meal' ? 200 : 126;
  const elevatedCutoff = type === 'post-meal' ? 140 : 100;
  if (mgDl >= highCutoff) return { label: 'High', color: 'text-red-700 bg-red-50' };
  if (mgDl >= elevatedCutoff) return { label: 'Elevated', color: 'text-amber-700 bg-amber-50' };
  return { label: 'Normal', color: 'text-green-700 bg-green-50' };
}

export default function VitalsPage() {
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('All');
  const { livePatients } = useLivePatients();
  const staff = useCurrentStaff();
  const clinicName = staff.isSuperAdmin ? null : staff.clinicName;

  const mockRows: ReadingRow[] = mockPatients
    .filter((p) => clinicName === null || p.clinicName === clinicName)
    .flatMap((p) =>
    p.vitals.map((v) => ({
      patientId: p.id,
      patientName: p.name,
      date: v.date,
      systolic: v.systolic,
      diastolic: v.diastolic,
      glucose: v.glucose,
      glucoseType: v.glucoseType,
      isLive: false,
    }))
  );

  const liveRows: ReadingRow[] = livePatients.flatMap((p) =>
    (p.vitals ?? []).map((v) => ({
      patientId: p.id,
      patientName: p.name,
      date: v.date,
      systolic: v.systolic,
      diastolic: v.diastolic,
      glucose: v.glucose,
      glucoseType: v.glucoseType,
      isLive: true,
    }))
  );

  const allRows = [...mockRows, ...liveRows]
    .filter((r) => {
      if (typeFilter === 'BP') return r.systolic != null;
      if (typeFilter === 'Glucose') return r.glucose != null;
      return true;
    })
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
    .slice(0, 100);

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header
          title="Vitals"
          subtitle={`Recent readings feed — ${staff.isSuperAdmin ? 'All Clinics' : staff.clinicName}`}
        />
        <main className="flex-1 p-6 space-y-6">
          <Card>
            <CardContent className="p-5">
              <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
                <div className="flex items-center gap-2">
                  <Activity className="w-4 h-4 text-gray-500" />
                  <h2 className="text-base font-semibold text-gray-900">
                    Recent Readings <span className="text-gray-400 font-normal">({allRows.length})</span>
                  </h2>
                </div>
                <div className="flex items-center gap-1 bg-gray-100 p-1 rounded-lg w-fit">
                  {(['All', 'BP', 'Glucose'] as TypeFilter[]).map((t) => (
                    <button
                      key={t}
                      onClick={() => setTypeFilter(t)}
                      className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
                        typeFilter === t ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                      }`}
                    >
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              {allRows.length === 0 ? (
                <div className="text-center py-12 text-gray-400 text-sm">No readings yet.</div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-gray-100">
                        <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Patient</th>
                        <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Timestamp</th>
                        <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Reading</th>
                        <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">Classification</th>
                        <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3"></th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-50">
                      {allRows.map((r, i) => {
                        const isBP = r.systolic != null && r.diastolic != null;
                        const cls = isBP
                          ? classifyBP(r.systolic!, r.diastolic!)
                          : r.glucose != null
                          ? classifyGlucose(r.glucose, r.glucoseType ?? 'fasting')
                          : null;
                        return (
                          <tr key={`${r.patientId}-${r.date}-${i}`} className="hover:bg-gray-50">
                            <td className="px-4 py-2.5 font-medium text-gray-900">{r.patientName}</td>
                            <td className="px-4 py-2.5 text-gray-500 text-xs">
                              {new Date(r.date).toLocaleString('en-IN', {
                                day: '2-digit',
                                month: 'short',
                                year: 'numeric',
                                ...(r.isLive ? { hour: '2-digit' as const, minute: '2-digit' as const } : {}),
                              })}
                            </td>
                            <td className="px-4 py-2.5 text-gray-900">
                              {isBP ? (
                                <span className="inline-flex items-center gap-1.5">
                                  <Activity className="w-3.5 h-3.5 text-gray-400" />
                                  {r.systolic}/{r.diastolic} mmHg
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1.5">
                                  <Droplets className="w-3.5 h-3.5 text-gray-400" />
                                  {r.glucose} mg/dL
                                  <span className="text-gray-400 text-xs">({r.glucoseType === 'post-meal' ? 'PP' : 'Fasting'})</span>
                                </span>
                              )}
                            </td>
                            <td className="px-4 py-2.5">
                              {cls && (
                                <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${cls.color}`}>
                                  {cls.label}
                                </span>
                              )}
                            </td>
                            <td className="px-4 py-2.5">
                              <Link href={`/dashboard/patient/${r.patientId}`} className="text-[#1e3a5f] text-xs hover:underline">
                                View patient
                              </Link>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>
        </main>

        <footer className="px-6 py-3 border-t border-gray-200 bg-white text-xs text-gray-400 flex items-center justify-between">
          <span>Nivara RPM Platform — India Pilot</span>
          <span>Guidelines: IGH-V (2025–2026) · RSSDI 2022/2024 · ADA Standards of Care 2026</span>
        </footer>
      </div>
    </div>
  );
}
