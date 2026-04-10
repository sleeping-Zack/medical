
export type UserRole = 'caregiver' | 'elder';

export type DosageForm = 'tablet' | 'capsule' | 'liquid' | 'granule' | 'other';
export type DosageUnit = 'tablet' | 'capsule' | 'ml' | 'pack' | 'other';
export type ReminderStatus = 'pending' | 'notified' | 'taken' | 'snoozed' | 'missed' | 'deleted';

export interface Medication {
  id: string;
  targetUserId: string;
  createdByUserId: string;
  name: string;
  specification?: string;
  dosageForm: DosageForm;
  colorDesc?: string;
  shapeDesc?: string;
  note?: string;
  archived: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Schedule {
  id: string;
  hour: number;
  minute: number;
  dosageAmount: number;
  dosageUnit: DosageUnit;
  weekdaysMask: string; // "1111111"
  graceMinutes: number;
  snoozeMinutes: number;
}

export interface MedicationPlan {
  id: string;
  targetUserId: string;
  createdByUserId: string;
  medicineId: string;
  status: 'active' | 'paused' | 'ended';
  startDate: string;
  endDate?: string;
  note?: string;
  schedules: Schedule[];
  createdAt: string;
  updatedAt: string;
}

export interface ReminderEvent {
  id: string;
  targetUserId: string;
  planId: string;
  scheduleId: string;
  dueTime: string;
  status: ReminderStatus;
  medicineName?: string;
  notifiedAt?: string;
  snoozeUntil?: string;
  confirmedAt?: string;
  createdAt: string;
}

export interface IntakeRecord {
  id: string;
  reminderEventId: string;
  targetUserId: string;
  confirmedByUserId: string;
  action: 'taken' | 'snoozed' | 'manual' | 'missed';
  intakeTime: string;
  photoRequired: boolean;
  createdAt: string;
}

export interface UserProfile {
  uid: string;
  displayName: string;
  defaultMode: UserRole;
  fontScale: number;
  voiceEnabled: boolean;
  highContrast: boolean;
  phone?: string;
  shortId?: string;
}

export interface ElderBinding {
  id: string;
  managerUserId: string;
  elderUserId: string;
  relationType: string;
  canViewRecords: boolean;
  canViewImages: boolean;
  canReceiveAlerts: boolean;
  canEditPlans: boolean;
  active: boolean;
  createdAt: string;
}
