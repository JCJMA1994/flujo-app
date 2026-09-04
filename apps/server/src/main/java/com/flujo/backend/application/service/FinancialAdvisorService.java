package com.flujo.backend.application.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.flujo.backend.adapter.out.persistence.SpringDataTransactionRepository;
import com.flujo.backend.adapter.out.persistence.TransactionJpaEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class FinancialAdvisorService {

    private static final Logger log = LoggerFactory.getLogger(FinancialAdvisorService.class);

    private final SpringDataTransactionRepository transactionRepository;
    private final String apiKey;
    private final String model;
    private final String apiUrl;
    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    public FinancialAdvisorService(
        SpringDataTransactionRepository transactionRepository,
        @Value("${gemini.api-key:}") String apiKey,
        @Value("${gemini.model:gemini-flash-latest}") String model,
        @Value("${gemini.api-url:https://generativelanguage.googleapis.com/v1beta/models}") String apiUrl,
        ObjectMapper objectMapper
    ) {
        this.transactionRepository = transactionRepository;
        this.apiKey = apiKey;
        this.model = model;
        this.apiUrl = apiUrl;
        this.objectMapper = objectMapper;
        this.restClient = RestClient.builder().build();
    }

    public record AdvisorResponse(
        String answer,
        List<String> suggestedChips
    ) {}

    public AdvisorResponse answerQuery(String userId, String userQuery) {
        List<TransactionJpaEntity> allTransactions = transactionRepository.findByUserIdOrderByOccurredAtDesc(userId);

        OffsetDateTime now = OffsetDateTime.now();
        int currentYear = now.getYear();
        int currentMonth = now.getMonthValue();

        List<TransactionJpaEntity> currentMonthTxs = allTransactions.stream()
            .filter(t -> t.getOccurredAt() != null &&
                         t.getOccurredAt().getYear() == currentYear &&
                         t.getOccurredAt().getMonthValue() == currentMonth)
            .toList();

        List<TransactionJpaEntity> activeTxs = currentMonthTxs;
        if (activeTxs.isEmpty() && !allTransactions.isEmpty()) {
            OffsetDateTime latest = allTransactions.get(0).getOccurredAt();
            if (latest != null) {
                int y = latest.getYear();
                int m = latest.getMonthValue();
                activeTxs = allTransactions.stream()
                    .filter(t -> t.getOccurredAt() != null &&
                                 t.getOccurredAt().getYear() == y &&
                                 t.getOccurredAt().getMonthValue() == m)
                    .toList();
            } else {
                activeTxs = allTransactions;
            }
        }

        double totalExpensesMonth = activeTxs.stream()
            .filter(t -> "expense".equalsIgnoreCase(t.getType()))
            .mapToDouble(t -> t.getAmount() != null ? t.getAmount() : 0.0)
            .sum();

        double totalIncomesMonth = activeTxs.stream()
            .filter(t -> "income".equalsIgnoreCase(t.getType()))
            .mapToDouble(t -> t.getAmount() != null ? t.getAmount() : 0.0)
            .sum();

        Map<String, Double> expensesByCategory = activeTxs.stream()
            .filter(t -> "expense".equalsIgnoreCase(t.getType()))
            .collect(Collectors.groupingBy(
                t -> t.getCategoryId() != null ? t.getCategoryId() : "other",
                Collectors.summingDouble(t -> t.getAmount() != null ? t.getAmount() : 0.0)
            ));

        Map<String, Double> expensesByMerchant = activeTxs.stream()
            .filter(t -> "expense".equalsIgnoreCase(t.getType()) && t.getMerchant() != null)
            .collect(Collectors.groupingBy(
                TransactionJpaEntity::getMerchant,
                Collectors.summingDouble(t -> t.getAmount() != null ? t.getAmount() : 0.0)
            ));

        // Si hay API key de Gemini, delegamos con contexto enriquecido
        if (apiKey != null && !apiKey.isBlank()) {
            try {
                String aiAnswer = queryGemini(userQuery, totalExpensesMonth, totalIncomesMonth, expensesByCategory, expensesByMerchant);
                if (aiAnswer != null && !aiAnswer.isBlank()) {
                    return new AdvisorResponse(aiAnswer, defaultChips());
                }
            } catch (Exception e) {
                log.warn("Fallo al consultar Gemini para chat, usando fallback local: {}", e.getMessage());
            }
        }

        // Fallback analítico determinista
        return generateDeterministicAnswer(userQuery, totalExpensesMonth, totalIncomesMonth, expensesByCategory, expensesByMerchant);
    }

    private String queryGemini(
        String userQuery,
        double totalExpenses,
        double totalIncomes,
        Map<String, Double> byCategory,
        Map<String, Double> byMerchant
    ) throws Exception {
        String endpoint = "%s/%s:generateContent".formatted(apiUrl, model);

        String systemPrompt = """
            Eres el Asistente Financiero inteligente de la app 'Flujo'.
            Tu objetivo es orientar y dar respuestas financieras precisas, amables y directas usando la información del usuario.
            Reglas:
            - Responde en tono cercano, profesional y conciso en formato Markdown.
            - Usa monedas en Soles (S/) o Dólares según los datos.
            - Basa tus respuestas ÚNICAMENTE en el contexto financiero proporcionado.
            - Si el usuario pregunta consejos de ahorro, sé práctico con relación a sus mayores gastos.
            """;

        String context = """
            Contexto del usuario este mes:
            - Total gastos este mes: S/ %.2f
            - Total ingresos este mes: S/ %.2f
            - Balance neto: S/ %.2f
            - Gastos por categoría: %s
            - Principales comercios: %s
            """.formatted(
                totalExpenses,
                totalIncomes,
                totalIncomes - totalExpenses,
                byCategory.toString(),
                byMerchant.entrySet().stream()
                    .sorted(Map.Entry.<String, Double>comparingByValue().reversed())
                    .limit(5)
                    .map(e -> "%s (S/ %.2f)".formatted(e.getKey(), e.getValue()))
                    .collect(Collectors.joining(", "))
            );

        Map<String, Object> requestBody = Map.of(
            "contents", List.of(
                Map.of("parts", List.of(
                    Map.of("text", context + "\n\nPregunta del usuario: " + userQuery)
                ))
            ),
            "systemInstruction", Map.of(
                "parts", List.of(Map.of("text", systemPrompt))
            ),
            "generationConfig", Map.of(
                "temperature", 0.3
            )
        );

        String responseJson = restClient.post()
            .uri(endpoint)
            .header("X-goog-api-key", apiKey)
            .contentType(MediaType.APPLICATION_JSON)
            .body(requestBody)
            .retrieve()
            .body(String.class);

        JsonNode root = objectMapper.readTree(responseJson);
        JsonNode candidates = root.path("candidates");
        if (candidates.isArray() && !candidates.isEmpty()) {
            JsonNode textNode = candidates.get(0).path("content").path("parts").get(0).path("text");
            if (!textNode.isMissingNode()) {
                return textNode.asText().trim();
            }
        }
        return null;
    }

    private AdvisorResponse generateDeterministicAnswer(
        String query,
        double totalExpenses,
        double totalIncomes,
        Map<String, Double> byCategory,
        Map<String, Double> byMerchant
    ) {
        String q = query.toLowerCase().trim();

        if (q.contains("gasto") || q.contains("total") || q.contains("este mes")) {
            String topCat = byCategory.entrySet().stream()
                .max(Map.Entry.comparingByValue())
                .map(e -> "%s con S/ %.2f".formatted(e.getKey(), e.getValue()))
                .orElse("ninguna");

            String answer = """
                **Resumen del mes actual:**
                - **Total gastos:** S/ %.2f
                - **Total ingresos:** S/ %.2f
                - **Balance neto:** S/ %.2f
                
                Tu mayor categoría de gasto es **%s**.
                """.formatted(totalExpenses, totalIncomes, totalIncomes - totalExpenses, topCat);

            return new AdvisorResponse(answer.trim(), defaultChips());
        }

        if (q.contains("comida") || q.contains("restaurante") || q.contains("food")) {
            double foodExpense = byCategory.getOrDefault("food", 0.0);
            String answer = "En la categoría de **Alimentación y Comida** has registrado un total de **S/ %.2f** este mes.".formatted(foodExpense);
            return new AdvisorResponse(answer, defaultChips());
        }

        String defaultAnswer = """
            **Hola, soy tu asistente de Flujo.**
            Este mes llevas registrado un gasto total de **S/ %.2f** y **S/ %.2f** de ingresos.
            ¿En qué más te puedo ayudar hoy?
            """.formatted(totalExpenses, totalIncomes);

        return new AdvisorResponse(defaultAnswer.trim(), defaultChips());
    }

    private List<String> defaultChips() {
        return List.of(
            "¿En qué gasté más este mes?",
            "¿Cuánto gasté en comida?",
            "¿Cuál es mi balance neto?"
        );
    }
}
