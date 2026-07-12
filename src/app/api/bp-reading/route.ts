import { NextRequest, NextResponse } from 'next/server';
import { addReading } from '@/lib/reading-store';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { patient_id, systolic, diastolic, pulse, timestamp } = body;

    if (!patient_id || !systolic || !diastolic || !timestamp) {
      return NextResponse.json({ error: 'Missing required fields: patient_id, systolic, diastolic, timestamp' }, { status: 400 });
    }

    if (systolic < 60 || systolic > 300 || diastolic < 40 || diastolic > 200) {
      return NextResponse.json({ error: 'BP values out of physiological range' }, { status: 422 });
    }

    const record = addReading(patient_id, {
      systolic: Number(systolic),
      diastolic: Number(diastolic),
      pulse: pulse != null ? Number(pulse) : undefined,
      timestamp,
    });

    return NextResponse.json({
      success: true,
      reading_id: `${patient_id}-${Date.now()}`,
      received_at: new Date().toISOString(),
      total_readings: record.readings.length,
      message: 'Reading recorded successfully',
    }, { status: 201 });
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 });
  }
}
