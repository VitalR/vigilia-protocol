import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        bg: "#0F0F11",
        surface: "#1A1A1F",
        "surface-2": "#222228",
        border: "#2E2E38",
        "border-2": "#3E3E4A",
        muted: "#8B8B9E",
        subtle: "#5A5A6E",
        text: "#F2F2F2",
        accent: {
          DEFAULT: "#5E6AD2",
          hover: "#6B77D9",
          subtle: "#1E2048",
        },
        green: {
          DEFAULT: "#4ADE80",
          dim: "#14532d",
          glow: "rgba(74, 222, 128, 0.12)",
        },
        yellow: {
          DEFAULT: "#F59E0B",
          dim: "#451a03",
          glow: "rgba(245, 158, 11, 0.12)",
        },
        red: {
          DEFAULT: "#F87171",
          dim: "#450a0a",
          glow: "rgba(248, 113, 113, 0.12)",
        },
        blue: {
          DEFAULT: "#3b82f6",
          dim: "#1e3a5f",
          glow: "rgba(59, 130, 246, 0.12)",
        },
        purple: {
          DEFAULT: "#8b5cf6",
          dim: "#2e1065",
          glow: "rgba(139, 92, 246, 0.12)",
        },
      },
      borderRadius: {
        none: "0",
        sm: "3px",
        DEFAULT: "4px",
        md: "6px",
        lg: "6px",
        xl: "6px",
        "2xl": "8px",
        "3xl": "8px",
        full: "9999px",
      },
      fontFamily: {
        sans: ["Inter", "-apple-system", "BlinkMacSystemFont", "sans-serif"],
        mono: ["'JetBrains Mono'", "ui-monospace", "monospace"],
      },
      letterSpacing: {
        tight: "-0.01em",
      },
      animation: {
        "pulse-slow": "pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        spin: "spin 1s linear infinite",
        "fade-in": "fadeIn 0.3s ease-out",
      },
      keyframes: {
        fadeIn: {
          from: { opacity: "0", transform: "translateY(4px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
