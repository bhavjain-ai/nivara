'use client';

import { Condition } from '@/types';

const conditions = ['All', 'Hypertension', 'Diabetes'] as const;
type ConditionFilter = 'All' | Condition;

interface ConditionTabsProps {
  selected: ConditionFilter;
  onChange: (c: ConditionFilter) => void;
  counts: Record<string, number>;
}

export function ConditionTabs({ selected, onChange, counts }: ConditionTabsProps) {
  return (
    <div className="flex items-center gap-1 bg-gray-100 p-1 rounded-lg w-fit">
      {conditions.map((c) => (
        <button
          key={c}
          onClick={() => onChange(c)}
          className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
            selected === c
              ? 'bg-white text-gray-900 shadow-sm'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          {c}
          {counts[c] !== undefined && (
            <span className={`ml-1.5 text-xs ${selected === c ? 'text-gray-500' : 'text-gray-400'}`}>
              ({counts[c]})
            </span>
          )}
        </button>
      ))}
    </div>
  );
}
