package com.flujo.backend.adapter.in.web;

import com.flujo.backend.application.service.JwtTokenService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Optional;

@Component
@Order(1)
public class AuthFilter extends OncePerRequestFilter {

    public static final String ATTR_USER_ID = "currentUserId";
    public static final String ATTR_USER_EMAIL = "currentUserEmail";

    private final JwtTokenService jwtTokenService;

    public AuthFilter(JwtTokenService jwtTokenService) {
        this.jwtTokenService = jwtTokenService;
    }

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain filterChain
    ) throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7).trim();
            Optional<JwtTokenService.JwtClaims> claims = jwtTokenService.validateToken(token);

            if (claims.isPresent()) {
                request.setAttribute(ATTR_USER_ID, claims.get().userId());
                request.setAttribute(ATTR_USER_EMAIL, claims.get().email());
            }
        }

        String path = request.getRequestURI();
        // Rutas que requieren autenticación estricta obligatoria
        if (requiresAuthentication(path, request.getMethod())) {
            if (request.getAttribute(ATTR_USER_ID) == null) {
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType("application/json");
                response.getWriter().write("{\"error\": \"No autorizado. Se requiere token Bearer válido.\"}");
                return;
            }
        }

        filterChain.doFilter(request, response);
    }

    private boolean requiresAuthentication(String path, String method) {
        if (path.startsWith("/v1/transactions")) {
            return true;
        }
        if (path.startsWith("/v1/chat")) {
            return true;
        }
        if (path.equals("/v1/auth/me")) {
            return true;
        }
        return false;
    }
}
