package com.speakit.shared.exception;
import com.speakit.tts.exception.SpeechConversionException;

import com.speakit.shared.dto.ApiErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    private ApiErrorResponse buildResponse(HttpStatus status, String error, String message, HttpServletRequest request) {
        return ApiErrorResponse.builder()
                .timestamp(LocalDateTime.now())
                .status(status.value())
                .error(error)
                .message(message)
                .path(request.getRequestURI())
                .build();
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidationExceptions(MethodArgumentNotValidException ex, HttpServletRequest request) {
        log.warn("Validation failed: {} errors — fields: {}", 
                ex.getBindingResult().getErrorCount(),
                ex.getBindingResult().getFieldErrors().stream()
                        .map(fe -> fe.getField() + "=" + fe.getRejectedValue() + " (" + fe.getDefaultMessage() + ")")
                        .toList());
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            errors.put(fieldName, errorMessage);
        });

        ApiErrorResponse response = buildResponse(HttpStatus.BAD_REQUEST, "Validation Error", "Invalid input data", request);
        response.setValidationErrors(errors);
        
        return new ResponseEntity<>(response, HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(RateLimitExceededException.class)
    public ResponseEntity<ApiErrorResponse> handleRateLimitExceeded(RateLimitExceededException ex, HttpServletRequest request) {
        log.warn("Rate limit exceeded for request. Retry after: {}s", ex.getRetryAfterSeconds());
        
        ApiErrorResponse response = buildResponse(HttpStatus.TOO_MANY_REQUESTS, "Too Many Requests", "Rate limit exceeded. Please try again later.", request);
        
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Retry-After", String.valueOf(ex.getRetryAfterSeconds()))
                .body(response);
    }

    @ExceptionHandler(SpeechConversionException.class)
    public ResponseEntity<ApiErrorResponse> handleSpeechConversion(SpeechConversionException ex, HttpServletRequest request) {
        log.error("TTS conversion failed: {}", ex.getMessage());
        
        ApiErrorResponse response = buildResponse(HttpStatus.INTERNAL_SERVER_ERROR, "TTS_ERROR", "Speech synthesis failed. Please try a different voice or shorter text.", request);
        return new ResponseEntity<>(response, HttpStatus.INTERNAL_SERVER_ERROR);
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ApiErrorResponse> handleRuntimeException(RuntimeException ex, HttpServletRequest request) {
        log.warn("Business rule violation: {}", ex.getMessage());
        if (ex.getMessage() != null && ex.getMessage().startsWith("EMAIL_NOT_VERIFIED")) {
            String email = ex.getMessage().contains(":") ? ex.getMessage().split(":")[1] : "";
            ApiErrorResponse response = buildResponse(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED", email, request);
            return new ResponseEntity<>(response, HttpStatus.FORBIDDEN);
        }
        ApiErrorResponse response = buildResponse(HttpStatus.BAD_REQUEST, "Bad Request", ex.getMessage(), request);
        return new ResponseEntity<>(response, HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleGeneralException(Exception ex, HttpServletRequest request) {
        log.error("Unexpected system error", ex);
        ApiErrorResponse response = buildResponse(HttpStatus.INTERNAL_SERVER_ERROR, "Internal Server Error", "An unexpected error occurred.", request);
        return new ResponseEntity<>(response, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
