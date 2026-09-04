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
        @Value("${gemini.model:gemini-flash-latest}") String model,
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
            log.warn("GEMINI_API_KEY no configurada en el servidor. Retornando resultado vacío.");
            return InterpretationResult.empty();
        }

        try {
            String endpoint = "%s/%s:generateContent".formatted(apiUrl, model);

            String systemPrompt = """
                Eres un intérprete experto de finanzas y notificaciones bancarias peruanas (Yape, Plin, BCP, BBVA, Interbank, Scotiabank, BanBif, Banco de la Nación, Cajas Municipales como Arequipa o Huancayo, transferencias interbancarias CCE/SIP y pagos de servicios como Luz, Agua, Telefonía o Cálidda).
                Extrae el movimiento financiero en formato JSON estricto:
                - amount (número decimal positivo o null si no hay monto)
                - currency ('PEN' o 'USD')
                - type ('expense' para gastos/compras/pagos de servicios/transferencias enviadas o 'income' para ingresos/abonos/transferencias recibidas/yapes o plins recibidos/sueldos)
                - merchant (nombre de la persona o comercio sin prefijos DLC*, IZI*, Yape, Plin)
                - occurred_at (formato ISO-8601 con zona horaria de Perú -05:00)
                - category_id ('food','transport','groceries','services','health','shopping','subscriptions','ants','salary','other')
                - bank_id ('yape','plin','bcp','bbva','interbank','scotiabank','banbif','bn','caja','other')
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
                .header("X-goog-api-key", apiKey)
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

    @Override
    public InterpretationResult interpretImage(byte[] imageBytes, String mimeType) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("GEMINI_API_KEY no configurada en el servidor. Retornando resultado vacío.");
            return InterpretationResult.empty();
        }

        try {
            String endpoint = "%s/%s:generateContent".formatted(apiUrl, model);
            String effectiveMimeType = (mimeType != null && !mimeType.isBlank()) ? mimeType : "image/jpeg";
            String base64Data = java.util.Base64.getEncoder().encodeToString(imageBytes);

            String systemPrompt = """
                Eres un asistente experto de finanzas personales en el Perú. Tu función es analizar imágenes de comprobantes, vouchers de pago, transferencias bancarias e interbancarias inmediatas o diferidas (CCE/SIP), recibos de servicios recurrentes (Luz del Sur, Pluz/Enel, Sedapal, Cálidda, Claro, Movistar, Entel) y capturas de pantalla de Yape, Plin, BCP, BBVA, Interbank, Scotiabank, BanBif, Banco de la Nación, Cajas (Arequipa, Huancayo, Piura, etc.) y POS (Niubiz, Izipay).
                Extrae con máxima precisión los siguientes datos en formato JSON estricto:
                - amount (número decimal positivo)
                - currency ('PEN' o 'USD')
                - type ('expense' si es un pago realizado, consumo, transferencia enviada, cuota o servicio pagado; 'income' si es un abono, constancia de dinero recibido a favor del titular, sueldo o te yapearon/plinearon)
                - merchant (nombre limpio de la contraparte, comercio, entidad o persona, sin códigos ni prefijos como DLC*, IZI*, Yape, Plin)
                - occurred_at (formato ISO-8601 con zona horaria de Perú -05:00)
                - category_id ('food','transport','groceries','services','health','shopping','subscriptions','ants','salary','other')
                - bank_id ('yape','plin','bcp','bbva','interbank','scotiabank','banbif','bn','caja','other')
                - confidence (número entre 0.0 y 1.0)
                Si la imagen no es un comprobante financiero válido, devuelve amount null y confidence 0.0.
                """;

            Map<String, Object> requestBody = Map.of(
                "contents", List.of(
                    Map.of("parts", List.of(
                        Map.of("text", "Analiza este comprobante de pago peruano:"),
                        Map.of("inlineData", Map.of(
                            "mimeType", effectiveMimeType,
                            "data", base64Data
                        ))
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
                .header("X-goog-api-key", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .body(requestBody)
                .retrieve()
                .body(String.class);

            return parseGeminiResponse(responseJson);

        } catch (Exception e) {
            log.error("Error al invocar API de Gemini para imagen: {}", e.getMessage());
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
            String rawType = parsed.path("type").asText("expense").toLowerCase().trim();
            String type = "income".equals(rawType) ? "income" : "expense";

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
                confidence,
                type
            );

        } catch (Exception e) {
            log.error("Error parseando respuesta estructurada de Gemini: {}", e.getMessage());
            return InterpretationResult.empty();
        }
    }
}
