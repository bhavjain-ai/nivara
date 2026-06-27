'use client';

import { useState } from 'react';
import { Patient, AIInsight } from '@/types';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Brain, AlertTriangle, CheckCircle, BookOpen, Sparkles, Loader2 } from 'lucide-react';

interface AIInsightsProps {
  patient: Patient;
}

const riskBadgeVariant: Record<string, 'critical' | 'warning' | 'stable' | 'info'> = {
  Critical: 'critical',
  High: 'critical',
  Moderate: 'warning',
  Low: 'stable',
};

const RAJESH_HARDCODED_INSIGHT: AIInsight = {
  summary:
    'Rajesh Kumar (67M, COPD, Mumbai) presents with a clinically significant and worsening pattern over the past 14 days. SpO2 has declined from 88% to a critical 83% — well below the GOLD COPD target of ≥90% — with no recovery trend. Concurrent Stage 2 hypertension (147/94 mmHg today) is placing additional strain on an already-compromised cardiopulmonary system. A slow but consistent 1.5 kg weight gain over two weeks raises concern for early fluid retention, possibly indicating COPD-HF overlap or early cor pulmonale. Heart rate has trended upward (88 → 96 bpm), likely a compensatory response to hypoxia. Immediate physician review is warranted.',
  riskLevel: 'Critical',
  recommendations: [
    'Urgent physician review within 24 hours — SpO2 of 83% warrants same-day telehealth or ER referral if accompanied by dyspnea or altered sensorium.',
    'Initiate or titrate supplemental oxygen to maintain SpO2 ≥90% per GOLD 2024 COPD guidelines; titrate to lowest effective FiO2.',
    'Review antihypertensive regimen — BP of 147/94 mmHg exceeds ISH India 2020 Stage 2 threshold; consider adding or up-titrating ACE inhibitor/ARB which may also benefit if cor pulmonale is developing.',
    'Order BNP/NT-proBNP and chest X-ray to rule out early right heart failure or cor pulmonale given weight gain trend and rising HR.',
    'Reassess bronchodilator regimen — confirm patient is on LAMA + LABA combination (GOLD Group C/D criteria); check inhaler technique and adherence.',
    'Schedule pulmonology review within 1 week; consider repeat spirometry if not performed in the past 6 months.',
    'Educate patient on home SpO2 monitoring: report any reading below 90% immediately; reinforce action plan for COPD exacerbations.',
  ],
  alertTriggers: [
    'SpO2 83% — severe hypoxia per GOLD COPD guidelines (Critical threshold: <85%)',
    'SpO2 declining trend over 14 days: 88% → 83% with no recovery',
    'BP 147/94 mmHg — Stage 2 Hypertension per ISH India 2020 (≥140/90 mmHg)',
    'Heart rate rising: 88 → 96 bpm over 14 days, likely compensatory tachycardia from hypoxia',
    'Weight gain 1.5 kg over 14 days — clinically significant in COPD context (possible fluid retention)',
  ],
  guidelinesReferenced: [
    'GOLD COPD Guidelines 2024',
    'ISH India Hypertension Guidelines 2020',
    'AHA/ACC Blood Pressure Guidelines 2017',
    'AHA/ACC Heart Failure Guidelines 2022',
    'MOHFW India COPD Management Protocol',
  ],
};

