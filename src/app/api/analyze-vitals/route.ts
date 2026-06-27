import { NextRequest, NextResponse } from 'next/server';
import Anthropic from '@anthropic-ai/sdk';
import { AnalyzeVitalsRequest, AIInsight } from '@/types';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

function buildPrompt(data: AnalyzeVitalsRequest): string {
  const { patient, latestVitals, last14DaysVitals, currentAlerts } = data;

  const vitalsSummary = last14DaysVitals
    .slice(-7)
    .map((v, i) => {
      const parts: string[] = [`Day ${i + 1}:`];
      if (v.systolic && v.diastolic) parts.push(`BP ${v.systolic}/${v.diastolic} mmHg`);
      if (v.glucose) parts.push(`Glucose ${v.glucose} mg/dL (${v.glucoseType || 'fasting'})`);
      if (v.o2Sat) parts.push(`SpO2 ${v.o2Sat}%`);
      if (v.weight) parts.push(`Weight ${v.weight} kg`);
      return parts.join(' | ');
    })
    .join('\n');

  const latestSummary: string[] = [];
  if (latestVitals.systolic && latestVitals.diastolic)
    latestSummary.push(`BP: ${latestVitals.systolic}/${latestVitals.diastolic} mmHg`);
  if (latestVitals.glucose)
    latestSummary.push(`Glucose: ${latestVitals.glucose} mg/dL (${latestVitals.glucoseType || 'fasting'})`);
  if (latestVitals.o2Sat) latestSummary.push(`SpO2: ${latestVitals.o2Sat}%`);
  if (latestVitals.weight) latestSummary.push(`Weight: ${latestVitals.weight} kg`);

  const alertSummary = currentAlerts
    .map((a) => `- [${a.severity.toUpperCase()}] ${a.type}: ${a.message}`)
    .join('\n');

  return `You are an expert clinical AI assistant for Indian physicians managing patients with Remote Patient Monitoring (RPM) systems.

PATIENT INFORMATION:
- Name: ${patient.name}
- Age: ${patient.age} years, ${patient.gender}
- Primary Condition: ${patient.condition}

LATEST VITALS (today):
${latestSummary.join('\n')}

TREND DATA (last 7 days):
${vitalsSummary}

CURRENT ALERTS:
${alertSummary || 'No active alerts'}

Please analyze this patient's vitals against the following guidelines:
- Blood Pressure: AHA 2017 + ISH India 2020 guidelines
- Blood Glucose: RSSDI (Research Society for Study of Diabetes in India) + ADA guidelines
- O2 Saturation: GOLD guidelines for COPD, AHA HF guidelines for Heart Failure
- Weight changes: AHA Heart Failure guidelines (>2kg/24h alert, >2.5kg/48h critical)

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
    "AHA 2017",
    "ISH India 2020"
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
