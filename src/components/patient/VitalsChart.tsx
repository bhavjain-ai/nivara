'use client';

import { Patient } from '@/types';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from 'recharts';

interface VitalsChartProps {
  patient: Patient;
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return `${d.getDate()}/${d.getMonth() + 1}`;
}

export function VitalsChart({ patient }: VitalsChartProps) {
  const bpData = patient.vitals
    .filter((v) => v.systolic && v.diastolic)
    .map((v) => ({ date: formatDate(v.date), systolic: v.systolic, diastolic: v.diastolic }));

  const glucoseData = patient.vitals
    .filter((v) => v.glucose)
    .map((v) => ({
      date: formatDate(v.date),
      fasting: v.glucoseType === 'fasting' ? v.glucose : undefined,
      postMeal: v.glucoseType === 'post-meal' ? v.glucose : undefined,
    }));

  const hba1cData = patient.hba1cReadings.map((r) => ({ date: formatDate(r.date), hba1c: r.value }));

  const hasBP = bpData.length > 0;
  const hasGlucose = glucoseData.length > 0;
  const hasHbA1c = hba1cData.length > 0;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
      {hasBP && (
        <Card>
          <CardHeader>
            <h3 className="text-sm font-semibold text-gray-700">Blood Pressure (14 days)</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={bpData} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis domain={[60, 200]} tick={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8 }}
                  formatter={(v, name) => [`${v} mmHg`, name === 'systolic' ? 'Systolic' : 'Diastolic']}
                />
                <ReferenceLine y={140} stroke="#dc2626" strokeDasharray="3 3" label={{ value: 'Stage I', fontSize: 10, fill: '#dc2626' }} />
                <ReferenceLine y={180} stroke="#7f1d1d" strokeDasharray="3 3" label={{ value: 'Crisis', fontSize: 10, fill: '#7f1d1d' }} />
                <Line type="monotone" dataKey="systolic" stroke="#1e3a5f" strokeWidth={2} dot={false} name="systolic" />
                <Line type="monotone" dataKey="diastolic" stroke="#60a5fa" strokeWidth={2} dot={false} name="diastolic" />
              </LineChart>
            </ResponsiveContainer>
            <div className="flex items-center gap-4 mt-2">
              <div className="flex items-center gap-1.5 text-xs text-gray-500">
                <div className="w-4 h-0.5 bg-[#1e3a5f]"></div> Systolic
              </div>
              <div className="flex items-center gap-1.5 text-xs text-gray-500">
                <div className="w-4 h-0.5 bg-blue-400"></div> Diastolic
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {hasGlucose && (
        <Card>
          <CardHeader>
            <h3 className="text-sm font-semibold text-gray-700">Blood Glucose — Fasting &amp; Post-meal</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={glucoseData} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8 }}
                  formatter={(v, name) => [`${v} mg/dL`, name === 'fasting' ? 'Fasting' : 'Post-meal']}
                />
                <ReferenceLine y={70} stroke="#7c3aed" strokeDasharray="3 3" label={{ value: 'Hypo', fontSize: 10, fill: '#7c3aed' }} />
                <Line type="monotone" dataKey="fasting" stroke="#f59e0b" strokeWidth={2} dot={{ r: 3 }} connectNulls name="fasting" />
                <Line type="monotone" dataKey="postMeal" stroke="#ec4899" strokeWidth={2} dot={{ r: 3 }} connectNulls name="postMeal" />
              </LineChart>
            </ResponsiveContainer>
            <div className="flex items-center gap-4 mt-2">
              <div className="flex items-center gap-1.5 text-xs text-gray-500">
                <div className="w-4 h-0.5 bg-amber-500"></div> Fasting
              </div>
              <div className="flex items-center gap-1.5 text-xs text-gray-500">
                <div className="w-4 h-0.5 bg-pink-500"></div> Post-meal (2hr)
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {hasHbA1c && (
        <Card>
          <CardHeader>
            <h3 className="text-sm font-semibold text-gray-700">HbA1c Trend</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={hba1cData} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis domain={[5, 12]} tick={{ fontSize: 11 }} />
                <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8 }} formatter={(v) => [`${v}%`, 'HbA1c']} />
                {patient.hba1cTier && (
                  <ReferenceLine
                    y={patient.hba1cTier.targetValue}
                    stroke="#16a34a"
                    strokeDasharray="3 3"
                    label={{ value: `Target (Tier ${patient.hba1cTier.tier})`, fontSize: 10, fill: '#16a34a' }}
                  />
                )}
                <Line type="monotone" dataKey="hba1c" stroke="#8b5cf6" strokeWidth={2} dot={{ r: 4 }} name="hba1c" />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
