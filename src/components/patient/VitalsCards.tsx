import { Patient } from '@/types';
import { Card, CardContent } from '@/components/ui/Card';
import { TrendingUp, TrendingDown, Minus, Activity, Droplets, Wind, Scale } from 'lucide-react';
import { analyzeBP, analyzeGlucose, analyzeO2Sat, analyzeWeight } from '@/lib/guidelines';

interface VitalsCardsProps {
  patient: Patient;
}

function TrendIcon({ direction }: { direction: 'up' | 'down' | 'stable' }) {
  if (direction === 'up') return <TrendingUp className="w-4 h-4" />;
  if (direction === 'down') return <TrendingDown className="w-4 h-4" />;
  return <Minus className="w-4 h-4" />;
}

function getTrend(values: (number | undefined)[]): 'up' | 'down' | 'stable' {
  const clean = values.filter((v): v is number => v !== undefined);
  if (clean.length < 2) return 'stable';
  const recent = clean.slice(-3);
  const diff = recent[recent.length - 1] - recent[0];
  if (Math.abs(diff) < 2) return 'stable';
  return diff > 0 ? 'up' : 'down';
}

const statusColors: Record<string, string> = {
  critical: 'border-red-300 bg-red-50',
  alert: 'border-amber-300 bg-amber-50',
  warning: 'border-amber-300 bg-amber-50',
  normal: 'border-green-200 bg-green-50',
};

const statusTextColors: Record<string, string> = {
  critical: 'text-red-600',
  alert: 'text-amber-600',
  warning: 'text-amber-600',
  normal: 'text-green-600',
};

export function VitalsCards({ patient }: VitalsCardsProps) {
  const vitals = patient.vitals;
  const latest = vitals[vitals.length - 1];

  const bpStatus =
    latest.systolic && latest.diastolic
      ? analyzeBP(latest.systolic, latest.diastolic, patient.condition)
      : null;

  const glucoseStatus = latest.glucose
    ? analyzeGlucose(latest.glucose, latest.glucoseType || 'fasting', patient.condition)
    : null;

  const o2Status = latest.o2Sat ? analyzeO2Sat(latest.o2Sat, patient.condition) : null;

  const prevWeights = vitals
    .slice(0, -1)
    .map((v) => v.weight)
    .filter((w): w is number => w !== undefined);
  const weightStatus = latest.weight
    ? analyzeWeight(latest.weight, prevWeights, patient.condition)
    : null;

  const systolicTrend = getTrend(vitals.map((v) => v.systolic));
  const glucoseTrend = getTrend(vitals.map((v) => v.glucose));
  const o2Trend = getTrend(vitals.map((v) => v.o2Sat));
  const weightTrend = getTrend(vitals.map((v) => v.weight));

  const cards = [
    {
      label: 'Blood Pressure',
      icon: Activity,
      value: latest.systolic && latest.diastolic ? `${latest.systolic}/${latest.diastolic}` : 'N/A',
      unit: 'mmHg',
      trend: systolicTrend,
      status: bpStatus,
    },
    {
      label: 'Blood Glucose',
      icon: Droplets,
      value: latest.glucose ? String(latest.glucose) : 'N/A',
      unit: 'mg/dL',
      subLabel: latest.glucoseType === 'post-meal' ? 'Post-meal' : 'Fasting',
      trend: glucoseTrend,
      status: glucoseStatus,
    },
    {
      label: 'O2 Saturation',
      icon: Wind,
      value: latest.o2Sat ? String(latest.o2Sat) : 'N/A',
      unit: '%',
      trend: o2Trend,
      status: o2Status,
    },
    {
      label: 'Weight',
      icon: Scale,
      value: latest.weight ? String(latest.weight) : 'N/A',
      unit: 'kg',
      trend: weightTrend,
      status: weightStatus,
    },
  ];

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map(({ label, icon: Icon, value, unit, subLabel, trend, status }) => {
        const borderClass = status ? statusColors[status.status] || statusColors.normal : 'border-gray-200 bg-white';
        const textClass = status ? statusTextColors[status.status] || statusTextColors.normal : 'text-gray-500';

        return (
          <Card key={label} className={`border-2 ${borderClass}`}>
            <CardContent className="p-4">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <Icon className={`w-4 h-4 ${textClass}`} />
                  <span className="text-xs font-medium text-gray-500">{label}</span>
                </div>
                <span className={`${textClass}`}>
                  <TrendIcon direction={trend} />
                </span>
              </div>
              <div className="flex items-baseline gap-1">
                <span className="text-2xl font-bold text-gray-900">{value}</span>
                <span className="text-sm text-gray-400">{unit}</span>
              </div>
              {subLabel && <div className="text-xs text-gray-400 mt-0.5">{subLabel}</div>}
              {status && (
                <div className={`text-xs font-medium mt-2 ${textClass}`}>{status.message}</div>
              )}
            </CardContent>
          </Card>
        );
      })}
    </div>
  );
}
