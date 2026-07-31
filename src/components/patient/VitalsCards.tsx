import { Patient } from '@/types';
import { Card, CardContent } from '@/components/ui/Card';
import { TrendingUp, TrendingDown, Minus, Activity, Droplets, FlaskConical } from 'lucide-react';
import { analyzeBP, analyzeGlucose, getBPTarget, getGlucoseTargets } from '@/lib/guidelines';

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
  warning: 'border-amber-300 bg-amber-50',
  normal: 'border-green-200 bg-green-50',
};

const statusTextColors: Record<string, string> = {
  critical: 'text-red-600',
  warning: 'text-amber-600',
  normal: 'text-green-600',
};

export function VitalsCards({ patient }: VitalsCardsProps) {
  const vitals = patient.vitals;
  const bpReadings = vitals.filter((v) => v.systolic && v.diastolic);
  const glucoseReadings = vitals.filter((v) => v.glucose);
  const latestBP = bpReadings[bpReadings.length - 1];
  const latestGlucose = glucoseReadings[glucoseReadings.length - 1];
  const latestHbA1c = patient.hba1cReadings[patient.hba1cReadings.length - 1];

  const bpTarget = getBPTarget(patient.conditions, patient.comorbidities, patient.age);
  const bpStatus = latestBP ? analyzeBP(latestBP.systolic!, latestBP.diastolic!, bpTarget) : null;

  const glucoseTargets = patient.hba1cTier ? getGlucoseTargets(patient.hba1cTier.tier) : null;
  const glucoseStatus =
    latestGlucose && glucoseTargets
      ? analyzeGlucose(latestGlucose.glucose!, latestGlucose.glucoseType || 'fasting', glucoseTargets)
      : null;

  const systolicTrend = getTrend(bpReadings.map((v) => v.systolic));
  const glucoseTrend = getTrend(glucoseReadings.map((v) => v.glucose));

  const cards: {
    label: string;
    icon: typeof Activity;
    value: string;
    unit: string;
    subLabel?: string;
    trend: 'up' | 'down' | 'stable';
    status: { status: string; message: string } | null;
  }[] = [];

  if (patient.conditions.includes('Hypertension')) {
    cards.push({
      label: 'Blood Pressure',
      icon: Activity,
      value: latestBP ? `${latestBP.systolic}/${latestBP.diastolic}` : 'N/A',
      unit: 'mmHg',
      subLabel: `Target: ${bpTarget.label}`,
      trend: systolicTrend,
      status: bpStatus,
    });
  }

  if (patient.conditions.includes('Diabetes')) {
    cards.push({
      label: 'Blood Glucose',
      icon: Droplets,
      value: latestGlucose ? String(latestGlucose.glucose) : 'N/A',
      unit: 'mg/dL',
      subLabel: latestGlucose?.glucoseType === 'post-meal' ? 'Post-meal (2hr)' : 'Fasting',
      trend: glucoseTrend,
      status: glucoseStatus,
    });
    cards.push({
      label: 'HbA1c',
      icon: FlaskConical,
      value: latestHbA1c ? latestHbA1c.value.toFixed(1) : 'N/A',
      unit: '%',
      subLabel: patient.hba1cTier ? `Target: ${patient.hba1cTier.target} (Tier ${patient.hba1cTier.tier})` : undefined,
      trend: 'stable',
      status:
        latestHbA1c && patient.hba1cTier
          ? {
              status: latestHbA1c.value <= patient.hba1cTier.targetValue ? 'normal' : 'warning',
              message: latestHbA1c.value <= patient.hba1cTier.targetValue ? 'At individualized target' : 'Above individualized target',
            }
          : null,
    });
  }

  return (
    <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
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
