"use client";

import { ArrowRight, ChevronLeft, ChevronRight, Plus } from "lucide-react";
import Link from "next/link";
import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { StatusPill } from "@/components/status-pill";
import { useMilestones } from "@/lib/hooks";
import { useRole } from "@/lib/role-context";
import { formatSTT, truncateAddress, parseRequirementsMeta } from "@/lib/utils";

export default function MilestonesPage() {
  const [page, setPage] = useState(0);
  const { tasks, totalTasks, totalPages, isLoading } = useMilestones(page);
  const { address } = useAccount();
  const { role } = useRole();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  // Filter tasks by role
  const filteredTasks = tasks?.filter(({ task }) => {
    if (!mounted || !address || role === "real" || role === "public") return true;
    const addr = address.toLowerCase();
    if (role === "client")     return task.client.toLowerCase()     === addr;
    if (role === "contractor") return task.contractor.toLowerCase() === addr;
    if (role === "resolver")   return task.resolver.toLowerCase()   === addr;
    return true;
  });

  const isEmpty = !isLoading && (!filteredTasks || filteredTasks.length === 0);

  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text">Milestones</h1>
          {!isLoading && (
            <p className="mt-1 text-sm text-muted">
              {role !== "real" && role !== "public"
                ? `${filteredTasks?.length ?? 0} as ${role}`
                : `${totalTasks} ${totalTasks === 1 ? "milestone" : "milestones"} on-chain`}
            </p>
          )}
        </div>
        <Link
          href="/milestones/create"
          className="flex h-9 items-center gap-2 rounded-md bg-accent px-4 text-sm font-medium text-white transition-colors duration-100 hover:bg-accent-hover"
        >
          <Plus size={15} />
          New Milestone
        </Link>
      </div>

      {isLoading && (
        <div className="flex flex-col gap-2">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="h-16 animate-pulse rounded-lg border border-border bg-surface" />
          ))}
        </div>
      )}

      {isEmpty && (
        <div className="flex flex-col items-center justify-center rounded-xl border border-dashed border-border py-24 text-center">
          <div className="mb-4 text-4xl">🔬</div>
          {role !== "real" && role !== "public" && totalTasks > 0 ? (
            <>
              <p className="mb-1 font-semibold text-text">No milestones as {role}</p>
              <p className="text-sm text-muted">No milestones found where your wallet is {role}</p>
            </>
          ) : (
            <>
              <p className="mb-1 font-semibold text-text">No milestones yet</p>
              <p className="mb-6 text-sm text-muted">
                Create the first agent-verified milestone on Somnia
              </p>
              <Link
                href="/milestones/create"
                className="flex h-9 items-center gap-2 rounded-lg bg-green px-4 text-sm font-semibold text-bg"
              >
                <Plus size={15} /> Create Milestone
              </Link>
            </>
          )}
        </div>
      )}

      {!isLoading && filteredTasks && filteredTasks.length > 0 && (
        <>
          <div className="overflow-hidden rounded-xl border border-border bg-surface">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border">
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted">ID</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted">Milestone / Status</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted md:table-cell">Amount</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted lg:table-cell">Client</th>
                  <th className="hidden px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted lg:table-cell">Contractor</th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {filteredTasks.map(({ id, task }) => {
                  const meta = parseRequirementsMeta(task.requirementsURI);
                  return (
                    <tr key={id} className="border-b border-border/50 transition-colors hover:bg-surface-2">
                      <td className="px-4 py-4">
                        <span className="font-mono text-sm font-semibold text-text">#{id}</span>
                      </td>
                      <td className="px-4 py-4">
                        <div className="flex flex-col gap-1">
                          {meta?.title && (
                            <span className="text-sm text-text">{meta.title}</span>
                          )}
                          <div className="flex items-center gap-2">
                            <StatusPill state={task.state} />
                          </div>
                        </div>
                      </td>
                      <td className="hidden px-4 py-4 md:table-cell">
                        <span className="font-mono text-sm text-text">{formatSTT(task.amount)}</span>
                      </td>
                      <td className="hidden px-4 py-4 lg:table-cell">
                        <span className="font-mono text-xs text-muted">{truncateAddress(task.client)}</span>
                      </td>
                      <td className="hidden px-4 py-4 lg:table-cell">
                        <span className="font-mono text-xs text-muted">{truncateAddress(task.contractor)}</span>
                      </td>
                      <td className="px-4 py-4 text-right">
                        <Link
                          href={`/milestones/${id}`}
                          className="inline-flex items-center gap-1 rounded px-2 py-1 text-xs text-muted transition-colors hover:text-text"
                        >
                          View <ArrowRight size={11} />
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {totalPages > 1 && (role === "real" || role === "public") && (
            <div className="mt-4 flex items-center justify-between text-sm">
              <span className="text-muted">
                Page {page + 1} of {totalPages}
              </span>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setPage((p) => Math.max(0, p - 1))}
                  disabled={page === 0}
                  className="flex h-8 w-8 items-center justify-center rounded border border-border text-muted transition-colors hover:text-text disabled:opacity-30"
                >
                  <ChevronLeft size={14} />
                </button>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
                  disabled={page >= totalPages - 1}
                  className="flex h-8 w-8 items-center justify-center rounded border border-border text-muted transition-colors hover:text-text disabled:opacity-30"
                >
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
