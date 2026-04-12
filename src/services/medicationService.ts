import type { ElderBinding, Medication, MedicationPlan, ReminderEvent, UserProfile } from '../types';

/** 解析 YYYY-MM-DD 为本地零点，避免时区偏移 */
function parseLocalDateYmd(ymd: string): Date {
  const part = ymd.split('T')[0];
  const [y, m, d] = part.split('-').map((x) => parseInt(x, 10));
  return new Date(y || 1970, (m || 1) - 1, d || 1);
}

function sameLocalCalendarDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** weekdaysMask 下标 0=周日 … 6=周六，与 Date#getDay() 一致 */
function isWeekdayActive(d: Date, mask: string | undefined): boolean {
  if (!mask || mask.length !== 7) return true;
  return mask[d.getDay()] === '1';
}

/**
 * 按活跃计划为「今天」生成提醒（原逻辑只在创建计划当天写一次，第二天起列表为空，弹窗也不会再出）
 */
function syncTodayRemindersFromPlans(userId: string, store: LocalStore): boolean {
  const now = new Date();
  const dayAnchor = new Date(now);
  dayAnchor.setHours(0, 0, 0, 0);

  let changed = false;
  for (const plan of store.plans) {
    if (plan.targetUserId !== userId) continue;
    if (plan.status !== 'active') continue;

    const start = plan.startDate ? parseLocalDateYmd(plan.startDate) : new Date(dayAnchor);
    start.setHours(0, 0, 0, 0);
    if (dayAnchor < start) continue;

    if (plan.endDate) {
      const end = parseLocalDateYmd(plan.endDate);
      end.setHours(23, 59, 59, 999);
      if (now > end) continue;
    }

    const med = store.medications.find((m) => m.id === plan.medicineId);
    const medicineName = med?.name ?? '药品';

    for (const sched of plan.schedules) {
      if (!isWeekdayActive(now, sched.weekdaysMask)) continue;

      const due = new Date(dayAnchor);
      due.setHours(sched.hour ?? 0, sched.minute ?? 0, 0, 0);

      const dup = store.reminders.some((r) => {
        if (r.planId !== plan.id) return false;
        const rt = new Date(r.dueTime);
        return (
          rt.getFullYear() === due.getFullYear() &&
          rt.getMonth() === due.getMonth() &&
          rt.getDate() === due.getDate() &&
          rt.getHours() === due.getHours() &&
          rt.getMinutes() === due.getMinutes()
        );
      });
      if (dup) continue;

      const createdAt = new Date().toISOString();
      store.reminders.push({
        id: newId(),
        targetUserId: userId,
        planId: plan.id,
        scheduleId: sched.id || newId(),
        dueTime: due.toISOString(),
        status: 'pending',
        medicineName,
        createdAt,
      });
      changed = true;
    }
  }
  return changed;
}

const REGISTRY_KEY = 'medapp_user_registry';

interface Registry {
  users: Record<
    string,
    {
      phone: string;
      shortId: string;
      displayName: string;
    }
  >;
}

interface LocalStore {
  medications: Medication[];
  plans: MedicationPlan[];
  reminders: ReminderEvent[];
  bindings: ElderBinding[];
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

function storeKey(userId: string): string {
  return `medapp_store_${userId}`;
}

function loadStore(userId: string): LocalStore {
  try {
    const raw = localStorage.getItem(storeKey(userId));
    if (!raw) {
      return { medications: [], plans: [], reminders: [], bindings: [] };
    }
    return JSON.parse(raw) as LocalStore;
  } catch {
    return { medications: [], plans: [], reminders: [], bindings: [] };
  }
}

function saveStore(userId: string, store: LocalStore): void {
  localStorage.setItem(storeKey(userId), JSON.stringify(store));
}

function newId(): string {
  return crypto.randomUUID();
}

class MedicationService {
  testConnection(): void {
    /* 无远程存储，跳过 */
  }

  async getBindings(userId: string): Promise<ElderBinding[]> {
    const store = loadStore(userId);
    return store.bindings.filter((b) => b.active);
  }

  async bindElder(managerUserId: string, shortId: string, phoneLast4: string): Promise<{ success: boolean; elderId: string }> {
    const reg = loadRegistry();
    let elderId: string | null = null;
    for (const [uid, u] of Object.entries(reg.users)) {
      if (u.shortId === shortId) {
        elderId = uid;
        break;
      }
    }
    if (!elderId) throw new Error('未找到该 ID 的用户');

    const elder = reg.users[elderId];
    if (!elder.phone || !elder.phone.endsWith(phoneLast4)) {
      throw new Error('手机尾号不匹配');
    }
    if (elderId === managerUserId) throw new Error('不能绑定自己');

    const store = loadStore(managerUserId);
    const exists = store.bindings.some(
      (b) => b.managerUserId === managerUserId && b.elderUserId === elderId && b.active,
    );
    if (exists) throw new Error('已经绑定过该用户');

    const binding: ElderBinding = {
      id: newId(),
      managerUserId,
      elderUserId: elderId,
      relationType: 'family',
      canViewRecords: true,
      canViewImages: true,
      canReceiveAlerts: true,
      canEditPlans: true,
      active: true,
      createdAt: new Date().toISOString(),
    };
    store.bindings.push(binding);
    saveStore(managerUserId, store);
    return { success: true, elderId };
  }

