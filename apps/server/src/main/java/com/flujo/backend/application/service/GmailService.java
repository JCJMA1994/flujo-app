package com.flujo.backend.application.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.flujo.backend.adapter.out.persistence.SpringDataTransactionRepository;
import com.flujo.backend.adapter.out.persistence.SpringDataUserIntegrationRepository;
import com.flujo.backend.adapter.out.persistence.TransactionJpaEntity;
import com.flujo.backend.adapter.out.persistence.UserIntegrationJpaEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.*;

@Service
public class GmailService {

    private static final Logger log = LoggerFactory.getLogger(GmailService.class);

    private final SpringDataUserIntegrationRepository integrationRepository;
    private final SpringDataTransactionRepository transactionRepository;
    private final EmailExpenseParser emailExpenseParser;
    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    private final String clientId;
    private final String clientSecret;
    private final String redirectUri;
    private final String pubsubTopic;

    public GmailService(
        SpringDataUserIntegrationRepository integrationRepository,
        SpringDataTransactionRepository transactionRepository,
        EmailExpenseParser emailExpenseParser,
        ObjectMapper objectMapper,
        @Value("${google.oauth.client-id:dummy-client-id}") String clientId,
        @Value("${google.oauth.client-secret:dummy-client-secret}") String clientSecret,
        @Value("${google.oauth.redirect-uri:https://api.system-failed-tech.com/v1/integrations/gmail/callback}") String redirectUri,
        @Value("${google.pubsub.topic-name:projects/flujo-finance/topics/gmail-notifications}") String pubsubTopic
    ) {
        this.integrationRepository = integrationRepository;
        this.transactionRepository = transactionRepository;
        this.emailExpenseParser = emailExpenseParser;
        this.objectMapper = objectMapper;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.redirectUri = redirectUri;
        this.pubsubTopic = pubsubTopic;
        this.restClient = RestClient.builder().build();
    }

    public String buildAuthorizationUrl(String userId) {
        String scope = "https://www.googleapis.com/auth/gmail.readonly email";
        return "https://accounts.google.com/o/oauth2/v2/auth?" +
               "client_id=" + URLEncoder.encode(clientId, StandardCharsets.UTF_8) +
               "&redirect_uri=" + URLEncoder.encode(redirectUri, StandardCharsets.UTF_8) +
               "&response_type=code" +
               "&scope=" + URLEncoder.encode(scope, StandardCharsets.UTF_8) +
               "&access_type=offline" +
               "&prompt=consent" +
               "&state=" + URLEncoder.encode(userId, StandardCharsets.UTF_8);
    }

    public Optional<UserIntegrationJpaEntity> getStatus(String userId) {
        return integrationRepository.findByUserIdAndProvider(userId, "GMAIL");
    }

    public void disconnect(String userId) {
        integrationRepository.findByUserIdAndProvider(userId, "GMAIL").ifPresent(integration -> {
            integration.setActive(false);
            integration.setUpdatedAt(OffsetDateTime.now());
            integrationRepository.save(integration);
        });
    }

