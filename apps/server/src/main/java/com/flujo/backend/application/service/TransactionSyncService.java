package com.flujo.backend.application.service;

import com.flujo.backend.adapter.out.persistence.SpringDataTransactionRepository;
import com.flujo.backend.adapter.out.persistence.TransactionJpaEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class TransactionSyncService {

    private static final Logger log = LoggerFactory.getLogger(TransactionSyncService.class);

    private final SpringDataTransactionRepository repository;

    public TransactionSyncService(SpringDataTransactionRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public List<String> syncTransactions(List<Map<String, Object>> transactionsData) {
        return syncTransactions(null, transactionsData);
    }

    @Transactional
    public List<String> syncTransactions(String userId, List<Map<String, Object>> transactionsData) {
        List<String> acknowledged = new ArrayList<>();

        for (Map<String, Object> data : transactionsData) {
            String id = (String) data.get("id");
            if (id == null || id.isBlank()) continue;

            try {
                TransactionJpaEntity entity = repository.findById(id).orElseGet(TransactionJpaEntity::new);
                entity.setId(id);
                if (userId != null && !userId.isBlank()) {
                    entity.setUserId(userId);
                }
                entity.setAmount(data.get("amount") != null ? ((Number) data.get("amount")).doubleValue() : 0.0);
                entity.setCurrency((String) data.getOrDefault("currency", "PEN"));
                entity.setMerchant((String) data.getOrDefault("merchant", ""));
                
                entity.setOccurredAt(parseOffsetDateTime(data.get("occurred_at")));

                entity.setCategoryId((String) data.getOrDefault("category_id", "other"));
                entity.setSource((String) data.getOrDefault("source", "bankNotification"));
                entity.setScope((String) data.getOrDefault("scope", "personal"));
                entity.setType((String) data.getOrDefault("type", "expense"));
                entity.setConfidence(data.get("confidence") != null ? ((Number) data.get("confidence")).doubleValue() : 1.0);
                
                Object rawReviewed = data.get("reviewed");
                if (rawReviewed instanceof Boolean b) {
                    entity.setReviewed(b);
                } else if (rawReviewed instanceof String s) {
                    entity.setReviewed(Boolean.parseBoolean(s));
                } else {
                    entity.setReviewed(true);
                }

                entity.setRawText((String) data.get("raw_text"));
                entity.setParser((String) data.get("parser"));
                entity.setParserVersion((String) data.get("parser_version"));
                entity.setNotificationHash((String) data.get("notification_hash"));
                entity.setSyncedAt(OffsetDateTime.now());

                repository.save(entity);
                acknowledged.add(id);
            } catch (Exception e) {
                log.error("Fallo al procesar transacción individual en sync [id={}]: {}", id, e.getMessage(), e);
            }
        }

        return acknowledged;
    }

    private OffsetDateTime parseOffsetDateTime(Object raw) {
        if (raw == null) {
            return OffsetDateTime.now();
        }
        String str = raw.toString().trim();
        if (str.isEmpty()) {
            return OffsetDateTime.now();
        }
        try {
            return OffsetDateTime.parse(str);
        } catch (Exception e1) {
            try {
                return LocalDateTime.parse(str).atOffset(ZoneOffset.UTC);
            } catch (Exception e2) {
                try {
                    return Instant.parse(str).atOffset(ZoneOffset.UTC);
                } catch (Exception e3) {
                    try {
                        return ZonedDateTime.parse(str).toOffsetDateTime();
                    } catch (Exception e4) {
                        log.warn("Formato de fecha no reconocido para occurred_at: '{}', usando now()", str);
                        return OffsetDateTime.now();
                    }
                }
            }
        }
    }

    public List<TransactionJpaEntity> getTransactionsSince(OffsetDateTime since) {
        return repository.findBySyncedAtAfterOrderByOccurredAtDesc(since);
    }

    public List<TransactionJpaEntity> getTransactionsSince(String userId, OffsetDateTime since) {
        if (userId != null && !userId.isBlank()) {
            return repository.findByUserIdAndSyncedAtAfterOrderByOccurredAtDesc(userId, since);
        }
        return repository.findBySyncedAtAfterOrderByOccurredAtDesc(since);
    }
}
