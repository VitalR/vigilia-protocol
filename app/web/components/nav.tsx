"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { BookOpen, ExternalLink, Github, Shield } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAccount } from "wagmi";
import { cn } from "@/lib/utils";
import { useRole, type RoleOverride } from "@/lib/role-context";


const links = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/milestones", label: "Milestones" },
  { href: "/grants", label: "Grants" },
  { href: "/trail", label: "Trail", beta: true },
];

type NavLink = { href: string; label: string; beta?: boolean };

const RESOURCE_LINKS = [
  { href: "https://github.com/VitalR/vigilia-protocol", label: "GitHub", Icon: Github },
  { href: "https://github.com/VitalR/vigilia-protocol/tree/main/docs", label: "Docs", Icon: BookOpen },
  { href: "https://github.com/VitalR/vigilia-protocol/tree/main/docs/proofs", label: "Proofs", Icon: Shield },
] as const;

const ROLE_OPTIONS: { value: RoleOverride; label: string }[] = [
  { value: "client",     label: "Client" },
  { value: "contractor", label: "Contractor" },
  { value: "resolver",   label: "Resolver" },
  { value: "public",     label: "Public" },
];

function RoleSwitcher() {
  const { role, setRole } = useRole();
  const { isConnected } = useAccount();
  const pathname = usePathname();

  if (!isConnected || !pathname?.startsWith("/milestones")) return null;

  return (
    <div className="flex items-center gap-0.5 rounded-md border border-border bg-surface p-0.5">
      <span className="px-2 text-[10px] font-semibold uppercase tracking-wider text-subtle">Role</span>
      {ROLE_OPTIONS.map((opt) => (
        <button
          key={opt.value}
          onClick={() => setRole(role === opt.value ? "real" : opt.value)}
          className={cn(
            "rounded px-2 py-1 text-xs transition-colors duration-100",
            role === opt.value
              ? "bg-accent/15 text-accent font-semibold"
              : "text-muted hover:text-text"
          )}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

const SHOW_RESOURCES_ON = ["/", "/dashboard"];

export function Nav() {
  const pathname = usePathname();
  const showResources = SHOW_RESOURCES_ON.some((p) => pathname === p);

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-bg">
      <div className="mx-auto flex h-12 max-w-6xl items-center justify-between px-4">
        <div className="flex items-center gap-6">
          <Link href="/" className="group flex items-center gap-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/brand/vigilia-header-icon.svg"
              alt="Vigilia"
              width={26}
              height={26}
              className="transition-opacity duration-150 group-hover:opacity-80"
              style={{ display: "block" }}
            />
            <span className="text-sm font-semibold tracking-tight text-text">Vigilia</span>
          </Link>

          <nav className="flex items-center gap-0.5">
            {(links as NavLink[]).map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className={cn(
                  "flex items-center gap-1 rounded px-3 py-1.5 text-sm transition-colors duration-100",
                  pathname === link.href || pathname?.startsWith(link.href + "/")
                    ? "bg-surface-2 text-text"
                    : "text-muted hover:text-text hover:bg-surface"
                )}
              >
                {link.label}
                {link.beta && (
                  <span className="rounded bg-surface-2 px-1 py-px font-mono text-[9px] font-semibold uppercase tracking-wider text-subtle">
                    beta
                  </span>
                )}
              </Link>
            ))}
          </nav>
        </div>

        <div className="flex items-center gap-3">
          {showResources && (
            <>
              <div className="flex items-center gap-0.5">
                {RESOURCE_LINKS.map(({ href, label, Icon }) => (
                  <a
                    key={href}
                    href={href}
                    target="_blank"
                    rel="noopener noreferrer"
                    title={label}
                    className="flex items-center gap-1.5 rounded px-2 py-1.5 text-muted transition-colors hover:text-text hover:bg-surface"
                  >
                    <Icon size={14} />
                    <span className="hidden text-xs lg:inline">{label}</span>
                    <ExternalLink size={9} className="hidden text-subtle lg:inline" />
                  </a>
                ))}
              </div>
              <div className="h-4 w-px bg-border" />
            </>
          )}
          <RoleSwitcher />
          <ConnectButton
            chainStatus="icon"
            showBalance={{ smallScreen: false, largeScreen: true }}
            accountStatus={{ smallScreen: "avatar", largeScreen: "full" }}
          />
        </div>
      </div>
    </header>
  );
}
