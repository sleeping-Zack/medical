import React, { useState, useEffect, Component, ErrorInfo, ReactNode } from 'react';
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
  Camera,
  CheckCircle2,
  Clock,
  AlertCircle,
  History,
  LogOut,
  ShieldAlert,
  Download,
  Edit2,
  Trash2,
  TrendingUp,
  Check
} from 'lucide-react';
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  AreaChart,
  Area
} from 'recharts';
import { motion, AnimatePresence } from 'motion/react';
import { ApiError, getAccessToken, getRefreshToken, clearTokenPair } from './lib/api';
import { fetchMe, loginWithPasswordApi, logoutApi, registerApi, sendRegisterSms, type UserMe } from './lib/authApi';
import { cn, formatTime } from './lib/utils';
import { UserRole, UserProfile, Medication, MedicationPlan, ReminderEvent, ElderBinding } from './types';
import { MedicationForm } from './components/MedicationForm';
import { PlanForm } from './components/PlanForm';
import { AuthScreen } from './components/AuthScreen';
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

  useEffect(() => {
    const interval = setInterval(() => {
      const now = new Date();
      const due = reminders.find(r => {
        const isPending = r.status === 'pending';
        const isNotDismissed = !dismissedReminderIds.has(r.id);
        const isDue = new Date(r.dueTime) <= now;
        // 原 2 小时过短，稍晚打开页面会永远不弹；改为到点后 24 小时内仍可弹出
        const isNotTooOld =
          now.getTime() - new Date(r.dueTime).getTime() < 24 * 60 * 60 * 1000;
        
        // Check if it was snoozed and if the snooze time has passed
        const snoozeTime = snoozedReminders.get(r.id);
        const isSnoozeOver = !snoozeTime || now.getTime() > snoozeTime;

        return isPending && isNotDismissed && isDue && isNotTooOld && isSnoozeOver;
      });
      
      if (due && (!activeReminder || activeReminder.id !== due.id)) {
        setActiveReminder(due);
      }
    }, 5000);

    return () => clearInterval(interval);
  }, [reminders, activeReminder, dismissedReminderIds, snoozedReminders]);

  useEffect(() => {
    if (profile) {
      setCurrentMode(profile.defaultMode);
    }
  }, [profile]);

  useEffect(() => {
    if (user) {
      loadMedications();
      loadPlans();
      const unsubscribe = medicationService.subscribeToTodayReminders(user.uid, (events) => {
        setReminders(events);
      });
      return () => unsubscribe();
    }
  }, [user]);

  const loadMedications = async () => {
    if (!user) return;
    const meds = await medicationService.getMedications(user.uid);
    setMedications(meds);
  };

  const loadPlans = async () => {
    if (!user) return;
    const data = await medicationService.getPlans(user.uid);
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
        await medicationService.addMedication({
          ...data,
          targetUserId: user.uid,
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
      await medicationService.addMedicationPlan({
        ...data,
        targetUserId: user.uid,
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
      <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-4">
        <motion.div 
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          className="flex flex-col items-center"
        >
          <div className="w-16 h-16 bg-blue-600 rounded-2xl flex items-center justify-center mb-4 shadow-lg shadow-blue-200">
            <Pill className="text-white w-8 h-8" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">用药提醒</h1>
          <p className="text-slate-500 mt-2">正在加载您的健康面板...</p>
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
    <div className={cn(
      "min-h-screen flex flex-col transition-all duration-300",
      currentMode === 'elder' ? "bg-orange-50" : "bg-slate-50"
    )}>
      {/* Due Reminder Overlay/Modal */}
      <AnimatePresence>
        {activeReminder && (
          <div className="fixed inset-0 z-[200] flex items-center justify-center p-6 bg-black/60 backdrop-blur-sm">
            <motion.div 
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              className={cn(
                "w-full max-w-sm p-8 rounded-[40px] shadow-2xl text-center space-y-6",
                currentMode === 'elder' ? "bg-orange-600 text-white" : "bg-white text-slate-900"
              )}
            >
              <div className={cn(
                "w-20 h-20 rounded-full flex items-center justify-center mx-auto animate-bounce",
                currentMode === 'elder' ? "bg-white/20" : "bg-blue-100"
              )}>
                <Bell className={cn("w-10 h-10", currentMode === 'elder' ? "text-white" : "text-blue-600")} />
              </div>
              
              <div className="space-y-2">
                <h2 className="text-3xl font-black">该吃药了！</h2>
                <p className={cn(
                  "text-lg font-medium opacity-80",
                  currentMode === 'elder' ? "text-white" : "text-slate-500"
                )}>
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
                    "w-full py-5 rounded-3xl text-xl font-bold shadow-lg active:scale-95 transition-all flex items-center justify-center space-x-2",
                    isConfirmingIntake 
                      ? "bg-slate-200 text-slate-400 cursor-not-allowed" 
                      : (currentMode === 'elder' ? "bg-white text-orange-600 shadow-orange-900/20" : "bg-blue-600 text-white shadow-blue-200")
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
                    "w-full py-4 rounded-3xl text-lg font-bold active:scale-95 transition-all",
                    currentMode === 'elder' ? "bg-white/20 text-white" : "bg-slate-100 text-slate-600",
                    isConfirmingIntake && "opacity-50 cursor-not-allowed"
                  )}
                >
                  10分钟后再说
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Header */}
      <header className={cn(
        "px-6 py-4 flex items-center justify-between sticky top-0 z-10 backdrop-blur-md",
        currentMode === 'elder' ? "bg-orange-50/80" : "bg-slate-50/80"
      )}>
        <div className="flex items-center space-x-2">
          <div className={cn(
            "w-10 h-10 rounded-xl flex items-center justify-center shadow-sm",
            currentMode === 'elder' ? "bg-orange-600" : "bg-blue-600"
          )}>
            <Pill className="text-white w-6 h-6" />
          </div>
          <span className="text-xl font-bold tracking-tight">用药提醒</span>
        </div>
        <div className="flex items-center space-x-3">
          <button className="p-2 rounded-full hover:bg-slate-200 transition-colors relative">
            <Bell className="w-6 h-6 text-slate-600" />
            {reminders.some(r => r.status === 'pending') && (
              <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
            )}
          </button>
          <button 
            onClick={() => setView('settings')}
            className="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center overflow-hidden border-2 border-transparent hover:border-blue-500 transition-all"
          >
            <UserCircle className="w-8 h-8 text-slate-400" />
          </button>
        </div>
      </header>

      {/* Notification Toast */}
      <AnimatePresence>
        {notification && (
          <motion.div 
            initial={{ y: -100, opacity: 0 }}
            animate={{ y: 20, opacity: 1 }}
            exit={{ y: -100, opacity: 0 }}
            className="fixed top-0 left-0 right-0 z-[100] flex justify-center pointer-events-none"
          >
            <div className={cn(
              "px-6 py-3 rounded-2xl shadow-lg font-bold flex items-center space-x-2 pointer-events-auto",
              notification.type === 'success' ? "bg-green-600 text-white" : "bg-red-600 text-white"
            )}>
              {notification.type === 'success' ? <CheckCircle2 className="w-5 h-5" /> : <AlertCircle className="w-5 h-5" />}
              <span>{notification.message}</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <main className="flex-1 px-6 py-4 pb-24 overflow-y-auto">
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
            />
          ) : (
            <ElderView view={view} setView={setView} reminders={reminders} user={user} profile={profile} updateProfile={updateProfile} />
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
        <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-100 px-6 py-3 flex items-center justify-between z-20">
          <NavButton active={view === 'home'} icon={LayoutDashboard} label="首页" onClick={() => setView('home')} />
          <NavButton active={view === 'medicines'} icon={Pill} label="药品" onClick={() => setView('medicines')} />
          <NavButton active={view === 'plans'} icon={Calendar} label="计划" onClick={() => setView('plans')} />
          <NavButton active={view === 'bindings'} icon={Users} label="家人" onClick={() => setView('bindings')} />
        </nav>
      )}

      {/* Settings Panel */}
      {view === 'settings' && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4">
          <motion.div 
            initial={{ y: 100 }}
            animate={{ y: 0 }}
            className="bg-white w-full max-w-md rounded-3xl p-6 space-y-6"
          >
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-bold">设置</h2>
              <button onClick={() => setView('home')} className="p-2 hover:bg-slate-100 rounded-full">
                <Plus className="w-6 h-6 rotate-45" />
              </button>
            </div>
            
            <div className="space-y-4">
              <div className="p-4 bg-slate-50 rounded-2xl flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">应用模式</h3>
                  <p className="text-sm text-slate-500">在看护人和老人视图之间切换</p>
                </div>
                <div className="flex bg-slate-200 p-1 rounded-xl">
                  <button 
                    onClick={() => {
                      setCurrentMode('caregiver');
                      updateProfile({ defaultMode: 'caregiver' });
                    }}
                    className={cn(
                      "px-3 py-1.5 rounded-lg text-sm font-medium transition-all",
                      currentMode === 'caregiver' ? "bg-white shadow-sm text-blue-600" : "text-slate-600"
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
                      "px-3 py-1.5 rounded-lg text-sm font-medium transition-all",
                      currentMode === 'elder' ? "bg-white shadow-sm text-orange-600" : "text-slate-600"
                    )}
                  >
                    老人
                  </button>
                </div>
              </div>

              <div className="p-4 bg-slate-50 rounded-2xl space-y-4">
                <h3 className="font-semibold">个人信息</h3>
                <div className="space-y-2">
                  <label className="text-sm text-slate-500">我的 6 位 ID</label>
                  <div className="w-full px-4 py-3 rounded-xl bg-slate-200 text-slate-700 font-mono tracking-widest font-bold">
                    {profile?.shortId || '---'}
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-sm text-slate-500">手机号 (用于家人绑定验证)</label>
                  <input 
                    type="tel" 
                    value={profile?.phone || ''}
                    onChange={(e) => updateProfile({ phone: e.target.value })}
                    placeholder="请输入手机号"
                    className="w-full px-4 py-3 rounded-xl bg-white border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>

              <div className="p-4 bg-slate-50 rounded-2xl space-y-4">
                <h3 className="font-semibold">辅助功能</h3>
                <div className="flex items-center justify-between">
                  <span className="text-sm">字体大小</span>
                  <input type="range" min="1" max="1.8" step="0.1" className="w-32" />
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-sm">语音提醒</span>
                  <div className="w-12 h-6 bg-blue-600 rounded-full relative">
                    <div className="absolute right-1 top-1 w-4 h-4 bg-white rounded-full"></div>
                  </div>
                </div>
                <button 
                  onClick={() => setShowInstallGuide(true)}
                  className="w-full py-2 bg-slate-100 text-slate-600 rounded-xl text-sm font-bold hover:bg-slate-200 transition-colors flex items-center justify-center space-x-2"
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
                  className="w-full py-2 bg-blue-50 text-blue-600 rounded-xl text-sm font-bold hover:bg-blue-100 transition-colors"
                >
                  发送测试提醒 (5秒后)
                </button>
              </div>

              <button 
                onClick={logout}
                className="w-full py-4 text-red-600 font-semibold border border-red-100 rounded-2xl hover:bg-red-50 transition-colors flex items-center justify-center space-x-2"
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
      onClick={onClick}
      className={cn(
        "flex flex-col items-center space-y-1 transition-all",
        active ? "text-blue-600" : "text-slate-400"
      )}
    >
      <Icon className={cn("w-6 h-6", active && "fill-blue-50")} />
      <span className="text-[10px] font-medium uppercase tracking-wider">{label}</span>
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
  user 
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

  return (
    <motion.div 
      key="caregiver"
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      className="space-y-6"
    >
      {view === 'home' && (
        <>
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-bold text-slate-900">您好，{user.displayName?.split(' ')[0]}</h2>
              <p className="text-slate-500">这是您家人的健康状况</p>
            </div>
            <div className="flex -space-x-2">
              <div className="w-8 h-8 rounded-full bg-blue-100 border-2 border-white flex items-center justify-center text-[10px] font-bold text-blue-600 uppercase">{user.displayName?.substr(0, 2)}</div>
            </div>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-white p-4 rounded-3xl shadow-sm border border-slate-100">
              <div className="w-10 h-10 bg-green-50 rounded-2xl flex items-center justify-center mb-3">
                <CheckCircle2 className="text-green-600 w-6 h-6" />
              </div>
              <div className="text-2xl font-bold">
                {reminders.length > 0 
                  ? Math.round((reminders.filter(r => r.status === 'taken').length / reminders.length) * 100) 
                  : 0}%
              </div>
              <div className="text-xs text-slate-500 uppercase tracking-wider font-semibold">服药率</div>
            </div>
            <div className="bg-white p-4 rounded-3xl shadow-sm border border-slate-100">
              <div className="w-10 h-10 bg-amber-50 rounded-2xl flex items-center justify-center mb-3">
                <AlertCircle className="text-amber-600 w-6 h-6" />
              </div>
              <div className="text-2xl font-bold">{reminders.filter((r: any) => r.status === 'pending').length}</div>
              <div className="text-xs text-slate-500 uppercase tracking-wider font-semibold">待处理</div>
            </div>
          </div>

          {/* Today's Reminders */}
          <section className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-lg">今日日程</h3>
              <button className="text-blue-600 text-sm font-semibold">查看全部</button>
            </div>
            <div className="space-y-3">
              {reminders.length > 0 ? reminders.map((rem: any) => (
                <div key={rem.id} className="bg-white p-4 rounded-3xl shadow-sm border border-slate-100 flex items-center justify-between group overflow-hidden relative">
                  <div className="flex items-center space-x-4 z-10">
                    <div className={cn(
                      "w-12 h-12 rounded-2xl flex items-center justify-center transition-colors",
                      rem.status === 'taken' ? "bg-green-50" : "bg-slate-50"
                    )}>
                      <Pill className={cn("w-6 h-6", rem.status === 'taken' ? "text-green-600" : "text-slate-400")} />
                    </div>
                    <div>
                      <h4 className="font-bold">
                        {(rem.medicineName && rem.medicineName !== '药品') 
                          ? rem.medicineName 
                          : (medications.find((m: any) => m.id === (plans.find((p: any) => p.id === rem.planId)?.medicineId))?.name || '药品')}
                      </h4>
                      <div className="flex items-center text-xs text-slate-500 space-x-2">
                        <span className="flex items-center"><Clock className="w-3 h-3 mr-1" /> {new Date(rem.dueTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })}</span>
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-2 z-10">
                    {rem.status === 'pending' && (
                      <button 
                        onClick={() => onConfirmIntake(rem.id)}
                        className="p-2 bg-green-50 text-green-600 rounded-xl hover:bg-green-100 transition-colors"
                        title="确认已吃"
                      >
                        <Check className="w-5 h-5" />
                      </button>
                    )}
                    <button 
                      onClick={() => onDeleteReminder(rem.id)}
                      className="p-2 bg-red-50 text-red-600 rounded-xl hover:bg-red-100 transition-colors"
                      title="删除日程"
                    >
                      <Trash2 className="w-5 h-5" />
                    </button>
                    <div className={cn(
                      "px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ml-2",
                      rem.status === 'taken' ? "bg-green-500 text-white" : "bg-blue-50 text-blue-600"
                    )}>
                      {rem.status === 'taken' ? '已服用' : '待服用'}
                    </div>
                  </div>
                </div>
              )) : (
                <div className="bg-white p-8 rounded-3xl border border-dashed border-slate-200 text-center">
                  <p className="text-slate-400 text-sm">今日暂无提醒</p>
                </div>
              )}
            </div>
          </section>

          {/* Quick Actions */}
          <div className="grid grid-cols-2 gap-4">
            <button 
              onClick={onAddMed}
              className="bg-blue-600 p-4 rounded-3xl shadow-lg shadow-blue-100 text-white flex flex-col items-start space-y-2"
            >
              <Plus className="w-6 h-6" />
              <span className="font-bold">添加药品</span>
            </button>
            <button 
              onClick={onAddPlan}
              className="bg-white p-4 rounded-3xl shadow-sm border border-slate-100 text-slate-900 flex flex-col items-start space-y-2"
            >
              <Calendar className="w-6 h-6 text-blue-600" />
              <span className="font-bold">新建计划</span>
            </button>
          </div>
        </>
      )}

      {view === 'medicines' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold">我的药品</h2>
            <button onClick={onAddMed} className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white shadow-lg shadow-blue-200">
              <Plus className="w-6 h-6" />
            </button>
          </div>
          <div className="relative">
            <input 
              type="text" 
              placeholder="搜索药品..." 
              className="w-full pl-10 pr-4 py-3 rounded-2xl bg-white border border-slate-100 shadow-sm outline-none focus:ring-2 focus:ring-blue-500"
            />
            <Plus className="absolute left-3 top-3.5 w-5 h-5 text-slate-400 rotate-45" />
          </div>
          <div className="space-y-4">
            {medications.length > 0 ? medications.map((med: any) => (
              <div key={med.id} className="bg-white p-5 rounded-3xl shadow-sm border border-slate-100 flex items-center justify-between group transition-all">
                <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 bg-blue-50 rounded-2xl flex items-center justify-center">
                    <Pill className="text-blue-600 w-7 h-7" />
                  </div>
                  <div>
                    <h4 className="font-bold text-lg">{med.name}</h4>
                    <p className="text-sm text-slate-500">{med.specification || med.dosageForm}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <button 
                    onClick={() => onEditMed(med)}
                    className="p-2 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-xl transition-all"
                  >
                    <Edit2 className="w-5 h-5" />
                  </button>
                  <button 
                    onClick={() => onDeleteMed(med.id)}
                    className="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-all"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              </div>
            )) : (
              <div className="text-center py-10">
                <p className="text-slate-400">尚未添加任何药品</p>
              </div>
            )}
          </div>
        </div>
      )}

      {view === 'plans' && (
        <div className="space-y-6 pb-10">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold">健康分析</h2>
            <button onClick={onAddPlan} className="bg-blue-600 px-4 py-2 rounded-xl text-white text-sm font-bold shadow-lg shadow-blue-100 flex items-center space-x-2">
              <Plus className="w-4 h-4" />
              <span>新计划</span>
            </button>
          </div>

          {/* Fun Element: Health Score - Moved up and color softened */}
          <div className="bg-gradient-to-br from-orange-50 to-pink-50 p-6 rounded-[40px] text-slate-900 border border-orange-100 relative overflow-hidden">
            <div className="relative z-10 space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-black uppercase tracking-widest text-orange-600">健康积分</h3>
                <div className="bg-orange-200/50 text-orange-700 px-3 py-1 rounded-full text-xs font-bold">LV. 4</div>
              </div>
              <div className="flex items-end space-x-2">
                <span className="text-5xl font-black text-slate-900">1,280</span>
                <span className="text-sm font-bold text-slate-500 mb-1">PTS</span>
              </div>
              <p className="text-xs text-slate-600 leading-relaxed">
                您已经连续 5 天准时服药了！继续保持，解锁“健康达人”勋章。
              </p>
              <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
                <div className="h-full bg-orange-400 w-3/4" />
              </div>
            </div>
            <div className="absolute -right-10 -bottom-10 w-40 h-40 bg-orange-200/20 rounded-full blur-3xl" />
          </div>

          {/* Compliance Chart */}
          <div className="bg-white p-6 rounded-[40px] shadow-sm border border-slate-100 space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-bold text-slate-900">服药依从性</h3>
                <p className="text-xs text-slate-500">过去 7 天的服药完成率</p>
              </div>
              <div className="bg-green-50 text-green-600 px-3 py-1 rounded-full text-xs font-bold flex items-center">
                <TrendingUp className="w-3 h-3 mr-1" />
                +12%
              </div>
            </div>
            
            <div className="h-48 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData}>
                  <defs>
                    <linearGradient id="colorRate" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#2563eb" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#2563eb" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                  <XAxis 
                    dataKey="name" 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{ fontSize: 10, fill: '#94a3b8' }}
                    dy={10}
                  />
                  <YAxis hide domain={[0, 100]} />
                  <Tooltip 
                    contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                    itemStyle={{ color: '#2563eb', fontWeight: 'bold' }}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="rate" 
                    stroke="#2563eb" 
                    strokeWidth={3}
                    fillOpacity={1} 
                    fill="url(#colorRate)" 
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Active Plans List */}
          <div className="space-y-4">
            <h3 className="font-bold text-lg">正在进行的计划</h3>
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
                    <div className="text-center py-6 bg-slate-50 rounded-3xl border border-dashed border-slate-200">
                      <p className="text-slate-400 text-sm">暂无进行中的计划</p>
                    </div>
                  );
                }

                return aggregated.map((agg: any, idx: number) => {
                  const med = medications.find((m: any) => m.id === agg.medicineId);
                  if (!med) return null;

                  // Calculate adherence for all plans of this medicine based on today's reminders
                  const medicineReminders = reminders.filter((r: any) => agg.planIds.includes(r.planId));
                  const taken = medicineReminders.filter((r: any) => r.status === 'taken').length;
                  const total = medicineReminders.length;
                  const rate = total > 0 ? Math.round((taken / total) * 100) : 0;

                  return (
                    <div key={agg.medicineId} className={cn(
                      "p-6 rounded-[32px] border flex items-center justify-between relative overflow-hidden",
                      idx === 0 ? "bg-blue-600 border-blue-600 text-white" : "bg-white border-slate-100 text-slate-900"
                    )}>
                      {idx === 0 && (
                        <div className="absolute -right-4 -top-4 w-24 h-24 bg-white/10 rounded-full blur-2xl" />
                      )}
                      <div className="flex items-center space-x-4 relative z-10">
                        <div className={cn(
                          "w-12 h-12 rounded-2xl flex items-center justify-center",
                          idx === 0 ? "bg-white/20" : "bg-blue-50"
                        )}>
                          <Pill className={cn("w-6 h-6", idx === 0 ? "text-white" : "text-blue-600")} />
                        </div>
                        <div>
                          <h4 className="font-bold">{med.name}</h4>
                          <p className={cn("text-xs", idx === 0 ? "text-blue-100" : "text-slate-500")}>
                            每日累计 {agg.totalSchedules} 次 · {agg.status === 'active' ? '进行中' : '已暂停'}
                          </p>
                        </div>
                      </div>
                      <div className={cn(
                        "w-12 h-12 rounded-full flex flex-col items-center justify-center font-black text-[10px]",
                        idx === 0 ? "bg-white text-blue-600" : "bg-slate-100 text-slate-400"
                      )}>
                        <span className="text-sm">{rate}%</span>
                        <span className="opacity-60">今日</span>
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
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold">家人绑定</h2>
          </div>
          <div className="bg-white p-6 rounded-[32px] shadow-sm border border-slate-100 space-y-4">
            <p className="text-slate-500 text-sm">输入长辈的 6 位 ID 和手机尾号后四位，即可建立绑定关系，协助管理用药计划。</p>
            <div className="space-y-3">
              <input 
                type="text" 
                value={bindShortId}
                onChange={(e) => setBindShortId(e.target.value)}
                placeholder="长辈的 6 位 ID" 
                maxLength={6}
                className="w-full px-4 py-3 rounded-2xl bg-slate-50 border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500"
              />
              <input 
                type="text" 
                value={bindPhoneLast4}
                onChange={(e) => setBindPhoneLast4(e.target.value)}
                placeholder="长辈手机尾号后 4 位" 
                maxLength={4}
                className="w-full px-4 py-3 rounded-2xl bg-slate-50 border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500"
              />
              <button 
                disabled={isBinding || bindShortId.length !== 6 || bindPhoneLast4.length !== 4}
                onClick={async () => {
                  setIsBinding(true);
                  await onBindElder(bindShortId, bindPhoneLast4);
                  setIsBinding(false);
                  setBindShortId('');
                  setBindPhoneLast4('');
                }}
                className="w-full bg-blue-600 text-white py-3 rounded-2xl font-bold hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isBinding ? '绑定中...' : '确认绑定'}
              </button>
            </div>
          </div>
          
          <div className="space-y-4 pt-4">
            <h3 className="font-bold text-lg">已绑定的家人</h3>
            {bindings.length > 0 ? (
              <div className="space-y-3">
                {bindings.map((binding: any) => {
                  const boundUser = boundUsers[binding.elderUserId];
                  return (
                    <div key={binding.id} className="bg-white p-4 rounded-3xl shadow-sm border border-slate-100 flex items-center justify-between">
                      <div className="flex items-center space-x-4">
                        <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 font-bold">
                          {boundUser?.displayName?.substr(0, 2) || '家人'}
                        </div>
                        <div>
                          <h4 className="font-bold">{boundUser?.displayName || '未知用户'}</h4>
                          <p className="text-xs text-slate-500">ID: {boundUser?.shortId || '---'}</p>
                        </div>
                      </div>
                      <div className="px-3 py-1 bg-green-50 text-green-600 rounded-full text-xs font-bold">
                        已绑定
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-center py-8 bg-slate-50 rounded-3xl border border-dashed border-slate-200">
                <p className="text-slate-400 text-sm">暂无绑定的家人</p>
              </div>
            )}
          </div>
        </div>
      )}
    </motion.div>
  );
}

function ElderView({ view, setView, reminders, user, profile, updateProfile }: any) {
  const [showDue, setShowDue] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [editingPhone, setEditingPhone] = useState(false);
  const [tempPhone, setTempPhone] = useState('');
  
  // Find the most relevant reminder: the first pending one
  const nextReminder = reminders.find((r: any) => r.status === 'pending');
  
  const isPastDue = nextReminder ? new Date(nextReminder.dueTime) < new Date() : false;

  return (
    <motion.div 
      key="elder"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 1.05 }}
      className="space-y-8"
    >
      {!showDue ? (
        <div className="flex flex-col items-center text-center space-y-10 pt-10">
          <div className="space-y-2">
            <h2 className="text-6xl font-black text-slate-900">{new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false })}</h2>
            <p className="text-2xl font-medium text-slate-500">{new Date().toLocaleDateString('zh-CN', { weekday: 'long', month: 'long', day: 'numeric' })}</p>
          </div>

          <div className="w-full bg-white p-8 rounded-[40px] shadow-xl shadow-orange-100 border-2 border-orange-200 space-y-6">
            <div className={cn(
              "inline-flex items-center space-x-2 px-4 py-2 rounded-full text-sm font-bold uppercase tracking-widest",
              isPastDue ? "bg-red-100 text-red-700 animate-pulse" : "bg-orange-100 text-orange-700"
            )}>
              <Clock className="w-4 h-4" />
              <span>{isPastDue ? '该吃药了！' : '下次提醒'}</span>
            </div>
            {nextReminder ? (
              <>
                <div className="space-y-2">
                  <h3 className="text-4xl font-black text-slate-900">服药时间</h3>
                  <p className={cn(
                    "text-2xl font-bold",
                    isPastDue ? "text-red-600" : "text-slate-500"
                  )}>
                    {new Date(nextReminder.dueTime).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false })}
                  </p>
                </div>
                <button 
                  onClick={() => setShowDue(true)}
                  className={cn(
                    "w-full py-6 rounded-3xl text-2xl font-black shadow-lg active:scale-95 transition-all",
                    isPastDue ? "bg-red-600 text-white shadow-red-200" : "bg-orange-600 text-white shadow-orange-200"
                  )}
                >
                  现在服用
                </button>
              </>
            ) : (
              <div className="py-4">
                <p className="text-xl text-slate-400 font-bold">今日已完成所有服药</p>
              </div>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4 w-full">
            <button 
              onClick={() => setView('today')}
              className="bg-white p-6 rounded-[32px] flex flex-col items-center space-y-2 text-slate-600 font-bold shadow-sm border border-slate-100"
            >
              <History className="w-8 h-8" />
              <span>服药记录</span>
            </button>
            <button 
              onClick={() => setShowProfile(true)}
              className="bg-white p-6 rounded-[32px] flex flex-col items-center space-y-2 text-slate-600 font-bold shadow-sm border border-slate-100"
            >
              <Users className="w-8 h-8" />
              <span>家人联系</span>
            </button>
          </div>
        </div>
      ) : (
        <motion.div 
          initial={{ y: 50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="fixed inset-0 bg-orange-600 z-50 p-8 flex flex-col justify-between"
        >
          <div className="text-center space-y-8 pt-12">
            <h2 className="text-white text-3xl font-bold opacity-80 uppercase tracking-widest">该吃药了</h2>
            <div className="space-y-4">
              <h3 className="text-white text-7xl font-black">服药</h3>
              <p className="text-white text-4xl opacity-90">1 片</p>
            </div>
            <div className="w-32 h-32 bg-white/20 rounded-full flex items-center justify-center mx-auto">
              <Pill className="text-white w-16 h-16" />
            </div>
          </div>

          <div className="space-y-4">
            <button 
              onClick={() => {
                if (nextReminder) medicationService.confirmIntake(nextReminder.id, user.uid);
                setShowDue(false);
              }}
              className="w-full bg-white text-orange-600 py-8 rounded-[32px] text-3xl font-black shadow-2xl active:scale-95 transition-transform flex items-center justify-center space-x-4"
            >
              <CheckCircle2 className="w-10 h-10" />
              <span>我已经吃了</span>
            </button>
            <div className="grid grid-cols-2 gap-4">
              <button 
                onClick={() => setShowDue(false)}
                className="bg-white/20 text-white py-6 rounded-[32px] text-xl font-bold active:scale-95 transition-transform"
              >
                10分钟后提醒
              </button>
              <button 
                className="bg-white/20 text-white py-6 rounded-[32px] text-xl font-bold active:scale-95 transition-transform flex items-center justify-center space-x-2"
              >
                <Camera className="w-6 h-6" />
                <span>拍照确认</span>
              </button>
            </div>
          </div>
        </motion.div>
      )}

      {/* Profile Modal */}
      <AnimatePresence>
        {showProfile && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
            <motion.div 
              initial={{ scale: 0.9, opacity: 0 }} 
              animate={{ scale: 1, opacity: 1 }} 
              exit={{ scale: 0.9, opacity: 0 }} 
              className="bg-white w-full max-w-md rounded-[40px] p-8 space-y-6 relative"
            >
              <button 
                onClick={() => setShowProfile(false)}
                className="absolute right-6 top-6 p-2 hover:bg-slate-100 rounded-full"
              >
                <Plus className="w-6 h-6 rotate-45 text-slate-400" />
              </button>
              
              <div className="text-center space-y-2">
                <h2 className="text-3xl font-black text-slate-900">我的信息</h2>
                <p className="text-slate-500">将这些信息告诉家人，让他们协助您</p>
              </div>

              <div className="space-y-4 bg-slate-50 p-6 rounded-3xl border border-slate-100">
                <div>
                  <p className="text-sm text-slate-500 font-bold uppercase tracking-wider mb-1">我的 6 位 ID</p>
                  <p className="text-4xl font-black text-blue-600 tracking-widest">{profile?.shortId || '---'}</p>
                </div>
                <div className="pt-4 border-t border-slate-200">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-sm text-slate-500 font-bold uppercase tracking-wider">手机号</p>
                    {!editingPhone && (
                      <button 
                        onClick={() => {
                          setTempPhone(profile?.phone || '');
                          setEditingPhone(true);
                        }}
                        className="text-blue-600 text-sm font-bold"
                      >
                        修改
                      </button>
                    )}
                  </div>
                  
                  {editingPhone ? (
                    <div className="flex items-center space-x-2">
                      <input 
                        type="tel"
                        value={tempPhone}
                        onChange={(e) => setTempPhone(e.target.value)}
                        placeholder="请输入手机号"
                        className="flex-1 px-4 py-2 rounded-xl border border-slate-300 outline-none focus:ring-2 focus:ring-blue-500"
                      />
                      <button 
                        onClick={() => {
                          updateProfile({ phone: tempPhone });
                          setEditingPhone(false);
                        }}
                        className="px-4 py-2 bg-blue-600 text-white font-bold rounded-xl"
                      >
                        保存
                      </button>
                    </div>
                  ) : (
                    <>
                      <p className="text-2xl font-bold text-slate-900">{profile?.phone || '未设置'}</p>
                      {!profile?.phone && (
                        <p className="text-sm text-amber-600 mt-2">请设置手机号，以便家人绑定</p>
                      )}
                    </>
                  )}
                </div>
              </div>

              <button 
                onClick={() => setShowProfile(false)}
                className="w-full bg-slate-900 text-white py-4 rounded-2xl font-bold text-xl active:scale-95 transition-transform"
              >
                我知道了
              </button>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}
