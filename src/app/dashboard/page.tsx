'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { StatsCards } from '@/components/dashboard/StatsCards';
import { PatientTable } from '@/components/dashboard/PatientTable';
import { AlertPanel } from '@/components/dashboard/AlertPanel';
import { ConditionTabs } from '@/components/dashboard/ConditionTabs';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { getDashboardStats, getPatientSummaries, getRecentAlerts, mockPatients } from '@/lib/mock-data';
import { Condition } from '@/types';
import { Bell } from 'lucide-react';

type ConditionFilter = 'All' | Condition;

export default function DashboardPage() {
  const [conditionFilter, setConditionFilter] = useState<ConditionFilter>('All');

  const stats = getDashboardStats();
  const patients = getPatientSummaries(conditionFilter === 'All' ? undefined : conditionFilter);
  const alerts = getRecentAlerts();

  const counts: Record<string, number> = {
    All: mockPatients.length,
    COPD: mockPatients.filter((p) => p.condition === 'COPD').length,
    Hypertension: mockPatients.filter((p) => p.condition === 'Hypertension').length,
    Diabetes: mockPatients.filter((p) => p.condition === 'Diabetes').length,
    'Heart Failure': mockPatients.filter((p) => p.condition === 'Heart Failure').length,
  };

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header
          title="Patient Overview"
          subtitle="Remote Patient Monitoring — India"
        />
        <main className="flex-1 p-6 space-y-6">
          {/* Stats */}
          <StatsCards stats={stats} />

          {/* Main content: patient table + alert panel */}
          <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
            {/* Patient Table */}
            <div className="xl:col-span-2">
              <Card>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <h2 className="text-base font-semibold text-gray-900">Enrolled Patients</h2>
                    <ConditionTabs
                      selected={conditionFilter}
                      onChange={setConditionFilter}
                      counts={counts}
                    />
                  </div>
                </CardHeader>
                <CardContent className="p-0">
                  <PatientTable patients={patients} />
                </CardContent>
              </Card>
            </div>

            {/* Alert Panel */}
            <div className="xl:col-span-1">
              <Card className="h-full">
                <CardHeader>
                  <div className="flex items-center gap-2">
                    <Bell className="w-4 h-4 text-gray-500" />
                    <h2 className="text-base font-semibold text-gray-900">Active Alerts</h2>
                    {alerts.length > 0 && (
                      <span className="ml-auto bg-red-500 text-white text-xs rounded-full px-2 py-0.5 font-medium">
                        {alerts.length}
                      </span>
                    )}
                  </div>
                </CardHeader>
                <CardContent className="overflow-y-auto max-h-[600px] scrollbar-hide">
                  <AlertPanel alerts={alerts} />
                </CardContent>
              </Card>
            </div>
          </div>
        </main>

        {/* Footer */}
        <footer className="px-6 py-3 border-t border-gray-200 bg-white text-xs text-gray-400 flex items-center justify-between">
          <span>Nivara RPM Platform — India Edition</span>
          <span>Guidelines: AHA 2017 · ISH India 2020 · RSSDI · GOLD · AHA HF</span>
        </footer>
      </div>
    </div>
  );
}
