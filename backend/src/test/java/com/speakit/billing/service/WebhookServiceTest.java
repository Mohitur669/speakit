package com.speakit.billing.service;

import com.speakit.billing.entity.WebhookEvent;
import com.speakit.billing.repository.WebhookEventRepository;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WebhookServiceTest {

    @Mock
    private WebhookEventRepository webhookEventRepository;

    @InjectMocks
    private WebhookService webhookService;

    @Test
    void processWebhook_unconfiguredSecret_throwsException() {
        // Set webhookSecret to blank to trigger validation failure
        ReflectionTestUtils.setField(webhookService, "webhookSecret", "");

        String payload = new JSONObject().put("id", "evt_123").put("event", "subscription.charged").toString();

        when(webhookEventRepository.findByEventId(any())).thenReturn(Optional.empty());

        assertThrows(IllegalStateException.class, () ->
            webhookService.processWebhook(payload, "sig_123")
        );

        verify(webhookEventRepository, times(2)).save(any(WebhookEvent.class));
    }
}
