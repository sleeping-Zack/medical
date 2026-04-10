import React, { useState, useEffect } from 'react';
import { Pill, AlertCircle, Download, CheckCircle2 } from 'lucide-react';
import { motion } from 'framer-motion';
import { cn } from '../lib/utils';
import { UserRole } from '../types';

interface AuthScreenProps {
  loginWithPhone: (phone: string, password: string) => Promise<void>;
  registerWithPhone: (phone: string, password: string, role: UserRole) => Promise<void>;
  isStandalone: boolean;
  setShowInstallGuide: (show: boolean) => void;
}

export function AuthScreen({ loginWithPhone, registerWithPhone, isStandalone, setShowInstallGuide }: AuthScreenProps) {
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [phone, setPhone] = useState('');
  const [smsCode, setSmsCode] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<UserRole>('caregiver');
  
  const [isSendingSms, setIsSendingSms] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [loading, setLoading] = useState(false);

  const isWeChat = /MicroMessenger/i.test(navigator.userAgent);

  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (countdown > 0) {
      timer = setTimeout(() => setCountdown(countdown - 1), 1000);
    }
    return () => clearTimeout(timer);
  }, [countdown]);

  const handleSendSms = async () => {
    if (!phone || phone.length !== 11) {
      alert('请输入正确的11位手机号');
      return;
    }
    setIsSendingSms(true);
    // Simulate sending SMS
    await new Promise(resolve => setTimeout(resolve, 1000));
    setIsSendingSms(false);
    setCountdown(60);
    // In a real app, we would call a backend API to send the SMS here.
    // For this MVP, we just simulate it. Any code will work.
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!phone || phone.length !== 11) {
      alert('请输入正确的11位手机号');
      return;
    }
    if (password.length < 6) {
      alert('密码至少需要6位');
      return;
    }

    setLoading(true);
    try {
      if (mode === 'login') {
        await loginWithPhone(phone, password);
      } else {
        if (!smsCode || smsCode.length !== 6) {
          alert('请输入6位短信验证码 (测试阶段可随意输入6位数字)');
          setLoading(false);
          return;
        }
        await registerWithPhone(phone, password, role);
      }
    } catch (error) {
      // Error is handled in useAuth hook
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center p-6">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-blue-600 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-blue-200">
            <Pill className="text-white w-8 h-8" />
          </div>
          <h1 className="text-3xl font-bold text-slate-900">智能用药提醒</h1>
          <p className="text-slate-500 mt-2">您的家庭健康守护助手</p>
        </div>

        <motion.div 
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="space-y-6"
        >
          {isWeChat && (
            <div className="bg-orange-50 p-4 rounded-2xl border border-orange-100 flex items-start space-x-3">
              <AlertCircle className="text-orange-600 w-5 h-5 mt-0.5 flex-shrink-0" />
              <p className="text-xs text-orange-700">
                检测到您正在使用微信浏览器。建议点击右上角选择“在浏览器中打开”以获得最佳体验。
              </p>
            </div>
          )}

          <div className="flex bg-slate-100 p-1 rounded-2xl">
            <button 
              onClick={() => setMode('login')}
              className={cn(
                "flex-1 py-3 rounded-xl text-sm font-bold transition-all",
                mode === 'login' ? "bg-white text-blue-600 shadow-sm" : "text-slate-500 hover:text-slate-700"
              )}
            >
              登录
            </button>
            <button 
              onClick={() => setMode('register')}
              className={cn(
                "flex-1 py-3 rounded-xl text-sm font-bold transition-all",
                mode === 'register' ? "bg-white text-blue-600 shadow-sm" : "text-slate-500 hover:text-slate-700"
              )}
            >
              注册
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === 'register' && (
              <div className="space-y-2 mb-4">
                <label className="text-sm font-bold text-slate-700">我是...</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setRole('caregiver')}
                    className={cn(
                      "p-4 rounded-2xl border-2 text-left transition-all",
                      role === 'caregiver' ? "border-blue-600 bg-blue-50" : "border-slate-100 bg-white"
                    )}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className={cn("font-bold", role === 'caregiver' ? "text-blue-900" : "text-slate-700")}>看护人</span>
                      {role === 'caregiver' && <CheckCircle2 className="w-5 h-5 text-blue-600" />}
                    </div>
                    <p className="text-xs text-slate-500">为家人设置提醒</p>
                  </button>
                  <button
                    type="button"
                    onClick={() => setRole('elder')}
                    className={cn(
                      "p-4 rounded-2xl border-2 text-left transition-all",
                      role === 'elder' ? "border-orange-600 bg-orange-50" : "border-slate-100 bg-white"
                    )}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className={cn("font-bold", role === 'elder' ? "text-orange-900" : "text-slate-700")}>长辈</span>
                      {role === 'elder' && <CheckCircle2 className="w-5 h-5 text-orange-600" />}
                    </div>
                    <p className="text-xs text-slate-500">接收吃药提醒</p>
                  </button>
                </div>
              </div>
            )}

            <div className="space-y-1">
              <label className="text-sm font-medium text-slate-700">手机号</label>
              <input 
                type="tel" 
                maxLength={11}
                placeholder="请输入11位手机号"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                className="w-full px-4 py-4 rounded-2xl bg-slate-50 border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition-all text-lg font-medium tracking-wider"
                required
              />
            </div>

            {mode === 'register' && (
              <div className="space-y-1">
                <label className="text-sm font-medium text-slate-700">验证码</label>
                <div className="flex space-x-2">
                  <input 
                    type="text" 
                    maxLength={6}
                    placeholder="6位数字"
                    value={smsCode}
                    onChange={(e) => setSmsCode(e.target.value.replace(/\D/g, ''))}
                    className="flex-1 px-4 py-4 rounded-2xl bg-slate-50 border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition-all text-lg font-medium tracking-wider"
                    required
                  />
                  <button 
                    type="button"
                    onClick={handleSendSms}
                    disabled={countdown > 0 || isSendingSms || phone.length !== 11}
                    className="px-6 py-4 bg-blue-50 text-blue-600 font-bold rounded-2xl disabled:opacity-50 disabled:cursor-not-allowed whitespace-nowrap transition-all active:scale-95"
                  >
                    {isSendingSms ? '发送中...' : countdown > 0 ? `${countdown}s 后重发` : '获取验证码'}
                  </button>
                </div>
                <p className="text-xs text-slate-400 mt-1">测试阶段：随意输入6位数字即可</p>
              </div>
            )}

            <div className="space-y-1">
              <label className="text-sm font-medium text-slate-700">密码</label>
              <input 
                type="password" 
                placeholder={mode === 'register' ? "设置至少6位密码" : "请输入密码"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-4 rounded-2xl bg-slate-50 border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white transition-all text-lg font-medium"
                required
              />
            </div>

            <button 
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 text-white py-4 rounded-2xl font-bold shadow-lg shadow-blue-200 mt-6 active:scale-95 transition-all flex items-center justify-center space-x-2"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <span>{mode === 'login' ? '登录' : '注册并登录'}</span>
              )}
            </button>
          </form>

          {!isStandalone && (
            <div className="pt-6 border-t border-slate-100">
              <button 
                onClick={() => setShowInstallGuide(true)}
                className="w-full bg-slate-50 text-slate-600 py-4 rounded-2xl font-bold flex items-center justify-center space-x-2 active:scale-95 transition-all hover:bg-slate-100"
              >
                <Download className="w-5 h-5" />
                <span>安装到手机桌面 (推荐)</span>
              </button>
              <p className="text-center text-[10px] text-slate-400 mt-2">
                安装后可像原生 App 一样使用，体验更佳
              </p>
            </div>
          )}

          <p className="text-center text-[10px] text-slate-400 px-8 pt-4">
            登录即表示您同意我们的 <span className="underline">服务条款</span> 和 <span className="underline">隐私政策</span>。
          </p>
        </motion.div>
      </div>
    </div>
  );
}
