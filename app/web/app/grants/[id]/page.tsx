import { GrantDetail } from "./grant-detail";

export default async function GrantDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const roundId = BigInt(id);
  return <GrantDetail roundId={roundId} />;
}
