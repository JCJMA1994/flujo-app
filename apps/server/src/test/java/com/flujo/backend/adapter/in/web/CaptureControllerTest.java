package com.flujo.backend.adapter.in.web;

import com.flujo.backend.application.service.JwtTokenService;
import com.flujo.backend.application.service.TransactionInterpretationService;
import com.flujo.backend.domain.model.InterpretationResult;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(CaptureController.class)
class CaptureControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private TransactionInterpretationService interpretationService;

    @MockBean
    private JwtTokenService jwtTokenService;

    @Test
    void shouldReturnInterpretedTransactionSuccessfully() throws Exception {
        InterpretationResult mockResult = new InterpretationResult(
            25.50,
            "PEN",
            "La Lucha Sanguchería",
            OffsetDateTime.now(),
            "food",
            "yape",
            0.98,
            "expense"
        );

        when(jwtTokenService.validateToken(eq("valid-mock-token")))
            .thenReturn(java.util.Optional.of(new JwtTokenService.JwtClaims("user-1", "user@test.com", "Test User")));

        when(interpretationService.interpret(eq("Yapeaste S/ 25.50 a La Lucha"), eq("com.bcp.innovacxion.yapeapp")))
            .thenReturn(mockResult);

        String requestJson = """
            {
                "raw_text": "Yapeaste S/ 25.50 a La Lucha",
                "package_name": "com.bcp.innovacxion.yapeapp"
            }
            """;

        mockMvc.perform(post("/v1/capture/interpret")
                .header("Authorization", "Bearer valid-mock-token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestJson))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.amount").value(25.50))
            .andExpect(jsonPath("$.currency").value("PEN"))
            .andExpect(jsonPath("$.merchant").value("La Lucha Sanguchería"))
            .andExpect(jsonPath("$.category_id").value("food"))
            .andExpect(jsonPath("$.bank_id").value("yape"))
            .andExpect(jsonPath("$.confidence").value(0.98))
            .andExpect(jsonPath("$.type").value("expense"));
    }

    @Test
    void shouldRejectUnauthenticatedCaptureRequest() throws Exception {
        mockMvc.perform(post("/v1/capture/interpret")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"raw_text\": \"Yapeaste S/ 10\"}"))
            .andExpect(status().isUnauthorized());
    }
}
