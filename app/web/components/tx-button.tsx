"use client";

import { ExternalLink, Loader2 } from "lucide-react";
import { cn, explorerTxUrl } from "@/lib/utils";

interface TxButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  loading?: boolean;
  variant?: "primary" | "secondary" | "danger" | "ghost";
  txHash?: `0x${string}`;
  confirming?: boolean;
}

export function TxButton({
  loading,
  variant = "primary",
  txHash,
  confirming,
  children,
  className,
  disabled,
  ...props
}: TxButtonProps) {
  const variantStyles = {
    primary:
      "bg-accent text-white hover:bg-accent-hover disabled:bg-accent/30 disabled:text-white/50",
    secondary:
      "bg-surface-2 border border-border text-text hover:bg-border disabled:opacity-40",
    danger:
      "bg-red/10 border border-red/30 text-red hover:bg-red/20 disabled:opacity-40",
    ghost: "text-muted hover:text-text hover:bg-surface-2 disabled:opacity-40",
  };

  const isDisabled = disabled || loading || confirming;

  return (
    <div className="flex flex-col gap-1">
      <button
        {...props}
        disabled={isDisabled}
        className={cn(
          "flex h-9 items-center justify-center gap-2 rounded-md px-4 text-sm font-medium transition-all duration-100",
          variantStyles[variant],
          "disabled:cursor-not-allowed",
          className
        )}
      >
        {(loading || confirming) && (
          <Loader2 size={14} className="animate-spin" />
        )}
        {children}
      </button>
      {txHash && (
        <a
          href={explorerTxUrl(txHash)}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-1 text-xs text-accent hover:text-accent-hover transition-colors duration-100"
        >
          <ExternalLink size={11} />
          View on explorer
        </a>
      )}
    </div>
  );
}

interface TxStatusProps {
  error?: Error | null;
  success?: boolean;
  successMessage?: string;
  txHash?: `0x${string}`;
}

export function TxStatus({ error, success, successMessage, txHash }: TxStatusProps) {
  if (!error && !success && !txHash) return null;
  return (
    <div className="mt-1 space-y-1">
      {error && (
        <div className="rounded-md border border-red/30 bg-red/10 px-3 py-2 text-xs text-red">
          {error.message.slice(0, 120)}
        </div>
      )}
      {success && (
        <div className="rounded-md border border-green/30 bg-green/10 px-3 py-2 text-xs text-green">
          {successMessage ?? "Transaction confirmed"}
        </div>
      )}
      {txHash && (
        <a
          href={explorerTxUrl(txHash)}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-1 text-xs text-accent hover:text-accent-hover transition-colors duration-100"
        >
          <ExternalLink size={11} />
          View on explorer
        </a>
      )}
    </div>
  );
}
