import axios from "axios";
import type {
  Ticket,
  CreateTicketRequest,
  UpdateTicketRequest,
  AttachmentResponse,
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

export const attachmentsApi = {
  initiate: (
    ticketId: string,
    data: {
      fileName: string;
      mimeType: string;
      fileSize: number;
    },
  ) =>
    client
      .post<{
        uploadUrl: string;
        fileKey: string;
      }>(`/tickets/${ticketId}/attachments/initiate`, data)
      .then((r) => r.data),

  confirm: (
    ticketId: string,
    data: {
      fileName: string;
      mimeType: string;
      fileSize: number;
      fileKey: string;
    },
  ) =>
    client
      .post<AttachmentResponse>(
        `/tickets/${ticketId}/attachments/confirm`,
        data,
      )
      .then((r) => r.data),

  getAll: (ticketId: string) =>
    client
      .get<AttachmentResponse[]>(`/tickets/${ticketId}/attachments`)
      .then((r) => r.data),

  getDownloadUrl: (ticketId: string, attachmentId: string) =>
    client
      .get<string>(`/tickets/${ticketId}/attachments/${attachmentId}/download`)
      .then((r) => r.data),

  delete: (ticketId: string, attachmentId: string) =>
    client
      .delete(`/tickets/${ticketId}/attachments/${attachmentId}`)
      .then((r) => r.data),
};
