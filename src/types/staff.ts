export interface CurrentStaff {
  id: string;
  name: string;
  role: string;
  email: string | null;
  clinicId: string | null; // null = super-admin, sees every clinic
  clinicName: string | null;
  isSuperAdmin: boolean;
}
