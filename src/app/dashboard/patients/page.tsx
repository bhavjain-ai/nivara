'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { PatientTable } from '@/components/dashboard/PatientTable';
import { ConditionTabs } from '@/components/dashboard/ConditionTabs';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { usePatientRoster, ConditionFilter } from '@/lib/live-patients';
import { Users, Wifi } from 'lucide-react';

export default function PatientsPage() {
  const [conditionFilter, setConditionFilter] = useState<ConditionFilter>('All');
  const [search, setSearch] = useState('');
  const { allPatients, counts, lastLiveFetch, livePatients } = usePatientRoster(conditionFilter);

  const filteredPatients = allPatients.filter((p) => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    return p.name.toLowerCase().includes(q) || p.city.toLowerCase().includes(q);
  });

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header
          title="Patients"
          subtitle="Full patient directory — Nivara Health, India Pilot"
        />
        <main className="flex-1 p-6 space-y-6">
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

          <Card>
            <CardHeader>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div className="flex items-center gap-2">
                  <Users className="w-4 h-4 text-gray-500" />
                  <h2 className="text-base font-semibold text-gray-900">
                    All Patients <span className="text-gray-400 font-normal">({filteredPatients.length})</span>
                  </h2>
                </div>
                <div className="flex items-center gap-3 flex-wrap">
                  <input
                    type="text"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="Search by name or city..."
                    className="px-3 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent w-56"
                  />
                  <ConditionTabs
                    selected={conditionFilter}
                    onChange={setConditionFilter}
                    counts={counts}
                  />
                </div>
              </div>
            </CardHeader>
            <CardContent className="p-0">
              <PatientTable patients={filteredPatients} />
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
