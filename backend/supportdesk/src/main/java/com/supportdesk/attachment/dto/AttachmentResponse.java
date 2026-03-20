package com.supportdesk.attachment.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

import com.supportdesk.attachment.Attachment;

import lombok.Data;

@Data
public class AttachmentResponse {
    private UUID id;
    private String fileName;
    private Long fileSize;
    private String mimeType;
    private OffsetDateTime uploadedAt;

    public static AttachmentResponse from(Attachment a) {
        AttachmentResponse r = new AttachmentResponse();
        r.setId(a.getId());
        r.setFileName(a.getFileName());
        r.setFileSize(a.getFileSize());
        r.setMimeType(a.getMimeType());
        r.setUploadedAt(a.getUploadedAt());
        return r;
    }
}