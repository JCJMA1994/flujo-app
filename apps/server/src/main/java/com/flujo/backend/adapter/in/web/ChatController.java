package com.flujo.backend.adapter.in.web;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.flujo.backend.application.service.FinancialAdvisorService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/v1/chat")
public class ChatController {

    private final FinancialAdvisorService financialAdvisorService;

    public ChatController(FinancialAdvisorService financialAdvisorService) {
        this.financialAdvisorService = financialAdvisorService;
    }

    public record ChatQueryRequest(
        @NotBlank @JsonProperty("query") String query
    ) {}

    public record ChatQueryResponse(
        String answer,
        @JsonProperty("suggested_chips") List<String> suggestedChips
    ) {}

    @PostMapping("/query")
    public ResponseEntity<ChatQueryResponse> query(
        @Valid @RequestBody ChatQueryRequest request,
        HttpServletRequest httpRequest
    ) {
        String userId = (String) httpRequest.getAttribute(AuthFilter.ATTR_USER_ID);
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }

        FinancialAdvisorService.AdvisorResponse response = financialAdvisorService.answerQuery(userId, request.query());

        return ResponseEntity.ok(new ChatQueryResponse(
            response.answer(),
            response.suggestedChips()
        ));
    }
}
