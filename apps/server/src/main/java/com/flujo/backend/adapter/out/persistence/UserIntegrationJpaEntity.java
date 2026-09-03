package com.flujo.backend.adapter.out.persistence;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "user_integrations", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"user_id", "provider"})
})
public class UserIntegrationJpaEntity {

    @Id
    private String id;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(nullable = false, length = 50)
    private String provider;

    @Column(name = "access_token", columnDefinition = "TEXT", nullable = false)
    private String accessToken;

    @Column(name = "refresh_token", columnDefinition = "TEXT")
    private String refreshToken;

    @Column(name = "token_expires_at")
    private OffsetDateTime tokenExpiresAt;

    @Column(length = 255)
    private String email;

    @Column(name = "history_id")
    private String historyId;

    @Column(nullable = false)
    private Boolean active = true;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public UserIntegrationJpaEntity() {}

    public UserIntegrationJpaEntity(
        String id,
        String userId,
        String provider,
        String accessToken,
        String refreshToken,
        OffsetDateTime tokenExpiresAt,
        String email,
        String historyId,
        Boolean active,
        OffsetDateTime updatedAt
    ) {
        this.id = id;
        this.userId = userId;
        this.provider = provider;
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.tokenExpiresAt = tokenExpiresAt;
        this.email = email;
        this.historyId = historyId;
        this.active = active != null ? active : true;
        this.updatedAt = updatedAt != null ? updatedAt : OffsetDateTime.now();
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getProvider() { return provider; }
    public void setProvider(String provider) { this.provider = provider; }

    public String getAccessToken() { return accessToken; }
    public void setAccessToken(String accessToken) { this.accessToken = accessToken; }

    public String getRefreshToken() { return refreshToken; }
    public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }

    public OffsetDateTime getTokenExpiresAt() { return tokenExpiresAt; }
    public void setTokenExpiresAt(OffsetDateTime tokenExpiresAt) { this.tokenExpiresAt = tokenExpiresAt; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getHistoryId() { return historyId; }
    public void setHistoryId(String historyId) { this.historyId = historyId; }

    public Boolean getActive() { return active; }
    public void setActive(Boolean active) { this.active = active; }

    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
