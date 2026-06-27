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
  const data = patient.vitals.map((v) => ({
    date: formatDate(v.date),
    systolic: v.systolic,
    diastolic: v.diastolic,
    glucose: v.glucose,
    o2Sat: v.o2Sat,
    weight: v.weight,
  }));

  const hasBP = patient.vitals.some((v) => v.systolic);
  const hasGlucose = patient.vitals.some((v) => v.glucose);
  const hasO2 = patient.vitals.some((v) => v.o2Sat);
  const hasWeight = patient.vitals.some((v) => v.weight);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
      {hasBP && (
        <Card>
          <CardHeader>
            <h3 className="text-sm font-semibold text-gray-700">Blood Pressure (14 days)</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis domain={[60, 200]} tick={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8 }}
                  formatter={(v, name) => [`${v} mmHg`, name === 'systolic' ? 'Systolic' : 'Diastolic']}
                />
                <ReferenceLine y={140} stroke="#dc2626" strokeDasharray="3 3" label={{ value: 'Stage 2', fontSize: 10, fill: '#dc2626' }} />
                <ReferenceLine y={130} stroke="#d97706" strokeDasharray="3 3" label={{ value: 'Stage 1', fontSize: 10, fill: '#d97706' }} />
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
            <h3 className="text-sm font-semibold text-gray-700">Blood Glucose (14 days)</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8 }}
                  formatter={(v) => [`${v} mg/dL`, 'Glucose']}
                />
                <ReferenceLine y={126} stroke="#dc2626" strokeDasharray="3 3" label={{ value: 'Diabetes', fontSize: 10, fill: '#dc2626' }} />
                <ReferenceLine y={100} stroke="#d97706" strokeDasharray="3 3" label={{ value: 'Prediabetes', fontSize: 10, fill: '#d97706' }} />
                <ReferenceLine y={70} stroke="#7c3aed" strokeDasharray="3 3" label={{ value: 'Hypo', fontSize: 10, fill: '#7c3aed' }} />
                <Line type="monotone" dataKey="glucose" stroke="#f59e0b" strokeWidth={2} dot={false} name="glucose" />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      )}

      {hasO2 && (
        <Card>
          <CardHeader>
            <h3 className="text-sm font-semibold text-gray-700">O2 Saturation (14 days)</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis domain={[75, 100]} tick={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8 }}
                  formatter={(v) => [`${v}%`, 'SpO2']}
                />
                <ReferenceLine y={95} stroke="#16a34a" strokeDasharray="3 3" label={{ value: 'Normal', fontSize: 10, fill: '#16a34a' }} />
                <ReferenceLine y={90} stroke="#d97706" strokeDasharray="3 3" label={{ value: 'Alert', fontSize: 10, fill: '#d97706' }} />
                <ReferenceLine y={85} stroke="#dc2626" strokeDasharray="3 3" label={{ value: 'Critical', fontSize: 10, fill: '#dc2626' }} />
                <Line type="monotone" dataKey="o2Sat" stroke="#06b6d4" strokeWidth={2} dot={false} name="o2Sat" />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      )}

      {hasWeight && (
        <Card>
          <CardHeader>
            <h3 className="text-sm font-semibold text-gray-700">Weight (14 days)</h3>
          </CardHeader>
          <CardContent className="pt-2">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8 }}
                  formatter={(v) => [`${v} kg`, 'Weight']}
                />
                <Line type="monotone" dataKey="weight" stroke="#8b5cf6" strokeWidth={2} dot={false} name="weight" />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
