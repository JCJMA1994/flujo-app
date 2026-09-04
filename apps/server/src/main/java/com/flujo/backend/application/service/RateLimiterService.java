package com.flujo.backend.application.service;

import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Servicio de limitación de tasa (Rate Limiting) en memoria para protección
 * contra ataques de fuerza bruta (brute-force) y DoS.
 */
@Service
public class RateLimiterService {

    private static final long WINDOW_MILLIS = 60_000L; // 1 minuto
    private final Map<String, AtomicInteger> counters = new ConcurrentHashMap<>();
    private final AtomicLong cleanupCounter = new AtomicLong(0);

    public boolean isAllowed(String clientIp, String endpoint) {
        int maxRequests = resolveLimit(endpoint);
        if (maxRequests <= 0) {
            return true; // Sin límite
        }

        long currentWindow = System.currentTimeMillis() / WINDOW_MILLIS;
        String key = clientIp + ":" + endpoint + ":" + currentWindow;

        AtomicInteger counter = counters.computeIfAbsent(key, k -> new AtomicInteger(0));
        boolean allowed = counter.incrementAndGet() <= maxRequests;

        // Limpieza periódica cada 200 llamadas para evitar fugas de memoria
        if (cleanupCounter.incrementAndGet() % 200 == 0) {
            cleanupOldWindows(currentWindow);
        }

        return allowed;
    }

    private int resolveLimit(String endpoint) {
        if (endpoint.startsWith("/v1/auth/login")) {
            return 5; // Máximo 5 intentos de login por minuto
        }
        if (endpoint.startsWith("/v1/auth/register")) {
            return 3; // Máximo 3 registros por minuto
        }
        if (endpoint.startsWith("/v1/capture")) {
            return 30; // Máximo 30 peticiones de IA por minuto
        }
        return 120; // 120 peticiones generales por minuto
    }

    private void cleanupOldWindows(long currentWindow) {
        long minValidWindow = currentWindow - 1;
        counters.keySet().removeIf(k -> {
            String[] parts = k.split(":");
            if (parts.length >= 3) {
                try {
                    return Long.parseLong(parts[2]) < minValidWindow;
                } catch (NumberFormatException ignored) {
                    return true;
                }
            }
            return true;
        });
    }

    public void reset() {
        counters.clear();
    }
}
