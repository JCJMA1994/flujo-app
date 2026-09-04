package com.flujo.backend.application.port.out;

import com.flujo.backend.domain.model.FinancialNotification;
import com.flujo.backend.domain.model.InterpretationResult;

/**
 * Puerto de salida para proveedores de IA (Gemini, Vertex AI, etc.).
 */
public interface AiCategorizerPort {
    InterpretationResult interpret(FinancialNotification notification);
    InterpretationResult interpretImage(byte[] imageBytes, String mimeType);
}
