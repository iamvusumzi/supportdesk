import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { ticketsApi } from "../api/tickets";
import { StatusBadge } from "../components/StatusBadge";
import { PriorityBadge } from "../components/PriorityBadge";
import { CreateTicketModal } from "../components/CreateTicketModal";
import type { TicketStatus } from "../types/ticket";
import { TeamBadge } from "../components/TeamBadge";

const STATUS_FILTERS: Array<{
  label: string;
  value: TicketStatus | undefined;
}> = [
  { label: "All", value: undefined },
  { label: "Open", value: "OPEN" },
  { label: "In Progress", value: "IN_PROGRESS" },
  { label: "Resolved", value: "RESOLVED" },
  { label: "Closed", value: "CLOSED" },
];

export function TicketListPage() {
  const [statusFilter, setStatusFilter] = useState<TicketStatus | undefined>();
  const [showCreate, setShowCreate] = useState(false);
  const queryClient = useQueryClient();

  const {
    data: tickets,
    isLoading,
    isError,
  } = useQuery({
    queryKey: ["tickets", statusFilter],
    queryFn: () => ticketsApi.getAll(statusFilter),
  });

  const deleteMutation = useMutation({
    mutationFn: ticketsApi.delete,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["tickets"] }),
  });

  if (isLoading) return <p className="text-gray-500">Loading tickets...</p>;
  if (isError) return <p className="text-red-500">Failed to load tickets.</p>;

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-xl font-semibold text-gray-900">Tickets</h1>
        <button
          onClick={() => setShowCreate(true)}
          className="bg-blue-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          New Ticket
        </button>
      </div>

      {/* Status filter tabs */}
      <div className="flex gap-2 mb-4">
        {STATUS_FILTERS.map((f) => (
          <button
            key={f.label}
            onClick={() => setStatusFilter(f.value)}
            className={`text-sm px-3 py-1 rounded-full border ${
              statusFilter === f.value
                ? "bg-blue-600 text-white border-blue-600"
                : "text-gray-600 border-gray-300 hover:border-gray-400"
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Ticket table */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              {[
                "Title",
                "Status",
                "Priority",
                "Customer",
                "Team",
                "Created",
                "",
              ].map((h) => (
                <th
                  key={h}
                  className="text-left px-4 py-3 text-gray-500 font-medium"
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {tickets?.map((ticket) => (
              <tr key={ticket.id} className="hover:bg-gray-50">
                <td className="px-4 py-3">
                  <Link
                    to={`/tickets/${ticket.id}`}
                    className="text-blue-600 hover:underline font-medium"
                  >
                    {ticket.title}
                  </Link>
                </td>
                <td className="px-4 py-3">
                  <StatusBadge status={ticket.status} />
                </td>
                <td className="px-4 py-3">
                  <PriorityBadge priority={ticket.priority} />
                </td>
                <td className="px-4 py-3 text-gray-600">
                  {ticket.customerEmail}
                </td>
                <td className="px-4 py-3">
                  <TeamBadge team={ticket.assignedTeam} />
                </td>
                <td className="px-4 py-3 text-gray-400">
                  {new Date(ticket.createdAt).toLocaleDateString()}
                </td>
                <td className="px-4 py-3">
                  <button
                    onClick={() => deleteMutation.mutate(ticket.id)}
                    className="text-red-400 hover:text-red-600 text-xs"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {tickets?.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-gray-400">
                  No tickets found
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {showCreate && <CreateTicketModal onClose={() => setShowCreate(false)} />}
    </div>
  );
}