export function AIInsights({ patient }: AIInsightsProps) {
  const isRajesh = patient.id === 'P001';
  const [insight, setInsight] = useState<AIInsight | null>(isRajesh ? RAJESH_HARDCODED_INSIGHT : null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function generateInsights() {
    setLoading(true);
    setError(null);
    try {
      const latestVitals = patient.vitals[patient.vitals.length - 1];
      const res = await fetch('/api/analyze-vitals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          patient: {
            name: patient.name,
            age: patient.age,
            condition: patient.condition,
            gender: patient.gender,
          },
          latestVitals,
          last14DaysVitals: patient.vitals,
          currentAlerts: patient.alerts,
        }),
      });
      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new Error(errData.error || `Request failed: ${res.status}`);
      }
      const data = await res.json();
      setInsight(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to generate insights');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Brain className="w-5 h-5 text-[#1e3a5f]" />
            <h2 className="text-base font-semibold text-gray-900">AI Clinical Insights</h2>
            <span className="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full font-medium">
              Claude
            </span>
          </div>
          <Button
            onClick={generateInsights}
            disabled={loading}
            variant="primary"
            size="sm"
          >
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                Analyzing...
              </>
            ) : (
              <>
                <Sparkles className="w-4 h-4 mr-2" />
                Generate Analysis
              </>
            )}
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700 text-sm">
            <AlertTriangle className="w-4 h-4 inline mr-2" />
            {error}
          </div>
        )}

        {!insight && !loading && !error && (
          <div className="text-center py-8 text-gray-400">
            <Brain className="w-10 h-10 mx-auto mb-3 opacity-30" />
            <p className="text-sm">Click &ldquo;Generate Analysis&rdquo; to get AI-powered clinical insights</p>
            <p className="text-xs mt-1">Powered by Claude, analyzed against AHA/RSSDI/ISH India guidelines</p>
          </div>
        )}

        {loading && (
          <div className="text-center py-8 text-gray-400">
            <Loader2 className="w-10 h-10 mx-auto mb-3 animate-spin opacity-50" />
            <p className="text-sm">Analyzing vitals against clinical guidelines...</p>
          </div>
        )}

        {insight && !loading && (
          <div className="space-y-5">
            {/* Risk Level + Summary */}
            <div className="bg-gray-50 rounded-lg p-4 border border-gray-100">
              <div className="flex items-center gap-2 mb-2">
                <span className="text-sm font-medium text-gray-600">Overall Risk:</span>
                <Badge variant={riskBadgeVariant[insight.riskLevel] || 'info'}>
                  {insight.riskLevel} Risk
                </Badge>
              </div>
              <p className="text-sm text-gray-700 leading-relaxed">{insight.summary}</p>
            </div>

            {/* Recommendations */}
            <div>
              <div className="flex items-center gap-2 mb-3">
                <CheckCircle className="w-4 h-4 text-green-600" />
                <h3 className="text-sm font-semibold text-gray-800">Clinical Recommendations</h3>
              </div>
              <ul className="space-y-2">
                {insight.recommendations.map((rec, i) => (
                  <li key={i} className="flex items-start gap-2 text-sm text-gray-700">
                    <span className="w-5 h-5 rounded-full bg-[#1e3a5f] text-white text-xs flex items-center justify-center flex-shrink-0 mt-0.5">
                      {i + 1}
                    </span>
                    {rec}
                  </li>
                ))}
              </ul>
            </div>

            {/* Alert Triggers */}
            {insight.alertTriggers.length > 0 && (
              <div>
                <div className="flex items-center gap-2 mb-3">
                  <AlertTriangle className="w-4 h-4 text-amber-600" />
                  <h3 className="text-sm font-semibold text-gray-800">Alert Triggers Identified</h3>
                </div>
                <ul className="space-y-1.5">
                  {insight.alertTriggers.map((trigger, i) => (
                    <li key={i} className="text-sm text-amber-700 bg-amber-50 px-3 py-2 rounded-lg border border-amber-100">
                      {trigger}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Guidelines Referenced */}
            <div>
              <div className="flex items-center gap-2 mb-3">
                <BookOpen className="w-4 h-4 text-blue-600" />
                <h3 className="text-sm font-semibold text-gray-800">Guidelines Referenced</h3>
              </div>
              <div className="flex flex-wrap gap-2">
                {insight.guidelinesReferenced.map((g, i) => (
                  <span key={i} className="text-xs bg-blue-50 text-blue-700 px-2.5 py-1 rounded-full border border-blue-100">
                    {g}
                  </span>
                ))}
              </div>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
