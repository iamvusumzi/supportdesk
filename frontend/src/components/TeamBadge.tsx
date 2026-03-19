import type { TeamName } from "../types/ticket";

const styles: Record<TeamName, string> = {
  GENERAL_SUPPORT: "bg-purple-100 text-purple-700",
  ESCALATIONS: "bg-red-100 text-red-700",
};

const labels: Record<TeamName, string> = {
  GENERAL_SUPPORT: "General Support",
  ESCALATIONS: "Escalations",
};

export function TeamBadge({ team }: { team: TeamName | null }) {
  if (!team)
    return <span className="text-xs text-gray-400 italic">Routing...</span>;
  return (
    <span
      className={`text-xs font-medium px-2 py-1 rounded-full ${styles[team]}`}
    >
      {labels[team]}
    </span>
  );
}
