// import { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ticketsApi } from "../api/tickets";
import { StatusBadge } from "../components/StatusBadge";
import { PriorityBadge } from "../components/PriorityBadge";
import type { TicketStatus, TicketPriority } from "../types/ticket";

export function TicketDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  //   const [isEditing, setIsEditing] = useState(false);

  const { data: ticket, isLoading } = useQuery({
    queryKey: ["ticket", id],
    queryFn: () => ticketsApi.getById(id!),
    enabled: !!id,
  });

  const updateMutation = useMutation({
    mutationFn: (data: { status?: TicketStatus; priority?: TicketPriority }) =>
      ticketsApi.update(id!, data),
    onSuccess: (updated) => {
      queryClient.setQueryData(["ticket", id], updated);
      queryClient.invalidateQueries({ queryKey: ["tickets"] });
    },
  });

  if (isLoading) return <p className="text-gray-500">Loading...</p>;
  if (!ticket) return <p className="text-red-500">Ticket not found.</p>;

  return (
    <div className="max-w-2xl">
      <button
        onClick={() => navigate("/tickets")}
        className="text-sm text-gray-500 hover:text-gray-700 mb-4"
      >
        ← Back to tickets
      </button>

      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-start justify-between mb-4">
          <h1 className="text-lg font-semibold text-gray-900">
            {ticket.title}
          </h1>
          <div className="flex gap-2">
            <StatusBadge status={ticket.status} />
            <PriorityBadge priority={ticket.priority} />
          </div>
        </div>

        <p className="text-gray-600 mb-6">{ticket.description}</p>

        <div className="text-sm text-gray-500 space-y-1 mb-6">
          <p>
            Customer:{" "}
            <span className="text-gray-700">{ticket.customerEmail}</span>
          </p>
          <p>
            Created:{" "}
            <span className="text-gray-700">
              {new Date(ticket.createdAt).toLocaleString()}
            </span>
          </p>
          <p>
            Updated:{" "}
            <span className="text-gray-700">
              {new Date(ticket.updatedAt).toLocaleString()}
            </span>
          </p>
        </div>

        {/* Quick status update */}
        <div className="border-t border-gray-100 pt-4">
          <p className="text-sm font-medium text-gray-700 mb-2">
            Update status
          </p>
          <div className="flex gap-2 flex-wrap">
            {(
              ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"] as TicketStatus[]
            ).map((s) => (
              <button
                key={s}
                disabled={ticket.status === s || updateMutation.isPending}
                onClick={() => updateMutation.mutate({ status: s })}
                className={`text-xs px-3 py-1 rounded-full border ${
                  ticket.status === s
                    ? "bg-gray-100 text-gray-400 border-gray-200 cursor-default"
                    : "border-gray-300 text-gray-600 hover:border-blue-400 hover:text-blue-600"
                }`}
              >
                {s.replace("_", " ")}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
