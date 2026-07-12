import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { patient_id, systolic, diastolic, pulse, timestamp } = body;

    if (!patient_id || !systolic || !diastolic || !timestamp) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Validate ranges
    if (systolic < 60 || systolic > 300 || diastolic < 40 || diastolic > 200) {
      return NextResponse.json({ error: 'BP values out of physiological range' }, { status: 422 });
    }

    // In production: write to database. For pilot: log and acknowledge.
    console.log(`[BP Reading] Patient ${patient_id}: ${systolic}/${diastolic} mmHg, pulse: ${pulse ?? 'N/A'}, at ${timestamp}`);

    return NextResponse.json({
      success: true,
      reading_id: `${patient_id}-${Date.now()}`,
      received_at: new Date().toISOString(),
      message: 'Reading recorded successfully',
    }, { status: 201 });
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }
}
