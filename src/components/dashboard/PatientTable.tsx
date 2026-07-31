'use client';

import Link from 'next/link';
import { AlertStatus, Condition, CoachingTier } from '@/types';
import { Badge } from '@/components/ui/Badge';
import { Clock, ChevronRight, PhoneCall } from 'lucide-react';

interface PatientRow {
  id: string;
  name: string;
  age: number;
  conditions: Condition[];
  city: string;
  alertStatus: AlertStatus;
  lastReadingTime: string;
  latestVitals: {
    bp?: string;
    glucose?: number;
    glucoseType?: 'fasting' | 'post-meal';
  };
  coachingTier: CoachingTier;
  coachingCallsCompleted: number;
  coachingCallsTarget: number;
}

interface PatientTableProps {
  patients: PatientRow[];
}

function statusLabel(s: AlertStatus) {
  if (s === 'critical') return 'Critical';
  if (s === 'warning') return 'Warning';
  return 'Stable';
}

const conditionColors: Record<string, string> = {
  Hypertension: 'bg-purple-50 text-purple-700',
  Diabetes: 'bg-orange-50 text-orange-700',
};

const coachingTierColors: Record<CoachingTier, string> = {
  'High-touch': 'bg-red-50 text-red-700',
  'Moderate-touch': 'bg-amber-50 text-amber-700',
  'Maintenance-touch': 'bg-green-50 text-green-700',
};

export function PatientTable({ patients }: PatientTableProps) {
  if (patients.length === 0) {
    return (
      <div className="text-center py-12 text-gray-400">
        <p>No patients found for this filter.</p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-gray-100">
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">
              Patient
            </th>
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">
              Condition
            </th>
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">
              Latest Vitals
            </th>
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">
              Status
            </th>
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">
              Care Outreach
            </th>
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3">
              Last Reading
            </th>
            <th className="text-left text-xs font-medium text-gray-500 uppercase tracking-wide px-4 py-3"></th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-50">
          {patients.map((p) => (
            <tr key={p.id} className="hover:bg-gray-50 transition-colors group cursor-pointer" onClick={() => window.location.href = `/dashboard/patient/${p.id}`}>
              <td className="px-4 py-3">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-[#1e3a5f]/10 flex items-center justify-center text-[#1e3a5f] font-semibold text-sm flex-shrink-0">
                    {p.name
                      .split(' ')
                      .map((n) => n[0])
                      .slice(0, 2)
                      .join('')}
                  </div>
                  <div>
                    <div className="font-medium text-gray-900 text-sm">{p.name}</div>
                    <div className="text-xs text-gray-400">
                      {p.age}y • {p.city}
                    </div>
                  </div>
                </div>
              </td>
              <td className="px-4 py-3">
                <div className="flex flex-wrap gap-1">
                  {p.conditions.map((c) => (
                    <span
                      key={c}
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${conditionColors[c]}`}
                    >
                      {c}
                    </span>
                  ))}
                </div>
              </td>
              <td className="px-4 py-3">
                <div className="text-sm text-gray-700 space-y-0.5">
                  {p.latestVitals.bp && (
                    <div>
                      <span className="text-gray-400 text-xs">BP: </span>
                      {p.latestVitals.bp} mmHg
                    </div>
                  )}
                  {p.latestVitals.glucose && (
                    <div>
                      <span className="text-gray-400 text-xs">
                        Glc ({p.latestVitals.glucoseType === 'post-meal' ? 'PP' : 'F'}):{' '}
                      </span>
                      {p.latestVitals.glucose} mg/dL
                    </div>
                  )}
                </div>
              </td>
              <td className="px-4 py-3">
                <Badge variant={p.alertStatus === 'normal' ? 'stable' : p.alertStatus}>
                  {statusLabel(p.alertStatus)}
                </Badge>
              </td>
              <td className="px-4 py-3">
                <div className="flex items-center gap-1.5">
                  <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${coachingTierColors[p.coachingTier]}`}>
                    {p.coachingTier}
                  </span>
                  <span className="flex items-center gap-1 text-xs text-gray-500">
                    <PhoneCall className="w-3 h-3" />
                    {p.coachingCallsCompleted}/{p.coachingCallsTarget}
                  </span>
                </div>
              </td>
              <td className="px-4 py-3">
                <div className="flex items-center gap-1 text-xs text-gray-400">
                  <Clock className="w-3.5 h-3.5" />
                  {p.lastReadingTime}
                </div>
              </td>
              <td className="px-4 py-3">
                <Link
                  href={`/dashboard/patient/${p.id}`}
                  className="text-[#1e3a5f] opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  <ChevronRight className="w-5 h-5" />
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
