package com.flujo.backend.application.service;

import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Component
public class EmailExpenseParser {

    public record ParsedEmailExpense(
        double amount,
        String currency,
        String merchant,
        String categoryId,
        String type,
        OffsetDateTime occurredAt
    ) {}

    // Patrones de regex bancarios para correos
    private static final Pattern PATTERN_BCP_CONSUMO = Pattern.compile(
        "(?:consumo|compra|pago)(?:\\s+con\\s+tarjeta)?(?:\\s+por)?\\s+(?:de\\s+)?(S/\\.?|\\$|USD)\\s*([0-9]+(?:\\.[0-9]{2})?)\\s+en\\s+([^\\n\\r.,]+)",
        Pattern.CASE_INSENSITIVE
    );

    private static final Pattern PATTERN_BCP_TRANSFERENCIA = Pattern.compile(
        "(?:transferencia|enviaste|pagaste)\\s+(?:de\\s+)?(S/\\.?|\\$|USD)\\s*([0-9]+(?:\\.[0-9]{2})?)\\s+a\\s+([^\\n\\r.,]+)",
        Pattern.CASE_INSENSITIVE
    );

    private static final Pattern PATTERN_INTERBANK = Pattern.compile(
        "(?:operaci[oó]n|consumo|pago)\\s+(?:de\\s+)?(S/\\.?|\\$|USD)\\s*([0-9]+(?:\\.[0-9]{2})?)\\s+en\\s+([^\\n\\r.,]+)",
        Pattern.CASE_INSENSITIVE
    );

    private static final Pattern PATTERN_BBVA = Pattern.compile(
        "(?:pago|compra|cargo)\\s+(?:de\\s+)?(S/\\.?|\\$|USD)\\s*([0-9]+(?:\\.[0-9]{2})?)\\s+en\\s+([^\\n\\r.,]+)",
        Pattern.CASE_INSENSITIVE
    );

    private static final Pattern PATTERN_YAPE_ENVIO = Pattern.compile(
        "(?:enviaste|yapeaste|pago)\\s+(?:un\\s+yape\\s+de\\s+)?(S/\\.?)\\s*([0-9]+(?:\\.[0-9]{2})?)\\s+a\\s+([^\\n\\r.,]+)",
        Pattern.CASE_INSENSITIVE
    );

    private static final Pattern PATTERN_YAPE_INGRESO = Pattern.compile(
        "(?:[¡!]?\\s*te\\s+acaban\\s+de\\s+yapear|recibiste\\s+un\\s+yape)[!.]?\\s+(?:de\\s+)?(S/\\.?)\\s*([0-9]+(?:\\.[0-9]{2})?)\\s+(?:de\\s+)?([^\\n\\r.,]+)?",
        Pattern.CASE_INSENSITIVE
    );

    public Optional<ParsedEmailExpense> parse(String from, String subject, String body) {
        if (from == null || body == null) {
            return Optional.empty();
        }

        String combined = (subject != null ? subject + " " : "") + body;
        String sender = from.toLowerCase();

        // 1. Yape
        if (sender.contains("yape") || combined.toLowerCase().contains("yape")) {
            Matcher mIngreso = PATTERN_YAPE_INGRESO.matcher(combined);
            if (mIngreso.find()) {
                double amount = Double.parseDouble(mIngreso.group(2));
                String person = mIngreso.group(3) != null ? mIngreso.group(3).trim() : "Yape Ingreso";
                return Optional.of(new ParsedEmailExpense(
                    amount, "PEN", person, "income", "income", OffsetDateTime.now()
                ));
            }

            Matcher mEnvio = PATTERN_YAPE_ENVIO.matcher(combined);
            if (mEnvio.find()) {
                double amount = Double.parseDouble(mEnvio.group(2));
                String person = mEnvio.group(3).trim();
                return Optional.of(new ParsedEmailExpense(
                    amount, "PEN", person, inferCategory(person), "expense", OffsetDateTime.now()
                ));
            }
        }

        // 2. BCP
        if (sender.contains("bcp") || sender.contains("bancodecredito")) {
            Matcher mConsumo = PATTERN_BCP_CONSUMO.matcher(combined);
            if (mConsumo.find()) {
                String currency = parseCurrency(mConsumo.group(1));
                double amount = Double.parseDouble(mConsumo.group(2));
                String merchant = cleanMerchant(mConsumo.group(3));
                return Optional.of(new ParsedEmailExpense(
                    amount, currency, merchant, inferCategory(merchant), "expense", OffsetDateTime.now()
                ));
            }

            Matcher mTransf = PATTERN_BCP_TRANSFERENCIA.matcher(combined);
            if (mTransf.find()) {
                String currency = parseCurrency(mTransf.group(1));
                double amount = Double.parseDouble(mTransf.group(2));
                String recipient = cleanMerchant(mTransf.group(3));
                return Optional.of(new ParsedEmailExpense(
                    amount, currency, recipient, inferCategory(recipient), "expense", OffsetDateTime.now()
                ));
            }
        }

        // 3. Interbank
        if (sender.contains("interbank")) {
            Matcher m = PATTERN_INTERBANK.matcher(combined);
            if (m.find()) {
                String currency = parseCurrency(m.group(1));
                double amount = Double.parseDouble(m.group(2));
                String merchant = cleanMerchant(m.group(3));
                return Optional.of(new ParsedEmailExpense(
                    amount, currency, merchant, inferCategory(merchant), "expense", OffsetDateTime.now()
                ));
            }
        }

        // 4. BBVA
        if (sender.contains("bbva")) {
            Matcher m = PATTERN_BBVA.matcher(combined);
            if (m.find()) {
                String currency = parseCurrency(m.group(1));
                double amount = Double.parseDouble(m.group(2));
                String merchant = cleanMerchant(m.group(3));
                return Optional.of(new ParsedEmailExpense(
                    amount, currency, merchant, inferCategory(merchant), "expense", OffsetDateTime.now()
                ));
            }
        }

        return Optional.empty();
    }

    private String parseCurrency(String symbol) {
        if (symbol == null) return "PEN";
        String s = symbol.trim().toUpperCase();
        if (s.contains("$") || s.contains("USD")) return "USD";
        return "PEN";
    }

    private String cleanMerchant(String raw) {
        if (raw == null) return "Comercio";
        String cleaned = raw.replaceAll("(?i)\\s+con\\s+(?:su|tu|la)?\\s*tarjeta.*", "")
                            .replaceAll("(?i)(POS|TARJETA|COMPROBANTE|NRO.*)", "")
                            .trim();
        return cleaned.isEmpty() ? "Comercio" : cleaned;
    }

    private String inferCategory(String merchant) {
        String m = merchant.toLowerCase();
        if (m.contains("restaurante") || m.contains("starbucks") || m.contains("bembos") || m.contains("rappi") || m.contains("pedidosya")) {
            return "food";
        }
        if (m.contains("metro") || m.contains("plaza vea") || m.contains("tottus") || m.contains("wong") || m.contains("vivanda")) {
            return "groceries";
        }
        if (m.contains("uber") || m.contains("cabify") || m.contains("didi") || m.contains("grifo") || m.contains("repsol") || m.contains("primax")) {
            return "transport";
        }
        if (m.contains("netflix") || m.contains("spotify") || m.contains("hbo") || m.contains("disney") || m.contains("cine")) {
            return "entertainment";
        }
        if (m.contains("luz") || m.contains("sedapal") || m.contains("claro") || m.contains("movistar") || m.contains("entel")) {
            return "services";
        }
        return "other";
    }
}
