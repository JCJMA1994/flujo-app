package com.flujo.backend.adapter.in.web;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.flujo.backend.adapter.out.persistence.SpringDataUserRepository;
import com.flujo.backend.adapter.out.persistence.UserJpaEntity;
import com.flujo.backend.application.service.JwtTokenService;
import com.flujo.backend.application.service.PasswordService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/v1/auth")
public class AuthController {

    private final SpringDataUserRepository userRepository;
    private final PasswordService passwordService;
    private final JwtTokenService jwtTokenService;

    public AuthController(
        SpringDataUserRepository userRepository,
        PasswordService passwordService,
        JwtTokenService jwtTokenService
    ) {
        this.userRepository = userRepository;
        this.passwordService = passwordService;
        this.jwtTokenService = jwtTokenService;
    }

    public record RegisterRequest(
        @NotBlank @Email String email,
        @NotBlank @Size(min = 6) String password,
        @NotBlank String name
    ) {}

    public record LoginRequest(
        @NotBlank @Email String email,
        @NotBlank String password
    ) {}

    public record UserDto(
        String id,
        String email,
        String name,
        @JsonProperty("created_at") String createdAt
    ) {}

    public record AuthResponse(
        String token,
        UserDto user
    ) {}

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        String normalizedEmail = request.email().trim().toLowerCase();

        if (userRepository.existsByEmail(normalizedEmail)) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("error", "El correo ya se encuentra registrado"));
        }

        String salt = passwordService.generateSalt();
        String hash = passwordService.hashPassword(request.password(), salt);
        String userId = UUID.randomUUID().toString();
        OffsetDateTime now = OffsetDateTime.now();

        UserJpaEntity entity = new UserJpaEntity(
            userId,
            normalizedEmail,
            hash,
            salt,
            request.name().trim(),
            now
        );

        userRepository.save(entity);

        String token = jwtTokenService.generateToken(userId, normalizedEmail, entity.getName());
        UserDto userDto = new UserDto(userId, normalizedEmail, entity.getName(), now.toString());

        return ResponseEntity.status(HttpStatus.CREATED).body(new AuthResponse(token, userDto));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        String normalizedEmail = request.email().trim().toLowerCase();
        Optional<UserJpaEntity> userOpt = userRepository.findByEmail(normalizedEmail);

        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "Credenciales inválidas"));
        }

        UserJpaEntity user = userOpt.get();
        boolean validPassword = passwordService.verifyPassword(request.password(), user.getSalt(), user.getPasswordHash());

        if (!validPassword) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "Credenciales inválidas"));
        }

        String token = jwtTokenService.generateToken(user.getId(), user.getEmail(), user.getName());
        UserDto userDto = new UserDto(user.getId(), user.getEmail(), user.getName(), user.getCreatedAt().toString());

        return ResponseEntity.ok(new AuthResponse(token, userDto));
    }

    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(HttpServletRequest request) {
        String userId = (String) request.getAttribute(AuthFilter.ATTR_USER_ID);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", "No autenticado"));
        }

        return userRepository.findById(userId)
            .map(user -> ResponseEntity.ok(new UserDto(user.getId(), user.getEmail(), user.getName(), user.getCreatedAt().toString())))
            .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }
}
