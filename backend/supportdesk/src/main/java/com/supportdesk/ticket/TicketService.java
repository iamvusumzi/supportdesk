package com.supportdesk.ticket;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.supportdesk.shared.exception.ResourceNotFoundException;
import com.supportdesk.ticket.dto.CreateTicketRequest;
import com.supportdesk.ticket.dto.TicketResponse;
import com.supportdesk.ticket.dto.UpdateTicketRequest;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TicketService {

    private final TicketRepository ticketRepository;

    public TicketResponse createTicket(CreateTicketRequest request) {
        Ticket ticket = new Ticket();
        ticket.setTitle(request.getTitle());
        ticket.setDescription(request.getDescription());
        ticket.setPriority(request.getPriority());
        ticket.setCustomerEmail(request.getCustomerEmail());

        return TicketResponse.from(ticketRepository.save(ticket));
    }

    public List<TicketResponse> getAllTickets(TicketStatus status) {
        List<Ticket> tickets = (status != null)
                ? ticketRepository.findByStatus(status)
                : ticketRepository.findAll();

        return tickets.stream()
                .map(TicketResponse::from)
                .toList();
    }

    public TicketResponse getTicket(UUID id) {
        return ticketRepository.findById(id)
                .map(TicketResponse::from)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket not found: " + id));
    }

    @Transactional
    public TicketResponse updateTicket(UUID id, UpdateTicketRequest request) {
        Ticket ticket = ticketRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket not found: " + id));

        if (request.getTitle() != null)       ticket.setTitle(request.getTitle());
        if (request.getDescription() != null) ticket.setDescription(request.getDescription());
        if (request.getStatus() != null)      ticket.setStatus(request.getStatus());
        if (request.getPriority() != null)    ticket.setPriority(request.getPriority());

        return TicketResponse.from(ticketRepository.save(ticket));
    }

    public void deleteTicket(UUID id) {
        if (!ticketRepository.existsById(id)) {
            throw new ResourceNotFoundException("Ticket not found: " + id);
        }
        ticketRepository.deleteById(id);
    }
}