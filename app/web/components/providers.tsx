"use client";

import { RainbowKitProvider, darkTheme, getDefaultConfig } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactNode, useState } from "react";
import { WagmiProvider } from "wagmi";
import { somniaTestnet } from "@/lib/chains";
import { RoleProvider } from "@/lib/role-context";

// WalletConnect requires a registered 32-char projectId.
// Until one is configured, we pad the fallback to satisfy the length check.
// Get a free projectId at https://cloud.walletconnect.com
const projectId =
  process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ||
  "00000000000000000000000000000000";

const config = getDefaultConfig({
  appName: "Vigilia Protocol",
  projectId,
  chains: [somniaTestnet],
  ssr: true,
});

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RoleProvider>
          <RainbowKitProvider
            theme={darkTheme({
              accentColor: "#5E6AD2",
              accentColorForeground: "#ffffff",
              borderRadius: "small",
              fontStack: "system",
            })}
            locale="en-US"
          >
            {children}
          </RainbowKitProvider>
        </RoleProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
