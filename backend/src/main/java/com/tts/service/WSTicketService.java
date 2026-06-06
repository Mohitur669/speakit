package com.tts.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages short-lived tickets for secure WebSocket handshakes.
 * Prevents JWT exposure in WebSocket query parameters.
 */
@Service
@Slf4j
public class WSTicketService {

    private final Map<String, String> ticketToUser = new ConcurrentHashMap<>();
    private final Map<String, Long> ticketExpiry = new ConcurrentHashMap<>();
    
    // Ticket valid for 30 seconds
    private static final long TICKET_TTL_MS = 30000;

    public String createTicket(String username) {
        String ticket = UUID.randomUUID().toString();
        ticketToUser.put(ticket, username);
        ticketExpiry.put(ticket, System.currentTimeMillis() + TICKET_TTL_MS);
        
        log.debug("WebSocket ticket created for user: {}", username);
        return ticket;
    }

    public String consumeTicket(String ticket) {
        cleanupExpiredTickets();
        
        Long expiry = ticketExpiry.get(ticket);
        if (expiry == null || System.currentTimeMillis() > expiry) {
            ticketToUser.remove(ticket);
            ticketExpiry.remove(ticket);
            return null;
        }

        String username = ticketToUser.remove(ticket);
        ticketExpiry.remove(ticket);
        
        log.debug("WebSocket ticket consumed for user: {}", username);
        return username;
    }

    private void cleanupExpiredTickets() {
        long now = System.currentTimeMillis();
        ticketExpiry.entrySet().removeIf(entry -> {
            if (now > entry.getValue()) {
                ticketToUser.remove(entry.getKey());
                return true;
            }
            return false;
        });
    }
}
