import React, { useEffect, useMemo, useState } from 'react';
import {
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
  ComposedChart,
} from 'recharts';
import { Phone, MessageCircle, Settings, LogOut } from 'lucide-react';
import { cn } from '../lib/utils';
import type { MedicationPlan, ReminderEvent, UserProfile } from '../types';
import { medicationService } from '../services/medicationService';

const warm = {
  text: '#5C4A3D',
  textSoft: '#8B7A6E',
  deep: '#E8863D',
  peach: '#FFE4CC',
  cream: '#FFF8F0',
};

const warmTips = [
  '记得慢慢喝几口温水，对身体更舒服。',
  '今天按时吃药，心里也会更踏实。',
  '您认真照顾自己的样子，真的很棒。',
  '吃完饭歇一会儿再吃药也可以哦。',
  '天气变化时，多注意休息。',
];

const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

function dosageLabel(rem: ReminderEvent, plans: MedicationPlan[]): string {
  const plan = plans.find((p) => p.id === rem.planId);
  const sched =
    plan?.schedules?.find((s) => s.id === rem.scheduleId) || plan?.schedules?.[0];
  if (sched) {
    const u =
      sched.dosageUnit === 'tablet'
        ? '片'
        : sched.dosageUnit === 'capsule'
          ? '粒'
          : sched.dosageUnit === 'ml'
            ? 'ml'
            : '';
    return `${sched.dosageAmount}${u ? ' ' + u : ''}`.trim();
  }
  return '按医嘱';
}

function buildWeeklyTrendFromServer(rows: Array<{ date: string; rate: number; taken: number; total: number }>) {
  if (!rows || rows.length === 0) {
    return weekLabels.map((name) => ({ name, rate: 0, taken: 0, total: 0 }));
  }
  return rows.map((r) => {
    const d = new Date(r.date);
    const jsWeek = d.getDay();
    const idx = jsWeek === 0 ? 6 : jsWeek - 1;
    return {
      name: weekLabels[idx],
      rate: r.rate,
      taken: r.taken,
      total: r.total,
    };
  });
}

function greeting(hour: number) {
  if (hour < 11) return '早上好呀，今天也从一口温水开始吧';
  if (hour < 14) return '中午好，慢慢吃、慢慢歇，身体最要紧';
  if (hour < 18) return '下午好，累了就坐一会儿，我在这儿陪着您';
  return '晚上好，把今天的事放下，好好放松';
}

function statusLabel(
  r: ReminderEvent,
  snoozedUntil: number | undefined,
  now: number,
): { text: string; className: string } {
  if (r.status === 'taken') return { text: '已服下 ✓', className: 'bg-emerald-100 text-emerald-800' };
  if (r.status === 'missed') return { text: '没赶上，别太担心', className: 'bg-rose-100 text-rose-800' };
  if (snoozedUntil && now < snoozedUntil)
    return { text: '稍后再服', className: 'bg-sky-100 text-sky-900' };
  const due = new Date(r.dueTime).getTime();
  if (now > due + 60 * 60 * 1000) return { text: '待处理', className: 'bg-amber-100 text-amber-900' };
  return { text: '待服用', className: 'bg-amber-50 text-amber-900' };
}

export interface ElderHomeViewProps {
  user: { uid: string; phone: string };
  profile: UserProfile | null;
  reminders: ReminderEvent[];
  plans: MedicationPlan[];
  snoozedReminders: Map<string, number>;
  setSnoozedReminders: React.Dispatch<React.SetStateAction<Map<string, number>>>;
  onConfirmIntake: (id: string) => Promise<void>;
  setNotification: (n: { message: string; type: 'success' | 'error' }) => void;
  setView: (v: 'home' | 'medicines' | 'plans' | 'bindings' | 'reports' | 'settings') => void;
  onLogout: () => void | Promise<void>;
}

