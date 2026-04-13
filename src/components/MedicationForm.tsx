
import React, { useState } from 'react';
import { Pill, Save, X } from 'lucide-react';
import { DosageForm, DosageUnit } from '../types';
import { DOSAGE_FORMS, DOSAGE_UNITS } from '../constants';
import { cn } from '../lib/utils';

interface MedicationFormProps {
  onSave: (data: any) => void;
  onCancel: () => void;
  initialData?: any;
  loading?: boolean;
  /** 新建药品时：可选「为谁添加」，与看护人顶栏管理对象同步 */
  careTargetUserId?: string;
  onCareTargetUserIdChange?: (userId: string) => void;
  careTargetOptions?: { id: string; label: string }[];
  showTargetPicker?: boolean;
}

export function MedicationForm({
  onSave,
  onCancel,
  initialData,
  loading,
  careTargetUserId,
  onCareTargetUserIdChange,
  careTargetOptions = [],
  showTargetPicker = false,
}: MedicationFormProps) {
  const [name, setName] = useState(initialData?.name || '');
  const [specification, setSpecification] = useState(initialData?.specification || '');
  const [dosageForm, setDosageForm] = useState<DosageForm>(initialData?.dosageForm || 'tablet');
  const [note, setNote] = useState(initialData?.note || '');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave({ name, specification, dosageForm, note });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 bg-white p-6 rounded-3xl shadow-sm border border-slate-100">
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-xl font-bold">{initialData ? '修改药品' : '添加药品'}</h3>
        <button type="button" onClick={onCancel} className="p-2 hover:bg-slate-100 rounded-full">
          <X className="w-6 h-6 text-slate-400" />
        </button>
      </div>

      <div className="space-y-4">
        {showTargetPicker && careTargetUserId && onCareTargetUserIdChange && careTargetOptions.length > 0 && (
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-1">为谁添加药品</label>
            <p className="text-xs text-slate-500 mb-2">药品会记入该对象名下，家人登录老人端后将看到自己的日程。</p>
            <select
              value={careTargetUserId}
              onChange={(e) => onCareTargetUserIdChange(e.target.value)}
              className="w-full px-4 py-3 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 bg-white font-medium"
            >
              {careTargetOptions.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">药品名称</label>
          <input 
            type="text" 
            required
            placeholder="例如：氨氯地平"
            className="w-full px-4 py-3 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">规格</label>
          <input 
            type="text" 
            placeholder="例如：5mg * 30片"
            className="w-full px-4 py-3 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500"
            value={specification}
            onChange={(e) => setSpecification(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">剂型</label>
          <div className="grid grid-cols-3 gap-2">
            {DOSAGE_FORMS.map((form) => (
              <button
                key={form.value}
                type="button"
                onClick={() => setDosageForm(form.value as DosageForm)}
                className={cn(
                  "py-2 rounded-xl text-sm font-medium border transition-all",
                  dosageForm === form.value 
                    ? "bg-blue-600 border-blue-600 text-white shadow-md shadow-blue-100" 
                    : "bg-white border-slate-200 text-slate-600 hover:border-blue-200"
                )}
              >
                {form.label}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-slate-700 mb-1">备注 (可选)</label>
          <textarea 
            rows={3}
            placeholder="例如：饭后服用"
            className="w-full px-4 py-3 rounded-xl border border-slate-200 outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
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
            <span>正在保存...</span>
          </>
        ) : (
          <>
            <Save className="w-5 h-5" />
            <span>保存药品</span>
          </>
        )}
      </button>
    </form>
  );
}
