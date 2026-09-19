package com.speakit.notification.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ResendOtpEmailSenderTest {

    @Mock
    private HttpClient httpClient;

    @Mock
    private HttpResponse<String> httpResponse;

    private ResendOtpEmailSender resendOtpEmailSender;

    @BeforeEach
    void setUp() {
        resendOtpEmailSender = new ResendOtpEmailSender(httpClient);
        ReflectionTestUtils.setField(resendOtpEmailSender, "apiKey", "test-api-key");
        ReflectionTestUtils.setField(resendOtpEmailSender, "fromEmail", "noreply@speakit.com");
    }

    @Test
    void sendOtpEmail_success_buildsCorrectRequest() throws IOException, InterruptedException {
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(httpResponse);
        when(httpResponse.statusCode()).thenReturn(200);

        resendOtpEmailSender.sendOtpEmail("user@example.com", "testuser", "123456", 10);

        ArgumentCaptor<HttpRequest> requestCaptor = ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));

        HttpRequest request = requestCaptor.getValue();
        assertEquals("https://api.resend.com/emails", request.uri().toString());
        assertEquals("POST", request.method());
        assertEquals(Duration.ofSeconds(10), request.timeout().orElse(null));
        assertTrue(request.headers().firstValue("Authorization").orElse("").contains("Bearer test-api-key"));
        assertTrue(request.headers().firstValue("Content-Type").orElse("").contains("application/json"));

        // No actual network calls happened (mocked)
    }

    @Test
    void sendOtpEmail_failure_doesNotThrowJustLikeLegacySender() throws IOException, InterruptedException {
        // Legacy sender logs error but doesn't throw, allowing flow to continue
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenThrow(new IOException("Network error"));

        assertDoesNotThrow(() -> resendOtpEmailSender.sendOtpEmail("user@example.com", "testuser", "123456", 10));
    }

    @Test
    void sendOtpEmail_non200Response_logsErrorButDoesNotThrow() throws IOException, InterruptedException {
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(httpResponse);
        when(httpResponse.statusCode()).thenReturn(403);
        when(httpResponse.body()).thenReturn("Forbidden");

        assertDoesNotThrow(() -> resendOtpEmailSender.sendOtpEmail("user@example.com", "testuser", "123456", 10));
    }
}
