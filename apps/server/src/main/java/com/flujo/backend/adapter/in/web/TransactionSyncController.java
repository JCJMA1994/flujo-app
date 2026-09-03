package com.flujo.backend.adapter.in.web;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.flujo.backend.adapter.out.persistence.TransactionJpaEntity;
import com.flujo.backend.application.service.TransactionSyncService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/v1/transactions")
public class TransactionSyncController {

    private final TransactionSyncService syncService;

    public TransactionSyncController(TransactionSyncService syncService) {
        this.syncService = syncService;
    }

    public record SyncRequest(
        List<Map<String, Object>> transactions
    ) {}

    public record SyncResponse(
        List<String> acknowledged,
        List<String> conflicts
    ) {}

    @PostMapping("/sync")
    public ResponseEntity<SyncResponse> sync(@RequestBody SyncRequest request) {
        List<String> ack = syncService.syncTransactions(
            request.transactions() != null ? request.transactions() : Collections.emptyList()
        );

        return ResponseEntity.ok(new SyncResponse(ack, Collections.emptyList()));
    }

    @GetMapping
    public ResponseEntity<List<TransactionJpaEntity>> getTransactions(
        @RequestParam(name = "since", required = false)
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime since
    ) {
        OffsetDateTime queryTime = since != null ? since : OffsetDateTime.MIN;
        List<TransactionJpaEntity> result = syncService.getTransactionsSince(queryTime);
        return ResponseEntity.ok(result);
    }
}
