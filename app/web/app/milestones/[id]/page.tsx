import { MilestoneDetail } from "./milestone-detail";

export default function MilestoneDetailPage({
  params,
}: {
  params: { id: string };
}) {
  return <MilestoneDetail taskId={BigInt(params.id)} />;
}
