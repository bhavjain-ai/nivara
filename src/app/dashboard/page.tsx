'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { StatsCards } from '@/components/dashboard/StatsCards';
import { PatientTable } from '@/components/dashboard/PatientTable';
import { AlertPanel } from '@/components/dashboard/AlertPanel';
import { ConditionTabs } from '@/components/dashboard/ConditionTabs';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { getRecentAlerts } from '@/lib/mock-data';
import { usePatientRoster, ConditionFilter } from '@/lib/live-patients';
import { useCurrentStaff } from '@/components/providers/CurrentStaffProvider';
import { Bell, Wifi } from 'lucide-react';

export default function DashboardPage() {
  const [conditionFilter, setConditionFilter] = useState<ConditionFilter>('All');
  const staff = useCurrentStaff();
  const { allPatients, stats, counts, lastLiveFetch, livePatients } = usePatientRoster(conditionFilter);
  const baseAlerts = getRecentAlerts(staff.isSuperAdmin ? null : staff.clinicName);

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header
          title="Patient Overview"
          subtitle={`${staff.isSuperAdmin ? 'All Clinics' : staff.clinicName} — Nivara Health, India Pilot`}
        />
        <main className="flex-1 p-6 space-y-6">
          {/* Live sync indicator */}
          {livePatients.length > 0 && (
            <div className="flex items-center gap-2 text-xs text-green-700 bg-green-50 border border-green-200 rounded-lg px-3 py-2 w-fit">
              <Wifi className="w-3.5 h-3.5" />
              <span>
                <span className="font-semibold">{livePatients.length}</span> patient{livePatients.length > 1 ? 's' : ''} sending live readings via Nivara Sync
                {lastLiveFetch && (
                  <span className="text-green-600 ml-1">
                    · updated {new Date(lastLiveFetch).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                  </span>
                )}
              </span>
            </div>
          )}

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
                  <PatientTable patients={allPatients} />
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
                    {baseAlerts.length > 0 && (
                      <span className="ml-auto bg-red-500 text-white text-xs rounded-full px-2 py-0.5 font-medium">
                        {baseAlerts.length}
                      </span>
                    )}
                  </div>
                </CardHeader>
                <CardContent className="overflow-y-auto max-h-[600px] scrollbar-hide">
                  <AlertPanel alerts={baseAlerts} />
                </CardContent>
              </Card>
            </div>
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
