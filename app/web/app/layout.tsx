import type { Metadata } from "next";
import { Providers } from "@/components/providers";
import { Nav } from "@/components/nav";
import "./globals.css";

export const metadata: Metadata = {
  title: "Vigilia Protocol",
  description: "Agent-verified work settlement on Somnia",
  icons: {
    icon: [
      { url: "/brand/vigilia-favicon.svg", type: "image/svg+xml" },
    ],
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-screen bg-bg text-text antialiased">
        <Providers>
          <Nav />
          <main>{children}</main>
        </Providers>
      </body>
    </html>
  );
}
