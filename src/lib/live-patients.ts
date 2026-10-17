'use client';

import { useState, useEffect, useCallback } from 'react';
import { Condition, AlertStatus } from '@/types';
import { getDashboardStats, getPatientSummaries, mockPatients } from '@/lib/mock-data';

export interface LiveReading {
  systolic: number;
  diastolic: number;
  pulse?: number;
  timestamp: string;
}

export interface LiveVital {
  date: string;
  systolic?: number;
  diastolic?: number;
  glucose?: number;
  glucoseType?: 'fasting' | 'post-meal';
}

export interface LivePatient {
  id: string;
  name: string;
  conditions: string[];
  city: string;
  alertStatus: string;
  lastReadingTime: string;
  liveReadings: LiveReading[];
  isLive: boolean;
  age?: number | null;
  vitals?: LiveVital[];
}

export type ConditionFilter = 'All' | Condition;

function buildLiveSummary(p: LivePatient) {
  const latestVital = p.vitals?.find((v) => v.systolic != null);
  const latestGlucoseVital = p.vitals?.find((v) => v.glucose != null);
  return {
    id: p.id,
    name: p.name,
    age: p.age ?? 0,
    conditions: (p.conditions.length > 0 ? p.conditions : ['Hypertension']) as Condition[],
    city: p.city,
    alertStatus: p.alertStatus as AlertStatus,
    lastReadingTime: p.lastReadingTime,
    isLive: true,
    latestVitals: {
      bp: latestVital ? `${latestVital.systolic}/${latestVital.diastolic}` : undefined,
      glucose: latestGlucoseVital?.glucose,
      glucoseType: latestGlucoseVital?.glucoseType,
    },
    coachingTier: 'Maintenance-touch' as const,
    coachingCallsCompleted: 0,
    coachingCallsTarget: 5,
  };
}

/// Polls /api/patients/live every 30s for real patients synced via Supabase
/// (see src/lib/supabase-live.ts) or the older flat-file store. Shared by
/// every page that needs the live roster so they all see the same patients
/// without re-implementing the fetch/poll loop.
export function useLivePatients() {
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

  return { livePatients, lastLiveFetch };
}

/// Merges mock patients with the live roster: known IDs get their rows
/// updated in place with live vitals, unknown IDs (e.g. the real patient
/// registered via the iOS app) are appended as new rows. Also rolls live
/// patients into the dashboard stats/condition counts.
export function usePatientRoster(conditionFilter: ConditionFilter) {
  const { livePatients, lastLiveFetch } = useLivePatients();

  const baseStats = getDashboardStats();
  const basePatients = getPatientSummaries(conditionFilter === 'All' ? undefined : conditionFilter);

  const liveById = new Map(livePatients.map((p) => [p.id, p]));
  const knownMockIds = new Set(mockPatients.map((p) => p.id));

  const mergedPatients = basePatients.map((p) => {
    const live = liveById.get(p.id);
    if (!live) return p;
    const latestVital = live.vitals?.find((v) => v.systolic != null);
    const latestGlucoseVital = live.vitals?.find((v) => v.glucose != null);
    return {
      ...p,
      lastReadingTime: live.lastReadingTime,
      alertStatus: live.alertStatus as AlertStatus,
      isLive: true,
      latestVitals: {
        bp: latestVital ? `${latestVital.systolic}/${latestVital.diastolic}` : p.latestVitals.bp,
        glucose: latestGlucoseVital?.glucose ?? p.latestVitals.glucose,
        glucoseType: latestGlucoseVital?.glucoseType ?? p.latestVitals.glucoseType,
      },
    };
  });

  const newLivePatients = livePatients
    .filter((p) => !knownMockIds.has(p.id))
    .filter((p) => conditionFilter === 'All' || p.conditions.includes(conditionFilter))
    .map(buildLiveSummary);

  const allPatients = [...mergedPatients, ...newLivePatients];

  const liveNewCount = livePatients.filter((p) => !knownMockIds.has(p.id)).length;
  const liveCritical = livePatients.filter((p) => !knownMockIds.has(p.id) && p.alertStatus === 'critical').length;
  const liveWarning = livePatients.filter((p) => !knownMockIds.has(p.id) && p.alertStatus === 'warning').length;

  const stats = {
    ...baseStats,
    total: baseStats.total + liveNewCount,
    critical: baseStats.critical + liveCritical,
    warning: baseStats.warning + liveWarning,
  };

  const counts: Record<string, number> = {
    All: mockPatients.length + liveNewCount,
    Hypertension:
      mockPatients.filter((p) => p.conditions.includes('Hypertension')).length +
      livePatients.filter((p) => !knownMockIds.has(p.id) && p.conditions.includes('Hypertension')).length,
    Diabetes:
      mockPatients.filter((p) => p.conditions.includes('Diabetes')).length +
      livePatients.filter((p) => !knownMockIds.has(p.id) && p.conditions.includes('Diabetes')).length,
  };

  return { allPatients, stats, counts, lastLiveFetch, livePatients, knownMockIds };
}
