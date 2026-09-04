package com.flujo.backend.adapter.in.web;

import com.flujo.backend.application.service.RateLimiterService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RateLimitingFilterTest {

    private RateLimiterService rateLimiterService;
    private RateLimitingFilter filter;

    @BeforeEach
    void setUp() {
        rateLimiterService = new RateLimiterService();
        filter = new RateLimitingFilter(rateLimiterService);
    }

    @Test
    void shouldAllowRequestsUnderLimit() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/v1/auth/login");
        request.setRemoteAddr("192.168.1.100");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain filterChain = new MockFilterChain();

        filter.doFilter(request, response, filterChain);

        assertEquals(200, response.getStatus());
    }

    @Test
    void shouldBlockWhenExceedingLoginLimit() throws Exception {
        String clientIp = "200.48.10.5";

        // Enviar 5 peticiones permitidas
        for (int i = 0; i < 5; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("POST", "/v1/auth/login");
            request.setRemoteAddr(clientIp);
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, new MockFilterChain());
            assertEquals(200, response.getStatus());
        }

        // La 6ta petición debe ser rechazada con HTTP 429
        MockHttpServletRequest blockedRequest = new MockHttpServletRequest("POST", "/v1/auth/login");
        blockedRequest.setRemoteAddr(clientIp);
        MockHttpServletResponse blockedResponse = new MockHttpServletResponse();

        filter.doFilter(blockedRequest, blockedResponse, new MockFilterChain());

        assertEquals(429, blockedResponse.getStatus());
        assertEquals("60", blockedResponse.getHeader("Retry-After"));
        assertTrue(blockedResponse.getContentAsString().contains("Demasiadas peticiones"));
    }

    @Test
    void shouldNeverLimitHealthCheck() throws Exception {
        String clientIp = "10.0.0.1";

        for (int i = 0; i < 200; i++) {
            MockHttpServletRequest request = new MockHttpServletRequest("GET", "/health");
            request.setRemoteAddr(clientIp);
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilter(request, response, new MockFilterChain());
            assertEquals(200, response.getStatus());
        }
    }
}
