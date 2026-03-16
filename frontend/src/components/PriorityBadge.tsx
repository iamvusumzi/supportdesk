import type { TicketPriority } from "../types/ticket";

const styles: Record<TicketPriority, string> = {
  LOW: "bg-gray-100 text-gray-600",
  MEDIUM: "bg-blue-100 text-blue-700",
  HIGH: "bg-orange-100 text-orange-700",
  CRITICAL: "bg-red-100 text-red-700",
};

export function PriorityBadge({ priority }: { priority: TicketPriority }) {
  return (
    <span
      className={`text-xs font-medium px-2 py-1 rounded-full ${styles[priority]}`}
    >
      {priority}
    </span>
  );
}
