package com.flujo.backend.application.service;

import com.flujo.backend.adapter.out.persistence.SpringDataTransactionRepository;
import com.flujo.backend.adapter.out.persistence.TransactionJpaEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class TransactionSyncService {

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
            if (id == null) continue;

            TransactionJpaEntity entity = repository.findById(id).orElseGet(TransactionJpaEntity::new);
            entity.setId(id);
            if (userId != null) {
                entity.setUserId(userId);
            }
            entity.setAmount(data.get("amount") != null ? ((Number) data.get("amount")).doubleValue() : 0.0);
            entity.setCurrency((String) data.getOrDefault("currency", "PEN"));
            entity.setMerchant((String) data.getOrDefault("merchant", ""));
            
            if (data.get("occurred_at") != null) {
                entity.setOccurredAt(OffsetDateTime.parse((String) data.get("occurred_at")));
            } else {
                entity.setOccurredAt(OffsetDateTime.now());
            }

            entity.setCategoryId((String) data.getOrDefault("category_id", "other"));
            entity.setSource((String) data.getOrDefault("source", "bankNotification"));
            entity.setScope((String) data.getOrDefault("scope", "personal"));
            entity.setType((String) data.getOrDefault("type", "expense"));
            entity.setConfidence(data.get("confidence") != null ? ((Number) data.get("confidence")).doubleValue() : 1.0);
            entity.setReviewed((Boolean) data.getOrDefault("reviewed", true));
            entity.setRawText((String) data.get("raw_text"));
            entity.setParser((String) data.get("parser"));
            entity.setParserVersion((String) data.get("parser_version"));
            entity.setNotificationHash((String) data.get("notification_hash"));
            entity.setSyncedAt(OffsetDateTime.now());

            repository.save(entity);
            acknowledged.add(id);
        }

        return acknowledged;
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
