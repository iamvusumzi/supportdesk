package com.supportdesk.shared.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsClient;

@Configuration
public class SqsConfig {

    @Bean
    public SqsClient sqsClient() {
        // Uses the Lambda execution role credentials automatically
        return SqsClient.builder()
                .region(Region.EU_WEST_1)
                .build();
    }
}