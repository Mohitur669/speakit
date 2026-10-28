package com.speakit.shared.util;

import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

class IpUtilTest {

    @Test
    void testPrioritizeCfConnectingIp() {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getHeader("CF-Connecting-IP")).thenReturn("203.0.113.195");
        when(request.getHeader("True-Client-IP")).thenReturn("198.51.100.1");
        when(request.getRemoteAddr()).thenReturn("10.0.0.1");

        String ip = IpUtil.getClientIp(request);
        assertEquals("203.0.113.195", ip);
    }

    @Test
    void testFallbackToTrueClientIpWhenCfMissing() {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getHeader("CF-Connecting-IP")).thenReturn(null);
        when(request.getHeader("True-Client-IP")).thenReturn("198.51.100.1");
        when(request.getRemoteAddr()).thenReturn("10.0.0.1");

        String ip = IpUtil.getClientIp(request);
        assertEquals("198.51.100.1", ip);
    }

    @Test
    void testFallbackToRemoteAddrWhenHeadersMissing() {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getHeader("CF-Connecting-IP")).thenReturn(null);
        when(request.getHeader("True-Client-IP")).thenReturn("");
        when(request.getRemoteAddr()).thenReturn("127.0.0.1");

        String ip = IpUtil.getClientIp(request);
        assertEquals("127.0.0.1", ip);
    }

    @Test
    void testNullRequestReturnsDefault() {
        String ip = IpUtil.getClientIp(null);
        assertEquals("0.0.0.0", ip);
    }
}