export function ElderHomeView({
  user,
  profile,
  reminders,
  plans,
  snoozedReminders,
  setSnoozedReminders,
  onConfirmIntake,
  setNotification,
  setView,
  onLogout,
}: ElderHomeViewProps) {
  const [now, setNow] = useState(() => new Date());
  const [managers, setManagers] = useState<
    { uid: string; name: string; phone: string; relation: string }[]
  >([]);
  const [weeklyData, setWeeklyData] = useState<Array<{ name: string; rate: number; taken: number; total: number }>>(
    weekLabels.map((name) => ({ name, rate: 0, taken: 0, total: 0 })),
  );

  useEffect(() => {
    const t = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(t);
  }, []);

  useEffect(() => {
    const refresh = async () => {
      try {
        const data = await medicationService.getManagersForElder(user.uid);
        setManagers(data);
      } catch {
        setManagers([]);
      }
    };
    void refresh();
    const onVis = () => {
      if (document.visibilityState === 'visible') void refresh();
    };
    document.addEventListener('visibilitychange', onVis);
    return () => {
      document.removeEventListener('visibilitychange', onVis);
    };
  }, [user.uid]);

  useEffect(() => {
    const load = async () => {
      try {
        const rows = await medicationService.getAdherenceTrend(user.uid, 7);
        setWeeklyData(buildWeeklyTrendFromServer(rows));
      } catch {
        setWeeklyData(weekLabels.map((name) => ({ name, rate: 0, taken: 0, total: 0 })));
      }
    };
    void load();
  }, [user.uid, reminders.length]);

  const sorted = useMemo(() => {
    return [...reminders].sort((a, b) => new Date(a.dueTime).getTime() - new Date(b.dueTime).getTime());
  }, [reminders]);

  const avatars = ['👨', '👩', '🧒', '👴', '👵'];

  const completedToday = sorted.filter((r) => r.status === 'taken').length;
  const scheduledToday = sorted.length;
  const progress = scheduledToday > 0 ? completedToday / scheduledToday : 0;

  const ts = now.getTime();
  const nextPending = sorted.find((r) => {
    if (r.status !== 'pending') return false;
    const sn = snoozedReminders.get(r.id);
    if (sn && ts < sn) return false;
    return true;
  });

  const allDone = scheduledToday > 0 && completedToday === scheduledToday;
  const phoneTail =
    user.phone && user.phone.length >= 4 ? `尾号 ${user.phone.slice(-4)}` : '';

  const companionLine = (() => {
    if (scheduledToday <= 0) return '今天还没有用药计划，可以让家人帮您加好，我会按时提醒您。';
    if (allDone) return '今天的药都安排完啦，喝口温水，慢慢休息一会儿吧。';
    const left = scheduledToday - completedToday;
    if (nextPending) {
      const t = new Date(nextPending.dueTime).toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
      });
      return `今天还剩 ${left} 次，下一剂约在 ${t}，我在这儿陪着您，别急。`;
    }
    return '下面按时间列好了今天的每一次，您慢慢看就好。';
  })();

  const tipIdx = now.getDate() % warmTips.length;
  const encourage =
    weeklyData[6].rate >= 90
      ? '曲线往上走，说明您对自己特别用心'
      : weeklyData[6].rate >= 60
        ? '有起有伏很正常，重要的是您还在坚持'
        : '咱们不和别人比，只要比昨天多一点点就好';

  const handleTaken = async () => {
    if (!nextPending) return;
    try {
      await onConfirmIntake(nextPending.id);
      setSnoozedReminders((prev) => {
        const m = new Map(prev);
        m.delete(nextPending.id);
        return m;
      });
      setNotification({ message: '记下来了，您真棒！', type: 'success' });
    } catch {
      setNotification({ message: '操作失败，请重试', type: 'error' });
    }
  };

  const handleSnooze = () => {
    if (!nextPending) return;
    setSnoozedReminders((prev) => new Map(prev).set(nextPending.id, Date.now() + 10 * 60 * 1000));
    setNotification({ message: '好的，稍后再提醒您～', type: 'success' });
  };

  const timeStr = now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false });
  const dateStr = `${now.getFullYear()} 年 ${now.getMonth() + 1} 月 ${now.getDate()} 日 · ${['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'][now.getDay()]}`;

  return (
    <div className="space-y-5 pb-28 max-w-lg mx-auto w-full">
      {/* 顶栏 */}
      <header className="flex items-center justify-between gap-3 px-1">
        <div>
          <h1 className="text-2xl font-black tracking-tight" style={{ color: warm.text }}>
            药安心
          </h1>
          <p className="text-base font-semibold mt-0.5" style={{ color: warm.textSoft }}>
            长辈版 · 大字好读
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setView('settings')}
            className="flex items-center gap-1.5 rounded-2xl px-4 py-2.5 font-bold text-base bg-white/90 border border-orange-200/80 shadow-md shadow-orange-900/5 active:scale-[0.98] transition-transform"
            style={{ color: warm.text }}
          >
            <Settings className="w-5 h-5" />
            设置
          </button>
          <button
            type="button"
            onClick={() => void onLogout()}
            className="flex items-center gap-1.5 rounded-2xl px-4 py-2.5 font-bold text-base bg-white/90 border border-orange-200/80 shadow-md shadow-orange-900/5 active:scale-[0.98] transition-transform"
            style={{ color: warm.text }}
          >
            <LogOut className="w-5 h-5" />
            退出
          </button>
        </div>
      </header>

      {/* 欢迎卡片 */}
      <section
        className="rounded-[28px] p-5 border shadow-xl shadow-amber-900/10"
        style={{
          background: `linear-gradient(135deg, rgba(255,255,255,0.96) 0%, ${warm.cream} 100%)`,
          borderColor: 'rgba(255, 179, 102, 0.45)',
        }}
      >
        <div className="flex gap-3">
          <div className="flex-1 min-w-0">
            <p className="text-[52px] font-extrabold leading-none tracking-tight" style={{ color: warm.text }}>
              {timeStr}
            </p>
            <p className="text-lg font-semibold mt-2 leading-snug" style={{ color: warm.textSoft }}>
              {dateStr}
            </p>
            <p className="text-xl font-bold mt-3 leading-snug" style={{ color: warm.deep }}>
              {greeting(now.getHours())}
            </p>
            {phoneTail ? (
              <p className="text-base font-semibold mt-1" style={{ color: warm.textSoft }}>
                亲爱的长辈（{phoneTail}）
              </p>
            ) : null}
            <p className="text-lg font-semibold mt-3 leading-relaxed" style={{ color: '#8FA894' }}>
              {companionLine}
            </p>
          </div>
          <div className="flex flex-col items-center shrink-0">
            <div
              className="w-[78px] h-[78px] rounded-full flex items-center justify-center text-[42px] shadow-lg"
              style={{
                background: 'rgba(244, 201, 93, 0.5)',
                boxShadow: '0 8px 18px rgba(255, 179, 102, 0.35)',
              }}
            >
              🌤️
            </div>
            <span className="text-[15px] font-bold mt-2" style={{ color: warm.textSoft }}>
              陪您
            </span>
          </div>
        </div>
      </section>

      {/* 绑定短号 */}
      {profile?.shortId ? (
        <section
          className="rounded-[22px] p-4 border shadow-md"
          style={{
            background: warm.cream,
            borderColor: 'rgba(255, 179, 102, 0.5)',
          }}
        >
          <p className="text-base font-bold" style={{ color: warm.textSoft }}>
            给子女看的绑定短号
          </p>
          <p className="text-[28px] font-black tracking-[0.35em] mt-1" style={{ color: warm.deep }}>
            {profile.shortId}
          </p>
          <p className="text-[15px] font-semibold mt-2 leading-snug" style={{ color: '#8FA894' }}>
            告诉孩子这几个数字，他们就能在手机上关心您啦
          </p>
        </section>
      ) : null}

      {/* 今日服药主卡片 */}
      <section
        className="rounded-[28px] p-6 border-2 border-white/65 shadow-xl shadow-amber-900/15 space-y-4"
        style={{
          background: allDone
            ? 'linear-gradient(135deg, #E8F5E9 0%, rgba(197, 213, 192, 0.5) 100%)'
            : `linear-gradient(135deg, ${warm.peach} 0%, rgba(255, 214, 204, 0.62) 100%)`,
        }}
      >
        <div className="flex items-center gap-2">
          <span className="text-2xl">💊</span>
          <h2 className="text-[22px] font-extrabold" style={{ color: warm.text }}>
            {allDone ? '今日服药已完成' : nextPending ? '下一剂记得按时吃' : '今日安排'}
          </h2>
        </div>

        {allDone ? (
          <p className="text-xl font-bold" style={{ color: warm.text }}>
            🌟 今天的药都吃完啦，真棒！
          </p>
        ) : nextPending ? (
          <>
            <p className="text-[26px] font-extrabold" style={{ color: warm.text }}>
              下一次：
              {new Date(nextPending.dueTime).toLocaleTimeString('zh-CN', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: false,
              })}
            </p>
            <p className="text-[22px] font-bold" style={{ color: warm.deep }}>
              {nextPending.medicineName || '药品'}
            </p>
            <p className="text-lg font-medium" style={{ color: warm.textSoft }}>
              数量：{dosageLabel(nextPending, plans)}
            </p>
          </>
        ) : (
          <p className="text-lg font-semibold" style={{ color: warm.textSoft }}>
            今天还没有安排服药哦
          </p>
        )}

        <div>
          <p className="text-lg font-bold mb-2" style={{ color: warm.text }}>
            今日已完成 {completedToday} / {scheduledToday} 次
          </p>
          <div className="h-3 rounded-full overflow-hidden bg-white/55">
            <div
              className="h-full rounded-full transition-all duration-500"
              style={{
                width: `${Math.round(progress * 100)}%`,
                backgroundColor: warm.deep,
              }}
            />
          </div>
        </div>

        {!allDone && nextPending ? (
          <div className="grid grid-cols-2 gap-3 pt-1">
            <button
              type="button"
              onClick={() => void handleTaken()}
              className="rounded-[22px] py-5 text-xl font-extrabold text-white shadow-lg active:scale-[0.98] transition-transform flex items-center justify-center gap-2"
              style={{ background: '#7CB87C' }}
            >
              我已服药
            </button>
            <button
              type="button"
              onClick={handleSnooze}
              className="rounded-[22px] py-5 text-xl font-extrabold shadow-lg active:scale-[0.98] transition-transform flex items-center justify-center gap-2 border-2 border-sky-200"
              style={{ background: '#B8D4E8', color: warm.text }}
            >
              稍后再服
            </button>
          </div>
        ) : null}
      </section>

      {/* 今日记录 */}
      <section
        className="rounded-[28px] p-5 border shadow-lg bg-white/95"
        style={{ borderColor: 'rgba(255, 228, 204, 0.55)' }}
      >
        <h3 className="text-[23px] font-extrabold" style={{ color: warm.text }}>
          今日吃药记录
        </h3>
        <p className="text-[17px] mt-1 leading-snug" style={{ color: warm.textSoft }}>
          按时间排好了，从上到下慢慢看就好
        </p>
        <div className="mt-4 space-y-2">
          {sorted.length === 0 ? (
            <p className="text-lg py-6 text-center leading-relaxed" style={{ color: warm.textSoft }}>
              今天还没有安排服药时间，可以让家人帮您加一下计划哦。
            </p>
          ) : (
            sorted.map((r, idx) => {
              const sn = snoozedReminders.get(r.id);
              const st = statusLabel(r, sn, ts);
              const time = new Date(r.dueTime).toLocaleTimeString('zh-CN', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: false,
              });
              return (
                <div key={r.id} className="flex gap-2">
                  <div className="flex flex-col items-center w-9 shrink-0 pt-1">
                    <span className="text-2xl">{r.status === 'taken' ? '✅' : '☀️'}</span>
                    {idx < sorted.length - 1 ? (
                      <div className="w-0.5 flex-1 min-h-[36px] mt-1 rounded-full" style={{ background: warm.peach }} />
                    ) : null}
                  </div>
                  <div
                    className="flex-1 rounded-[22px] p-4 border shadow-md mb-2"
                    style={{
                      background: 'rgba(255,255,255,0.92)',
                      borderColor: 'rgba(255, 228, 204, 0.55)',
                    }}
                  >
                    <p className="text-[22px] font-extrabold" style={{ color: warm.text }}>
                      {time}
                    </p>
                    <p className="text-[21px] font-bold mt-1" style={{ color: warm.deep }}>
                      {r.medicineName || '药品'}
                    </p>
                    <p className="text-[17px] mt-0.5" style={{ color: warm.textSoft }}>
                      数量：{dosageLabel(r, plans)}
                    </p>
                    <span className={cn('inline-block mt-2 px-3 py-1 rounded-full text-base font-bold', st.className)}>
                      {st.text}
                    </span>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </section>

      {/* 7 天趋势 */}
      <section
        className="rounded-[28px] p-5 border shadow-lg bg-white/95"
        style={{ borderColor: 'rgba(255, 228, 204, 0.5)' }}
      >
        <div className="flex items-center gap-2 mb-1">
          <span className="text-2xl">📈</span>
          <h3 className="text-[23px] font-extrabold" style={{ color: warm.text }}>
            最近 7 天按时完成率
          </h3>
        </div>
        <p className="text-lg font-semibold leading-snug" style={{ color: '#8FA894' }}>
          {encourage}
        </p>
        <p className="text-base mt-2" style={{ color: warm.textSoft }}>
          今天约 {weeklyData[6]?.rate ?? 0}% · 基于真实服药记录自动计算
        </p>
        <div className="h-52 w-full mt-4">
          <ResponsiveContainer width="100%" height="100%">
            <ComposedChart data={weeklyData}>
              <defs>
                <linearGradient id="elderRate" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#22c55e" stopOpacity={0.35} />
                  <stop offset="35%" stopColor="#3b82f6" stopOpacity={0.28} />
                  <stop offset="68%" stopColor="#ffffff" stopOpacity={0.22} />
                  <stop offset="100%" stopColor="#ef4444" stopOpacity={0.24} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke={warm.peach} />
              <XAxis dataKey="name" tick={{ fontSize: 15, fill: warm.text, fontWeight: 700 }} axisLine={false} tickLine={false} />
              <YAxis domain={[0, 100]} tickFormatter={(v) => `${v}%`} tick={{ fontSize: 12, fill: warm.textSoft }} width={36} />
              <Tooltip
                formatter={(v: number) => [`约 ${v}%`, '完成率']}
                contentStyle={{ borderRadius: 14, border: 'none', boxShadow: '0 8px 24px rgba(92,74,61,0.12)' }}
              />
              <Area type="monotone" dataKey="rate" stroke="transparent" strokeWidth={0} fill="url(#elderRate)" />
              <Line
                type="monotone"
                dataKey="rate"
                stroke="#E8863D"
                strokeWidth={3}
                dot={{ r: 5, fill: '#fff', strokeWidth: 2, stroke: '#E8863D' }}
              />
            </ComposedChart>
          </ResponsiveContainer>
        </div>
      </section>

      {/* 家人 */}
      <section
        className="rounded-[28px] p-5 border shadow-lg space-y-3"
        style={{
          background: `linear-gradient(135deg, rgba(184, 212, 232, 0.38) 0%, ${warm.cream} 100%)`,
          borderColor: 'rgba(184, 212, 232, 0.52)',
        }}
      >
        <div className="flex items-center gap-2">
          <span className="text-2xl">💛</span>
          <h3 className="text-[23px] font-extrabold" style={{ color: warm.text }}>
            已绑定的子女与家人
          </h3>
        </div>
        <p className="text-[17px] leading-snug" style={{ color: warm.textSoft }}>
          头像下面是称呼，有事一键联系（演示为提示，可后续接短信/电话）
        </p>
        {managers.length === 0 ? (
          <div className="text-lg leading-relaxed py-2 space-y-2" style={{ color: warm.textSoft }}>
            <p>还没有已绑定家人。</p>
            <p>请让对方使用绑定短号 + 手机后四位发起绑定，成功后这里会自动显示。</p>
          </div>
        ) : (
          <ul className="space-y-3">
            {managers.map((m, i) => (
              <li
                key={m.uid}
                className="flex items-center gap-4 rounded-3xl p-4 bg-white/95 border border-orange-100/80 shadow-md"
              >
                <div
                  className="w-[68px] h-[68px] rounded-full flex items-center justify-center text-[34px] shrink-0 shadow-md"
                  style={{ background: 'rgba(255, 228, 204, 0.65)' }}
                >
                  {avatars[i % avatars.length]}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-[22px] font-extrabold truncate" style={{ color: warm.text }}>
                    {m.name}
                  </p>
                  <p className="text-[17px] font-semibold" style={{ color: warm.textSoft }}>
                    {m.relation}
                  </p>
                </div>
                <div className="flex flex-col gap-2 shrink-0">
                  <button
                    type="button"
                    onClick={() => setNotification({ message: m.phone ? `可拨打 ${m.phone}（演示）` : '家人未留电话', type: 'success' })}
                    className="flex items-center gap-1.5 rounded-2xl px-3.5 py-2.5 text-base font-extrabold"
                    style={{ background: 'rgba(255, 179, 102, 0.48)', color: warm.text }}
                  >
                    <Phone className="w-5 h-5" />
                    电话
                  </button>
                  <button
                    type="button"
                    onClick={() => setNotification({ message: '发消息功能即将上线～', type: 'success' })}
                    className="flex items-center gap-1.5 rounded-2xl px-3.5 py-2.5 text-base font-extrabold"
                    style={{ background: 'rgba(255, 179, 102, 0.48)', color: warm.text }}
                  >
                    <MessageCircle className="w-5 h-5" />
                    消息
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* 底部关怀 */}
      <footer
        className="rounded-3xl p-5 border shadow-md flex gap-3"
        style={{
          background: 'rgba(244, 201, 93, 0.22)',
          borderColor: 'rgba(255, 179, 102, 0.42)',
        }}
      >
        <span className="text-2xl shrink-0">🌸</span>
        <div>
          <p className="text-lg font-bold leading-relaxed" style={{ color: warm.text }}>
            {warmTips[tipIdx]}
          </p>
          <p className="text-base font-semibold mt-2 leading-relaxed" style={{ color: '#8FA894' }}>
            您不用一次做完所有事，慢慢来，我们陪着您。
          </p>
        </div>
      </footer>
    </div>
  );
}
