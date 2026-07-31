import { NextRequest, NextResponse } from 'next/server';
import Anthropic from '@anthropic-ai/sdk';
import { AnalyzeVitalsRequest, AIInsight } from '@/types';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

function buildPrompt(data: AnalyzeVitalsRequest): string {
  const { patient, latestVitals, last14DaysVitals, currentAlerts } = data;

  const vitalsSummary = last14DaysVitals
    .slice(-10)
    .map((v, i) => {
      const parts: string[] = [`Reading ${i + 1} (${v.date}):`];
      if (v.systolic && v.diastolic) parts.push(`BP ${v.systolic}/${v.diastolic} mmHg`);
      if (v.glucose) parts.push(`Glucose ${v.glucose} mg/dL (${v.glucoseType || 'fasting'})`);
      return parts.join(' | ');
    })
    .join('\n');

  const latestSummary: string[] = [];
  if (latestVitals.systolic && latestVitals.diastolic)
    latestSummary.push(`BP: ${latestVitals.systolic}/${latestVitals.diastolic} mmHg`);
  if (latestVitals.glucose)
    latestSummary.push(`Glucose: ${latestVitals.glucose} mg/dL (${latestVitals.glucoseType || 'fasting'})`);

  const alertSummary = currentAlerts
    .map((a) => `- [${a.severity.toUpperCase()}] ${a.type}: ${a.message}`)
    .join('\n');

  return `You are an expert clinical AI assistant supporting Nivara Health's physician-led remote monitoring pilot for hypertension and Type 2 diabetes patients in India.

PATIENT INFORMATION:
- Name: ${patient.name}
- Age: ${patient.age} years, ${patient.gender}
- Enrolled condition(s): ${patient.conditions.join(' + ')}

LATEST VITALS (today):
${latestSummary.join('\n') || 'No vitals recorded yet'}

TREND DATA (recent readings):
${vitalsSummary}

CURRENT ALERTS:
${alertSummary || 'No active alerts'}

Please analyze this patient's vitals against the following guidelines:
- Blood Pressure: Indian Hypertension Guidelines V (IGH-V, 2025-2026), individualized target by risk profile (general <140/90, high-risk <130/80, diabetes-comorbid 120-129/70-79, elderly 130-140/70-80)
- Blood Glucose / HbA1c: RSSDI Clinical Practice Recommendations 2022/2024 + ADA Standards of Care 2026, individualized HbA1c tier (6.5% / <7.0% / 7.5-8.0%) and matching fasting/postprandial glucose targets
- Hypoglycemia: Level 1 (<70, >=54 mg/dL) requires patient+family notification; Level 2 (<54 mg/dL) requires immediate physician contact

Respond ONLY with a valid JSON object in this exact format (no markdown, no explanation, just JSON):
{
  "summary": "2-3 sentence clinical summary of the patient's current status and key concerns",
  "riskLevel": "Low|Moderate|High|Critical",
  "recommendations": [
    "Specific actionable recommendation 1",
    "Specific actionable recommendation 2",
    "Specific actionable recommendation 3"
  ],
  "alertTriggers": [
    "Specific alert trigger if any vitals breach thresholds"
  ],
  "guidelinesReferenced": [
    "IGH-V 2025-2026",
    "RSSDI 2022/2024"
  ]
}`;
}

export async function POST(req: NextRequest) {
  try {
    const body: AnalyzeVitalsRequest = await req.json();

    if (!body.patient || !body.latestVitals) {
      return NextResponse.json({ error: 'Missing required fields: patient and latestVitals' }, { status: 400 });
    }

    const prompt = buildPrompt(body);

    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    });

    const content = response.content[0];
    if (content.type !== 'text') {
      throw new Error('Unexpected response type from Claude');
    }

    // Parse JSON response
    let insight: AIInsight;
    try {
      // Strip potential markdown code fences
      const jsonText = content.text.replace(/^```json\s*/i, '').replace(/\s*```$/i, '').trim();
      insight = JSON.parse(jsonText);
    } catch {
      throw new Error('Failed to parse AI response as JSON');
    }

    // Validate required fields
    if (!insight.summary || !insight.riskLevel || !Array.isArray(insight.recommendations)) {
      throw new Error('AI response missing required fields');
    }

    return NextResponse.json(insight);
  } catch (error) {
    console.error('AI analysis error:', error);
    const message = error instanceof Error ? error.message : 'Internal server error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
