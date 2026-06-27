import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Nivara — Physician RPM Dashboard',
  description: 'Remote Patient Monitoring for COPD, Hypertension, Diabetes & Heart Failure',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
