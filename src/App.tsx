import React, { useState, useEffect, useMemo, Component, ErrorInfo, ReactNode } from 'react';
import { 
  LayoutDashboard, 
  Pill, 
  Calendar, 
  Users, 
  Settings, 
  Bell, 
  UserCircle,
  ChevronRight,
  Plus,
  ArrowLeft,
  CheckCircle2,
  Clock,
  AlertCircle,
  LogOut,
  ShieldAlert,
  Download,
  Edit2,
  Trash2,
  TrendingUp,
  Check
} from 'lucide-react';
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
} from 'recharts';
import { motion, AnimatePresence } from 'motion/react';
import { ApiError, getAccessToken, getRefreshToken, clearTokenPair } from './lib/api';
import { fetchMe, loginWithPasswordApi, logoutApi, registerApi, sendRegisterSms, type UserMe } from './lib/authApi';
import { cn, formatTime } from './lib/utils';
import { UserRole, UserProfile, Medication, MedicationPlan, ReminderEvent, ElderBinding } from './types';
import { MedicationForm } from './components/MedicationForm';
import { PlanForm } from './components/PlanForm';
import { AuthScreen } from './components/AuthScreen';
import { ElderHomeView } from './components/ElderHomeView';
import { getProfileFromRegistry, medicationService, syncProfileToRegistry } from './services/medicationService';

/** 已登录用户（对接 JWT 后端，uid 为后端用户数字 id 的字符串） */
export interface AuthUser {
  uid: string;
  phone: string;
}

