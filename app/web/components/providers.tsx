"use client";

import { RainbowKitProvider, darkTheme, getDefaultConfig, type AvatarComponent } from "@rainbow-me/rainbowkit";
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

const VigiliaAvatar: AvatarComponent = ({ address, ensImage, size }) => {
  const label = address ? address.slice(2, 4).toUpperCase() : "VI";

  return (
    <div
      style={{
        alignItems: "center",
        background: "linear-gradient(135deg, #312e81, #5865f2)",
        borderRadius: "9999px",
        color: "#ffffff",
        display: "flex",
        fontSize: Math.max(10, Math.floor(size * 0.34)),
        fontWeight: 700,
        height: size,
        justifyContent: "center",
        overflow: "hidden",
        width: size,
      }}
    >
      {ensImage ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          alt={address}
          src={ensImage}
          style={{ display: "block", height: "100%", objectFit: "cover", width: "100%" }}
        />
      ) : (
        label
      )}
    </div>
  );
};

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RoleProvider>
          <RainbowKitProvider
            avatar={VigiliaAvatar}
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
