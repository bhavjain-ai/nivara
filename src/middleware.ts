import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/// Gates every /dashboard/* route behind a real staff login (a `staff` row
/// linked to the session, not just any authenticated session — Supabase
/// Anonymous Auth, used by the iOS patient app, issues a real JWT too, so
/// "authenticated" alone isn't enough to prove someone is staff).
/// See supabase/migrations/0003_clinics_and_staff.sql for the staff/clinic
/// model this enforces.
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request: { headers: request.headers } });

  // No Supabase configured (e.g. a fresh checkout with no .env.local yet) —
  // let everything through rather than locking the dashboard out entirely,
  // matching the rest of this app's "missing backend degrades gracefully"
  // philosophy.
  if (!supabaseUrl || !anonKey) {
    return response;
  }

  const supabase = createServerClient(supabaseUrl, anonKey, {
    cookies: {
      get(name: string) {
        return request.cookies.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        request.cookies.set({ name, value, ...options });
        response = NextResponse.next({ request: { headers: request.headers } });
        response.cookies.set({ name, value, ...options });
      },
      remove(name: string, options: CookieOptions) {
        request.cookies.set({ name, value: '', ...options });
        response = NextResponse.next({ request: { headers: request.headers } });
        response.cookies.set({ name, value: '', ...options });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  let isStaff = false;
  if (user) {
    const { data: staffRow } = await supabase.from('staff').select('id').eq('auth_user_id', user.id).maybeSingle();
    isStaff = Boolean(staffRow);
  }

  const isLoginPage = request.nextUrl.pathname.startsWith('/login');
  const isDashboardPage = request.nextUrl.pathname.startsWith('/dashboard');

  if (!isStaff && isDashboardPage) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('next', request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (isStaff && isLoginPage) {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }

  return response;
}

export const config = {
  matcher: ['/dashboard/:path*', '/login'],
};
