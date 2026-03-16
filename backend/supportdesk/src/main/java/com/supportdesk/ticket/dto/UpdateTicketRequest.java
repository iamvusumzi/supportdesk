package com.supportdesk.ticket.dto;

import com.supportdesk.ticket.TicketPriority;
import com.supportdesk.ticket.TicketStatus;

import lombok.Data;

@Data
public class UpdateTicketRequest {
    private String title;
    private String description;
    private TicketStatus status;
    private TicketPriority priority;
}