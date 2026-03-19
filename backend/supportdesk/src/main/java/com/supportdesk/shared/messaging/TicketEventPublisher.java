package com.supportdesk.shared.messaging;

import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

@Slf4j
@Component
@RequiredArgsConstructor
public class TicketEventPublisher {

    private final SqsClient sqsClient;
    private final ObjectMapper objectMapper;

    @Value("${sqs.queue.url}")
    private String queueUrl;

    public void publishTicketCreated(UUID ticketId, String priority) {
        try {
            String body = objectMapper.writeValueAsString(Map.of(
                "ticketId", ticketId.toString(),
                "priority", priority
            ));

            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .messageBody(body)
                    .build());

            log.info("Published ticket created event for ticketId={}", ticketId);
        } catch (Exception e) {
            // SQS failure should not roll back a successful ticket creation
            log.error("Failed to publish ticket created event for ticketId={}", ticketId, e);
        }
    }
}