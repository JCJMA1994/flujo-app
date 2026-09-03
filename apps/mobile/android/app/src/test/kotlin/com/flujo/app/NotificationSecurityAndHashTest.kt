package com.flujo.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.MessageDigest

class NotificationSecurityAndHashTest {

    private val authorizedBankPackages = setOf(
        "pe.com.bcp.bank.bcp",
        "com.bcp.innovacxion.yapeapp",
        "pe.com.bcp.innovacxion.yapeapp",
        "com.bcp.yape",
        "pe.interbank.appnew",
        "pe.plin.app",
        "com.bbva.pe.bbvacontigo",
        "pe.scotiabank.banking",
        "pe.com.banbif.android",
        "pe.com.banbif.banbifmovil",
        "com.pichincha.pe",
        "pe.com.cajapiura.pexpe",
        "com.pexpe.app",
        "pe.interbank.tunki",
        "com.tunki.app",
        "pe.com.cajaarequipa.agora",
        "pe.com.cajahuancayo.migente",
        "com.mercadopago.wallet",
        "com.mercadolibre.wallet",
        "pe.com.maximo.app",
        "com.maximo.wallet",
        "ar.com.lemon",
        "com.lemoncash.app",
        "com.grability.rappi"
    )

    private fun computeSha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    @Test
    fun shouldAcceptOnlyWhitelistedPackages() {
        assertTrue(authorizedBankPackages.contains("com.bcp.innovacxion.yapeapp"))
        assertTrue(authorizedBankPackages.contains("pe.plin.app"))
        assertTrue(authorizedBankPackages.contains("com.bbva.pe.bbvacontigo"))

        // Apps de mensajería y redes deben ser rechazadas categóricamente
        assertFalse(authorizedBankPackages.contains("com.whatsapp"))
        assertFalse(authorizedBankPackages.contains("org.telegram.messenger"))
        assertFalse(authorizedBankPackages.contains("com.google.android.apps.messaging"))
        assertFalse(authorizedBankPackages.contains("com.google.android.gm"))
    }

    @Test
    fun shouldGenerateIdenticalHashWithinSame15SecondBucket() {
        val pkg = "com.bcp.innovacxion.yapeapp"
        val title = "Yape"
        val body = "Juan te envió S/ 25.00"

        val time1 = 1725390000000L // t = 0s
        val time2 = 1725390005000L // t = +5s (mismo bucket de 15s)

        val bucket1 = time1 / 15000L
        val bucket2 = time2 / 15000L

        assertEquals(bucket1, bucket2)

        val hash1 = computeSha256("$pkg|$title|$body|$bucket1")
        val hash2 = computeSha256("$pkg|$title|$body|$bucket2")

        assertEquals(hash1, hash2)
    }

    @Test
    fun shouldGenerateDifferentHashForDifferentBuckets() {
        val pkg = "com.bcp.innovacxion.yapeapp"
        val title = "Yape"
        val body = "Juan te envió S/ 25.00"

        val time1 = 1725390000000L // bucket N
        val time2 = 1725390020000L // bucket N + 1 (+20s después)

        val bucket1 = time1 / 15000L
        val bucket2 = time2 / 15000L

        assertNotEquals(bucket1, bucket2)

        val hash1 = computeSha256("$pkg|$title|$body|$bucket1")
        val hash2 = computeSha256("$pkg|$title|$body|$bucket2")

        assertNotEquals(hash1, hash2)
    }
}
