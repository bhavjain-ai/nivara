import fs from 'fs';
import path from 'path';

const STORE_PATH = path.join(process.cwd(), 'data', 'live-readings.json');

export interface LiveReading {
  systolic: number;
  diastolic: number;
  pulse?: number;
  timestamp: string;  // ISO-8601
}

export interface LivePatientRecord {
  patientId: string;
  readings: LiveReading[];
  firstSeen: string;
  lastUpdate: string;
}

type Store = Record<string, LivePatientRecord>;

function readStore(): Store {
  try {
    const raw = fs.readFileSync(STORE_PATH, 'utf-8');
    return JSON.parse(raw) as Store;
  } catch {
    return {};
  }
}

function writeStore(store: Store): void {
  fs.mkdirSync(path.dirname(STORE_PATH), { recursive: true });
  fs.writeFileSync(STORE_PATH, JSON.stringify(store, null, 2), 'utf-8');
}

export function addReading(patientId: string, reading: LiveReading): LivePatientRecord {
  const store = readStore();

  if (store[patientId]) {
    // Deduplicate by timestamp
    const exists = store[patientId].readings.some(r => r.timestamp === reading.timestamp);
    if (!exists) {
      store[patientId].readings.unshift(reading); // newest first
    }
    store[patientId].lastUpdate = new Date().toISOString();
  } else {
    store[patientId] = {
      patientId,
      readings: [reading],
      firstSeen: new Date().toISOString(),
      lastUpdate: new Date().toISOString(),
    };
  }

  writeStore(store);
  return store[patientId];
}

export function getAllLivePatients(): LivePatientRecord[] {
  const store = readStore();
  return Object.values(store).sort((a, b) =>
    b.lastUpdate.localeCompare(a.lastUpdate)
  );
}

export function getLivePatient(patientId: string): LivePatientRecord | null {
  const store = readStore();
  return store[patientId] ?? null;
}
