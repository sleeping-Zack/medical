/** 与 production_stack FastAPI 通信；认证数据存 localStorage */

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly code?: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

const ACCESS_KEY = 'medapp_access_token';
const REFRESH_KEY = 'medapp_refresh_token';

export function getAccessToken(): string | null {
  return localStorage.getItem(ACCESS_KEY);
}

export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_KEY);
}

export function saveTokenPair(pair: TokenPair): void {
  localStorage.setItem(ACCESS_KEY, pair.access_token);
  localStorage.setItem(REFRESH_KEY, pair.refresh_token);
}

export function clearTokenPair(): void {
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

async function parseJson(res: Response): Promise<{ code: number; message: string; data: unknown }> {
  const text = await res.text();
  try {
    return JSON.parse(text) as { code: number; message: string; data: unknown };
  } catch {
    throw new ApiError('服务返回格式异常');
  }
}

export async function apiPostJson<T>(path: string, body: unknown, withAuth = false): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (withAuth) {
    const t = getAccessToken();
    if (t) headers['Authorization'] = `Bearer ${t}`;
  }
  const res = await fetch(`${API_BASE_URL}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  const json = await parseJson(res);
  if (json.code !== 0) throw new ApiError(json.message || '请求失败', json.code);
  return json.data as T;
}

export async function apiGetJson<T>(path: string): Promise<T> {
  const headers: Record<string, string> = {};
  const t = getAccessToken();
  if (t) headers['Authorization'] = `Bearer ${t}`;
  const res = await fetch(`${API_BASE_URL}${path}`, { headers });
  const json = await parseJson(res);
  if (json.code !== 0) throw new ApiError(json.message || '请求失败', json.code);
  return json.data as T;
}

export async function apiPutJson<T>(path: string, body: unknown): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const t = getAccessToken();
  if (t) headers['Authorization'] = `Bearer ${t}`;
  const res = await fetch(`${API_BASE_URL}${path}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify(body),
  });
  const json = await parseJson(res);
  if (json.code !== 0) throw new ApiError(json.message || '请求失败', json.code);
  return json.data as T;
}

export async function tryRefreshTokens(): Promise<boolean> {
  const refresh = getRefreshToken();
  if (!refresh) return false;
  try {
    const pair = await apiPostJson<TokenPair>('/api/v1/auth/refresh', {
      refresh_token: refresh,
    });
    saveTokenPair(pair);
    return true;
  } catch {
    clearTokenPair();
    return false;
  }
}
