package com.flujo.backend.adapter.in.web;

import com.flujo.backend.adapter.out.persistence.TransactionJpaEntity;
import com.flujo.backend.application.service.TransactionSyncService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TransactionSyncController.class)
class TransactionSyncControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private TransactionSyncService syncService;

    @Test
    void shouldAcknowledgeSyncedTransactions() throws Exception {
        when(syncService.syncTransactions(any())).thenReturn(List.of("tx-123", "tx-456"));

        String requestJson = """
            {
                "transactions": [
                    {"id": "tx-123", "amount": 10.5, "currency": "PEN"},
                    {"id": "tx-456", "amount": 20.0, "currency": "PEN"}
                ]
            }
            """;

        mockMvc.perform(post("/v1/transactions/sync")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.acknowledged[0]").value("tx-123"))
            .andExpect(jsonPath("$.acknowledged[1]").value("tx-456"))
            .andExpect(jsonPath("$.conflicts").isArray());
    }

    @Test
    void shouldReturnTransactionsSinceGivenTimestamp() throws Exception {
        TransactionJpaEntity entity = new TransactionJpaEntity();
        entity.setId("tx-789");
        entity.setAmount(100.0);
        entity.setCurrency("PEN");
        entity.setMerchant("Supermercado Metro");

        when(syncService.getTransactionsSince(any())).thenReturn(List.of(entity));

        mockMvc.perform(get("/v1/transactions")
                .param("since", "2026-09-01T00:00:00Z"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].id").value("tx-789"))
            .andExpect(jsonPath("$[0].merchant").value("Supermercado Metro"))
            .andExpect(jsonPath("$[0].amount").value(100.0));
    }
}
