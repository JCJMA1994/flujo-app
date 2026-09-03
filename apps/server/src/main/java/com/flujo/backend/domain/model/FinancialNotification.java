package com.flujo.backend.domain.model;

import java.time.OffsetDateTime;

/**
 * Notificación financiera cruda recibida para interpretación.
 */
public record FinancialNotification(
    String rawText,
    String packageName,
    OffsetDateTime receivedAt
) {}
