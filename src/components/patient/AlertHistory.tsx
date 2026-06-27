import { Alert } from '@/types';
import { Card, CardHeader, CardContent } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Bell, CheckCircle } from 'lucide-react';

interface AlertHistoryProps {
  alerts: Alert[];
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function AlertHistory({ alerts }: AlertHistoryProps) {
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <Bell className="w-5 h-5 text-gray-500" />
          <h2 className="text-base font-semibold text-gray-900">Alert History</h2>
          <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">
            {alerts.length} total
          </span>
        </div>
      </CardHeader>
      <CardContent>
        {alerts.length === 0 ? (
          <div className="text-center py-6 text-gray-400">
            <CheckCircle className="w-8 h-8 mx-auto mb-2 text-green-400" />
            <p className="text-sm">No alerts for this patient</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-100">
                  <th className="text-left text-xs font-medium text-gray-400 uppercase py-2">Time</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase py-2">Type</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase py-2">Message</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase py-2">Severity</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase py-2">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {alerts.map((a) => (
                  <tr key={a.id} className="hover:bg-gray-50">
                    <td className="py-3 text-xs text-gray-500 whitespace-nowrap">
                      {formatTime(a.timestamp)}
                    </td>
                    <td className="py-3 text-sm font-medium text-gray-700">{a.type}</td>
                    <td className="py-3 text-sm text-gray-600 max-w-xs">{a.message}</td>
                    <td className="py-3">
                      <Badge variant={a.severity === 'critical' ? 'critical' : 'warning'}>
                        {a.severity === 'critical' ? 'Critical' : 'Warning'}
                      </Badge>
                    </td>
                    <td className="py-3">
                      {a.acknowledged ? (
                        <span className="text-xs text-green-600 flex items-center gap-1">
                          <CheckCircle className="w-3.5 h-3.5" /> Acknowledged
                        </span>
                      ) : (
                        <span className="text-xs text-amber-600 font-medium">Pending</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
