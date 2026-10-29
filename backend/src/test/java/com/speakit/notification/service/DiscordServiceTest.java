package com.speakit.notification.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class DiscordServiceTest {

    private DiscordService discordService;

    @BeforeEach
    void setUp() {
        discordService = new DiscordService();
    }

    @Test
    void init_whenWebhookUrlBlank_doesNotThrow() {
        ReflectionTestUtils.setField(discordService, "webhookUrl", "");
        assertDoesNotThrow(() -> discordService.init());
        assertNull(ReflectionTestUtils.getField(discordService, "restClient"));
    }

    @Test
    void init_whenWebhookUrlValid_initializesRestClient() {
        ReflectionTestUtils.setField(discordService, "webhookUrl", "https://discord.com/api/webhooks/123/abc");
        assertDoesNotThrow(() -> discordService.init());
        assertNotNull(ReflectionTestUtils.getField(discordService, "restClient"));
    }

    @Test
    void sendNotification_whenWebhookUrlMissing_returnsSafelyWithoutCallingClient() {
        ReflectionTestUtils.setField(discordService, "webhookUrl", null);
        assertDoesNotThrow(() -> discordService.sendNotification(
                "John Doe", "john@example.com", "billing", "My bill is incorrect", "req-123"
        ));
    }

    @Test
    void resolveColor_matchesTopicsCorrectly() {
        int billingColor = ReflectionTestUtils.invokeMethod(discordService, "resolveColor", "billing");
        assertEquals(0xE02424, billingColor);

        int supportColor = ReflectionTestUtils.invokeMethod(discordService, "resolveColor", "technical support");
        assertEquals(0x3B82F6, supportColor);

        int enterpriseColor = ReflectionTestUtils.invokeMethod(discordService, "resolveColor", "enterprise");
        assertEquals(0x10B981, enterpriseColor);

        int feedbackColor = ReflectionTestUtils.invokeMethod(discordService, "resolveColor", "feedback");
        assertEquals(0xF59E0B, feedbackColor);

        int defaultColor = ReflectionTestUtils.invokeMethod(discordService, "resolveColor", "unknown");
        assertEquals(0x5865F2, defaultColor);
    }

    @Test
    void truncate_guardsMaxLengthsProperly() {
        String shortText = ReflectionTestUtils.invokeMethod(discordService, "truncate", "Hello", 10);
        assertEquals("Hello", shortText);

        String longText = "a".repeat(50);
        String truncated = ReflectionTestUtils.invokeMethod(discordService, "truncate", longText, 10);
        assertEquals(10, truncated.length());
        assertTrue(truncated.endsWith("..."));
    }
}
