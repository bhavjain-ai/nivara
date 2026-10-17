'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  Users,
  Bell,
  Settings,
  Activity,
  HeartPulse,
  LogOut,
} from 'lucide-react';
import { useCurrentStaff } from '@/components/providers/CurrentStaffProvider';
import { createSupabaseBrowserClient } from '@/lib/supabase-browser';

const navItems = [
  { href: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { href: '/dashboard/patients', icon: Users, label: 'Patients' },
  { href: '/dashboard/alerts', icon: Bell, label: 'Alerts' },
  { href: '/dashboard/vitals', icon: Activity, label: 'Vitals' },
  { href: '/dashboard/settings', icon: Settings, label: 'Settings' },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const staff = useCurrentStaff();

  const initials = staff.name
    .split(' ')
    .map((n) => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  async function handleSignOut() {
    const supabase = createSupabaseBrowserClient();
    await supabase?.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  return (
    <aside className="w-64 min-h-screen bg-[#1e3a5f] flex flex-col fixed left-0 top-0 bottom-0 z-20">
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 py-5 border-b border-white/10">
        <div className="w-9 h-9 bg-white/20 rounded-lg flex items-center justify-center">
          <HeartPulse className="w-5 h-5 text-white" />
        </div>
        <div>
          <div className="text-white font-bold text-lg leading-tight">Nivara</div>
          <div className="text-blue-200 text-xs">RPM Platform</div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-1">
        {navItems.map(({ href, icon: Icon, label }) => {
          const isActive = pathname === href || (href !== '/dashboard' && pathname.startsWith(href));
          const isDashboardActive = href === '/dashboard' && (pathname === '/dashboard' || pathname.startsWith('/dashboard/patient'));

          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                isActive || isDashboardActive
                  ? 'bg-white/20 text-white'
                  : 'text-blue-100 hover:bg-white/10 hover:text-white'
              }`}
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              {label}
            </Link>
          );
        })}
      </nav>

      {/* Staff info */}
      <div className="px-4 py-4 border-t border-white/10">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center text-white font-semibold text-sm">
            {initials}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-white text-sm font-medium truncate">{staff.name}</div>
            <div className="text-blue-200 text-xs truncate">
              {staff.isSuperAdmin ? 'All Clinics' : staff.clinicName ?? staff.role}
            </div>
          </div>
        </div>
        <button
          onClick={handleSignOut}
          className="flex items-center gap-2 text-blue-200 hover:text-white text-xs transition-colors w-full"
        >
          <LogOut className="w-4 h-4" />
          Sign out
        </button>
      </div>
    </aside>
  );
}
