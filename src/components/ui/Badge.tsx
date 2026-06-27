import React from 'react';

interface BadgeProps {
  variant?: 'critical' | 'warning' | 'stable' | 'normal' | 'info';
  children: React.ReactNode;
  className?: string;
}

const variantStyles: Record<string, string> = {
  critical: 'bg-red-100 text-red-700 border border-red-200',
  warning: 'bg-amber-100 text-amber-700 border border-amber-200',
  stable: 'bg-green-100 text-green-700 border border-green-200',
  normal: 'bg-green-100 text-green-700 border border-green-200',
  info: 'bg-blue-100 text-blue-700 border border-blue-200',
};

export function Badge({ variant = 'normal', children, className = '' }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${variantStyles[variant]} ${className}`}
    >
      {children}
    </span>
  );
}
