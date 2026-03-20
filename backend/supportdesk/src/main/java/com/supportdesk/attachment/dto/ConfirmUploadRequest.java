package com.supportdesk.attachment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import lombok.Data;

@Data
public class ConfirmUploadRequest {

    @NotBlank
    private String fileName;

    @NotBlank
    private String mimeType;

    @Positive
    private Long fileSize;

    @NotBlank
    private String fileKey;   // returned from initiate, sent back here
}