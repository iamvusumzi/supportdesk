package com.supportdesk.ticket.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

import com.supportdesk.ticket.TeamName;
import com.supportdesk.ticket.Ticket;
import com.supportdesk.ticket.TicketPriority;
import com.supportdesk.ticket.TicketStatus;

import lombok.Data;

@Data
public class TicketResponse {

    private UUID id;
    private String title;
    private String description;
    private TicketStatus status;
    private TicketPriority priority;
    private String customerEmail;
    private TeamName assignedTeam;
    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;

    public static TicketResponse from(Ticket ticket) {
        TicketResponse response = new TicketResponse();
        response.setId(ticket.getId());
        response.setTitle(ticket.getTitle());
        response.setDescription(ticket.getDescription());
        response.setStatus(ticket.getStatus());
        response.setPriority(ticket.getPriority());
        response.setCustomerEmail(ticket.getCustomerEmail());
        response.setAssignedTeam(ticket.getAssignedTeam());
        response.setCreatedAt(ticket.getCreatedAt());
        response.setUpdatedAt(ticket.getUpdatedAt());
        return response;
    }
}