package com.flujo.backend.adapter.in.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.flujo.backend.adapter.out.persistence.SpringDataUserIntegrationRepository;
import com.flujo.backend.adapter.out.persistence.UserIntegrationJpaEntity;
import com.flujo.backend.application.service.GmailService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/v1/webhooks/gmail")
public class GmailWebhookController {

    private static final Logger log = LoggerFactory.getLogger(GmailWebhookController.class);

    private final GmailService gmailService;
    private final SpringDataUserIntegrationRepository userIntegrationRepository;
    private final ObjectMapper objectMapper;

    public GmailWebhookController(
        GmailService gmailService,
        SpringDataUserIntegrationRepository userIntegrationRepository,
        ObjectMapper objectMapper
    ) {
        this.gmailService = gmailService;
        this.userIntegrationRepository = userIntegrationRepository;
        this.objectMapper = objectMapper;
    }

    @PostMapping("/pubsub")
    public ResponseEntity<Map<String, String>> handlePubSubPush(@RequestBody Map<String, Object> payload) {
        try {
            if (payload == null || !payload.containsKey("message")) {
                return ResponseEntity.ok(Map.of("status", "ignored_no_message"));
            }

            @SuppressWarnings("unchecked")
            Map<String, Object> message = (Map<String, Object>) payload.get("message");
            String dataBase64 = (String) message.get("data");

            if (dataBase64 == null) {
                return ResponseEntity.ok(Map.of("status", "ignored_no_data"));
            }

            String decodedJson = new String(Base64.getDecoder().decode(dataBase64), StandardCharsets.UTF_8);
            JsonNode dataNode = objectMapper.readTree(decodedJson);

            String emailAddress = dataNode.path("emailAddress").asText(null);
            String historyId = dataNode.path("historyId").asText(null);

            log.info("Notificación PubSub recibida de Gmail para email: {}, historyId: {}", emailAddress, historyId);

            if (emailAddress != null) {
                Optional<UserIntegrationJpaEntity> userOpt = userIntegrationRepository.findByEmailAndProvider(emailAddress, "GMAIL");
                if (userOpt.isPresent() && Boolean.TRUE.equals(userOpt.get().getActive())) {
                    log.info("Procesando actualización de correo para userId: {}", userOpt.get().getUserId());
                }
            }

            // Google Pub/Sub espera 200/204 para dar el mensaje por entregado (ack)
            return ResponseEntity.ok(Map.of("status", "acknowledged"));
        } catch (Exception e) {
            log.error("Error al procesar mensaje push de PubSub: {}", e.getMessage(), e);
            // Siempre respondemos 200 a Pub/Sub para evitar retries infinitos si es un mensaje corrupto
            return ResponseEntity.ok(Map.of("status", "error_logged"));
        }
    }
}
