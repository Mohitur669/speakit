package com.speakit.contact.service;

import com.speakit.contact.dto.ContactRequest;
import com.speakit.contact.entity.ContactSubmission;
import com.speakit.contact.repository.ContactSubmissionRepository;
import com.speakit.notification.service.DiscordService;
import com.speakit.notification.service.TelegramService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ContactServiceTest {

    @Mock
    private ContactSubmissionRepository contactRepository;

    @Mock
    private TelegramService telegramService;

    @Mock
    private DiscordService discordService;

    private ContactService contactService;

    @BeforeEach
    void setUp() {
        contactService = new ContactService(contactRepository, telegramService, discordService);
    }

    @Test
    void handleSubmission_whenValid_dispatchesToBothTelegramAndDiscord() {
        ContactRequest request = new ContactRequest();
        request.setFirstName("Jane");
        request.setLastName("Doe");
        request.setEmail("jane.doe@example.com");
        request.setTopic("billing");
        request.setMessage("Question regarding my invoice and subscription.");

        contactService.handleSubmission(request, "192.168.1.1", "req-xyz-123");

        verify(contactRepository, times(1)).save(any(ContactSubmission.class));

        ArgumentCaptor<String> nameCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> emailCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> topicCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> messageCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> reqIdCaptor = ArgumentCaptor.forClass(String.class);

        // Verify Telegram dispatch
        verify(telegramService, times(1)).sendNotification(
                nameCaptor.capture(),
                emailCaptor.capture(),
                topicCaptor.capture(),
                messageCaptor.capture(),
                reqIdCaptor.capture()
        );
        assertEquals("Jane Doe", nameCaptor.getValue());
        assertEquals("jane.doe@example.com", emailCaptor.getValue());
        assertEquals("Billing", topicCaptor.getValue());
        assertEquals("req-xyz-123", reqIdCaptor.getValue());

        // Verify Discord dispatch
        verify(discordService, times(1)).sendNotification(
                eq("Jane Doe"),
                eq("jane.doe@example.com"),
                eq("Billing"),
                eq("Question regarding my invoice and subscription."),
                eq("req-xyz-123")
        );
    }

    @Test
    void handleSubmission_whenHoneypotTriggered_doesNotDispatchNotifications() {
        ContactRequest request = new ContactRequest();
        request.setFirstName("Bot");
        request.setLastName("User");
        request.setEmail("bot@spam.com");
        request.setTopic("support");
        request.setMessage("Spam message content here.");
        request.setWebsite("http://spam-link.com"); // Honeypot filled

        contactService.handleSubmission(request, "10.0.0.1", "req-bot-1");

        verify(contactRepository, never()).save(any());
        verify(telegramService, never()).sendNotification(any(), any(), any(), any(), any());
        verify(discordService, never()).sendNotification(any(), any(), any(), any(), any());
    }
}
