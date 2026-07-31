import { Alert } from '@/types';
import { Badge } from '@/components/ui/Badge';
import { AlertCircle, Activity, Droplets } from 'lucide-react';
import Link from 'next/link';

interface AlertPanelProps {
  alerts: Alert[];
}

const typeIcon: Record<string, React.ComponentType<{ className?: string }>> = {
  BP: Activity,
  Glucose: Droplets,
};

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  return `${hrs}h ago`;
}

export function AlertPanel({ alerts }: AlertPanelProps) {
  return (
    <div className="space-y-3">
      {alerts.length === 0 ? (
        <div className="text-center py-8 text-gray-400 text-sm">
          No active alerts
        </div>
      ) : (
        alerts.map((a) => {
          const Icon = typeIcon[a.type] || AlertCircle;
          return (
            <Link
              key={a.id}
              href={`/dashboard/patient/${a.patientId}`}
              className="block"
            >
              <div
                className={`p-3 rounded-lg border transition-colors hover:shadow-sm ${
                  a.severity === 'critical'
                    ? 'bg-red-50 border-red-200 hover:border-red-300'
                    : 'bg-amber-50 border-amber-200 hover:border-amber-300'
                }`}
              >
                <div className="flex items-start gap-2">
                  <Icon
                    className={`w-4 h-4 flex-shrink-0 mt-0.5 ${
                      a.severity === 'critical' ? 'text-red-500' : 'text-amber-500'
                    }`}
                  />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 mb-1">
                      <span className="text-sm font-medium text-gray-900 truncate">
                        {a.patientName}
                      </span>
                      <Badge variant={a.severity}>
                        {a.severity === 'critical' ? 'Critical' : 'Warning'}
                      </Badge>
                    </div>
                    <p className="text-xs text-gray-600 leading-relaxed">{a.message}</p>
                    <div className="mt-1 flex items-center justify-between">
                      <span className="text-xs text-gray-400">{a.type}</span>
                      <span className="text-xs text-gray-400">{timeAgo(a.timestamp)}</span>
                    </div>
                  </div>
                </div>
              </div>
            </Link>
          );
        })
      )}
    </div>
  );
}
