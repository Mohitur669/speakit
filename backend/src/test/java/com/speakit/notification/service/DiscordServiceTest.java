package com.speakit.notification.service;

import com.speakit.notification.entity.LogBackupAudit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

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
        ReflectionTestUtils.setField(discordService, "contactWebhookUrl", "");
        ReflectionTestUtils.setField(discordService, "backendWebhookUrl", "");
        ReflectionTestUtils.setField(discordService, "infraWebhookUrl", "");
        assertDoesNotThrow(() -> discordService.init());
        assertNull(ReflectionTestUtils.getField(discordService, "restClient"));
    }

    @Test
    void init_whenWebhookUrlValid_initializesRestClient() {
        ReflectionTestUtils.setField(discordService, "contactWebhookUrl", "https://discord.com/api/webhooks/123/abc");
        assertDoesNotThrow(() -> discordService.init());
        assertNotNull(ReflectionTestUtils.getField(discordService, "restClient"));
    }

    @Test
    void init_whenBackendWebhookUrlValid_initializesRestClient() {
        ReflectionTestUtils.setField(discordService, "backendWebhookUrl", "https://discord.com/api/webhooks/backend/abc");
        assertDoesNotThrow(() -> discordService.init());
        assertNotNull(ReflectionTestUtils.getField(discordService, "restClient"));
    }

    @Test
    void sendNotification_whenWebhookUrlMissing_returnsSafelyWithoutCallingClient() {
        ReflectionTestUtils.setField(discordService, "contactWebhookUrl", null);
        assertDoesNotThrow(() -> discordService.sendNotification(
                "John Doe", "john@example.com", "billing", "My bill is incorrect", "req-123"
        ));
    }

    @Test
    void sendLogBackupNotification_whenBackendWebhookUrlMissing_returnsSafelyWithoutError() {
        ReflectionTestUtils.setField(discordService, "infraWebhookUrl", null);
        LogBackupAudit audit = LogBackupAudit.builder().id(100L).status("Completed").build();
        assertDoesNotThrow(() -> discordService.sendLogBackupNotification(audit));
    }

    @Test
    void buildLogBackupEmbedPayload_forCompletedScheduledUpload_buildsCorrectEmbed() {
        LogBackupAudit audit = LogBackupAudit.builder()
                .id(101L)
                .actionType("Upload")
                .triggerType("Scheduled")
                .triggeredBy("system")
                .status("Completed")
                .bucketName("speakit-logs")
                .objectKey("speakit-backend/2026/active.log.gz")
                .etag("abc123etag")
                .originalSizeBytes(102400L)
                .compressedSizeBytes(2048L)
                .compressionRatio("98.00%")
                .archivedChunksCount(3)
                .executionDurationMs(150L)
                .createdAt(LocalDateTime.now())
                .build();

        ReflectionTestUtils.setField(discordService, "logEnvironment", "coolify");
        Map<String, Object> embed = ReflectionTestUtils.invokeMethod(discordService, "buildLogBackupEmbedPayload", audit);

        assertNotNull(embed);
        assertEquals("🗄️ Cloudflare R2 Log Backup — Completed", embed.get("title"));
        assertEquals(0x10B981, embed.get("color"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> fields = (List<Map<String, Object>>) embed.get("fields");
        assertNotNull(fields);
        assertTrue(fields.stream().anyMatch(f -> "📌 Action".equals(f.get("name")) && "Upload".equals(f.get("value"))));
        assertTrue(fields.stream().anyMatch(f -> "⚡ Trigger".equals(f.get("name")) && "Scheduled".equals(f.get("value"))));
        assertTrue(fields.stream().anyMatch(f -> "🆔 Audit ID".equals(f.get("name")) && "#101".equals(f.get("value"))));
    }

    @Test
    void buildLogBackupEmbedPayload_forCompletedManualDownload_buildsCorrectEmbed() {
        LogBackupAudit audit = LogBackupAudit.builder()
                .id(102L)
                .actionType("Download")
                .triggerType("Manual")
                .triggeredBy("mohitur")
                .status("Completed")
                .bucketName("speakit-logs")
                .objectKey("speakit-logs-range.zip")
                .originalSizeBytes(5242880L)
                .archivedChunksCount(7)
                .executionDurationMs(400L)
                .createdAt(LocalDateTime.now())
                .build();

        ReflectionTestUtils.setField(discordService, "logEnvironment", "coolify");
        Map<String, Object> embed = ReflectionTestUtils.invokeMethod(discordService, "buildLogBackupEmbedPayload", audit);

        assertNotNull(embed);
        assertEquals("📥 Cloudflare R2 Log Download — Streamed", embed.get("title"));
        assertEquals(0x5865F2, embed.get("color"));
    }

    @Test
    void buildLogBackupEmbedPayload_forFailedUpload_buildsRedEmbed() {
        LogBackupAudit audit = LogBackupAudit.builder()
                .id(103L)
                .actionType("Upload")
                .triggerType("Manual")
                .triggeredBy("admin")
                .status("Failed")
                .errorMessage("R2 connection timeout")
                .executionDurationMs(5000L)
                .build();

        Map<String, Object> embed = ReflectionTestUtils.invokeMethod(discordService, "buildLogBackupEmbedPayload", audit);

        assertNotNull(embed);
        assertEquals("❌ Cloudflare R2 Log Upload — Failed", embed.get("title"));
        assertEquals(0xE02424, embed.get("color"));
    }

    @Test
    void buildLogBackupEmbedPayload_forSkippedUpload_buildsAmberEmbed() {
        LogBackupAudit audit = LogBackupAudit.builder()
                .id(104L)
                .actionType("Upload")
                .triggerType("Manual")
                .triggeredBy("admin")
                .status("Skipped")
                .errorMessage("No active log file found on disk.")
                .executionDurationMs(5L)
                .build();

        Map<String, Object> embed = ReflectionTestUtils.invokeMethod(discordService, "buildLogBackupEmbedPayload", audit);

        assertNotNull(embed);
        assertEquals("⚠️ Cloudflare R2 Log Backup — Skipped", embed.get("title"));
        assertEquals(0xF59E0B, embed.get("color"));
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
