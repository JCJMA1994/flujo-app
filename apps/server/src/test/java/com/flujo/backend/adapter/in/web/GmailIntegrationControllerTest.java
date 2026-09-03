package com.flujo.backend.adapter.in.web;

import com.flujo.backend.adapter.out.persistence.UserIntegrationJpaEntity;
import com.flujo.backend.application.service.GmailService;
import com.flujo.backend.application.service.JwtTokenService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;
import java.util.Optional;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(GmailIntegrationController.class)
class GmailIntegrationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private GmailService gmailService;

    @MockBean
    private JwtTokenService jwtTokenService;

    @Test
    void connectRechazaPeticionSinToken() throws Exception {
        mockMvc.perform(get("/v1/integrations/gmail/connect"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void connectDevuelveAuthUrlConTokenValido() throws Exception {
        when(jwtTokenService.validateToken("valid-token")).thenReturn(
            Optional.of(new JwtTokenService.JwtClaims("user-123", "user@flujo.com", "Juan"))
        );

        when(gmailService.buildAuthorizationUrl("user-123")).thenReturn("https://accounts.google.com/o/oauth2/v2/auth?test=1");

        mockMvc.perform(get("/v1/integrations/gmail/connect")
                .header("Authorization", "Bearer valid-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.auth_url").value("https://accounts.google.com/o/oauth2/v2/auth?test=1"));
    }

    @Test
    void statusDevuelveEstadoConectado() throws Exception {
        when(jwtTokenService.validateToken("valid-token")).thenReturn(
            Optional.of(new JwtTokenService.JwtClaims("user-123", "user@flujo.com", "Juan"))
        );

        UserIntegrationJpaEntity entity = new UserIntegrationJpaEntity(
            "int-1", "user-123", "GMAIL", "acc-token", "ref-token",
            OffsetDateTime.now().plusHours(1), "user@gmail.com", "hist-1", true, OffsetDateTime.now()
        );

        when(gmailService.getStatus("user-123")).thenReturn(Optional.of(entity));

        mockMvc.perform(get("/v1/integrations/gmail/status")
                .header("Authorization", "Bearer valid-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.connected").value(true))
            .andExpect(jsonPath("$.email").value("user@gmail.com"));
    }

    @Test
    void disconnectDesactivaIntegracion() throws Exception {
        when(jwtTokenService.validateToken("valid-token")).thenReturn(
            Optional.of(new JwtTokenService.JwtClaims("user-123", "user@flujo.com", "Juan"))
        );

        mockMvc.perform(delete("/v1/integrations/gmail/disconnect")
                .header("Authorization", "Bearer valid-token"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.message").isNotEmpty());
    }
}
