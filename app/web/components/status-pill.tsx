import { cn } from "@/lib/utils";
import { TaskState, TASK_STATE_LABEL } from "@/lib/contracts";

interface StatusPillProps {
  state: TaskState;
  size?: "sm" | "md";
  className?: string;
}

export function StatusPill({ state, size = "md", className }: StatusPillProps) {
  const label = TASK_STATE_LABEL[state] ?? String(state);

  const styles: Record<string, string> = {
    // success
    [TaskState.Claimed]: "bg-green/10 text-green border-green/30",
    [TaskState.Approved]: "bg-green/10 text-green border-green/30",
    [TaskState.VerifiedComplete]: "bg-green/10 text-green border-green/30",
    // warning
    [TaskState.NeedsReview]: "bg-yellow/10 text-yellow border-yellow/30",
    [TaskState.Submitted]: "bg-yellow/10 text-yellow border-yellow/30",
    // error
    [TaskState.Incomplete]: "bg-red/10 text-red border-red/30",
    [TaskState.Disputed]: "bg-red/10 text-red border-red/30",
    [TaskState.VerificationFailed]: "bg-red/10 text-red border-red/30",
    // active/blue
    [TaskState.Funded]: "bg-blue/10 text-blue border-blue/30",
    [TaskState.Created]: "bg-blue/10 text-blue border-blue/30",
    // neutral
    [TaskState.Resolved]: "bg-surface-2 text-muted border-border",
    [TaskState.Cancelled]: "bg-surface-2 text-muted border-border",
    [TaskState.None]: "bg-surface-2 text-muted border-border",
  };

  return (
    <span
      className={cn(
        "inline-flex items-center rounded border font-mono font-medium uppercase tracking-wider",
        size === "sm" ? "px-1.5 py-0.5 text-[10px]" : "px-2 py-0.5 text-xs",
        styles[state] ?? "bg-surface-2 text-muted border-border",
        className
      )}
    >
      {state === TaskState.Submitted && (
        <span className="mr-1.5 inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-yellow" />
      )}
      {label}
    </span>
  );
}