    public UserIntegrationJpaEntity handleOAuthCallback(String code, String userId) {
        try {
            Map<String, String> tokenParams = Map.of(
                "code", code,
                "client_id", clientId,
                "client_secret", clientSecret,
                "redirect_uri", redirectUri,
                "grant_type", "authorization_code"
            );

            String tokenResponse = restClient.post()
                .uri("https://oauth2.googleapis.com/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(toFormData(tokenParams))
                .retrieve()
                .body(String.class);

            JsonNode tokenJson = objectMapper.readTree(tokenResponse);
            String accessToken = tokenJson.path("access_token").asText();
            String refreshToken = tokenJson.path("refresh_token").asText(null);
            long expiresIn = tokenJson.path("expires_in").asLong(3600);

            // Obtener email del perfil de usuario de Google
            String profileResponse = restClient.get()
                .uri("https://gmail.googleapis.com/gmail/v1/users/me/profile")
                .header("Authorization", "Bearer " + accessToken)
                .retrieve()
                .body(String.class);

            JsonNode profileJson = objectMapper.readTree(profileResponse);
            String emailAddress = profileJson.path("emailAddress").asText();
            String historyId = profileJson.path("historyId").asText(null);

            // Activar Gmail Watch a Pub/Sub si el tópico está configurado
            activateGmailWatch(accessToken);

            UserIntegrationJpaEntity entity = integrationRepository.findByUserIdAndProvider(userId, "GMAIL")
                .orElse(new UserIntegrationJpaEntity(
                    UUID.randomUUID().toString(),
                    userId,
                    "GMAIL",
                    accessToken,
                    refreshToken,
                    OffsetDateTime.now().plusSeconds(expiresIn),
                    emailAddress,
                    historyId,
                    true,
                    OffsetDateTime.now()
                ));

            entity.setAccessToken(accessToken);
            if (refreshToken != null && !refreshToken.isBlank()) {
                entity.setRefreshToken(refreshToken);
            }
            entity.setTokenExpiresAt(OffsetDateTime.now().plusSeconds(expiresIn));
            entity.setEmail(emailAddress);
            entity.setHistoryId(historyId);
            entity.setActive(true);
            entity.setUpdatedAt(OffsetDateTime.now());

            return integrationRepository.save(entity);
        } catch (Exception e) {
            log.error("Error al procesar OAuth callback de Gmail: {}", e.getMessage(), e);
            throw new RuntimeException("Error al vincular cuenta de Gmail: " + e.getMessage(), e);
        }
    }

    private void activateGmailWatch(String accessToken) {
        if (pubsubTopic == null || pubsubTopic.contains("dummy")) {
            return;
        }
        try {
            Map<String, Object> watchRequest = Map.of(
                "topicName", pubsubTopic,
                "labelIds", List.of("INBOX")
            );

            restClient.post()
                .uri("https://gmail.googleapis.com/gmail/v1/users/me/watch")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .body(watchRequest)
                .retrieve()
                .toBodilessEntity();
            log.info("Watch de Gmail activado exitosamente hacia Pub/Sub {}", pubsubTopic);
        } catch (Exception e) {
            log.warn("No se pudo activar watch de Gmail (esperado en entorno local sin credenciales GCP): {}", e.getMessage());
        }
    }

    public int processIncomingEmail(String userId, String from, String subject, String body) {
        Optional<EmailExpenseParser.ParsedEmailExpense> parsedOpt = emailExpenseParser.parse(from, subject, body);
        if (parsedOpt.isEmpty()) {
            return 0;
        }

        EmailExpenseParser.ParsedEmailExpense parsed = parsedOpt.get();

        TransactionJpaEntity transaction = new TransactionJpaEntity(
            UUID.randomUUID().toString(),
            userId,
            parsed.amount(),
            parsed.currency(),
            parsed.merchant(),
            parsed.occurredAt(),
            parsed.categoryId(),
            "gmail_pubsub",
            "personal",
            parsed.type(),
            0.95,
            true,
            subject + " | " + body,
            "GmailEmailParser",
            "1.0",
            null,
            OffsetDateTime.now()
        );

        transactionRepository.save(transaction);
        log.info("Transacción capturada vía correo para userId {}: {} S/ {}", userId, parsed.merchant(), parsed.amount());
        return 1;
    }

    public void handleHistoryNotification(String userId, String historyId) {
        log.info("Sincronizando historial de correos para userId {} a partir de historyId {}", userId, historyId);
    }

    private String toFormData(Map<String, String> params) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> entry : params.entrySet()) {
            if (!sb.isEmpty()) sb.append("&");
            sb.append(URLEncoder.encode(entry.getKey(), StandardCharsets.UTF_8))
              .append("=")
              .append(URLEncoder.encode(entry.getValue(), StandardCharsets.UTF_8));
        }
        return sb.toString();
    }
}
