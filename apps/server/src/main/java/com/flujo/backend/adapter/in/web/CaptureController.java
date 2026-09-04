package com.flujo.backend.adapter.in.web;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.flujo.backend.application.service.TransactionInterpretationService;
import com.flujo.backend.domain.model.InterpretationResult;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.format.DateTimeFormatter;

@RestController
@RequestMapping("/v1/capture")
public class CaptureController {

    private final TransactionInterpretationService interpretationService;

    public CaptureController(TransactionInterpretationService interpretationService) {
        this.interpretationService = interpretationService;
    }

    public record InterpretRequest(
        @NotBlank @JsonProperty("raw_text") String rawText,
        @JsonProperty("package_name") String packageName
    ) {}

    public record InterpretResponse(
        Double amount,
        String currency,
        String merchant,
        @JsonProperty("occurred_at") String occurredAt,
        @JsonProperty("category_id") String categoryId,
        @JsonProperty("bank_id") String bankId,
        Double confidence,
        String type
    ) {}

    @PostMapping("/interpret")
    public ResponseEntity<InterpretResponse> interpret(@RequestBody InterpretRequest request) {
        InterpretationResult result = interpretationService.interpret(
            request.rawText(),
            request.packageName()
        );

        String occurredAtStr = result.occurredAt() != null
            ? result.occurredAt().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
            : null;

        InterpretResponse response = new InterpretResponse(
            result.amount(),
            result.currency(),
            result.merchant(),
            occurredAtStr,
            result.categoryId(),
            result.bankId(),
            result.confidence(),
            result.type()
        );

        return ResponseEntity.ok(response);
    }

    public record InterpretImageRequest(
        @NotBlank @JsonProperty("image_base64") String imageBase64,
        @JsonProperty("mime_type") String mimeType
    ) {}

    @PostMapping("/interpret-image")
    public ResponseEntity<InterpretResponse> interpretImage(@RequestBody InterpretImageRequest request) {
        byte[] imageBytes;
        try {
            imageBytes = java.util.Base64.getDecoder().decode(request.imageBase64());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        }

        InterpretationResult result = interpretationService.interpretImage(
            imageBytes,
            request.mimeType()
        );

        String occurredAtStr = result.occurredAt() != null
            ? result.occurredAt().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
            : null;

        InterpretResponse response = new InterpretResponse(
            result.amount(),
            result.currency(),
            result.merchant(),
            occurredAtStr,
            result.categoryId(),
            result.bankId(),
            result.confidence(),
            result.type()
        );

        return ResponseEntity.ok(response);
    }
}
