package com.flujo.backend.application.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;

@Service
public class JwtTokenService {

    private final String secretKey;
    private final long expirationSeconds;
    private final ObjectMapper objectMapper;

    public JwtTokenService(
        @Value("${jwt.secret:flujo-super-secure-default-secret-key-for-local-development-256bit}") String secretKey,
        @Value("${jwt.expiration-seconds:2592000}") long expirationSeconds, // 30 días
        ObjectMapper objectMapper
    ) {
        this.secretKey = secretKey;
        this.expirationSeconds = expirationSeconds;
        this.objectMapper = objectMapper;
    }

    public String generateToken(String userId, String email, String name) {
        try {
            String headerJson = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
            long now = Instant.now().getEpochSecond();
            long exp = now + expirationSeconds;

            Map<String, Object> payloadMap = Map.of(
                "sub", userId,
                "email", email,
                "name", name,
                "iat", now,
                "exp", exp
            );
            String payloadJson = objectMapper.writeValueAsString(payloadMap);

            String encodedHeader = base64UrlEncode(headerJson.getBytes(StandardCharsets.UTF_8));
            String encodedPayload = base64UrlEncode(payloadJson.getBytes(StandardCharsets.UTF_8));

            String dataToSign = encodedHeader + "." + encodedPayload;
            String signature = sign(dataToSign, secretKey);

            return dataToSign + "." + signature;
        } catch (Exception e) {
            throw new IllegalStateException("Error al generar token JWT", e);
        }
    }

    private final Map<String, Long> revokedTokens = new java.util.concurrent.ConcurrentHashMap<>();

    public void revokeToken(String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        try {
            String[] parts = token.split("\\.");
            if (parts.length == 3) {
                byte[] payloadBytes = Base64.getUrlDecoder().decode(parts[1]);
                JsonNode payload = objectMapper.readTree(payloadBytes);
                long exp = payload.path("exp").asLong(Instant.now().getEpochSecond() + expirationSeconds);
                revokedTokens.put(token, exp);
            }
        } catch (Exception e) {
            revokedTokens.put(token, Instant.now().getEpochSecond() + expirationSeconds);
        }
    }

    public boolean isTokenRevoked(String token) {
        if (token == null) {
            return true;
        }
        Long exp = revokedTokens.get(token);
        if (exp == null) {
            return false;
        }
        if (exp < Instant.now().getEpochSecond()) {
            revokedTokens.remove(token);
            return false;
        }
        return true;
    }

    public Optional<JwtClaims> validateToken(String token) {
        if (token == null || token.isBlank() || isTokenRevoked(token)) {
            return Optional.empty();
        }

        String[] parts = token.split("\\.");
        if (parts.length != 3) {
            return Optional.empty();
        }

        String dataToSign = parts[0] + "." + parts[1];
        String expectedSignature = sign(dataToSign, secretKey);

        byte[] expectedBytes = expectedSignature.getBytes(StandardCharsets.UTF_8);
        byte[] actualBytes = parts[2].getBytes(StandardCharsets.UTF_8);
        if (!java.security.MessageDigest.isEqual(expectedBytes, actualBytes)) {
            return Optional.empty();
        }

        try {
            byte[] payloadBytes = Base64.getUrlDecoder().decode(parts[1]);
            JsonNode payload = objectMapper.readTree(payloadBytes);

            long exp = payload.path("exp").asLong(0);
            long now = Instant.now().getEpochSecond();
            if (exp < now) {
                return Optional.empty(); // Token expirado
            }

            String userId = payload.path("sub").asText();
            String email = payload.path("email").asText();
            String name = payload.path("name").asText();

            return Optional.of(new JwtClaims(userId, email, name));
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    private String sign(String data, String key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKeySpec = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKeySpec);
            byte[] rawHmac = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return base64UrlEncode(rawHmac);
        } catch (Exception e) {
            throw new IllegalStateException("Error al firmar HMAC-SHA256", e);
        }
    }

    private String base64UrlEncode(byte[] bytes) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public record JwtClaims(String userId, String email, String name) {}
}
