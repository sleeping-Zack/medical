
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatTime(hour: number, minute: number): string {
  return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
}

export function getStatusColor(status: string): string {
  switch (status) {
    case 'taken': return 'text-green-600 bg-green-50 border-green-200';
    case 'pending': return 'text-blue-600 bg-blue-50 border-blue-200';
    case 'snoozed': return 'text-amber-600 bg-amber-50 border-amber-200';
    case 'missed': return 'text-red-600 bg-red-50 border-red-200';
    default: return 'text-gray-600 bg-gray-50 border-gray-200';
  }
}
