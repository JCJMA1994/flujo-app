package com.flujo.backend.adapter.out.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SpringDataUserIntegrationRepository extends JpaRepository<UserIntegrationJpaEntity, String> {
    Optional<UserIntegrationJpaEntity> findByUserIdAndProvider(String userId, String provider);
    Optional<UserIntegrationJpaEntity> findByEmailAndProvider(String email, String provider);
}