  async getMedications(targetUserId: string): Promise<Medication[]> {
    const store = loadStore(targetUserId);
    return store.medications.filter((m) => !m.archived);
  }

  async getPlans(targetUserId: string): Promise<MedicationPlan[]> {
    return loadStore(targetUserId).plans;
  }

  async addMedication(med: Omit<Medication, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const store = loadStore(med.targetUserId);
    const id = newId();
    const now = new Date().toISOString();
    store.medications.push({
      ...med,
      id,
      createdAt: now,
      updatedAt: now,
    });
    saveStore(med.targetUserId, store);
    return id;
  }

  async updateMedication(id: string, updates: Partial<Medication>): Promise<void> {
    /* 在所有 store 中查找（通常只有本人 targetUserId） */
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key?.startsWith('medapp_store_')) continue;
      const userId = key.replace('medapp_store_', '');
      const store = loadStore(userId);
      const idx = store.medications.findIndex((m) => m.id === id);
      if (idx >= 0) {
        store.medications[idx] = {
          ...store.medications[idx],
          ...updates,
          updatedAt: new Date().toISOString(),
        };
        saveStore(userId, store);
        return;
      }
    }
  }

  async deleteMedication(id: string): Promise<void> {
    await this.updateMedication(id, { archived: true });
  }

  async getTodayReminders(targetUserId: string): Promise<ReminderEvent[]> {
    const store = loadStore(targetUserId);
    if (syncTodayRemindersFromPlans(targetUserId, store)) {
      saveStore(targetUserId, store);
    }
    const today = new Date();
    return store.reminders.filter(
      (r) => r.targetUserId === targetUserId && sameLocalCalendarDay(new Date(r.dueTime), today),
    );
  }

  subscribeToTodayReminders(targetUserId: string, callback: (events: ReminderEvent[]) => void): () => void {
    const run = () => {
      void this.getTodayReminders(targetUserId).then((events) => {
        events.sort((a, b) => new Date(a.dueTime).getTime() - new Date(b.dueTime).getTime());
        callback(events);
      });
    };
    run();
    const id = window.setInterval(run, 3000);
    return () => window.clearInterval(id);
  }

  async confirmIntake(eventId: string, _userId: string): Promise<void> {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key?.startsWith('medapp_store_')) continue;
      const uid = key.replace('medapp_store_', '');
      const store = loadStore(uid);
      const idx = store.reminders.findIndex((r) => r.id === eventId);
      if (idx >= 0) {
        store.reminders[idx] = {
          ...store.reminders[idx],
          status: 'taken',
          confirmedAt: new Date().toISOString(),
        };
        saveStore(uid, store);
        return;
      }
    }
  }

  async deleteReminder(eventId: string): Promise<void> {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key?.startsWith('medapp_store_')) continue;
      const uid = key.replace('medapp_store_', '');
      const store = loadStore(uid);
      const idx = store.reminders.findIndex((r) => r.id === eventId);
      if (idx >= 0) {
        store.reminders.splice(idx, 1);
        saveStore(uid, store);
        return;
      }
    }
  }

  async addMedicationPlan(plan: Omit<MedicationPlan, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const store = loadStore(plan.targetUserId);
    const med = store.medications.find((m) => m.id === plan.medicineId);
    const medicineName = med?.name ?? '药品';
    const planId = newId();
    const createdAt = new Date().toISOString();
    const fullPlan: MedicationPlan = {
      ...plan,
      id: planId,
      createdAt,
      updatedAt: createdAt,
    };
    store.plans.push(fullPlan);

    const now = new Date();
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    for (const schedule of plan.schedules) {
      const dueTime = new Date(today);
      dueTime.setHours(schedule.hour, schedule.minute, 0, 0);
      if (dueTime.getTime() > now.getTime() - 5 * 60 * 1000) {
        store.reminders.push({
          id: newId(),
          targetUserId: plan.targetUserId,
          planId,
          scheduleId: schedule.id || newId(),
          dueTime: dueTime.toISOString(),
          status: 'pending',
          medicineName,
          createdAt,
        });
      }
    }
    saveStore(plan.targetUserId, store);
    return planId;
  }

  async addTestReminder(userId: string): Promise<void> {
    const store = loadStore(userId);
    const now = new Date();
    const testTime = new Date(now.getTime() + 5000);
    store.reminders.push({
      id: newId(),
      targetUserId: userId,
      planId: 'test-plan',
      scheduleId: 'test-schedule',
      dueTime: testTime.toISOString(),
      status: 'pending',
      createdAt: now.toISOString(),
    });
    saveStore(userId, store);
  }
}

export const medicationService = new MedicationService();
