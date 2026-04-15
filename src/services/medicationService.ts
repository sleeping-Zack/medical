import { apiGetJson, apiPostJson, apiPutJson } from '../lib/api';
import type {
  ElderBinding,
  Medication,
  MedicationPlan,
  ReminderEvent,
  UserProfile,
} from '../types';

const REGISTRY_KEY = 'medapp_user_registry';

interface Registry {
  users: Record<string, { phone: string; shortId: string; displayName: string }>;
}

interface ServerMedicine {
  id: number;
  target_user_id: number;
  name: string;
  specification?: string | null;
  note?: string | null;
  archived: boolean;
  created_at: string;
  updated_at: string;
}

interface ServerPlan {
  id: number;
  target_user_id: number;
  medicine_id: number;
  medicine_name: string;
  status: 'active' | 'paused';
  start_date: string;
  schedules_json: Array<{ hour: number; minute: number; weekdays: string }>;
  label?: string | null;
  created_at: string;
  updated_at: string;
}

interface ServerReminder {
  id: string;
  target_user_id: number;
  plan_id: number;
  schedule_id: string;
  due_time: string;
  status: 'pending' | 'taken' | 'deleted' | 'missed' | 'snoozed';
  medicine_name: string;
  created_at: string;
  confirmed_at?: string | null;
  snooze_until?: string | null;
  action_source?: string | null;
}

interface ServerIncomingBinding {
  caregiver_id: number;
  short_id: string;
  phone_masked: string;
  role: string;
}

interface AdherencePoint {
  date: string;
  total: number;
  taken: number;
  rate: number;
}

function loadRegistry(): Registry {
  try {
    const raw = localStorage.getItem(REGISTRY_KEY);
    if (!raw) return { users: {} };
    return JSON.parse(raw) as Registry;
  } catch {
    return { users: {} };
  }
}

function saveRegistry(reg: Registry): void {
  localStorage.setItem(REGISTRY_KEY, JSON.stringify(reg));
}

export function syncProfileToRegistry(profile: UserProfile): void {
  const reg = loadRegistry();
  reg.users[profile.uid] = {
    phone: profile.phone || '',
    shortId: profile.shortId || '',
    displayName: profile.displayName,
  };
  saveRegistry(reg);
}

export function getProfileFromRegistry(uid: string): UserProfile | null {
  const reg = loadRegistry();
  const u = reg.users[uid];
  if (!u) return null;
  return {
    uid,
    displayName: u.displayName,
    defaultMode: 'elder',
    fontScale: 1.2,
    voiceEnabled: true,
    highContrast: false,
    phone: u.phone,
    shortId: u.shortId,
  };
}

function toFrontendWeekdaysMask(weekdaysMonToSun: string): string {
  if (!weekdaysMonToSun || weekdaysMonToSun.length !== 7) return '1111111';
  return weekdaysMonToSun.slice(-1) + weekdaysMonToSun.slice(0, 6);
}

function toBackendWeekdays(maskSunToSat: string): string {
  if (!maskSunToSat || maskSunToSat.length !== 7) return '1111111';
  return maskSunToSat.slice(1) + maskSunToSat[0];
}

