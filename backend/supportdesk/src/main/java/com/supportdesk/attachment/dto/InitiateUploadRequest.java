package com.supportdesk.attachment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import lombok.Data;

@Data
public class InitiateUploadRequest {

    @NotBlank
    private String fileName;

    @NotBlank
    private String mimeType;

    @Positive
    private Long fileSize;
}