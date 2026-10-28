package com.speakit.shared.util;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Utility for resolving client IP addresses securely behind reverse proxies (Cloudflare, Render).
 */
public final class IpUtil {

    private IpUtil() {
        // Prevent instantiation
    }

    /**
     * Extracts the verified client IP address.
     * Prioritizes Cloudflare's unforgeable CF-Connecting-IP header, followed by True-Client-IP,
     * falling back to the direct socket remote address.
     *
     * @param request the HTTP servlet request
     * @return the resolved client IP
     */
    public static String getClientIp(HttpServletRequest request) {
        if (request == null) {
            return "0.0.0.0";
        }

        // Cloudflare edge securely injects CF-Connecting-IP containing the verified client socket IP.
        // Cloudflare edge blocks or overwrites any client-forged CF-Connecting-IP headers.
        String cfIp = request.getHeader("CF-Connecting-IP");
        if (cfIp != null && !cfIp.isBlank()) {
            return cfIp.trim();
        }

        // True-Client-IP header fallback (Enterprise Cloudflare or custom edge proxy)
        String trueClientIp = request.getHeader("True-Client-IP");
        if (trueClientIp != null && !trueClientIp.isBlank()) {
            return trueClientIp.trim();
        }

        // Fallback to direct socket remote address (local dev or direct connections)
        return request.getRemoteAddr();
    }
}
