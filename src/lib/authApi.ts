import {
  apiGetJson,
  apiPostJson,
  clearTokenPair,
  saveTokenPair,
  tryRefreshTokens,
  type TokenPair,
} from './api';

export interface UserMe {
  id: number;
  phone: string;
  role: string;
}

export async function sendRegisterSms(phone: string): Promise<{ cooldown_seconds: number; debug_code?: string | null }> {
  return apiPostJson('/api/v1/auth/sms/send', { phone, scene: 'register' });
}

export async function loginWithPasswordApi(phone: string, password: string): Promise<UserMe> {
  const pair = await apiPostJson<TokenPair>('/api/v1/auth/login/password', { phone, password });
  saveTokenPair(pair);
  return fetchMe();
}

export async function registerApi(
  phone: string,
  code: string,
  password: string,
  role: 'personal' | 'elderly',
): Promise<UserMe> {
  const pair = await apiPostJson<TokenPair>('/api/v1/auth/register', {
    phone,
    code,
    password,
    role,
  });
  saveTokenPair(pair);
  return fetchMe();
}

export async function fetchMe(): Promise<UserMe> {
  try {
    return await apiGetJson<UserMe>('/api/v1/auth/me');
  } catch (e) {
    const ok = await tryRefreshTokens();
    if (ok) return await apiGetJson<UserMe>('/api/v1/auth/me');
    throw e;
  }
}

export async function logoutApi(): Promise<void> {
  try {
    await apiPostJson('/api/v1/auth/logout', {}, true);
  } catch {
    /* 仍清理本地 token */
  }
  clearTokenPair();
}