function mapMedicine(row: ServerMedicine): Medication {
  return {
    id: String(row.id),
    targetUserId: String(row.target_user_id),
    createdByUserId: String(row.target_user_id),
    name: row.name,
    specification: row.specification || undefined,
    dosageForm: 'other',
    colorDesc: '',
    shapeDesc: '',
    note: row.note || undefined,
    archived: row.archived,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapPlan(row: ServerPlan): MedicationPlan {
  return {
    id: String(row.id),
    targetUserId: String(row.target_user_id),
    createdByUserId: String(row.target_user_id),
    medicineId: String(row.medicine_id),
    status: row.status,
    startDate: row.start_date,
    note: row.label || undefined,
    schedules: (row.schedules_json || []).map((s, idx) => ({
      id: `${row.id}-${idx}`,
      hour: s.hour,
      minute: s.minute,
      dosageAmount: 1,
      dosageUnit: 'other',
      weekdaysMask: toFrontendWeekdaysMask(s.weekdays),
      graceMinutes: 30,
      snoozeMinutes: 10,
    })),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function dateYmd(d: Date): string {
  const y = d.getFullYear();
  const m = `${d.getMonth() + 1}`.padStart(2, '0');
  const day = `${d.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${day}`;
}

class MedicationService {
  testConnection(): void {
    /* no-op */
  }

  async getBindings(_userId: string): Promise<ElderBinding[]> {
    return [];
  }

  async bindElder(_managerUserId: string, _shortId: string, _phoneLast4: string): Promise<{ success: boolean; elderId: string }> {
    throw new Error('绑定能力已迁移到 careApi.createBinding');
  }

  async getManagersForElder(_elderUserId: string): Promise<{ uid: string; name: string; phone: string; relation: string }[]> {
    const rows = await apiGetJson<ServerIncomingBinding[]>('/api/v1/bindings/incoming');
    return rows.map((r) => ({
      uid: String(r.caregiver_id),
      name: `家人（${r.phone_masked}）`,
      phone: r.phone_masked,
      relation: r.role === 'personal' ? '家人' : '看护',
    }));
  }

  async getMedications(targetUserId: string): Promise<Medication[]> {
    const rows = await apiGetJson<ServerMedicine[]>(`/api/v1/care/medicines?target_user_id=${encodeURIComponent(targetUserId)}`);
    return rows.map(mapMedicine).filter((m) => !m.archived);
  }

  async getPlans(targetUserId: string): Promise<MedicationPlan[]> {
    const rows = await apiGetJson<ServerPlan[]>(`/api/v1/care/plans?target_user_id=${encodeURIComponent(targetUserId)}`);
    return rows.map(mapPlan);
  }

  async addMedication(med: Omit<Medication, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const row = await apiPostJson<ServerMedicine>(
      '/api/v1/care/medicines',
      {
        target_user_id: Number(med.targetUserId),
        name: med.name,
        specification: med.specification || null,
        note: med.note || null,
      },
      true,
    );
    return String(row.id);
  }

  async updateMedication(id: string, updates: Partial<Medication>): Promise<void> {
    await apiPutJson<ServerMedicine>(`/api/v1/care/medicines/${encodeURIComponent(id)}`, {
      name: updates.name,
      specification: updates.specification,
      note: updates.note,
      archived: updates.archived,
    });
  }

  async deleteMedication(id: string): Promise<void> {
    await this.updateMedication(id, { archived: true });
  }

  async getTodayReminders(targetUserId: string): Promise<ReminderEvent[]> {
    const rows = await apiGetJson<ServerReminder[]>(
      `/api/v1/care/reminders?target_user_id=${encodeURIComponent(targetUserId)}&on_date=${encodeURIComponent(dateYmd(new Date()))}`,
    );
    return rows
      .filter((r) => r.status !== 'deleted')
      .map((r) => ({
        id: r.id,
        targetUserId: String(r.target_user_id),
        planId: String(r.plan_id),
        scheduleId: r.schedule_id,
        dueTime: r.due_time,
        status: r.status,
        medicineName: r.medicine_name,
        createdAt: r.created_at,
        confirmedAt: r.confirmed_at || undefined,
        snoozeUntil: r.snooze_until || undefined,
      }));
  }

  async getAdherenceTrend(targetUserId: string, days = 7): Promise<Array<{ date: string; rate: number; taken: number; total: number }>> {
    const rows = await apiGetJson<AdherencePoint[]>(
      `/api/v1/care/adherence?target_user_id=${encodeURIComponent(targetUserId)}&days=${encodeURIComponent(String(days))}`,
    );
    return rows.map((r) => ({ date: r.date, rate: r.rate, taken: r.taken, total: r.total }));
  }

  subscribeToTodayReminders(targetUserId: string, callback: (events: ReminderEvent[]) => void): () => void {
    const run = () => {
      void this.getTodayReminders(targetUserId).then(callback);
    };
    run();
    const id = window.setInterval(run, 3000);
    return () => window.clearInterval(id);
  }

  async confirmIntake(eventId: string, _userId: string): Promise<void> {
    const [targetUserId, planId, scheduleId, dueTime] = eventId.split('|');
    if (!targetUserId || !planId || !scheduleId || !dueTime) return;
    await apiPostJson(
      '/api/v1/care/reminders/mark',
      {
        target_user_id: Number(targetUserId),
        plan_id: Number(planId),
        schedule_id: scheduleId,
        due_time: dueTime,
        action: 'taken',
      },
      true,
    );
  }

  async deleteReminder(eventId: string): Promise<void> {
    const [targetUserId, planId, scheduleId, dueTime] = eventId.split('|');
    if (!targetUserId || !planId || !scheduleId || !dueTime) return;
    await apiPostJson(
      '/api/v1/care/reminders/mark',
      {
        target_user_id: Number(targetUserId),
        plan_id: Number(planId),
        schedule_id: scheduleId,
        due_time: dueTime,
        action: 'deleted',
      },
      true,
    );
  }

  async markMissedReminder(eventId: string): Promise<void> {
    const [targetUserId, planId, scheduleId, dueTime] = eventId.split('|');
    if (!targetUserId || !planId || !scheduleId || !dueTime) return;
    await apiPostJson(
      '/api/v1/care/reminders/mark',
      {
        target_user_id: Number(targetUserId),
        plan_id: Number(planId),
        schedule_id: scheduleId,
        due_time: dueTime,
        action: 'missed',
      },
      true,
    );
  }

  async snoozeReminder(eventId: string, snoozeMinutes = 10): Promise<void> {
    const [targetUserId, planId, scheduleId, dueTime] = eventId.split('|');
    if (!targetUserId || !planId || !scheduleId || !dueTime) return;
    await apiPostJson(
      '/api/v1/care/reminders/snooze',
      {
        target_user_id: Number(targetUserId),
        plan_id: Number(planId),
        schedule_id: scheduleId,
        due_time: dueTime,
        snooze_minutes: snoozeMinutes,
        action_source: 'app',
      },
      true,
    );
  }

  async addMedicationPlan(plan: Omit<MedicationPlan, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const row = await apiPostJson<ServerPlan>(
      '/api/v1/care/plans',
      {
        target_user_id: Number(plan.targetUserId),
        medicine_id: Number(plan.medicineId),
        start_date: (plan.startDate || '').split('T')[0],
        schedules: plan.schedules.map((s) => ({
          hour: s.hour,
          minute: s.minute,
          weekdays: toBackendWeekdays(s.weekdaysMask),
        })),
        label: plan.note || null,
      },
      true,
    );
    return String(row.id);
  }

  async addTestReminder(_userId: string): Promise<void> {
    return;
  }
}

export const medicationService = new MedicationService();
