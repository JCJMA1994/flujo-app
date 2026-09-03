package com.flujo.backend.adapter.out.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface SpringDataTransactionRepository extends JpaRepository<TransactionJpaEntity, String> {
    List<TransactionJpaEntity> findBySyncedAtAfterOrderByOccurredAtDesc(OffsetDateTime since);
}
