import Link from "next/link";
import { AlertTriangle } from "lucide-react";

export function NotDeployedBanner() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <div className="rounded-xl border border-yellow/20 bg-yellow/5 p-8 text-center">
        <AlertTriangle size={32} className="mx-auto mb-4 text-yellow" />
        <h2 className="mb-2 text-lg font-bold text-text">Contract not deployed</h2>
        <p className="mb-4 text-sm text-muted">
          Add contract addresses to{" "}
          <code className="rounded bg-surface-2 px-1.5 py-0.5 font-mono text-xs text-text">
            .env.local
          </code>{" "}
          to connect to Somnia Testnet.
        </p>
        <div className="mx-auto mb-6 max-w-sm rounded-lg bg-surface p-3 text-left font-mono text-xs text-muted">
          <div>NEXT_PUBLIC_VIGILIA_ESCROW_ADDRESS=0x...</div>
          <div>NEXT_PUBLIC_VIGILIA_VERIFIER_ADDRESS=0x...</div>
        </div>
        <Link
          href="/demo"
          className="inline-flex h-9 items-center gap-2 rounded-md bg-accent px-4 text-sm font-medium text-white transition-colors duration-100 hover:bg-accent-hover"
        >
          Watch the demo instead →
        </Link>
      </div>
    </div>
  );
}
