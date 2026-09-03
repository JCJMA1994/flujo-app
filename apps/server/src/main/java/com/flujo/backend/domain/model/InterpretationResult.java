package com.flujo.backend.domain.model;

import java.time.OffsetDateTime;

/**
 * Resultado de la interpretación estructurada de una notificación.
 * Si no se reconoce movimiento, amount es null y confidence es 0.0.
 */
public record InterpretationResult(
    Double amount,
    String currency,
    String merchant,
    OffsetDateTime occurredAt,
    String categoryId,
    String bankId,
    Double confidence
) {
    public static InterpretationResult empty() {
        return new InterpretationResult(null, null, null, null, null, null, 0.0);
    }
}
