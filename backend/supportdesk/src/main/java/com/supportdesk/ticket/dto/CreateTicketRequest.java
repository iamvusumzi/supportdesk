package com.supportdesk.ticket.dto;

import com.supportdesk.ticket.TicketPriority;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreateTicketRequest {

    @NotBlank(message = "Title is required")
    private String title;

    @NotBlank(message = "Description is required")
    private String description;

    @NotNull(message = "Priority is required")
    private TicketPriority priority;

    @Email(message = "Must be a valid email")
    @NotBlank(message = "Customer email is required")
    private String customerEmail;
}