package com.flujo.backend.adapter.out.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;

@Entity
@Table(name = "transactions")
public class TransactionJpaEntity {

    @Id
    private String id;

    @Column(nullable = false)
    private Double amount;

    @Column(length = 3, nullable = false)
    private String currency;

    @Column(nullable = false)
    private String merchant;

    @Column(name = "occurred_at", nullable = false)
    private OffsetDateTime occurredAt;

    @Column(name = "category_id", nullable = false)
    private String categoryId;

    @Column(nullable = false)
    private String source;

    @Column(nullable = false)
    private String scope;

    @Column(nullable = false)
    private String type;

    private Double confidence;
    private Boolean reviewed;

    @Column(name = "raw_text", columnDefinition = "TEXT")
    private String rawText;

    @Column(name = "parser")
    private String parser;

    @Column(name = "parser_version")
    private String parserVersion;

    @Column(name = "notification_hash")
    private String notificationHash;

    @Column(name = "synced_at", nullable = false)
    private OffsetDateTime syncedAt;

    public TransactionJpaEntity() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getMerchant() { return merchant; }
    public void setMerchant(String merchant) { this.merchant = merchant; }

    public OffsetDateTime getOccurredAt() { return occurredAt; }
    public void setOccurredAt(OffsetDateTime occurredAt) { this.occurredAt = occurredAt; }

    public String getCategoryId() { return categoryId; }
    public void setCategoryId(String categoryId) { this.categoryId = categoryId; }

    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }

    public String getScope() { return scope; }
    public void setScope(String scope) { this.scope = scope; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public Double getConfidence() { return confidence; }
    public void setConfidence(Double confidence) { this.confidence = confidence; }

    public Boolean getReviewed() { return reviewed; }
    public void setReviewed(Boolean reviewed) { this.reviewed = reviewed; }

    public String getRawText() { return rawText; }
    public void setRawText(String rawText) { this.rawText = rawText; }

    public String getParser() { return parser; }
    public void setParser(String parser) { this.parser = parser; }

    public String getParserVersion() { return parserVersion; }
    public void setParserVersion(String parserVersion) { this.parserVersion = parserVersion; }

    public String getNotificationHash() { return notificationHash; }
    public void setNotificationHash(String notificationHash) { this.notificationHash = notificationHash; }

    public OffsetDateTime getSyncedAt() { return syncedAt; }
    public void setSyncedAt(OffsetDateTime syncedAt) { this.syncedAt = syncedAt; }
}
