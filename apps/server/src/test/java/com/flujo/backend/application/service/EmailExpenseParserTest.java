package com.flujo.backend.application.service;

import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class EmailExpenseParserTest {

    private final EmailExpenseParser parser = new EmailExpenseParser();

    @Test
    void parseaConsumoBcp() {
        String from = "notificaciones@bcp.com.pe";
        String subject = "Aviso de Consumo con Tarjeta";
        String body = "Estimado cliente, registramos un consumo por S/ 45.90 en STARBUCKS con su tarjeta.";

        Optional<EmailExpenseParser.ParsedEmailExpense> result = parser.parse(from, subject, body);

        assertTrue(result.isPresent());
        assertEquals(45.90, result.get().amount());
        assertEquals("PEN", result.get().currency());
        assertEquals("STARBUCKS", result.get().merchant());
        assertEquals("food", result.get().categoryId());
        assertEquals("expense", result.get().type());
    }

    @Test
    void parseaTransferenciaBcpDolares() {
        String from = "notificaciones@bcp.com.pe";
        String subject = "Constancia de Transferencia";
        String body = "Has realizado una transferencia de $ 120.00 a Maria Ramos.";

        Optional<EmailExpenseParser.ParsedEmailExpense> result = parser.parse(from, subject, body);

        assertTrue(result.isPresent());
        assertEquals(120.00, result.get().amount());
        assertEquals("USD", result.get().currency());
        assertEquals("Maria Ramos", result.get().merchant());
        assertEquals("expense", result.get().type());
    }

    @Test
    void parseaIngresoYape() {
        String from = "contacto@yape.com.pe";
        String subject = "¡Te acaban de yapear!";
        String body = "¡Te acaban de yapear! S/ 35.50 de Carlos Diaz. Ya puedes usar tu dinero.";

        Optional<EmailExpenseParser.ParsedEmailExpense> result = parser.parse(from, subject, body);

        assertTrue(result.isPresent());
        assertEquals(35.50, result.get().amount());
        assertEquals("Carlos Diaz", result.get().merchant());
        assertEquals("income", result.get().categoryId());
        assertEquals("income", result.get().type());
    }

    @Test
    void parseaPagoBbva() {
        String from = "notificaciones@bbva.pe";
        String subject = "Notificación de pago";
        String body = "Has realizado un pago de S/ 89.90 en WONG.";

        Optional<EmailExpenseParser.ParsedEmailExpense> result = parser.parse(from, subject, body);

        assertTrue(result.isPresent());
        assertEquals(89.90, result.get().amount());
        assertEquals("WONG", result.get().merchant());
        assertEquals("groceries", result.get().categoryId());
    }

    @Test
    void descartaCorreosNoBancarios() {
        String from = "newsletter@medium.com";
        String subject = "Top stories for you";
        String body = "Here is what happened today in tech.";

        Optional<EmailExpenseParser.ParsedEmailExpense> result = parser.parse(from, subject, body);

        assertTrue(result.isEmpty());
    }
}
