import { redirect } from 'next/navigation';
import { getCurrentStaff } from '@/lib/current-staff';
import { CurrentStaffProvider } from '@/components/providers/CurrentStaffProvider';

/// Second gate behind the middleware (src/middleware.ts) — reads the staff
/// session server-side and redirects to /login if it's missing, then makes
/// the staff member's identity/clinic available to every /dashboard/* page
/// via useCurrentStaff().
export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const staff = await getCurrentStaff();
  if (!staff) {
    redirect('/login');
  }

  return <CurrentStaffProvider staff={staff}>{children}</CurrentStaffProvider>;
}
