'use client';

import { use } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { VitalsCards } from '@/components/patient/VitalsCards';
import { VitalsChart } from '@/components/patient/VitalsChart';
import { AIInsights } from '@/components/patient/AIInsights';
import { AlertHistory } from '@/components/patient/AlertHistory';
import { Badge } from '@/components/ui/Badge';
import { getPatientById } from '@/lib/mock-data';
import { AlertStatus } from '@/types';
import { MapPin, Phone, Calendar, User, ArrowLeft } from 'lucide-react';
import Link from 'next/link';

interface PageProps {
  params: Promise<{ id: string }>;
}

const conditionColors: Record<string, string> = {
  COPD: 'bg-blue-50 text-blue-700',
  Hypertension: 'bg-purple-50 text-purple-700',
  Diabetes: 'bg-orange-50 text-orange-700',
  'Heart Failure': 'bg-rose-50 text-rose-700',
};

function statusLabel(s: AlertStatus): string {
  if (s === 'critical') return 'Critical';
  if (s === 'warning') return 'Warning';
  return 'Stable';
}

export default function PatientDetailPage({ params }: PageProps) {
  const { id } = use(params);
  const patient = getPatientById(id);

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
        <Header title={patient.name} subtitle={`Patient ID: ${patient.id} · ${patient.condition}`} />
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
                    <div className="flex items-center gap-3 mb-1">
                      <h1 className="text-xl font-bold text-gray-900">{patient.name}</h1>
                      <Badge variant={patient.alertStatus === 'normal' ? 'stable' : patient.alertStatus}>
                        {statusLabel(patient.alertStatus)}
                      </Badge>
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${conditionColors[patient.condition]}`}
                      >
                        {patient.condition}
                      </span>
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

          {/* Vitals Cards */}
          <section>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
              Latest Vitals
            </h2>
            <VitalsCards patient={patient} />
          </section>

          {/* Vitals Charts */}
          <section>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">
              Trend Charts — Last 14 Days
            </h2>
            <VitalsChart patient={patient} />
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
          <span>Nivara RPM Platform — India Edition</span>
          <span>Guidelines: AHA 2017 · ISH India 2020 · RSSDI · GOLD · AHA HF</span>
        </footer>
      </div>
    </div>
  );
}