// Error Boundary Component
interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("未捕获的错误:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      let errorMessage = "出错了。请尝试刷新页面。";
      try {
        const parsedError = JSON.parse(this.state.error?.message || "");
        if (parsedError.error) {
          errorMessage = `错误: ${parsedError.error} (操作: ${parsedError.operationType})`;
        }
      } catch (e) {
        // 不是 JSON 错误
      }

      return (
        <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-6 text-center">
          <div className="w-16 h-16 bg-red-100 rounded-2xl flex items-center justify-center mb-4">
            <ShieldAlert className="text-red-600 w-8 h-8" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900 mb-2">应用错误</h1>
          <p className="text-slate-600 mb-6 max-w-md">{errorMessage}</p>
          <button 
            onClick={() => window.location.reload()}
            className="px-6 py-3 bg-blue-600 text-white rounded-xl font-semibold shadow-lg shadow-blue-200"
          >
            重新加载应用
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

// Auth Hook：对接 production_stack FastAPI（JWT），不再使用 Firebase
const useAuth = () => {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [notification, setNotification] = useState<{ message: string; type: 'success' | 'error' } | null>(null);

  const applyMeToState = (me: UserMe) => {
    const uid = String(me.id);
    setUser({ uid, phone: me.phone });
    const saved = localStorage.getItem(`profile_${uid}`);
    if (saved) {
      try {
        const p = JSON.parse(saved) as UserProfile;
        setProfile(p);
        syncProfileToRegistry(p);
        return;
      } catch {
        /* fallthrough */
      }
    }
    const shortId = Math.floor(100000 + Math.random() * 900000).toString();
    const defaultMode: UserRole = me.role === 'elderly' ? 'elder' : 'caregiver';
    const p: UserProfile = {
      uid,
      displayName: `用户${me.phone.slice(-4)}`,
      defaultMode,
      fontScale: 1.2,
      voiceEnabled: true,
      highContrast: false,
      shortId,
      phone: me.phone,
    };
    localStorage.setItem(`profile_${uid}`, JSON.stringify(p));
    setProfile(p);
    syncProfileToRegistry(p);
  };

  useEffect(() => {
    if (notification) {
      const timer = setTimeout(() => setNotification(null), 3000);
      return () => clearTimeout(timer);
    }
  }, [notification]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!getAccessToken() && !getRefreshToken()) {
        if (!cancelled) setLoading(false);
        return;
      }
      try {
        const me = await fetchMe();
        if (cancelled) return;
        applyMeToState(me);
      } catch {
        clearTokenPair();
        if (!cancelled) {
          setUser(null);
          setProfile(null);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const loginWithPhone = async (phone: string, password: string) => {
    try {
      const me = await loginWithPasswordApi(phone, password);
      applyMeToState(me);
    } catch (e) {
      console.error('登录失败', e);
      const msg = e instanceof ApiError ? e.message : '登录失败，请重试';
      setNotification({ message: msg, type: 'error' });
      throw e;
    }
  };

  const registerWithPhone = async (
    phone: string,
    password: string,
    role: UserRole,
    smsCode: string,
  ) => {
    try {
      const apiRole = role === 'caregiver' ? 'personal' : 'elderly';
      const me = await registerApi(phone, smsCode, password, apiRole);
      const uid = String(me.id);
      setUser({ uid, phone: me.phone });
      const shortId = Math.floor(100000 + Math.random() * 900000).toString();
      const newProfile: UserProfile = {
        uid,
        displayName: `用户${phone.slice(-4)}`,
        defaultMode: role,
        fontScale: 1.2,
        voiceEnabled: true,
        highContrast: false,
        shortId,
        phone,
      };
      localStorage.setItem(`profile_${uid}`, JSON.stringify(newProfile));
      setProfile(newProfile);
      syncProfileToRegistry(newProfile);
    } catch (e) {
      console.error('注册失败', e);
      const msg = e instanceof ApiError ? e.message : '注册失败，请重试';
      setNotification({ message: msg, type: 'error' });
      throw e;
    }
  };

  const sendRegisterSmsCode = async (phone: string) => {
    const data = await sendRegisterSms(phone);
    return data.debug_code ?? null;
  };

  const logout = async () => {
    try {
      await logoutApi();
    } catch (error) {
      console.error('退出失败', error);
    }
    setUser(null);
    setProfile(null);
  };

  const updateProfile = async (updates: Partial<UserProfile>) => {
    if (!profile || !user) return;
    const updated = { ...profile, ...updates };
    setProfile(updated);
    localStorage.setItem(`profile_${user.uid}`, JSON.stringify(updated));
    syncProfileToRegistry(updated);
  };

  return {
    user,
    profile,
    loading,
    loginWithPhone,
    registerWithPhone,
    sendRegisterSmsCode,
    logout,
    updateProfile,
    notification,
    setNotification,
  };
};

function AppContent() {
  const {
    user,
    profile,
    loading,
    loginWithPhone,
    registerWithPhone,
    sendRegisterSmsCode,
    logout,
    updateProfile,
    notification,
    setNotification,
  } = useAuth();
  const [currentMode, setCurrentMode] = useState<UserRole>('caregiver');
  const [view, setView] = useState<'home' | 'medicines' | 'plans' | 'bindings' | 'reports' | 'settings'>('home');
  
  const [medications, setMedications] = useState<Medication[]>([]);
  const [plans, setPlans] = useState<MedicationPlan[]>([]);
  const [reminders, setReminders] = useState<ReminderEvent[]>([]);
  const [bindings, setBindings] = useState<ElderBinding[]>([]);
  const [boundUsers, setBoundUsers] = useState<Record<string, UserProfile>>({});
  /** 看护人模式下：药品/计划/今日日程对应的用户（本人 uid 或已绑定长辈的 elderUserId） */
  const [careTargetUserId, setCareTargetUserId] = useState('');
  const [showMedForm, setShowMedForm] = useState(false);
  const [showPlanForm, setShowPlanForm] = useState(false);
  const [isCreatingPlan, setIsCreatingPlan] = useState(false);
  const [isSavingMed, setIsSavingMed] = useState(false);
  const [editingMed, setEditingMed] = useState<Medication | null>(null);
  const [activeReminder, setActiveReminder] = useState<ReminderEvent | null>(null);
  const [dismissedReminderIds, setDismissedReminderIds] = useState<Set<string>>(new Set());
  const [snoozedReminders, setSnoozedReminders] = useState<Map<string, number>>(new Map());
  const [isConfirmingIntake, setIsConfirmingIntake] = useState(false);
  const [showInstallGuide, setShowInstallGuide] = useState(false);

  // 到点弹窗：subscribeToTodayReminders 每 3s 会 setReminders 产生新引用，若仅依赖 setInterval(5s)
  // 则 effect 每次都会 clear 定时器，5s 内又被重置，回调几乎永不执行 → 表现为「到点不提醒」。
  // 到点弹窗：仅提醒「属于当前登录账号本人」的日程。看护人为长辈代建的提醒 targetUserId 为长辈 uid，
  // 不应在看护端弹窗，只应在长辈本人登录（老人模式）时弹出。
  useEffect(() => {
    const checkDue = () => {
      const now = new Date();
      const due = reminders.find((r) => {
        if (!user || r.targetUserId !== user.uid) return false;
        const isPending = r.status === 'pending';
        const isNotDismissed = !dismissedReminderIds.has(r.id);
        const isDue = new Date(r.dueTime) <= now;
        const isNotTooOld =
          now.getTime() - new Date(r.dueTime).getTime() < 24 * 60 * 60 * 1000;
        const snoozeTime = snoozedReminders.get(r.id);
        const isSnoozeOver = !snoozeTime || now.getTime() > snoozeTime;
        return isPending && isNotDismissed && isDue && isNotTooOld && isSnoozeOver;
      });

      setActiveReminder((prev) => {
        if (!due) {
          if (prev && user && prev.targetUserId !== user.uid) return null;
          return prev;
        }
        if (prev?.id === due.id) return prev;
        return due;
      });
    };

    checkDue();
    const interval = window.setInterval(checkDue, 5000);
    const onVisible = () => {
      if (document.visibilityState === 'visible') checkDue();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      window.clearInterval(interval);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [reminders, dismissedReminderIds, snoozedReminders, user]);

  useEffect(() => {
    if (profile) {
      setCurrentMode(profile.defaultMode);
    }
  }, [profile]);

  useEffect(() => {
    if (!user) {
      setCareTargetUserId('');
      return;
    }
    setCareTargetUserId(user.uid);
  }, [user?.uid]);

  const dataUserId = !user ? '' : currentMode === 'elder' ? user.uid : careTargetUserId || user.uid;

  const careTargetOptions = useMemo(() => {
    if (!user) return [] as { id: string; label: string }[];
    const opts: { id: string; label: string }[] = [
      { id: user.uid, label: `本人（${profile?.displayName?.trim() || '我'}）` },
    ];
    for (const b of bindings) {
      const bu = boundUsers[b.elderUserId];
      opts.push({
        id: b.elderUserId,
        label: bu?.displayName
          ? `${bu.displayName}（家人）`
          : `家人 · 短号 ${bu?.shortId || '未知'}`,
      });
    }
    return opts;
  }, [user, profile?.displayName, bindings, boundUsers]);

  useEffect(() => {
    if (!user || !dataUserId) {
      if (!user) {
        setMedications([]);
        setPlans([]);
        setReminders([]);
      }
      return;
    }
    const load = async () => {
      const meds = await medicationService.getMedications(dataUserId);
      setMedications(meds);
      const pls = await medicationService.getPlans(dataUserId);
      setPlans(pls);
    };
    void load();
    const unsubscribe = medicationService.subscribeToTodayReminders(dataUserId, (events) => {
      setReminders(events);
    });
    return () => unsubscribe();
  }, [user, dataUserId]);

  const loadMedications = async () => {
    if (!user || !dataUserId) return;
    const meds = await medicationService.getMedications(dataUserId);
    setMedications(meds);
  };

  const loadPlans = async () => {
    if (!user || !dataUserId) return;
    const data = await medicationService.getPlans(dataUserId);
    setPlans(data);
  };

  const loadBindings = async () => {
    if (!user) return;
    const data = await medicationService.getBindings(user.uid) as ElderBinding[];
    setBindings(data);
    
    const newBoundUsers: Record<string, UserProfile> = {};
    for (const binding of data) {
      const p = getProfileFromRegistry(binding.elderUserId);
      if (p) newBoundUsers[binding.elderUserId] = p;
    }
    setBoundUsers(newBoundUsers);
  };

  useEffect(() => {
    if (user && currentMode === 'caregiver') {
      loadBindings();
    }
  }, [user, currentMode]);

  const handleBindElder = async (shortId: string, phoneLast4: string) => {
    if (!user) return;
    try {
      await medicationService.bindElder(user.uid, shortId, phoneLast4);
      setNotification({ message: '绑定成功！', type: 'success' });
      loadBindings();
    } catch (error: any) {
      setNotification({ message: error.message || '绑定失败，请检查信息是否正确', type: 'error' });
    }
  };

  const handleAddMed = async (data: any) => {
    if (!user) return;
    setIsSavingMed(true);
    try {
      if (editingMed) {
        await medicationService.updateMedication(editingMed.id, data);
        setNotification({ message: '药品修改成功！', type: 'success' });
      } else {
        const targetUid = careTargetUserId || user.uid;
        await medicationService.addMedication({
          ...data,
          targetUserId: targetUid,
          createdByUserId: user.uid,
          archived: false
        });
        setNotification({ message: '药品添加成功！', type: 'success' });
      }
      setShowMedForm(false);
      setEditingMed(null);
      loadMedications();
    } catch (error) {
      console.error("保存药品失败", error);
      setNotification({ message: '保存失败，请重试', type: 'error' });
    } finally {
      setIsSavingMed(false);
    }
  };

  const handleDeleteMed = async (id: string) => {
    // window.confirm might be blocked in iframe, removing for better reliability
    try {
      await medicationService.deleteMedication(id);
      setNotification({ message: '药品已删除', type: 'success' });
      loadMedications();
    } catch (error) {
      console.error("删除药品失败", error);
      setNotification({ message: '删除失败', type: 'error' });
    }
  };

  const handleDeleteReminder = async (id: string) => {
    try {
      await medicationService.deleteReminder(id);
      setNotification({ message: '日程已删除', type: 'success' });
    } catch (error) {
      console.error("删除日程失败", error);
      setNotification({ message: '删除失败', type: 'error' });
    }
  };

  const handleCreatePlan = async (data: any) => {
    if (!user) return;
    setIsCreatingPlan(true);
    try {
      const targetUid = (data.targetUserId as string) || careTargetUserId || user.uid;
      await medicationService.addMedicationPlan({
        ...data,
        targetUserId: targetUid,
        createdByUserId: user.uid,
        status: 'active'
      });
      setNotification({ message: '计划创建成功！', type: 'success' });
      setShowPlanForm(false);
      loadPlans();
    } catch (error) {
      console.error("创建计划失败", error);
      setNotification({ message: '创建失败，请重试', type: 'error' });
    } finally {
      setIsCreatingPlan(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-[#FFE8DC] via-[#FFF0E6] to-[#FFFBF5] flex flex-col items-center justify-center p-4">
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          className="flex flex-col items-center"
        >
          <div className="w-16 h-16 bg-[#E8863D] rounded-[22px] flex items-center justify-center mb-4 shadow-lg shadow-orange-900/15">
            <Pill className="text-white w-8 h-8" />
          </div>
          <h1 className="text-2xl font-black text-[#5C4A3D]">药安心</h1>
          <p className="text-[#8B7A6E] font-medium mt-2">正在为您准备好页面…</p>
        </motion.div>
      </div>
    );
  }

  if (!user) {
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches || (window.navigator as any).standalone;

    return (
      <>
        <AuthScreen
          loginWithPhone={loginWithPhone}
          registerWithPhone={registerWithPhone}
          sendRegisterSms={sendRegisterSmsCode}
          isStandalone={isStandalone}
          setShowInstallGuide={setShowInstallGuide}
        />
        <AnimatePresence>
          {notification && (
            <motion.div
              initial={{ y: -100, opacity: 0 }}
              animate={{ y: 20, opacity: 1 }}
              exit={{ y: -100, opacity: 0 }}
              className="fixed top-0 left-0 right-0 z-[100] flex justify-center pointer-events-none"
            >
              <div
                className={cn(
                  'px-6 py-3 rounded-2xl shadow-lg font-bold flex items-center space-x-2 pointer-events-auto',
                  notification.type === 'success' ? 'bg-green-600 text-white' : 'bg-red-600 text-white'
                )}
              >
                {notification.type === 'success' ? <CheckCircle2 className="w-5 h-5" /> : <AlertCircle className="w-5 h-5" />}
                <span>{notification.message}</span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </>
    );
  }

  return (
    <div
      className={cn(
        'min-h-screen flex flex-col transition-all duration-300',
        currentMode === 'elder' || currentMode === 'caregiver'
          ? 'bg-gradient-to-b from-[#FFE8DC] via-[#FFF0E6] to-[#FFFBF5]'
          : 'bg-slate-50',
      )}
    >
      {/* Due Reminder Overlay/Modal */}
      <AnimatePresence>
        {activeReminder && (
          <div className="fixed inset-0 z-[200] flex items-center justify-center p-6 bg-black/60 backdrop-blur-sm">
            <motion.div 
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              className={cn(
                'w-full max-w-sm p-8 rounded-[40px] shadow-2xl text-center space-y-6 border-2',
                currentMode === 'elder'
                  ? 'bg-[#E8863D] text-white border-white/20'
                  : 'bg-gradient-to-br from-[#FFF8F0] to-[#FFE4CC] text-[#5C4A3D] border-[#FFB366]/40',
              )}
            >
              <div
                className={cn(
                  'w-20 h-20 rounded-full flex items-center justify-center mx-auto animate-bounce',
                  currentMode === 'elder' ? 'bg-white/20' : 'bg-[#E8863D]/15',
                )}
              >
                <Bell className={cn('w-10 h-10', currentMode === 'elder' ? 'text-white' : 'text-[#E8863D]')} />
              </div>
              
              <div className="space-y-2">
                <h2 className="text-3xl font-black">该吃药了！</h2>
                <p
                  className={cn(
                    'text-lg font-medium',
                    currentMode === 'elder' ? 'text-white/90' : 'text-[#8B7A6E]',
                  )}
                >
                  设定时间: {new Date(activeReminder.dueTime).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false })}
                </p>
              </div>

              <div className="flex flex-col gap-3">
                <button 
                  disabled={isConfirmingIntake}
                  onClick={async () => {
                    if (!activeReminder || !user) return;
                    setIsConfirmingIntake(true);
                    try {
                      await medicationService.confirmIntake(activeReminder.id, user.uid);
                      setActiveReminder(null);
                      setNotification({ message: '已确认服药', type: 'success' });
                    } catch (error) {
                      console.error("确认服药失败", error);
                      setNotification({ message: '操作失败，请重试', type: 'error' });
                    } finally {
                      setIsConfirmingIntake(false);
                    }
                  }}
                  className={cn(
                    'w-full py-5 rounded-3xl text-xl font-bold shadow-lg active:scale-95 transition-all flex items-center justify-center space-x-2',
                    isConfirmingIntake
                      ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                      : currentMode === 'elder'
                        ? 'bg-white text-[#E8863D] shadow-orange-900/20'
                        : 'bg-[#7CB87C] text-white shadow-[#7CB87C]/30',
                  )}
                >
                  {isConfirmingIntake ? (
                    <>
                      <div className="w-6 h-6 border-3 border-slate-300 border-t-slate-500 rounded-full animate-spin" />
                      <span>处理中...</span>
                    </>
                  ) : (
                    <span>我已经吃了</span>
                  )}
                </button>
                <button 
                  disabled={isConfirmingIntake}
                  onClick={() => {
                    if (activeReminder) {
                      // Snooze for 10 minutes
                      const nextTime = Date.now() + 10 * 60 * 1000;
                      setSnoozedReminders(prev => new Map(prev).set(activeReminder.id, nextTime));
                    }
                    setActiveReminder(null);
                  }}
                  className={cn(
                    'w-full py-4 rounded-3xl text-lg font-bold active:scale-95 transition-all',
                    currentMode === 'elder'
                      ? 'bg-white/20 text-white'
                      : 'bg-[#B8D4E8]/80 text-[#5C4A3D]',
                    isConfirmingIntake && 'opacity-50 cursor-not-allowed',
                  )}
                >
                  10分钟后再说
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Header（长辈模式由 ElderHomeView 自带顶栏，避免重复） */}
      {currentMode !== 'elder' && (
        <header className="px-5 py-3.5 flex items-center justify-between sticky top-0 z-10 backdrop-blur-md bg-[#FFFBF5]/90 border-b border-[#FFE4CC]/80 shadow-sm shadow-amber-900/5">
          <div className="flex items-center gap-2.5">
            <div className="w-11 h-11 rounded-2xl flex items-center justify-center shadow-md bg-[#E8863D] shadow-orange-900/15">
              <Pill className="text-white w-6 h-6" />
            </div>
            <div>
              <span className="text-xl font-black tracking-tight text-[#5C4A3D]">药安心</span>
              <p className="text-[13px] font-semibold text-[#8B7A6E] leading-tight">看护端 · 陪家人好好吃药</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              className="p-2.5 rounded-full hover:bg-[#FFE4CC]/60 transition-colors relative text-[#5C4A3D]"
            >
              <Bell className="w-6 h-6" />
              {reminders.some((r) => r.status === 'pending' && r.targetUserId === user?.uid) && (
                <span className="absolute top-1.5 right-1.5 w-2.5 h-2.5 bg-red-500 rounded-full border-2 border-[#FFFBF5]" />
              )}
            </button>
            <button
              type="button"
              onClick={() => setView('settings')}
              className="w-11 h-11 rounded-full bg-white border-2 border-[#FFE4CC] flex items-center justify-center shadow-sm hover:border-[#E8863D]/50 transition-all"
            >
              <UserCircle className="w-7 h-7 text-[#8B7A6E]" />
            </button>
          </div>
        </header>
      )}

      {/* Notification Toast */}
      <AnimatePresence>
        {notification && (
          <motion.div 
            initial={{ y: -100, opacity: 0 }}
            animate={{ y: 20, opacity: 1 }}
            exit={{ y: -100, opacity: 0 }}
            className="fixed top-0 left-0 right-0 z-[100] flex justify-center pointer-events-none"
          >
            <div
              className={cn(
                'px-6 py-3 rounded-2xl shadow-lg font-bold flex items-center space-x-2 pointer-events-auto border border-white/20',
                notification.type === 'success'
                  ? 'bg-[#7CB87C] text-white shadow-[#7CB87C]/25'
                  : 'bg-red-600 text-white',
              )}
            >
              {notification.type === 'success' ? <CheckCircle2 className="w-5 h-5" /> : <AlertCircle className="w-5 h-5" />}
              <span>{notification.message}</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <main
        className={cn(
          'flex-1 overflow-y-auto max-w-lg mx-auto w-full',
          currentMode === 'elder' ? 'px-4 py-3 pb-8' : 'px-4 py-4 pb-28',
        )}
      >
        <AnimatePresence mode="wait">
          {currentMode === 'caregiver' ? (
            <CaregiverView 
              view={view} 
              setView={setView} 
              medications={medications} 
              plans={plans}
              reminders={reminders}
              onAddMed={() => setShowMedForm(true)}
              onEditMed={(med: Medication) => {
                setEditingMed(med);
                setShowMedForm(true);
              }}
              onDeleteMed={handleDeleteMed}
              onAddPlan={() => setShowPlanForm(true)}
              onConfirmIntake={(id: string) => medicationService.confirmIntake(id, user.uid)}
              onDeleteReminder={handleDeleteReminder}
              onBindElder={handleBindElder}
              bindings={bindings}
              boundUsers={boundUsers}
              user={user}
              profile={profile}
              careTargetUserId={careTargetUserId || user.uid}
              onCareTargetUserIdChange={setCareTargetUserId}
              careTargetOptions={careTargetOptions}
              onManageElderMedication={(elderUserId: string) => {
                setCareTargetUserId(elderUserId);
                setView('medicines');
              }}
            />
          ) : (
            <ElderHomeView
              user={user}
              profile={profile}
              reminders={reminders.filter((r) => r.targetUserId === user.uid)}
              plans={plans}
              snoozedReminders={snoozedReminders}
              setSnoozedReminders={setSnoozedReminders}
              onConfirmIntake={(id) => medicationService.confirmIntake(id, user.uid)}
              setNotification={setNotification}
              setView={setView}
              onLogout={logout}
            />
          )}
        </AnimatePresence>
      </main>

      {/* Modals */}
      <AnimatePresence>
        {showMedForm && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }} className="w-full max-w-md">
              <MedicationForm 
                onSave={handleAddMed} 
                onCancel={() => {
                  setShowMedForm(false);
                  setEditingMed(null);
                }} 
                loading={isSavingMed}
                initialData={editingMed}
                careTargetUserId={careTargetUserId || user.uid}
                onCareTargetUserIdChange={setCareTargetUserId}
                careTargetOptions={careTargetOptions}
                showTargetPicker={!editingMed}
              />
            </motion.div>
          </div>
        )}
        {showPlanForm && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.9, opacity: 0 }} className="w-full max-w-md">
              <PlanForm 
                medications={medications} 
                onSave={handleCreatePlan} 
                onCancel={() => setShowPlanForm(false)} 
                loading={isCreatingPlan}
                careTargetUserId={careTargetUserId || user.uid}
                onCareTargetUserIdChange={setCareTargetUserId}
                careTargetOptions={careTargetOptions}
              />
            </motion.div>
          </div>
        )}
        {showInstallGuide && (
          <div className="fixed inset-0 bg-black/50 z-[100] flex items-center justify-center p-4">
            <motion.div 
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="bg-white w-full max-w-md rounded-[40px] p-8 space-y-6 overflow-hidden relative"
            >
              <button 
                onClick={() => setShowInstallGuide(false)}
                className="absolute right-6 top-6 p-2 hover:bg-slate-100 rounded-full"
              >
                <Plus className="w-6 h-6 rotate-45 text-slate-400" />
              </button>

              <div className="text-center space-y-2">
                <div className="w-16 h-16 bg-blue-600 rounded-3xl flex items-center justify-center mx-auto shadow-lg shadow-blue-200 mb-4">
                  <Download className="text-white w-8 h-8" />
                </div>
                <h2 className="text-2xl font-black text-slate-900">安装到手机</h2>
                <p className="text-slate-500">将应用添加到桌面，像原生 App 一样使用</p>
              </div>

              <div className="space-y-6">
                <div className="space-y-3">
                  <div className="flex items-center space-x-2 font-bold text-slate-800">
                    <div className="w-6 h-6 bg-slate-900 text-white rounded-full flex items-center justify-center text-xs">1</div>
                    <span>苹果手机 (iPhone)</span>
                  </div>
                  <ul className="text-sm text-slate-600 space-y-2 pl-8 list-disc">
                    <li>在 Safari 浏览器中打开本页面</li>
                    <li>点击底部的“分享”图标 (方块带箭头)</li>
                    <li>选择“添加到主屏幕”</li>
                  </ul>
                </div>

                <div className="space-y-3">
                  <div className="flex items-center space-x-2 font-bold text-slate-800">
                    <div className="w-6 h-6 bg-slate-900 text-white rounded-full flex items-center justify-center text-xs">2</div>
                    <span>安卓手机 (Android)</span>
                  </div>
                  <ul className="text-sm text-slate-600 space-y-2 pl-8 list-disc">
                    <li>在 Chrome 浏览器中打开本页面</li>
                    <li>点击右上角的“三个点”菜单</li>
                    <li>选择“安装应用”或“添加到主屏幕”</li>
                  </ul>
                </div>
              </div>

              <button 
                onClick={() => setShowInstallGuide(false)}
                className="w-full bg-slate-900 text-white py-4 rounded-2xl font-bold active:scale-95 transition-transform"
              >
                我知道了
              </button>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Bottom Navigation (Caregiver only) */}
      {currentMode === 'caregiver' && (
        <nav className="fixed bottom-0 left-0 right-0 z-20 flex justify-center pointer-events-none">
          <div className="pointer-events-auto w-full max-w-lg mx-4 mb-3 rounded-[28px] bg-[#FFFBF5]/95 border border-[#FFE4CC] shadow-lg shadow-amber-900/10 px-4 py-3 flex items-center justify-between backdrop-blur-md">
            <NavButton active={view === 'home'} icon={LayoutDashboard} label="首页" onClick={() => setView('home')} />
            <NavButton active={view === 'medicines'} icon={Pill} label="药品" onClick={() => setView('medicines')} />
            <NavButton active={view === 'plans'} icon={Calendar} label="计划" onClick={() => setView('plans')} />
            <NavButton active={view === 'bindings'} icon={Users} label="家人" onClick={() => setView('bindings')} />
          </div>
        </nav>
      )}

      {/* Settings Panel */}
      {view === 'settings' && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4">
          <motion.div 
            initial={{ y: 100 }}
            animate={{ y: 0 }}
            className="bg-gradient-to-b from-[#FFFBF5] to-[#FFF8F0] w-full max-w-md rounded-[28px] p-6 space-y-6 border border-[#FFE4CC] shadow-xl shadow-amber-900/10"
          >
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-black text-[#5C4A3D]">设置</h2>
              <button onClick={() => setView('home')} className="p-2 hover:bg-[#FFE4CC]/50 rounded-full">
                <Plus className="w-6 h-6 rotate-45 text-[#8B7A6E]" />
              </button>
            </div>
            
            <div className="space-y-4">
              <div className="p-4 bg-white/90 rounded-[22px] border border-[#FFE4CC] shadow-sm flex items-center justify-between">
                <div>
                  <h3 className="font-bold text-[#5C4A3D]">应用模式</h3>
                  <p className="text-sm text-[#8B7A6E]">在看护人和长辈视图之间切换</p>
                </div>
                <div className="flex bg-[#FFF8F0] p-1 rounded-xl border border-[#FFE4CC]">
                  <button 
                    onClick={() => {
                      setCurrentMode('caregiver');
                      updateProfile({ defaultMode: 'caregiver' });
                    }}
                    className={cn(
                      'px-3 py-1.5 rounded-lg text-sm font-bold transition-all',
                      currentMode === 'caregiver'
                        ? 'bg-white shadow text-[#E8863D]'
                        : 'text-[#8B7A6E]',
                    )}
                  >
                    看护人
                  </button>
                  <button 
                    onClick={() => {
                      setCurrentMode('elder');
                      updateProfile({ defaultMode: 'elder' });
                    }}
                    className={cn(
                      'px-3 py-1.5 rounded-lg text-sm font-bold transition-all',
                      currentMode === 'elder' ? 'bg-white shadow text-[#E8863D]' : 'text-[#8B7A6E]',
                    )}
                  >
                    长辈
                  </button>
                </div>
              </div>

              <div className="p-4 bg-white/90 rounded-[22px] border border-[#FFE4CC] shadow-sm space-y-4">
                <h3 className="font-bold text-[#5C4A3D]">个人信息</h3>
                <div className="space-y-2">
                  <label className="text-sm font-semibold text-[#8B7A6E]">我的 6 位 ID</label>
                  <div className="w-full px-4 py-3 rounded-xl bg-[#FFF8F0] text-[#5C4A3D] font-mono tracking-widest font-black border border-[#FFE4CC]">
                    {profile?.shortId || '---'}
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-semibold text-[#8B7A6E]">手机号 (用于家人绑定验证)</label>
                  <input 
                    type="tel" 
                    value={profile?.phone || ''}
                    onChange={(e) => updateProfile({ phone: e.target.value })}
                    placeholder="请输入手机号"
                    className="w-full px-4 py-3 rounded-xl bg-white border border-[#FFE4CC] outline-none focus:ring-2 focus:ring-[#E8863D]/40"
                  />
                </div>
              </div>

              <div className="p-4 bg-white/90 rounded-[22px] border border-[#FFE4CC] shadow-sm space-y-4">
                <h3 className="font-bold text-[#5C4A3D]">辅助功能</h3>
                <div className="flex items-center justify-between">
                  <span className="text-sm">字体大小</span>
                  <input type="range" min="1" max="1.8" step="0.1" className="w-32" />
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-[#5C4A3D]">语音提醒</span>
                  <div className="w-12 h-6 bg-[#7CB87C] rounded-full relative">
                    <div className="absolute right-1 top-1 w-4 h-4 bg-white rounded-full shadow-sm" />
                  </div>
                </div>
                <button 
                  onClick={() => setShowInstallGuide(true)}
                  className="w-full py-2.5 bg-[#FFF8F0] text-[#5C4A3D] rounded-xl text-sm font-bold hover:bg-[#FFE4CC]/80 transition-colors flex items-center justify-center gap-2 border border-[#FFE4CC]"
                >
                  <Download className="w-4 h-4" />
                  <span>下载/安装到手机桌面</span>
                </button>
                <button 
                  onClick={async () => {
                    await medicationService.addTestReminder(user.uid);
                    setNotification({ message: '测试提醒已发出，5秒后弹出', type: 'success' });
                    setView('home');
                  }}
                  className="w-full py-2.5 bg-[#E8863D]/12 text-[#C96D2E] rounded-xl text-sm font-bold hover:bg-[#E8863D]/20 transition-colors border border-[#FFB366]/50"
                >
                  发送测试提醒 (5秒后)
                </button>
              </div>

              <button 
                onClick={logout}
                className="w-full py-4 text-red-700 font-bold border border-red-100 rounded-[22px] hover:bg-red-50 transition-colors flex items-center justify-center gap-2 bg-white/80"
              >
                <LogOut className="w-5 h-5" />
                <span>退出登录</span>
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </div>
  );
}

export default function App() {
  return (
    <ErrorBoundary>
      <AppContent />
    </ErrorBoundary>
  );
}

function NavButton({ active, icon: Icon, label, onClick }: { active: boolean, icon: any, label: string, onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex flex-col items-center gap-1 transition-all min-w-[52px] active:scale-95',
        active ? 'text-[#E8863D]' : 'text-[#8B7A6E]',
      )}
    >
      <span className={cn('p-2 rounded-2xl transition-colors', active ? 'bg-[#FFE4CC]/90 shadow-sm' : 'bg-transparent')}>
        <Icon className="w-6 h-6" strokeWidth={active ? 2.25 : 2} />
      </span>
      <span className="text-[11px] font-bold">{label}</span>
    </button>
  );
}

function CaregiverView({ 
  view, 
  setView, 
  medications, 
  plans,
  reminders, 
  onAddMed, 
  onEditMed,
  onDeleteMed,
  onAddPlan, 
  onConfirmIntake,
  onDeleteReminder,
  onBindElder,
  bindings = [],
  boundUsers = {},
  user,
  careTargetUserId,
  onCareTargetUserIdChange,
  careTargetOptions = [],
  onManageElderMedication,
  profile,
}: any) {
  const [bindShortId, setBindShortId] = useState('');
  const [bindPhoneLast4, setBindPhoneLast4] = useState('');
  const [isBinding, setIsBinding] = useState(false);

  // Prepare chart data
  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (6 - i));
    return d.toISOString().split('T')[0];
  });

  const chartData = last7Days.map(date => {
    // In a real app, we'd fetch historical data. For now, we'll mock some based on current reminders if they match the date
    // or just show a nice trend.
    const dayReminders = reminders.filter((r: any) => r.dueTime.startsWith(date));
    const takenCount = dayReminders.filter((r: any) => r.status === 'taken').length;
    const totalCount = dayReminders.length;
    const rate = totalCount > 0 ? Math.round((takenCount / totalCount) * 100) : Math.floor(Math.random() * 40) + 60;
    
    return {
      name: date.split('-').slice(1).join('/'),
      rate: rate
    };
  });

  const careTargetLabel =
    careTargetOptions.find((o: any) => o.id === careTargetUserId)?.label || '本人';

  const showCareTargetBar = view === 'home' || view === 'medicines' || view === 'plans';

  return (
    <motion.div 
      key="caregiver"
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      className="space-y-5 w-full"
    >
      {showCareTargetBar && (
        <div className="bg-white/95 p-5 rounded-[26px] border border-[#FFE4CC] shadow-lg shadow-amber-900/8 space-y-3">
          <label className="block text-sm font-extrabold text-[#5C4A3D]">当前关心的人</label>
          <p className="text-sm text-[#8B7A6E] leading-relaxed">
            切换后，首页日程、药品与计划都会跟着变；可以管自己，也可以帮已绑定的长辈远程打理。
          </p>
          <select
            value={careTargetUserId}
            onChange={(e) => onCareTargetUserIdChange(e.target.value)}
            className="w-full px-4 py-3.5 rounded-[18px] border border-[#FFE4CC] bg-[#FFF8F0] font-bold text-[#5C4A3D] outline-none focus:ring-2 focus:ring-[#E8863D]/35"
          >
            {careTargetOptions.map((o: any) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </select>
          <p className="text-sm font-semibold text-[#8FA894]">现在在看：<span className="text-[#E8863D]">{careTargetLabel}</span></p>
        </div>
      )}

      {view === 'home' && (
        <>
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-2xl font-black text-[#5C4A3D]">
                您好，{(profile?.displayName || '家人').split(/\s+/)[0]}
              </h2>
              <p className="text-[#8B7A6E] text-base font-medium mt-1">今天也一起把用药安排得明明白白 💛</p>
            </div>
            <div className="w-12 h-12 rounded-full bg-[#FFE4CC] border-2 border-white shadow-md flex items-center justify-center text-sm font-black text-[#E8863D]">
              {(profile?.displayName || '我').slice(0, 2)}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="bg-white/95 p-4 rounded-[26px] shadow-md border border-[#FFE4CC]/80">
              <div className="w-11 h-11 bg-[#7CB87C]/20 rounded-2xl flex items-center justify-center mb-3">
                <CheckCircle2 className="text-[#5a9a5a] w-6 h-6" />
              </div>
              <div className="text-3xl font-black text-[#5C4A3D]">
                {reminders.length > 0
                  ? Math.round((reminders.filter((r) => r.status === 'taken').length / reminders.length) * 100)
                  : 0}
                %
              </div>
              <div className="text-sm text-[#8B7A6E] font-bold mt-1">今日完成度</div>
            </div>
            <div className="bg-white/95 p-4 rounded-[26px] shadow-md border border-[#FFE4CC]/80">
              <div className="w-11 h-11 bg-[#F4C95D]/35 rounded-2xl flex items-center justify-center mb-3">
                <AlertCircle className="text-[#C96D2E] w-6 h-6" />
              </div>
              <div className="text-3xl font-black text-[#5C4A3D]">
                {reminders.filter((r: any) => r.status === 'pending').length}
              </div>
              <div className="text-sm text-[#8B7A6E] font-bold mt-1">还有待确认</div>
            </div>
          </div>

          <section className="space-y-3">
            <div className="flex items-center justify-between px-1">
              <h3 className="font-extrabold text-lg text-[#5C4A3D]">今日日程</h3>
              <span className="text-sm font-semibold text-[#8FA894]">按时间排好了</span>
            </div>
            <div className="space-y-3">
              {reminders.length > 0 ? (
                reminders.map((rem: any) => (
                  <div
                    key={rem.id}
                    className="bg-white/95 p-4 rounded-[24px] shadow-md border border-[#FFE4CC]/70 flex items-center justify-between gap-2"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div
                        className={cn(
                          'w-12 h-12 rounded-2xl flex items-center justify-center shrink-0',
                          rem.status === 'taken' ? 'bg-[#7CB87C]/20' : 'bg-[#FFF8F0]',
                        )}
                      >
                        <Pill
                          className={cn('w-6 h-6', rem.status === 'taken' ? 'text-[#5a9a5a]' : 'text-[#E8863D]')}
                        />
                      </div>
                      <div className="min-w-0">
                        <h4 className="font-bold text-[#5C4A3D] truncate">
                          {rem.medicineName && rem.medicineName !== '药品'
                            ? rem.medicineName
                            : medications.find(
                                (m: any) =>
                                  m.id === plans.find((p: any) => p.id === rem.planId)?.medicineId,
                              )?.name || '药品'}
                        </h4>
                        <div className="flex items-center text-sm text-[#8B7A6E] font-semibold mt-0.5">
                          <Clock className="w-3.5 h-3.5 mr-1 shrink-0" />
                          {new Date(rem.dueTime).toLocaleTimeString([], {
                            hour: '2-digit',
                            minute: '2-digit',
                            hour12: false,
                          })}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-1.5 shrink-0">
                      {rem.status === 'pending' && (
                        <button
                          type="button"
                          onClick={() => onConfirmIntake(rem.id)}
                          className="p-2.5 bg-[#7CB87C]/20 text-[#3d7a3d] rounded-xl hover:bg-[#7CB87C]/30 transition-colors"
                          title="确认已吃"
                        >
                          <Check className="w-5 h-5" />
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => onDeleteReminder(rem.id)}
                        className="p-2.5 bg-red-50 text-red-600 rounded-xl hover:bg-red-100 transition-colors"
                        title="删除日程"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                      <div
                        className={cn(
                          'px-2.5 py-1 rounded-full text-xs font-bold ml-1',
                          rem.status === 'taken' ? 'bg-[#7CB87C] text-white' : 'bg-[#FFE4CC] text-[#8B4513]',
                        )}
                      >
                        {rem.status === 'taken' ? '已服' : '待服'}
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="bg-white/90 p-8 rounded-[26px] border border-dashed border-[#FFB366]/50 text-center">
                  <p className="text-[#8B7A6E] font-medium">今天还没有提醒，加个计划或药品吧～</p>
                </div>
              )}
            </div>
          </section>

          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={onAddMed}
              className="bg-gradient-to-br from-[#E8863D] to-[#d97830] p-5 rounded-[26px] shadow-lg shadow-orange-900/15 text-white flex flex-col items-start gap-2 active:scale-[0.98] transition-transform"
            >
              <Plus className="w-7 h-7" />
              <span className="font-extrabold text-lg">添加药品</span>
            </button>
            <button
              type="button"
              onClick={onAddPlan}
              className="bg-white/95 p-5 rounded-[26px] shadow-md border border-[#FFE4CC] text-[#5C4A3D] flex flex-col items-start gap-2 active:scale-[0.98] transition-transform"
            >
              <Calendar className="w-7 h-7 text-[#E8863D]" />
              <span className="font-extrabold text-lg">新建计划</span>
            </button>
          </div>
        </>
      )}

      {view === 'medicines' && (
        <div className="space-y-5">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-2xl font-black text-[#5C4A3D] leading-tight">
              {careTargetUserId === user.uid ? '我的药品' : `${careTargetLabel.split('（')[0] || '家人'}的药品`}
            </h2>
            <button
              type="button"
              onClick={onAddMed}
              className="w-12 h-12 bg-[#E8863D] rounded-full flex items-center justify-center text-white shadow-lg shadow-orange-900/20 active:scale-95 transition-transform"
            >
              <Plus className="w-6 h-6" />
            </button>
          </div>
          <div className="relative">
            <input
              type="text"
              placeholder="搜索药品…"
              className="w-full pl-11 pr-4 py-3.5 rounded-[22px] bg-white/95 border border-[#FFE4CC] shadow-sm outline-none focus:ring-2 focus:ring-[#E8863D]/30 text-[#5C4A3D] placeholder:text-[#8B7A6E]/70"
            />
            <Plus className="absolute left-3.5 top-3.5 w-5 h-5 text-[#E8863D]/60 rotate-45" />
          </div>
          <div className="space-y-3">
            {medications.length > 0 ? (
              medications.map((med: any) => (
                <div
                  key={med.id}
                  className="bg-white/95 p-5 rounded-[26px] shadow-md border border-[#FFE4CC]/80 flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-4 min-w-0">
                    <div className="w-14 h-14 bg-[#FFF8F0] rounded-2xl flex items-center justify-center border border-[#FFE4CC] shrink-0">
                      <Pill className="text-[#E8863D] w-7 h-7" />
                    </div>
                    <div className="min-w-0">
                      <h4 className="font-bold text-lg text-[#5C4A3D] truncate">{med.name}</h4>
                      <p className="text-sm text-[#8B7A6E] font-medium">{med.specification || med.dosageForm}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-1 shrink-0">
                    <button
                      type="button"
                      onClick={() => onEditMed(med)}
                      className="p-2.5 text-[#8B7A6E] hover:text-[#E8863D] hover:bg-[#FFE4CC]/50 rounded-xl transition-all"
                    >
                      <Edit2 className="w-5 h-5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => onDeleteMed(med.id)}
                      className="p-2.5 text-[#8B7A6E] hover:text-red-600 hover:bg-red-50 rounded-xl transition-all"
                    >
                      <Trash2 className="w-5 h-5" />
                    </button>
                  </div>
                </div>
              ))
            ) : (
              <div className="text-center py-12 rounded-[26px] border border-dashed border-[#FFB366]/45 bg-white/60">
                <p className="text-[#8B7A6E] font-medium">还没有药品，点右上角加一颗吧</p>
              </div>
            )}
          </div>
        </div>
      )}

      {view === 'plans' && (
        <div className="space-y-5 pb-10">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-2xl font-black text-[#5C4A3D]">健康与计划</h2>
            <button
              type="button"
              onClick={onAddPlan}
              className="bg-[#E8863D] px-4 py-2.5 rounded-[18px] text-white text-sm font-extrabold shadow-md shadow-orange-900/15 flex items-center gap-2 active:scale-95 transition-transform"
            >
              <Plus className="w-4 h-4" />
              <span>新计划</span>
            </button>
          </div>

          <div className="bg-gradient-to-br from-[#FFF8F0] via-[#FFE4CC]/60 to-[#FFD6CC]/40 p-6 rounded-[32px] text-[#5C4A3D] border border-[#FFB366]/35 relative overflow-hidden shadow-md">
            <div className="relative z-10 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-black text-[#C96D2E]">陪伴小成就</h3>
                <div className="bg-white/80 text-[#E8863D] px-3 py-1 rounded-full text-xs font-bold border border-[#FFE4CC]">
                  加油中
                </div>
              </div>
              <div className="flex items-end gap-2">
                <span className="text-5xl font-black text-[#5C4A3D]">1,280</span>
                <span className="text-sm font-bold text-[#8B7A6E] mb-1">分</span>
              </div>
              <p className="text-sm text-[#8B7A6E] leading-relaxed font-medium">
                每一次按时确认，都是对家人温柔的支持～
              </p>
              <div className="h-2.5 bg-white/70 rounded-full overflow-hidden border border-[#FFE4CC]/50">
                <div className="h-full bg-gradient-to-r from-[#E8863D] to-[#F4C95D] w-3/4 rounded-full" />
              </div>
            </div>
            <div className="absolute -right-10 -bottom-10 w-40 h-40 bg-[#FFB366]/15 rounded-full blur-3xl" />
          </div>

          <div className="bg-white/95 p-6 rounded-[32px] shadow-lg border border-[#FFE4CC]/80 space-y-5">
            <div className="flex items-center justify-between gap-2">
              <div>
                <h3 className="font-extrabold text-[#5C4A3D] text-lg">服药依从性</h3>
                <p className="text-sm text-[#8B7A6E] font-medium mt-0.5">过去 7 天完成率（示意曲线）</p>
              </div>
              <div className="bg-[#7CB87C]/15 text-[#3d6b3d] px-3 py-1.5 rounded-full text-xs font-bold flex items-center gap-1 border border-[#7CB87C]/25">
                <TrendingUp className="w-3.5 h-3.5" />
                稳步
              </div>
            </div>

            <div className="h-48 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="colorRateCare" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#E8863D" stopOpacity={0.35} />
                      <stop offset="95%" stopColor="#E8863D" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#FFE4CC" />
                  <XAxis
                    dataKey="name"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 11, fill: '#8B7A6E', fontWeight: 600 }}
                    dy={10}
                  />
                  <YAxis hide domain={[0, 100]} />
                  <Tooltip
                    contentStyle={{
                      borderRadius: '16px',
                      border: '1px solid #FFE4CC',
                      boxShadow: '0 10px 24px rgba(139, 69, 19, 0.08)',
                    }}
                    itemStyle={{ color: '#C96D2E', fontWeight: 'bold' }}
                  />
                  <Area
                    type="monotone"
                    dataKey="rate"
                    stroke="#E8863D"
                    strokeWidth={3}
                    fillOpacity={1}
                    fill="url(#colorRateCare)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="space-y-3">
            <h3 className="font-extrabold text-lg text-[#5C4A3D] px-1">正在进行的计划</h3>
            <div className="grid gap-4">
              {(() => {
                // Group plans by medicineId to avoid duplicates and aggregate frequency based on CURRENT reminders
                const grouped = plans.reduce((acc: any, plan: any) => {
                  if (!acc[plan.medicineId]) {
                    acc[plan.medicineId] = {
                      medicineId: plan.medicineId,
                      totalSchedules: 0,
                      planIds: [],
                      status: plan.status
                    };
                  }
                  // Instead of using plan.schedules.length (which might be stale),
                  // we use the actual reminders count for today to ensure consistency with the home screen
                  const todayRemindersCount = reminders.filter((r: any) => r.planId === plan.id).length;
                  acc[plan.medicineId].totalSchedules += todayRemindersCount;
                  acc[plan.medicineId].planIds.push(plan.id);
                  if (plan.status === 'active') acc[plan.medicineId].status = 'active';
                  return acc;
                }, {});

                const aggregated = Object.values(grouped);

                if (aggregated.length === 0) {
                  return (
                    <div className="text-center py-8 bg-white/70 rounded-[26px] border border-dashed border-[#FFB366]/45">
                      <p className="text-[#8B7A6E] text-sm font-medium">暂无进行中的计划</p>
                    </div>
                  );
                }

                return aggregated.map((agg: any, idx: number) => {
                  const med = medications.find((m: any) => m.id === agg.medicineId);
                  if (!med) return null;

                  const medicineReminders = reminders.filter((r: any) => agg.planIds.includes(r.planId));
                  const taken = medicineReminders.filter((r: any) => r.status === 'taken').length;
                  const total = medicineReminders.length;
                  const rate = total > 0 ? Math.round((taken / total) * 100) : 0;

                  return (
                    <div
                      key={agg.medicineId}
                      className={cn(
                        'p-5 rounded-[28px] border flex items-center justify-between relative overflow-hidden shadow-md',
                        idx === 0
                          ? 'bg-gradient-to-br from-[#E8863D] to-[#d97830] border-[#E8863D] text-white'
                          : 'bg-white/95 border-[#FFE4CC] text-[#5C4A3D]',
                      )}
                    >
                      {idx === 0 && (
                        <div className="absolute -right-4 -top-4 w-24 h-24 bg-white/15 rounded-full blur-2xl" />
                      )}
                      <div className="flex items-center gap-4 relative z-10 min-w-0">
                        <div
                          className={cn(
                            'w-12 h-12 rounded-2xl flex items-center justify-center shrink-0',
                            idx === 0 ? 'bg-white/20' : 'bg-[#FFF8F0] border border-[#FFE4CC]',
                          )}
                        >
                          <Pill className={cn('w-6 h-6', idx === 0 ? 'text-white' : 'text-[#E8863D]')} />
                        </div>
                        <div className="min-w-0">
                          <h4 className="font-bold truncate">{med.name}</h4>
                          <p
                            className={cn(
                              'text-xs font-medium mt-0.5',
                              idx === 0 ? 'text-white/85' : 'text-[#8B7A6E]',
                            )}
                          >
                            今日共 {agg.totalSchedules} 次 · {agg.status === 'active' ? '进行中' : '已暂停'}
                          </p>
                        </div>
                      </div>
                      <div
                        className={cn(
                          'w-14 h-14 rounded-full flex flex-col items-center justify-center font-black text-[10px] shrink-0',
                          idx === 0 ? 'bg-white text-[#E8863D]' : 'bg-[#FFF8F0] text-[#8B7A6E] border border-[#FFE4CC]',
                        )}
                      >
                        <span className="text-base leading-none">{rate}%</span>
                        <span className="opacity-80 mt-0.5">今日</span>
                      </div>
                    </div>
                  );
                });
              })()}
            </div>
          </div>
        </div>
      )}

      {view === 'bindings' && (
        <div className="space-y-5">
          <h2 className="text-2xl font-black text-[#5C4A3D]">家人绑定</h2>
          <div className="bg-white/95 p-6 rounded-[28px] shadow-lg border border-[#FFE4CC] space-y-4">
            <p className="text-[#8B7A6E] text-sm leading-relaxed font-medium">
              输入长辈的 6 位 ID 和手机尾号后四位，就能陪 Ta 一起管理用药啦。
            </p>
            <div className="space-y-3">
              <input
                type="text"
                value={bindShortId}
                onChange={(e) => setBindShortId(e.target.value)}
                placeholder="长辈的 6 位 ID"
                maxLength={6}
                className="w-full px-4 py-3.5 rounded-[18px] bg-[#FFF8F0] border border-[#FFE4CC] outline-none focus:ring-2 focus:ring-[#E8863D]/35 text-[#5C4A3D] font-semibold tracking-widest"
              />
              <input
                type="text"
                value={bindPhoneLast4}
                onChange={(e) => setBindPhoneLast4(e.target.value)}
                placeholder="长辈手机尾号后 4 位"
                maxLength={4}
                className="w-full px-4 py-3.5 rounded-[18px] bg-[#FFF8F0] border border-[#FFE4CC] outline-none focus:ring-2 focus:ring-[#E8863D]/35 text-[#5C4A3D] font-semibold"
              />
              <button
                type="button"
                disabled={isBinding || bindShortId.length !== 6 || bindPhoneLast4.length !== 4}
                onClick={async () => {
                  setIsBinding(true);
                  await onBindElder(bindShortId, bindPhoneLast4);
                  setIsBinding(false);
                  setBindShortId('');
                  setBindPhoneLast4('');
                }}
                className="w-full bg-gradient-to-r from-[#E8863D] to-[#d97830] text-white py-3.5 rounded-[18px] font-extrabold shadow-md shadow-orange-900/15 disabled:opacity-45 disabled:cursor-not-allowed active:scale-[0.99] transition-transform"
              >
                {isBinding ? '绑定中…' : '确认绑定'}
              </button>
            </div>
          </div>

          <div className="space-y-3 pt-1">
            <h3 className="font-extrabold text-lg text-[#5C4A3D] px-1">已绑定的长辈</h3>
            {bindings.length > 0 ? (
              <div className="space-y-3">
                {bindings.map((binding: any) => {
                  const boundUser = boundUsers[binding.elderUserId];
                  return (
                    <div
                      key={binding.id}
                      className="bg-white/95 p-4 rounded-[26px] shadow-md border border-[#FFE4CC]/80 flex items-center justify-between gap-3"
                    >
                      <div className="flex items-center gap-4 min-w-0">
                        <div className="w-14 h-14 bg-[#FFE4CC]/70 rounded-full flex items-center justify-center text-[#5C4A3D] font-black text-sm shrink-0 border-2 border-white shadow-sm">
                          {boundUser?.displayName?.slice(0, 2) || '长辈'}
                        </div>
                        <div className="min-w-0">
                          <h4 className="font-bold text-[#5C4A3D] truncate">
                            {boundUser?.displayName || '未知用户'}
                          </h4>
                          <p className="text-xs text-[#8B7A6E] font-semibold mt-0.5">
                            短号 {boundUser?.shortId || '---'}
                          </p>
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-2 shrink-0">
                        <div className="px-3 py-1 bg-[#7CB87C]/20 text-[#2d6a2d] rounded-full text-xs font-bold border border-[#7CB87C]/25">
                          已绑定
                        </div>
                        <button
                          type="button"
                          onClick={() => onManageElderMedication(binding.elderUserId)}
                          className="text-xs font-extrabold text-[#E8863D] hover:underline"
                        >
                          管理用药 →
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-center py-10 bg-white/70 rounded-[26px] border border-dashed border-[#FFB366]/45">
                <p className="text-[#8B7A6E] text-sm font-medium">还没有绑定，填上面信息即可邀请长辈</p>
              </div>
            )}
          </div>
        </div>
      )}
    </motion.div>
  );
}
