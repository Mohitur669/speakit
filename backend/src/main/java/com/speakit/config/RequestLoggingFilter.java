package com.speakit.config;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.UUID;

/**
 * Filter that adds a unique Request-ID to the MDC for every incoming request.
 * This allows all logs generated within the thread to be correlated back to 
 * a specific HTTP request.
 */
@Component
public class RequestLoggingFilter implements Filter {

    private static final String REQUEST_ID_KEY = "requestId";
    private static final String REQUEST_ID_HEADER = "X-Request-ID";
    private static final String SERVER_TIMING_HEADER = "Server-Timing";

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        // Extract ID from header if present (from reverse proxy), otherwise generate new
        String requestId = httpRequest.getHeader(REQUEST_ID_HEADER);
        if (requestId == null || requestId.isEmpty()) {
            requestId = UUID.randomUUID().toString().substring(0, 8);
        }

        long startTime = System.currentTimeMillis();
        try {
            MDC.put(REQUEST_ID_KEY, requestId);
            // Add to response headers for frontend troubleshooting
            httpResponse.setHeader(REQUEST_ID_HEADER, requestId);
            
            chain.doFilter(request, response);
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            if (!httpResponse.isCommitted()) {
                httpResponse.setHeader(SERVER_TIMING_HEADER, "app;dur=" + duration);
            }
            MDC.remove(REQUEST_ID_KEY);
        }
    }
}

