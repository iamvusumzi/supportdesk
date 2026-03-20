package com.supportdesk.attachment.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class InitiateUploadResponse {
    private String uploadUrl;
    private String fileKey;
}