import axios from "axios";
import type {
  Ticket,
  CreateTicketRequest,
  UpdateTicketRequest,
} from "../types/ticket";

const client = axios.create({
  baseURL: import.meta.env.VITE_API_URL
    ? `${import.meta.env.VITE_API_URL}/api/v1`
    : "/api/v1",
});

export const ticketsApi = {
  getAll: (status?: string) =>
    client
      .get<Ticket[]>("/tickets", {
        params: status ? { status } : undefined,
      })
      .then((r) => r.data),

  getById: (id: string) =>
    client.get<Ticket>(`/tickets/${id}`).then((r) => r.data),

  create: (data: CreateTicketRequest) =>
    client.post<Ticket>("/tickets", data).then((r) => r.data),

  update: (id: string, data: UpdateTicketRequest) =>
    client.patch<Ticket>(`/tickets/${id}`, data).then((r) => r.data),

  delete: (id: string) => client.delete(`/tickets/${id}`).then((r) => r.data),
};
