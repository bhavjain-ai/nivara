import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Nivara — Physician RPM Dashboard',
  description: 'Physician-led remote monitoring for hypertension and Type 2 diabetes — Nivara Health India pilot',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
