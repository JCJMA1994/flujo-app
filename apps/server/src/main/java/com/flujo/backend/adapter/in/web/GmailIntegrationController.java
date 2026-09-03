package com.flujo.backend.adapter.in.web;

import com.flujo.backend.adapter.out.persistence.UserIntegrationJpaEntity;
import com.flujo.backend.application.service.GmailService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/v1/integrations/gmail")
public class GmailIntegrationController {

    private final GmailService gmailService;

    public GmailIntegrationController(GmailService gmailService) {
        this.gmailService = gmailService;
    }

    public record GmailStatusResponse(
        boolean connected,
        String email
    ) {}

    @GetMapping("/connect")
    public ResponseEntity<Map<String, String>> connect(HttpServletRequest request) {
        String userId = (String) request.getAttribute(AuthFilter.ATTR_USER_ID);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }

        String authUrl = gmailService.buildAuthorizationUrl(userId);
        return ResponseEntity.ok(Map.of("auth_url", authUrl));
    }

    @GetMapping("/status")
    public ResponseEntity<GmailStatusResponse> status(HttpServletRequest request) {
        String userId = (String) request.getAttribute(AuthFilter.ATTR_USER_ID);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }

        Optional<UserIntegrationJpaEntity> statusOpt = gmailService.getStatus(userId);
        if (statusOpt.isPresent() && Boolean.TRUE.equals(statusOpt.get().getActive())) {
            return ResponseEntity.ok(new GmailStatusResponse(true, statusOpt.get().getEmail()));
        }

        return ResponseEntity.ok(new GmailStatusResponse(false, null));
    }

    @DeleteMapping("/disconnect")
    public ResponseEntity<Map<String, String>> disconnect(HttpServletRequest request) {
        String userId = (String) request.getAttribute(AuthFilter.ATTR_USER_ID);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }

        gmailService.disconnect(userId);
        return ResponseEntity.ok(Map.of("message", "Integración con Gmail desactivada"));
    }

    @GetMapping("/callback")
    public ResponseEntity<String> callback(
        @RequestParam("code") String code,
        @RequestParam(value = "state", required = false) String state
    ) {
        if (state == null || state.isBlank()) {
            return ResponseEntity.badRequest().body("Parámetro state inválido o ausente");
        }

        gmailService.handleOAuthCallback(code, state);

        String successHtml = """
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"><title>Gmail Conectado - Flujo</title></head>
            <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
              <h2>✅ ¡Gmail conectado exitosamente a Flujo!</h2>
              <p>Ya puedes volver a la aplicación móvil. Los comprobantes bancarios se capturarán automáticamente.</p>
            </body>
            </html>
            """;

        return ResponseEntity.ok().header("Content-Type", "text/html; charset=utf-8").body(successHtml);
    }
}
