'use client';

import { useState, useEffect, useCallback } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { StatsCards } from '@/components/dashboard/StatsCards';
import { PatientTable } from '@/components/dashboard/PatientTable';
import { AlertPanel } from '@/components/dashboard/AlertPanel';
import { ConditionTabs } from '@/components/dashboard/ConditionTabs';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { getDashboardStats, getPatientSummaries, getRecentAlerts, mockPatients } from '@/lib/mock-data';
import { Condition, AlertStatus } from '@/types';
import { Bell, Wifi } from 'lucide-react';

type ConditionFilter = 'All' | Condition;

interface LiveReading {
  systolic: number;
  diastolic: number;
  pulse?: number;
  timestamp: string;
}

interface LivePatient {
  id: string;
  name: string;
  condition: string;
  city: string;
  alertStatus: string;
  lastReadingTime: string;
  liveReadings: LiveReading[];
  isLive: boolean;
  age?: number;
  vitals?: Array<{ date: string; systolic?: number; diastolic?: number }>;
}

function buildLiveSummary(p: LivePatient) {
  const latest = p.liveReadings[0];
  return {
    id: p.id,
    name: p.name,
    age: p.age ?? 0,
    conditions: ['Hypertension'] as Condition[],
    city: p.city,
    alertStatus: p.alertStatus as AlertStatus,
    lastReadingTime: p.lastReadingTime,
    isLive: true,
    latestVitals: {
      bp: latest ? `${latest.systolic}/${latest.diastolic}` : undefined,
    },
    coachingTier: 'Maintenance-touch' as const,
    coachingCallsCompleted: 0,
    coachingCallsTarget: 5,
  };
}

export default function DashboardPage() {
  const [conditionFilter, setConditionFilter] = useState<ConditionFilter>('All');
  const [livePatients, setLivePatients] = useState<LivePatient[]>([]);
  const [lastLiveFetch, setLastLiveFetch] = useState<string | null>(null);

  const fetchLive = useCallback(async () => {
    try {
      const res = await fetch('/api/patients/live');
      if (!res.ok) return;
      const data = await res.json();
      setLivePatients(data.patients ?? []);
      setLastLiveFetch(data.updatedAt);
    } catch {
      // silently fail — mock data still shows
    }
  }, []);

  useEffect(() => {
    fetchLive();
    const interval = setInterval(fetchLive, 30_000);
    return () => clearInterval(interval);
  }, [fetchLive]);

  // Base data from mock
  const baseStats = getDashboardStats();
  const basePatients = getPatientSummaries(conditionFilter === 'All' ? undefined : conditionFilter);
  const baseAlerts = getRecentAlerts();

  // IDs of mock patients that have live readings — we'll update their rows
  const liveById = new Map(livePatients.map(p => [p.id, p]));
  const knownMockIds = new Set(mockPatients.map(p => p.id));

  // Merge: update existing mock patients with live data, then append new patients
  const mergedPatients = basePatients.map(p => {
    const live = liveById.get(p.id);
    if (!live) return p;
    const latest = live.liveReadings[0];
    return {
      ...p,
      lastReadingTime: live.lastReadingTime,
      alertStatus: live.alertStatus as AlertStatus,
      isLive: true,
      latestVitals: {
        ...p.latestVitals,
        bp: latest ? `${latest.systolic}/${latest.diastolic}` : p.latestVitals.bp,
      },
    };
  });

  // Append truly new patients (IDs not in mock data), applying condition filter
  const newLivePatients = livePatients
    .filter(p => !knownMockIds.has(p.id))
    .filter(p => conditionFilter === 'All' || p.condition === conditionFilter)
    .map(buildLiveSummary);

  const allPatients = [...mergedPatients, ...newLivePatients];

  // Stats: add new live patients to totals
  const liveNewCount = livePatients.filter(p => !knownMockIds.has(p.id)).length;
  const liveCritical = livePatients.filter(p => !knownMockIds.has(p.id) && p.alertStatus === 'critical').length;
  const liveWarning = livePatients.filter(p => !knownMockIds.has(p.id) && p.alertStatus === 'warning').length;

  const stats = {
    ...baseStats,
    total: baseStats.total + liveNewCount,
    critical: baseStats.critical + liveCritical,
    warning: baseStats.warning + liveWarning,
  };

  const counts: Record<string, number> = {
    All: mockPatients.length + liveNewCount,
    Hypertension: mockPatients.filter((p) => p.conditions.includes('Hypertension')).length + livePatients.filter(p => !knownMockIds.has(p.id) && p.condition === 'Hypertension').length,
    Diabetes: mockPatients.filter((p) => p.conditions.includes('Diabetes')).length,
  };

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header
          title="Patient Overview"
          subtitle="Nivara Health — Chronic Disease Monitoring Pilot, India"
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
