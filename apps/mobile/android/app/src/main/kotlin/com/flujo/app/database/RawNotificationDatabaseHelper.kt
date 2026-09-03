package com.flujo.app.database

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Almacén nativo de staging para notificaciones financieras crudas.
 * Opera de forma desacoplada de Flutter y Drift en modo WAL (Write-Ahead Logging),
 * garantizando persistencia inmediata y segura aun con el proceso de Flutter apagado.
 */
class RawNotificationDatabaseHelper private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "RawNotifDB"
        private const val DATABASE_NAME = "raw_capture.db"
        private const val DATABASE_VERSION = 1

        const val TABLE_NAME = "raw_notifications"
        const val COLUMN_ID = "id"
        const val COLUMN_KEY = "notification_key"
        const val COLUMN_HASH = "notification_hash"
        const val COLUMN_PACKAGE = "package_name"
        const val COLUMN_TITLE = "title"
        const val COLUMN_BODY = "body"
        const val COLUMN_POST_TIME = "post_time"
        const val COLUMN_STATUS = "status"
        const val COLUMN_CREATED_AT = "created_at"

        const val STATUS_RECEIVED = "RECEIVED"
        const val STATUS_PROCESSED = "PROCESSED"
        const val STATUS_FAILED = "FAILED"

        @Volatile
        private var instance: RawNotificationDatabaseHelper? = null

        fun getInstance(context: Context): RawNotificationDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: RawNotificationDatabaseHelper(context).also { instance = it }
            }
        }
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTableQuery = """
            CREATE TABLE $TABLE_NAME (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_KEY TEXT UNIQUE,
                $COLUMN_HASH TEXT UNIQUE,
                $COLUMN_PACKAGE TEXT NOT NULL,
                $COLUMN_TITLE TEXT,
                $COLUMN_BODY TEXT,
                $COLUMN_POST_TIME INTEGER NOT NULL,
                $COLUMN_STATUS TEXT NOT NULL DEFAULT '$STATUS_RECEIVED',
                $COLUMN_CREATED_AT INTEGER NOT NULL
            );
        """.trimIndent()

        db.execSQL(createTableQuery)
        db.execSQL("CREATE INDEX idx_raw_notif_status ON $TABLE_NAME($COLUMN_STATUS);")
        db.execSQL("CREATE INDEX idx_raw_notif_hash ON $TABLE_NAME($COLUMN_HASH);")
        Log.i(TAG, "Tabla $TABLE_NAME creada exitosamente con WAL")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // En staging, si se incrementa la versión se aplican migraciones aditivas
    }

    /**
     * Inserta una notificación cruda. Retorna el ID generado o -1 si ya existía por duplicidad de hash/key.
     */
    @Synchronized
    fun insertRawNotification(
        notificationKey: String,
        notificationHash: String,
        packageName: String,
        title: String?,
        body: String?,
        postTime: Long
    ): Long {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_KEY, notificationKey)
            put(COLUMN_HASH, notificationHash)
            put(COLUMN_PACKAGE, packageName)
            put(COLUMN_TITLE, title ?: "")
            put(COLUMN_BODY, body ?: "")
            put(COLUMN_POST_TIME, postTime)
            put(COLUMN_STATUS, STATUS_RECEIVED)
            put(COLUMN_CREATED_AT, System.currentTimeMillis())
        }

        return try {
            val id = db.insertWithOnConflict(TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_IGNORE)
            if (id != -1L) {
                Log.i(TAG, "Notificación RAW persistida: id=$id, pkg=$packageName")
            } else {
                Log.d(TAG, "Notificación descartada por duplicidad de hash: $notificationHash")
            }
            id
        } catch (e: Exception) {
            Log.e(TAG, "Error insertando notificación RAW", e)
            -1L
        }
    }

    /**
     * Obtiene hasta [limit] notificaciones en estado RECEIVED para ser consumidas por Flutter.
     */
    @Synchronized
    fun getPendingNotifications(limit: Int = 100): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val db = readableDatabase
        val query = """
            SELECT $COLUMN_ID, $COLUMN_KEY, $COLUMN_HASH, $COLUMN_PACKAGE, $COLUMN_TITLE, $COLUMN_BODY, $COLUMN_POST_TIME, $COLUMN_CREATED_AT
            FROM $TABLE_NAME
            WHERE $COLUMN_STATUS = '$STATUS_RECEIVED'
            ORDER BY $COLUMN_POST_TIME ASC
            LIMIT $limit
        """.trimIndent()

        db.rawQuery(query, null).use { cursor ->
            while (cursor.moveToNext()) {
                val map = mutableMapOf<String, Any>()
                map["id"] = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_ID))
                map["notificationKey"] = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_KEY)) ?: ""
                map["notificationHash"] = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_HASH)) ?: ""
                map["packageName"] = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_PACKAGE)) ?: ""
                map["title"] = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_TITLE)) ?: ""
                map["body"] = cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_BODY)) ?: ""
                map["postTime"] = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_POST_TIME))
                map["createdAt"] = cursor.getLong(cursor.getColumnIndexOrThrow(COLUMN_CREATED_AT))
                result.add(map)
            }
        }
        return result
    }

    /**
     * Marca un lote de notificaciones como procesadas exitosamente por Drift / Flutter.
     */
    @Synchronized
    fun markAsProcessed(ids: List<Long>) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        val idList = ids.joinToString(",")
        try {
            db.execSQL("UPDATE $TABLE_NAME SET $COLUMN_STATUS = '$STATUS_PROCESSED' WHERE $COLUMN_ID IN ($idList)")
            Log.i(TAG, "${ids.size} notificaciones marcadas como PROCESSED")
        } catch (e: Exception) {
            Log.e(TAG, "Error marcando notificaciones como procesadas", e)
        }
    }

    /**
     * Marca una notificación como fallida en caso de error de análisis o corrupción.
     */
    @Synchronized
    fun markAsFailed(id: Long) {
        val db = writableDatabase
        try {
            db.execSQL("UPDATE $TABLE_NAME SET $COLUMN_STATUS = '$STATUS_FAILED' WHERE $COLUMN_ID = $id")
        } catch (e: Exception) {
            Log.e(TAG, "Error marcando notificación $id como FAILED", e)
        }
    }

    /**
     * Retorna métricas de diagnóstico sin exponer datos sensibles.
     */
    @Synchronized
    fun getDiagnosticMetrics(): Map<String, Long> {
        val metrics = mutableMapOf<String, Long>()
        val db = readableDatabase
        val query = "SELECT $COLUMN_STATUS, COUNT(*) as count FROM $TABLE_NAME GROUP BY $COLUMN_STATUS"
        try {
            db.rawQuery(query, null).use { cursor ->
                while (cursor.moveToNext()) {
                    val status = cursor.getString(0)
                    val count = cursor.getLong(1)
                    metrics[status] = count
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error leyendo métricas de diagnóstico", e)
        }
        return metrics
    }
}
