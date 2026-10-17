'use client';

import { createContext, useContext } from 'react';
import type { CurrentStaff } from '@/types/staff';

const CurrentStaffContext = createContext<CurrentStaff | null>(null);

export function CurrentStaffProvider({ staff, children }: { staff: CurrentStaff; children: React.ReactNode }) {
  return <CurrentStaffContext.Provider value={staff}>{children}</CurrentStaffContext.Provider>;
}

/// The logged-in staff member for everything under /dashboard — set once by
/// src/app/dashboard/layout.tsx, which already redirects to /login if
/// nobody's signed in, so this is safe to call unconditionally from any
/// dashboard page or component.
export function useCurrentStaff(): CurrentStaff {
  const staff = useContext(CurrentStaffContext);
  if (!staff) {
    throw new Error('useCurrentStaff() must be used within /dashboard (CurrentStaffProvider missing)');
  }
  return staff;
}
