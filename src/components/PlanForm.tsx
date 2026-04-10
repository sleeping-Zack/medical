
import React, { useState } from 'react';
import { Calendar, Clock, Plus, Trash2, X, Check } from 'lucide-react';
import { Schedule, DosageUnit } from '../types';
import { DOSAGE_UNITS } from '../constants';
import { cn, formatTime } from '../lib/utils';

interface PlanFormProps {
  medications: any[];
  onSave: (data: any) => void;
  onCancel: () => void;
  loading?: boolean;
}

export function PlanForm({ medications, onSave, onCancel, loading }: PlanFormProps) {
  const [medicineId, setMedicineId] = useState(medications[0]?.id || '');
  const [startDate, setStartDate] = useState(new Date().toISOString().split('T')[0]);
  const [schedules, setSchedules] = useState<Partial<Schedule>[]>([
    { hour: 8, minute: 0, dosageAmount: 1, dosageUnit: 'tablet', weekdaysMask: '1111111' }
  ]);
  const [frequency, setFrequency] = useState(1);
  const [activeTimePicker, setActiveTimePicker] = useState<{ index: number, time: string } | null>(null);

  React.useEffect(() => {
    if (!medicineId && medications.length > 0) {
      setMedicineId(medications[0].id);
    }
  }, [medications, medicineId]);

  const handleFrequencyChange = (freq: number) => {
    setFrequency(freq);
    const newSchedules: Partial<Schedule>[] = [];
    const times = [
      { h: 8, m: 0 },
      { h: 12, m: 0 },
      { h: 18, m: 0 },
      { h: 22, m: 0 }
    ];
    
    for (let i = 0; i < freq; i++) {
      newSchedules.push({ 
        hour: times[i]?.h || 8 + i * 4, 
        minute: 0, 
        dosageAmount: 1, 
        dosageUnit: 'tablet', 
        weekdaysMask: '1111111' 
      });
    }
    setSchedules(newSchedules);
  };

  const addSchedule = () => {
    setSchedules([...schedules, { hour: 12, minute: 0, dosageAmount: 1, dosageUnit: 'tablet', weekdaysMask: '1111111' }]);
    setFrequency(schedules.length + 1);
  };

  const removeSchedule = (index: number) => {
    const newSchedules = schedules.filter((_, i) => i !== index);
    setSchedules(newSchedules);
    setFrequency(newSchedules.length);
  };

  const updateSchedule = (index: number, updates: Partial<Schedule>) => {
    const newSchedules = [...schedules];
    newSchedules[index] = { ...newSchedules[index], ...updates };
    setSchedules(newSchedules);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave({ medicineId, startDate, schedules });
  };

  return (
    <div className="relative">
      <form onSubmit={handleSubmit} className="space-y-6 bg-white p-6 rounded-3xl shadow-sm border border-slate-100">
        <div className="flex items-center justify-between">
          <h3 className="text-xl font-bold">新建用药计划</h3>
          <button type="button" onClick={onCancel} className="p-2 hover:bg-slate-100 rounded-full">
            <X className="w-6 h-6 text-slate-400" />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">选择药品</label>
            <select 
              className="w-full px-4 py-3 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 bg-white"
              value={medicineId}
              onChange={(e) => setMedicineId(e.target.value)}
            >
              {medications.map(m => (
                <option key={m.id} value={m.id}>{m.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">开始日期</label>
            <div className="relative">
              <input 
                type="date" 
                className="w-full px-4 py-3 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
              />
              <Calendar className="absolute right-4 top-3.5 w-5 h-5 text-slate-400 pointer-events-none" />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">用药频率</label>
            <div className="grid grid-cols-4 gap-2">
              {[1, 2, 3, 4].map((freq) => (
                <button
                  key={freq}
                  type="button"
                  onClick={() => handleFrequencyChange(freq)}
                  className={cn(
                    "py-2 rounded-xl text-sm font-bold border transition-all",
                    frequency === freq 
                      ? "bg-blue-600 border-blue-600 text-white shadow-md shadow-blue-100" 
                      : "bg-white border-slate-200 text-slate-600 hover:border-blue-200"
                  )}
                >
                  每日{freq}次
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium text-slate-700">用药时间</label>
              <button 
                type="button" 
                onClick={addSchedule}
                className="text-blue-600 text-xs font-bold flex items-center"
              >
                <Plus className="w-4 h-4 mr-1" /> 添加时间
              </button>
            </div>

            {schedules.map((s, idx) => (
              <div key={idx} className="p-4 bg-slate-50 rounded-2xl space-y-3 border border-slate-100">
                <div className="flex items-center justify-between">
                  <button 
                    type="button"
                    onClick={() => setActiveTimePicker({ index: idx, time: formatTime(s.hour || 0, s.minute || 0) })}
                    className="flex items-center space-x-2 bg-white px-3 py-1.5 rounded-xl border border-slate-200 shadow-sm"
                  >
                    <Clock className="w-4 h-4 text-blue-600" />
                    <span className="font-bold text-slate-900">{formatTime(s.hour || 0, s.minute || 0)}</span>
                  </button>
                  {schedules.length > 1 && (
                    <button type="button" onClick={() => removeSchedule(idx)} className="text-red-400 p-2 hover:bg-red-50 rounded-full transition-colors">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
                
                <div className="flex items-center space-x-2">
                  <div className="relative flex-1">
                    <input 
                      type="number" 
                      className="w-full pl-3 pr-8 py-2 rounded-lg border border-slate-200 text-center font-bold"
                      value={s.dosageAmount}
                      onChange={(e) => updateSchedule(idx, { dosageAmount: Number(e.target.value) })}
                    />
                    <span className="absolute right-3 top-2 text-xs text-slate-400 font-medium">份量</span>
                  </div>
                  <select 
                    className="flex-1 px-2 py-2 rounded-lg border border-slate-200 bg-white text-sm font-medium"
                    value={s.dosageUnit}
                    onChange={(e) => updateSchedule(idx, { dosageUnit: e.target.value as DosageUnit })}
                  >
                    {DOSAGE_UNITS.map(u => (
                      <option key={u.value} value={u.value}>{u.label}</option>
                    ))}
                  </select>
                </div>
              </div>
            ))}
          </div>
        </div>

        <button 
          type="submit"
          disabled={loading}
          className={cn(
            "w-full py-4 rounded-2xl font-bold shadow-lg transition-all active:scale-95 flex items-center justify-center space-x-2",
            loading ? "bg-slate-100 text-slate-400 cursor-not-allowed" : "bg-blue-600 text-white shadow-blue-100"
          )}
        >
          {loading ? (
            <>
              <div className="w-5 h-5 border-2 border-slate-300 border-t-slate-500 rounded-full animate-spin" />
              <span>正在创建...</span>
            </>
          ) : (
            <span>创建计划</span>
          )}
        </button>
      </form>

      {/* Custom Time Picker Modal to avoid native lag and provide confirm button */}
      {activeTimePicker && (
        <div className="fixed inset-0 bg-black/60 z-[60] flex items-center justify-center p-6 backdrop-blur-sm">
          <div className="bg-white w-full max-w-[280px] rounded-[32px] p-6 shadow-2xl space-y-6 animate-in zoom-in-95 duration-200">
            <div className="text-center">
              <h4 className="text-lg font-bold text-slate-900">设定服药时间</h4>
              <p className="text-xs text-slate-500">请选择准确的小时和分钟</p>
            </div>
            
            <div className="flex justify-center items-center space-x-2">
              <select 
                className="text-3xl font-black text-blue-600 bg-slate-50 p-3 rounded-2xl border-2 border-blue-100 outline-none focus:border-blue-500 appearance-none text-center w-24"
                value={activeTimePicker.time.split(':')[0]}
                onChange={(e) => setActiveTimePicker({ ...activeTimePicker, time: `${e.target.value.padStart(2, '0')}:${activeTimePicker.time.split(':')[1]}` })}
              >
                {Array.from({ length: 24 }, (_, i) => (
                  <option key={i} value={i.toString().padStart(2, '0')}>{i.toString().padStart(2, '0')}</option>
                ))}
              </select>
              <span className="text-3xl font-black text-slate-400">:</span>
              <select 
                className="text-3xl font-black text-blue-600 bg-slate-50 p-3 rounded-2xl border-2 border-blue-100 outline-none focus:border-blue-500 appearance-none text-center w-24"
                value={activeTimePicker.time.split(':')[1]}
                onChange={(e) => setActiveTimePicker({ ...activeTimePicker, time: `${activeTimePicker.time.split(':')[0]}:${e.target.value.padStart(2, '0')}` })}
              >
                {Array.from({ length: 60 }, (_, i) => (
                  <option key={i} value={i.toString().padStart(2, '0')}>{i.toString().padStart(2, '0')}</option>
                ))}
              </select>
            </div>

            <div className="flex flex-col gap-2">
              <button 
                type="button"
                onClick={() => {
                  const [h, m] = activeTimePicker.time.split(':').map(Number);
                  updateSchedule(activeTimePicker.index, { hour: h, minute: m });
                  setActiveTimePicker(null);
                }}
                className="w-full bg-blue-600 text-white py-3 rounded-xl font-bold shadow-lg shadow-blue-100 flex items-center justify-center space-x-2 active:scale-95 transition-transform"
              >
                <Check className="w-5 h-5" />
                <span>确认时间</span>
              </button>
              <button 
                type="button"
                onClick={() => setActiveTimePicker(null)}
                className="w-full bg-slate-100 text-slate-600 py-3 rounded-xl font-bold active:scale-95 transition-transform"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
