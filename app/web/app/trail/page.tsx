"use client";

import { ExternalLink, RefreshCw } from "lucide-react";
import { StatusPill } from "@/components/status-pill";
import { TrailIcon } from "@/components/trail-icon";
import { VIGILIA_ESCROW_ADDRESS } from "@/lib/contracts";
import { useTrailEvents } from "@/lib/hooks";
import {
  explorerAddressUrl,
  explorerTxUrl,
  formatRelativeTime,
  formatSTT,
  truncateAddress,
} from "@/lib/utils";

export default function TrailPage() {
  const { events, isLoading, isLoadingMore, hasMore, loadMore, lastFetched, scanProgress } = useTrailEvents();

  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text">Execution Trail</h1>
          <p className="mt-1 text-sm text-muted">
            Real-time on-chain event feed · all milestones
          </p>
        </div>
        <div className="flex items-center gap-3">
          {lastFetched && (
            <span className="text-xs text-muted">
              Updated {formatRelativeTime(Math.floor(lastFetched.getTime() / 1000))}
            </span>
          )}
          <button
            onClick={() => window.location.reload()}
            disabled={isLoading}
            className="flex h-8 items-center gap-1.5 rounded-lg border border-border bg-surface px-3 text-xs text-muted transition-colors hover:text-text disabled:opacity-40"
          >
            <RefreshCw size={12} className={isLoading ? "animate-spin" : ""} />
            Refresh
          </button>
        </div>
      </div>

      {isLoading && events.length === 0 && (
        <div className="flex h-48 flex-col items-center justify-center gap-3 text-muted">
          <RefreshCw size={18} className="animate-spin text-accent" />
          <div className="text-center">
            <p className="text-sm font-medium text-text">Scanning on-chain events…</p>
            {scanProgress && (
              <p className="mt-1 font-mono text-xs text-subtle">{scanProgress}</p>
            )}
            <p className="mt-1 text-xs text-subtle">
              Somnia blocks arrive every ~400 ms — events may be millions of blocks back
            </p>
          </div>
        </div>
      )}

      {!isLoading && events.length === 0 && (
        <div className="flex h-64 flex-col items-center justify-center gap-2 text-muted">
          <p className="text-sm">No events found in the scanned range</p>
          <p className="text-xs text-subtle">
            Contract:{" "}
            {VIGILIA_ESCROW_ADDRESS === "0x0000000000000000000000000000000000000000"
              ? "not deployed yet"
              : truncateAddress(VIGILIA_ESCROW_ADDRESS)}
          </p>
          {hasMore && (
            <p className="mt-1 text-xs text-subtle">Use "Load older events" to scan further back</p>
          )}
        </div>
      )}

      {events.length > 0 && (
        <div className="overflow-hidden rounded-xl border border-border bg-surface">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border">
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted">Event</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted">Milestone</th>
                <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted md:table-cell">Details</th>
                <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted lg:table-cell">From</th>
                <th className="hidden px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-muted sm:table-cell">Amount</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-muted">Tx</th>
              </tr>
            </thead>
            <tbody>
              {events.map((ev) => (
                <tr key={ev.key} className="border-b border-border/40 transition-colors hover:bg-surface-2">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <TrailIcon name={ev.name} className={ev.colorClass} />
                      <span className="text-xs font-medium text-text">
                        {ev.name.replace(/([A-Z])/g, " $1").trim()}
                      </span>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    {ev.taskId != null ? (
                      <div className="flex items-center gap-2">
                        <a
                          href={`/milestones/${ev.taskId}`}
                          className="font-mono text-xs font-semibold text-text hover:text-accent transition-colors"
                        >
                          #{ev.taskId.toString()}
                        </a>
                        {ev.state != null && <StatusPill state={ev.state} size="sm" />}
                      </div>
                    ) : (
                      <span className="text-xs text-muted">—</span>
                    )}
                  </td>
                  <td className="hidden px-4 py-3 md:table-cell">
                    <span className="text-xs text-muted">{ev.details}</span>
                  </td>
                  <td className="hidden px-4 py-3 lg:table-cell">
                    {ev.address ? (
                      <a
                        href={explorerAddressUrl(ev.address)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="font-mono text-xs text-muted hover:text-text transition-colors"
                      >
                        {truncateAddress(ev.address)}
                      </a>
                    ) : (
                      <span className="text-xs text-subtle">—</span>
                    )}
                  </td>
                  <td className="hidden px-4 py-3 text-right sm:table-cell">
                    {ev.amount != null && ev.amount > 0n ? (
                      <span className="font-mono text-xs font-medium text-text">{formatSTT(ev.amount)}</span>
                    ) : (
                      <span className="text-xs text-subtle">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {ev.txHash ? (
                      <a
                        href={explorerTxUrl(ev.txHash)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 font-mono text-xs text-muted hover:text-accent transition-colors"
                      >
                        {ev.txHash.slice(0, 8)}…
                        <ExternalLink size={10} />
                      </a>
                    ) : (
                      <span className="text-xs text-subtle">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Load more */}
      {(hasMore || isLoadingMore) && !isLoading && (
        <div className="mt-4 flex flex-col items-center gap-1.5">
          <button
            onClick={loadMore}
            disabled={isLoadingMore}
            className="flex h-9 items-center gap-2 rounded-lg border border-border bg-surface px-5 text-xs text-muted transition-colors hover:text-text disabled:opacity-40"
          >
            <RefreshCw size={12} className={isLoadingMore ? "animate-spin" : ""} />
            {isLoadingMore ? "Scanning older blocks…" : "Load older events"}
          </button>
          {isLoadingMore && scanProgress && (
            <p className="font-mono text-[10px] text-subtle">{scanProgress}</p>
          )}
        </div>
      )}
    </div>
  );
}
