package com.flujo.backend.adapter.in.web;

import com.flujo.backend.adapter.out.persistence.SpringDataUserRepository;
import com.flujo.backend.adapter.out.persistence.UserJpaEntity;
import com.flujo.backend.application.service.JwtTokenService;
import com.flujo.backend.application.service.PasswordService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AuthController.class)
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private SpringDataUserRepository userRepository;

    @MockBean
    private PasswordService passwordService;

    @MockBean
    private JwtTokenService jwtTokenService;

    @Test
    void shouldRegisterNewUserSuccessfully() throws Exception {
        when(userRepository.existsByEmail("test@flujo.com")).thenReturn(false);
        when(passwordService.generateSalt()).thenReturn("random-salt");
        when(passwordService.hashPassword(eq("password123"), eq("random-salt"))).thenReturn("hashed-pass");
        when(jwtTokenService.generateToken(any(), eq("test@flujo.com"), eq("Usuario Demo"))).thenReturn("jwt-token-xyz");

        String registerJson = """
            {
                "email": "test@flujo.com",
                "password": "password123",
                "name": "Usuario Demo"
            }
            """;

        mockMvc.perform(post("/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(registerJson))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.token").value("jwt-token-xyz"))
            .andExpect(jsonPath("$.user.email").value("test@flujo.com"))
            .andExpect(jsonPath("$.user.name").value("Usuario Demo"));
    }

    @Test
    void shouldLoginExistingUserSuccessfully() throws Exception {
        UserJpaEntity user = new UserJpaEntity(
            "user-abc",
            "test@flujo.com",
            "hashed-pass",
            "salt",
            "Usuario Demo",
            OffsetDateTime.now()
        );

        when(userRepository.findByEmail("test@flujo.com")).thenReturn(Optional.of(user));
        when(passwordService.verifyPassword("password123", "salt", "hashed-pass")).thenReturn(true);
        when(jwtTokenService.generateToken("user-abc", "test@flujo.com", "Usuario Demo")).thenReturn("jwt-token-xyz");

        String loginJson = """
            {
                "email": "test@flujo.com",
                "password": "password123"
            }
            """;

        mockMvc.perform(post("/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginJson))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.token").value("jwt-token-xyz"))
            .andExpect(jsonPath("$.user.email").value("test@flujo.com"));
    }

    @Test
    void shouldReturnCurrentUserWhenAuthenticated() throws Exception {
        UserJpaEntity user = new UserJpaEntity(
            "user-abc",
            "test@flujo.com",
            "hash",
            "salt",
            "Usuario Demo",
            OffsetDateTime.now()
        );

        when(userRepository.findById("user-abc")).thenReturn(Optional.of(user));

        mockMvc.perform(get("/v1/auth/me")
                .requestAttr(AuthFilter.ATTR_USER_ID, "user-abc"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value("user-abc"))
            .andExpect(jsonPath("$.email").value("test@flujo.com"));
    }
}
