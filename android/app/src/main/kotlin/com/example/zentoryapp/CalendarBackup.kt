package com.example.zentoryapp

import android.content.Context
import android.net.Uri
import android.provider.CalendarContract

/**
 * Limpieza del antiguo "respaldo en calendario" (versión 9 y 10 de la app).
 *
 * Esa función se retiró al pasar a notificaciones push (FCM). Este objeto solo
 * borra, una vez, el calendario local "Zentory - Vencimientos" que se hubiera
 * creado, para que sus recordatorios dejen de sonar.
 */
object CalendarBackup {
    private const val ACCOUNT_NAME = "Zentory"
    private const val CALENDAR_NAME = "zentory_vencimientos"

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
