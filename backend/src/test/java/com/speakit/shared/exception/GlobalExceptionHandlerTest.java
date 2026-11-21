package com.speakit.shared.exception;

import com.speakit.shared.dto.ApiErrorResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class GlobalExceptionHandlerTest {

    private GlobalExceptionHandler exceptionHandler;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        exceptionHandler = new GlobalExceptionHandler();
        request = new MockHttpServletRequest();
        request.setRequestURI("/api/auth/login");
    }

    @Test
    void handleHttpMediaTypeNotSupported_shouldReturn415() {
        HttpMediaTypeNotSupportedException ex = new HttpMediaTypeNotSupportedException(
                MediaType.APPLICATION_FORM_URLENCODED,
                List.of(MediaType.APPLICATION_JSON)
        );

        ResponseEntity<ApiErrorResponse> response = exceptionHandler.handleHttpMediaTypeNotSupported(ex, request);

        assertNotNull(response);
        assertEquals(HttpStatus.UNSUPPORTED_MEDIA_TYPE, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(415, response.getBody().getStatus());
        assertEquals("Unsupported Media Type", response.getBody().getError());
        assertTrue(response.getBody().getMessage().contains("application/x-www-form-urlencoded"));
        assertEquals("/api/auth/login", response.getBody().getPath());
    }

    @Test
    void handleHttpRequestMethodNotSupported_shouldReturn405() {
        HttpRequestMethodNotSupportedException ex = new HttpRequestMethodNotSupportedException(
                "GET",
                List.of("POST")
        );

        ResponseEntity<ApiErrorResponse> response = exceptionHandler.handleHttpRequestMethodNotSupported(ex, request);

        assertNotNull(response);
        assertEquals(HttpStatus.METHOD_NOT_ALLOWED, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(405, response.getBody().getStatus());
        assertEquals("Method Not Allowed", response.getBody().getError());
        assertTrue(response.getBody().getMessage().contains("GET"));
        assertEquals("/api/auth/login", response.getBody().getPath());
    }
}
