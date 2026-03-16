import type { TicketStatus } from "../types/ticket";

const styles: Record<TicketStatus, string> = {
  OPEN: "bg-blue-100 text-blue-700",
  IN_PROGRESS: "bg-yellow-100 text-yellow-700",
  RESOLVED: "bg-green-100 text-green-700",
  CLOSED: "bg-gray-100 text-gray-600",
};

export function StatusBadge({ status }: { status: TicketStatus }) {
  return (
    <span
      className={`text-xs font-medium px-2 py-1 rounded-full ${styles[status]}`}
    >
      {status.replace("_", " ")}
    </span>
  );
}
