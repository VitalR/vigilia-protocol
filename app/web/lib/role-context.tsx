"use client";

import { createContext, useContext, useState, ReactNode } from "react";

export type RoleOverride = "real" | "client" | "contractor" | "resolver" | "public";

type RoleContextValue = {
  role: RoleOverride;
  setRole: (r: RoleOverride) => void;
};

const RoleContext = createContext<RoleContextValue>({
  role: "real",
  setRole: () => {},
});

export function RoleProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<RoleOverride>("real");
  return (
    <RoleContext.Provider value={{ role, setRole }}>
      {children}
    </RoleContext.Provider>
  );
}

export function useRole() {
  return useContext(RoleContext);
}

// Resolves effective booleans given a role override
export function resolveRoles(
  role: RoleOverride,
  address: string | undefined,
  client: string,
  contractor: string,
  resolver: string,
) {
  if (role === "real") {
    const addr = address?.toLowerCase();
    return {
      isClient:     addr === client.toLowerCase(),
      isContractor: addr === contractor.toLowerCase(),
      isResolver:   addr === resolver.toLowerCase(),
    };
  }
  return {
    isClient:     role === "client",
    isContractor: role === "contractor",
    isResolver:   role === "resolver",
  };
}
