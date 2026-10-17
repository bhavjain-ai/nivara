'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { Card, CardContent } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { getAllAlerts } from '@/lib/mock-data';
import { useLivePatients } from '@/lib/live-patients';
import { AlertStatus } from '@/types';
import { AlertCircle, Activity, Droplets, Wifi, CheckCircle2 } from 'lucide-react';
import Link from 'next/link';

type SeverityFilter = 'All' | 'Critical' | 'Warning';

const typeIcon = {
  BP: Activity,
  Glucose: Droplets,
} as const;

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

export default function AlertsPage() {
  const [severity, setSeverity] = useState<SeverityFilter>('All');
  const allAlerts = getAllAlerts();
  const { livePatients } = useLivePatients();

  const liveAtRisk = livePatients.filter((p) => p.alertStatus === 'critical' || p.alertStatus === 'warning');

  const filteredAlerts = allAlerts.filter((a) => {
    if (severity === 'All') return true;
    if (severity === 'Critical') return a.severity === 'critical';
    return a.severity === 'warning';
  });

  const counts = {
    All: allAlerts.length,
    Critical: allAlerts.filter((a) => a.severity === 'critical').length,
    Warning: allAlerts.filter((a) => a.severity === 'warning').length,
  };

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />
      <div className="flex-1 ml-64 flex flex-col min-h-screen">
        <Header title="Alerts" subtitle="Clinical alert history across all patients" />
        <main className="flex-1 p-6 space-y-6">
          {/* Live patients currently out of range */}
          {liveAtRisk.length > 0 && (
            <Card className="border-amber-200">
              <CardContent className="p-5">
                <div className="flex items-center gap-2 mb-3">
                  <Wifi className="w-4 h-4 text-green-600" />
                  <h2 className="text-sm font-semibold text-gray-900">Live Patients — Current Status</h2>
                </div>
                <div className="space-y-2">
                  {liveAtRisk.map((p) => (
                    <Link
                      key={p.id}
                      href={`/dashboard/patient/${p.id}`}
                      className={`flex items-center justify-between p-3 rounded-lg border transition-colors hover:shadow-sm ${
                        p.alertStatus === 'critical'
                          ? 'bg-red-50 border-red-200 hover:border-red-300'
                          : 'bg-amber-50 border-amber-200 hover:border-amber-300'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-gray-900">{p.name}</span>
                        <Badge variant={p.alertStatus as AlertStatus}>
                          {p.alertStatus === 'critical' ? 'Critical' : 'Warning'}
                        </Badge>
                      </div>
                      <span className="text-xs text-gray-400">{p.lastReadingTime}</span>
                    </Link>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}

          <Card>
            <CardContent className="p-5">
              <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
                <div className="flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 text-gray-500" />
                  <h2 className="text-base font-semibold text-gray-900">
                    Alert History <span className="text-gray-400 font-normal">({filteredAlerts.length})</span>
                  </h2>
                </div>
                <div className="flex items-center gap-1 bg-gray-100 p-1 rounded-lg w-fit">
                  {(['All', 'Critical', 'Warning'] as SeverityFilter[]).map((s) => (
                    <button
                      key={s}
                      onClick={() => setSeverity(s)}
                      className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
                        severity === s ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                      }`}
                    >
                      {s}
                      <span className={`ml-1.5 text-xs ${severity === s ? 'text-gray-500' : 'text-gray-400'}`}>
                        ({counts[s]})
                      </span>
                    </button>
                  ))}
                </div>
              </div>

              {filteredAlerts.length === 0 ? (
                <div className="text-center py-12 text-gray-400 text-sm">No alerts for this filter.</div>
              ) : (
                <div className="space-y-2">
                  {filteredAlerts.map((a) => {
                    const Icon = typeIcon[a.type] || AlertCircle;
                    return (
                      <Link
                        key={a.id}
                        href={`/dashboard/patient/${a.patientId}`}
                        className={`flex items-start gap-3 p-3.5 rounded-lg border transition-colors hover:shadow-sm ${
                          a.severity === 'critical'
                            ? 'bg-red-50 border-red-200 hover:border-red-300'
                            : 'bg-amber-50 border-amber-200 hover:border-amber-300'
                        }`}
                      >
                        <Icon
                          className={`w-4 h-4 flex-shrink-0 mt-0.5 ${
                            a.severity === 'critical' ? 'text-red-500' : 'text-amber-500'
                          }`}
                        />
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1 flex-wrap">
                            <span className="text-sm font-medium text-gray-900">{a.patientName}</span>
                            <Badge variant={a.severity}>{a.severity === 'critical' ? 'Critical' : 'Warning'}</Badge>
                            {a.acknowledged && (
                              <span className="inline-flex items-center gap-1 text-xs text-gray-400">
                                <CheckCircle2 className="w-3 h-3" /> Acknowledged
                              </span>
                            )}
                          </div>
                          <p className="text-sm text-gray-600">{a.message}</p>
                        </div>
                        <div className="flex flex-col items-end gap-1 flex-shrink-0">
                          <span className="text-xs text-gray-400">{a.type}</span>
                          <span className="text-xs text-gray-400">{timeAgo(a.timestamp)}</span>
                        </div>
                      </Link>
                    );
                  })}
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
