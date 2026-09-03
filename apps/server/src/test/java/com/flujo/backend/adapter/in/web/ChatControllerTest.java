package com.flujo.backend.adapter.in.web;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.flujo.backend.application.service.FinancialAdvisorService;
import com.flujo.backend.application.service.JwtTokenService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ChatController.class)
class ChatControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private FinancialAdvisorService financialAdvisorService;

    @MockBean
    private JwtTokenService jwtTokenService;

    @Test
    void queryRechazaPeticionSinToken() throws Exception {
        ChatController.ChatQueryRequest request = new ChatController.ChatQueryRequest("¿Cuánto gasté?");

        mockMvc.perform(post("/v1/chat/query")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void queryRespondeExitosamenteConTokenValido() throws Exception {
        when(jwtTokenService.validateToken("valid-token")).thenReturn(
            Optional.of(new JwtTokenService.JwtClaims("user-123", "user@flujo.com", System.currentTimeMillis()))
        );

        when(financialAdvisorService.answerQuery(eq("user-123"), any()))
            .thenReturn(new FinancialAdvisorService.AdvisorResponse(
                "Gastaste S/ 500 este mes.",
                List.of("¿Cuánto en comida?")
            ));

        ChatController.ChatQueryRequest request = new ChatController.ChatQueryRequest("¿Cuánto gasté este mes?");

        mockMvc.perform(post("/v1/chat/query")
                .header("Authorization", "Bearer valid-token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.answer").value("Gastaste S/ 500 este mes."))
            .andExpect(jsonPath("$.suggested_chips[0]").value("¿Cuánto en comida?"));
    }
}
