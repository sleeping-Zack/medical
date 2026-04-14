import type { ElderBinding, UserProfile } from '../types';
import { apiGetJson, apiPostJson } from './api';

/** 与后端 BoundElderOut 一致 */
export interface BoundElderOut {
  elder_id: number;
  short_id: string;
  phone_masked: string;
  can_manage_medicine: boolean;
  can_view_records: boolean;
  can_receive_alerts: boolean;
}

/** 将服务端绑定列表转为 Web 端既有结构（原先用 localStorage，现与库一致） */
export function mapServerBindingsToUi(
  managerUid: string,
  rows: BoundElderOut[],
): { bindings: ElderBinding[]; boundUsers: Record<string, UserProfile> } {
  const boundUsers: Record<string, UserProfile> = {};
  const bindings: ElderBinding[] = rows.map((row) => {
    const elderUserId = String(row.elder_id);
    boundUsers[elderUserId] = {
      uid: elderUserId,
      displayName: `长辈 ${row.phone_masked}`,
      defaultMode: 'elder',
      fontScale: 1.2,
      voiceEnabled: true,
      highContrast: false,
      shortId: row.short_id,
    };
    return {
      id: `srv-${row.elder_id}`,
      managerUserId: managerUid,
      elderUserId,
      relationType: 'family',
      canViewRecords: row.can_view_records,
      canViewImages: true,
      canReceiveAlerts: row.can_receive_alerts,
      canEditPlans: row.can_manage_medicine,
      active: true,
      createdAt: new Date().toISOString(),
    };
  });
  return { bindings, boundUsers };
}

/** 家属端：短号 + 手机后四位，与数据库 users.short_id 校验 */
export async function createBinding(elder_short_id: string, phone_last4: string): Promise<BoundElderOut> {
  return apiPostJson<BoundElderOut>(
    '/api/v1/bindings',
    { elder_short_id, phone_last4 },
    true,
  );
}

export async function listBindingsFromServer(): Promise<BoundElderOut[]> {
  return apiGetJson<BoundElderOut[]>('/api/v1/bindings');
}
