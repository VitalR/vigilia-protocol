import {
  AlertTriangle,
  ArrowDown,
  ArrowDownToLine,
  Ban,
  Banknote,
  CheckCircle2,
  CircleDot,
  Clock,
  FilePlus,
  LucideIcon,
  RotateCcw,
  Scale,
  Upload,
  XCircle,
} from "lucide-react";

const EVENT_ICONS: Record<string, LucideIcon> = {
  TaskCreated:                FilePlus,
  TaskFunded:                 Banknote,
  WorkSubmitted:              Upload,
  VerdictRecorded:            CheckCircle2,
  VerificationFailedRecorded: XCircle,
  VerificationTimedOut:       Clock,
  VerificationRetried:        RotateCcw,
  TaskApproved:               CheckCircle2,
  TaskClaimed:                ArrowDownToLine,
  DisputeRaised:              AlertTriangle,
  DisputeResolved:            Scale,
  TaskCancelled:              Ban,
  PendingWithdrawalClaimed:   ArrowDown,
};

export function TrailIcon({
  name,
  size = 13,
  className,
}: {
  name: string;
  size?: number;
  className?: string;
}) {
  const Icon = EVENT_ICONS[name] ?? CircleDot;
  return <Icon size={size} className={className} />;
}
