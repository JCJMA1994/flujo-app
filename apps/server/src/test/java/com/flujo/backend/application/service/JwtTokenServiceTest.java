package com.flujo.backend.application.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class JwtTokenServiceTest {

    private JwtTokenService jwtTokenService;

    @BeforeEach
    void setUp() {
        jwtTokenService = new JwtTokenService(
            "test-secret-key-that-is-at-least-256-bits-long-flujo-app-testing",
            3600,
            new ObjectMapper()
        );
    }

    @Test
    void shouldGenerateAndValidateTokenSuccessfully() {
        String token = jwtTokenService.generateToken("user-1", "test@flujo.com", "Test User");
        assertNotNull(token);

        Optional<JwtTokenService.JwtClaims> claimsOpt = jwtTokenService.validateToken(token);
        assertTrue(claimsOpt.isPresent());

        JwtTokenService.JwtClaims claims = claimsOpt.get();
        assertEquals("user-1", claims.userId());
        assertEquals("test@flujo.com", claims.email());
        assertEquals("Test User", claims.name());
    }

    @Test
    void shouldRejectInvalidSignature() {
        String token = jwtTokenService.generateToken("user-1", "test@flujo.com", "Test User");
        String tamperedToken = token.substring(0, token.lastIndexOf('.') + 1) + "invalidSignature";

        Optional<JwtTokenService.JwtClaims> claimsOpt = jwtTokenService.validateToken(tamperedToken);
        assertTrue(claimsOpt.isEmpty());
    }
}
