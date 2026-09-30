package com.example.zentoryapp

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.provider.CalendarContract
import java.util.TimeZone

/**
 * Respaldo de las alertas de vencimiento en el calendario del teléfono.
 *
 * Cuando el usuario cierra Zentory deslizándola en Recientes, sistemas como
 * ColorOS la "detienen a la fuerza" y Android cancela todas sus alarmas. El
 * calendario del sistema no se cierra nunca, así que sus recordatorios siguen
 * llegando aunque Zentory esté cerrada.
 *
 * Se usa un calendario **local** propio ("Zentory - Vencimientos") que no se
 * sincroniza con ninguna cuenta; cada sincronización lo vacía y vuelve a crear
 * los eventos, así nunca quedan eventos viejos o duplicados.
 */
object CalendarBackup {
    private const val ACCOUNT_NAME = "Zentory"
    private const val CALENDAR_NAME = "zentory_vencimientos"
    private const val DISPLAY_NAME = "Zentory - Vencimientos"
    private const val COLOR = 0xFF10B981.toInt()

    private fun asSyncAdapter(uri: Uri): Uri = uri.buildUpon()
        .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
        .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
        .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
        .build()

    private fun findCalendarId(context: Context): Long? {
        val cursor = context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            "${CalendarContract.Calendars.ACCOUNT_NAME} = ? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE} = ? AND " +
                "${CalendarContract.Calendars.NAME} = ?",
            arrayOf(ACCOUNT_NAME, CalendarContract.ACCOUNT_TYPE_LOCAL, CALENDAR_NAME),
            null,
        ) ?: return null
        cursor.use { return if (it.moveToFirst()) it.getLong(0) else null }
    }

    private fun getOrCreateCalendarId(context: Context): Long {
        findCalendarId(context)?.let { return it }
        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.NAME, CALENDAR_NAME)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, DISPLAY_NAME)
            put(CalendarContract.Calendars.CALENDAR_COLOR, COLOR)
            put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER)
            put(CalendarContract.Calendars.OWNER_ACCOUNT, ACCOUNT_NAME)
            put(CalendarContract.Calendars.VISIBLE, 1)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
            put(CalendarContract.Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
        }
        val uri = context.contentResolver.insert(
            asSyncAdapter(CalendarContract.Calendars.CONTENT_URI),
            values,
        ) ?: throw IllegalStateException("No se pudo crear el calendario de Zentory")
        return uri.lastPathSegment!!.toLong()
    }

    private fun clearEvents(context: Context, calendarId: Long) {
        context.contentResolver.delete(
            asSyncAdapter(CalendarContract.Events.CONTENT_URI),
            "${CalendarContract.Events.CALENDAR_ID} = ?",
            arrayOf(calendarId.toString()),
        )
    }

    /**
     * Reemplaza todos los eventos del calendario de Zentory.
     * Cada evento: title, description, startMillis y reminders (minutos antes).
     * Devuelve cuántos eventos se crearon.
     */
    fun sync(context: Context, events: List<Map<String, Any?>>): Int {
        val calendarId = getOrCreateCalendarId(context)
        clearEvents(context, calendarId)
        val tz = TimeZone.getDefault().id
        var created = 0
        for (e in events) {
            val start = (e["startMillis"] as? Number)?.toLong() ?: continue
            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calendarId)
                put(CalendarContract.Events.TITLE, e["title"] as? String ?: "Vencimiento")
                put(CalendarContract.Events.DESCRIPTION, e["description"] as? String ?: "")
                put(CalendarContract.Events.DTSTART, start)
                put(CalendarContract.Events.DTEND, start + 30 * 60 * 1000L)
                put(CalendarContract.Events.EVENT_TIMEZONE, tz)
                put(CalendarContract.Events.HAS_ALARM, 1)
            }
            val uri = context.contentResolver.insert(
                asSyncAdapter(CalendarContract.Events.CONTENT_URI),
                values,
            ) ?: continue
            val eventId = uri.lastPathSegment?.toLongOrNull() ?: continue
            @Suppress("UNCHECKED_CAST")
            val reminders = (e["reminders"] as? List<Number>) ?: listOf(0)
            for (minutes in reminders) {
                val r = ContentValues().apply {
                    put(CalendarContract.Reminders.EVENT_ID, eventId)
                    put(CalendarContract.Reminders.MINUTES, minutes.toInt())
                    put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
                }
                context.contentResolver.insert(asSyncAdapter(CalendarContract.Reminders.CONTENT_URI), r)
            }
            created++
        }
        return created
    }

    /** Borra el calendario de Zentory con todos sus eventos. */
    fun remove(context: Context): Boolean {
        val id = findCalendarId(context) ?: return true
        context.contentResolver.delete(
            asSyncAdapter(CalendarContract.Calendars.CONTENT_URI),
            "${CalendarContract.Calendars._ID} = ?",
            arrayOf(id.toString()),
        )
        return true
    }
}
