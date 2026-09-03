package com.flujo.backend.application.service;

import com.flujo.backend.application.port.out.AiCategorizerPort;
import com.flujo.backend.domain.model.FinancialNotification;
import com.flujo.backend.domain.model.InterpretationResult;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servicio de aplicación para interpretar notificaciones con caché en memoria
 * por hash del texto normalizado (ahorro de costos de tokens y baja latencia).
 */
@Service
public class TransactionInterpretationService {

    private final AiCategorizerPort aiCategorizer;
    private final Map<String, InterpretationResult> cache = new ConcurrentHashMap<>();

    public TransactionInterpretationService(AiCategorizerPort aiCategorizer) {
        this.aiCategorizer = aiCategorizer;
    }

    public InterpretationResult interpret(String rawText, String packageName) {
        if (rawText == null || rawText.isBlank()) {
            return InterpretationResult.empty();
        }

        String normalizedKey = rawText.trim().toLowerCase().replaceAll("\\s+", " ");
        
        return cache.computeIfAbsent(normalizedKey, key -> {
            FinancialNotification notification = new FinancialNotification(
                rawText,
                packageName,
                java.time.OffsetDateTime.now()
            );
            return aiCategorizer.interpret(notification);
        });
    }
}
