package com.supportdesk.attachment;

import com.supportdesk.attachment.dto.AttachmentResponse;
import com.supportdesk.attachment.dto.ConfirmUploadRequest;
import com.supportdesk.attachment.dto.InitiateUploadRequest;
import com.supportdesk.attachment.dto.InitiateUploadResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/tickets/{ticketId}/attachments")
@RequiredArgsConstructor
public class AttachmentController {

    private final AttachmentService attachmentService;

    @PostMapping("/initiate")
    public ResponseEntity<InitiateUploadResponse> initiateUpload(
            @PathVariable UUID ticketId,
            @Valid @RequestBody InitiateUploadRequest request) {
        return ResponseEntity.ok(attachmentService.initiateUpload(ticketId, request));
    }

    @PostMapping("/confirm")
    public ResponseEntity<AttachmentResponse> confirmUpload(
            @PathVariable UUID ticketId,
            @Valid @RequestBody ConfirmUploadRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(attachmentService.confirmUpload(ticketId, request));
    }

    @GetMapping
    public ResponseEntity<List<AttachmentResponse>> getAttachments(@PathVariable UUID ticketId) {
        return ResponseEntity.ok(attachmentService.getAttachments(ticketId));
    }

    @GetMapping("/{attachmentId}/download")
    public ResponseEntity<String> getDownloadUrl(
            @PathVariable UUID ticketId,
            @PathVariable UUID attachmentId) {
        return ResponseEntity.ok(attachmentService.getDownloadUrl(ticketId, attachmentId));
    }

    @DeleteMapping("/{attachmentId}")
    public ResponseEntity<Void> deleteAttachment(
            @PathVariable UUID ticketId,
            @PathVariable UUID attachmentId) {
        attachmentService.deleteAttachment(ticketId, attachmentId);
        return ResponseEntity.noContent().build();
    }
}