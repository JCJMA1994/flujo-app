package com.flujo.backend.adapter.out.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.flujo.backend.application.port.out.AiCategorizerPort;
import com.flujo.backend.domain.model.FinancialNotification;
import com.flujo.backend.domain.model.InterpretationResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * Adaptador de salida para la API de Gemini (Google GenAI) con Structured Outputs.
 */
@Component
public class GeminiAiCategorizerAdapter implements AiCategorizerPort {

    private static final Logger log = LoggerFactory.getLogger(GeminiAiCategorizerAdapter.class);

    private final String apiKey;
    private final String model;
    private final String apiUrl;
    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    public GeminiAiCategorizerAdapter(
        @Value("${gemini.api-key:}") String apiKey,
        @Value("${gemini.model:gemini-2.5-flash}") String model,
        @Value("${gemini.api-url:https://generativelanguage.googleapis.com/v1beta/models}") String apiUrl,
        ObjectMapper objectMapper
    ) {
        this.apiKey = apiKey;
        this.model = model;
        this.apiUrl = apiUrl;
        this.objectMapper = objectMapper;
        this.restClient = RestClient.builder().build();
    }

    @Override
    public InterpretationResult interpret(FinancialNotification notification) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("GEMINI_API_KEY no configurada. Retornando resultado vacío.");
            return InterpretationResult.empty();
        }

        try {
            String endpoint = "%s/%s:generateContent?key=%s".formatted(apiUrl, model, apiKey);

            String systemPrompt = """
                Eres un intérprete experto de notificaciones bancarias peruanas (Yape, Plin, BCP, BBVA, Interbank, Scotiabank).
                Extrae el movimiento financiero en formato JSON estricto:
                - amount (número decimal o null)
                - currency ('PEN' o 'USD')
                - merchant (nombre de la persona o comercio sin códigos DLC*, IZI*, Yape)
                - occurred_at (formato ISO-8601 con zona horaria de Perú -05:00)
                - category_id ('food','transport','groceries','services','health','shopping','subscriptions','ants','salary','other')
                - bank_id ('yape','plin','bcp','bbva','interbank','scotiabank')
                - confidence (número entre 0.0 y 1.0)
                Si la notificación no describe un movimiento financiero, devuelve amount null y confidence 0.0.
                """;

            Map<String, Object> requestBody = Map.of(
                "contents", List.of(
                    Map.of("parts", List.of(
                        Map.of("text", "Notificación: " + notification.rawText())
                    ))
                ),
                "systemInstruction", Map.of(
                    "parts", List.of(Map.of("text", systemPrompt))
                ),
                "generationConfig", Map.of(
                    "responseMimeType", "application/json",
                    "temperature", 0.1
                )
            );

            String responseJson = restClient.post()
                .uri(endpoint)
                .contentType(MediaType.APPLICATION_JSON)
                .body(requestBody)
                .retrieve()
                .body(String.class);

            return parseGeminiResponse(responseJson);

        } catch (Exception e) {
            log.error("Error al invocar API de Gemini: {}", e.getMessage());
            return InterpretationResult.empty();
        }
    }

    private InterpretationResult parseGeminiResponse(String responseJson) {
        try {
            JsonNode root = objectMapper.readTree(responseJson);
            JsonNode textNode = root.path("candidates")
                .path(0)
                .path("content")
                .path("parts")
                .path(0)
                .path("text");

            if (textNode.isMissingNode()) {
                return InterpretationResult.empty();
            }

            JsonNode parsed = objectMapper.readTree(textNode.asText());
            if (!parsed.has("amount") || parsed.get("amount").isNull()) {
                return InterpretationResult.empty();
            }

            Double amount = parsed.get("amount").asDouble();
            String currency = parsed.path("currency").asText("PEN");
            String merchant = parsed.path("merchant").asText("");
            String categoryId = parsed.path("category_id").asText("other");
            String bankId = parsed.path("bank_id").asText("");
            Double confidence = parsed.path("confidence").asDouble(0.85);

            OffsetDateTime occurredAt = OffsetDateTime.now();
            if (parsed.has("occurred_at") && !parsed.get("occurred_at").isNull()) {
                try {
                    occurredAt = OffsetDateTime.parse(parsed.get("occurred_at").asText());
                } catch (Exception ignored) {}
            }

            return new InterpretationResult(
                amount,
                currency,
                merchant,
                occurredAt,
                categoryId,
                bankId,
                confidence
            );

        } catch (Exception e) {
            log.error("Error parseando respuesta estructurada de Gemini: {}", e.getMessage());
            return InterpretationResult.empty();
        }
    }
}
