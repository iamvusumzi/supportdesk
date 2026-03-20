package com.supportdesk.attachment;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.supportdesk.attachment.dto.AttachmentResponse;
import com.supportdesk.attachment.dto.ConfirmUploadRequest;
import com.supportdesk.attachment.dto.InitiateUploadRequest;
import com.supportdesk.attachment.dto.InitiateUploadResponse;
import com.supportdesk.shared.exception.ResourceNotFoundException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;

@Slf4j
@Service
@RequiredArgsConstructor
public class AttachmentService {

    private final AttachmentRepository attachmentRepository;
    private final S3Client s3Client;
    private final S3Presigner s3Presigner;

    @Value("${attachments.bucket.name}")
    private String bucketName;

    private static final long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
    private static final Duration PRESIGN_DURATION = Duration.ofMinutes(15);

    public InitiateUploadResponse initiateUpload(UUID ticketId, InitiateUploadRequest request) {
        if (request.getFileSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("File size exceeds 10MB limit");
        }

        // S3 key: attachments/<ticketId>/<uuid>/<filename>
        // Including ticketId and a UUID prevents collisions and keeps files organised
        String fileKey = String.format("attachments/%s/%s/%s",
                ticketId, UUID.randomUUID(), request.getFileName());

        PresignedPutObjectRequest presigned = s3Presigner.presignPutObject(r -> r
                .signatureDuration(PRESIGN_DURATION)
                .putObjectRequest(PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(fileKey)
                        .contentType(request.getMimeType())
                        .contentLength(request.getFileSize())
                        .build()));

        log.info("Generated upload URL for ticketId={} fileName={}", ticketId, request.getFileName());

        return new InitiateUploadResponse(
                presigned.url().toString(),
                fileKey
        );
    }

    public AttachmentResponse confirmUpload(UUID ticketId, ConfirmUploadRequest request) {
        Attachment attachment = new Attachment();
        attachment.setTicketId(ticketId);
        attachment.setFileName(request.getFileName());
        attachment.setFileKey(request.getFileKey());
        attachment.setFileSize(request.getFileSize());
        attachment.setMimeType(request.getMimeType());

        return AttachmentResponse.from(attachmentRepository.save(attachment));
    }

    public List<AttachmentResponse> getAttachments(UUID ticketId) {
        return attachmentRepository.findByTicketIdOrderByUploadedAtDesc(ticketId)
                .stream()
                .map(AttachmentResponse::from)
                .toList();
    }

    public String getDownloadUrl(UUID ticketId, UUID attachmentId) {
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .filter(a -> a.getTicketId().equals(ticketId))
                .orElseThrow(() -> new ResourceNotFoundException("Attachment not found: " + attachmentId));

        PresignedGetObjectRequest presigned = s3Presigner.presignGetObject(r -> r
                .signatureDuration(PRESIGN_DURATION)
                .getObjectRequest(GetObjectRequest.builder()
                        .bucket(bucketName)
                        .key(attachment.getFileKey())
                        .build()));

        return presigned.url().toString();
    }

    public void deleteAttachment(UUID ticketId, UUID attachmentId) {
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .filter(a -> a.getTicketId().equals(ticketId))
                .orElseThrow(() -> new ResourceNotFoundException("Attachment not found: " + attachmentId));

        s3Client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucketName)
                .key(attachment.getFileKey())
                .build());

        attachmentRepository.delete(attachment);
        log.info("Deleted attachment id={} from S3 and DB", attachmentId);
    }
}