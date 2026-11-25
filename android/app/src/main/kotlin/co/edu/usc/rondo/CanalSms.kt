package co.edu.usc.rondo

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * RF-15 / RF-16: SMS de alerta a los contactos, sin abrir la app de mensajes
 * (la persona puede estar inconsciente). Lo usa lib/core/alertas/aviso_alerta.dart.
 *
 * Responde cuando Android confirma que el SMS SALIÓ del celular (o que falló:
 * sin señal, sin saldo, modo avión). Así la app no dice "avisamos" sin saberlo.
 */
class CanalSms(private val contexto: Context) : MethodChannel.MethodCallHandler {
    private val principal = Handler(Looper.getMainLooper())

    override fun onMethodCall(llamada: MethodCall, resultado: MethodChannel.Result) {
        if (llamada.method != "enviar") {
            resultado.notImplemented()
            return
        }
        val permiso = ContextCompat.checkSelfPermission(contexto, Manifest.permission.SEND_SMS)
        if (permiso != PackageManager.PERMISSION_GRANTED) {
            resultado.error("sin-permiso", "Sin permiso de SMS", null)
            return
        }
        val numero = llamada.argument<String>("numero")
        val texto = llamada.argument<String>("texto")
        if (numero.isNullOrBlank() || texto.isNullOrBlank()) {
            resultado.error("datos", "Falta el número o el texto", null)
            return
        }
        try {
            enviar(numero, texto, resultado)
        } catch (e: Exception) {
            Log.w("Rondo", "SMS", e)
            resultado.error("fallo", e.message, null)
        }
    }

    private fun enviar(numero: String, texto: String, resultado: MethodChannel.Result) {
        val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            contexto.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val partes = partir(sms, texto)
        val accion = "${contexto.packageName}.SMS_${UUID.randomUUID()}"
        var faltan = partes.size
        var respondido = false
        lateinit var receptor: BroadcastReceiver

        fun responder(error: String?) {
            if (respondido) return
            respondido = true
            if (error != null) Log.w("Rondo", "SMS: $error")
            contexto.unregisterReceiver(receptor)
            if (error == null) resultado.success(true) else resultado.error("fallo", error, null)
        }

        receptor = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                if (resultCode != Activity.RESULT_OK) {
                    responder("No salió (código $resultCode)")
                } else if (--faltan == 0) {
                    responder(null)
                }
            }
        }
        ContextCompat.registerReceiver(
            contexto,
            receptor,
            IntentFilter(accion),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        val avisos = ArrayList(
            partes.indices.map { n ->
                PendingIntent.getBroadcast(
                    contexto,
                    n,
                    Intent(accion).setPackage(contexto.packageName),
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
                )
            },
        )
        try {
            sms.sendMultipartTextMessage(numero, null, partes, avisos, null)
        } catch (e: Exception) {
            responder(e.message ?: "No se pudo enviar")
            return
        }
        principal.postDelayed({ responder("Android no confirmó el envío") }, ESPERA_MS)
    }

    /**
     * Un SMS largo se manda en varias partes. Con tildes, en los Android nuevos
     * `divideMessage` exige un permiso de teléfono que Rondó no necesita y lanza
     * SecurityException: en ese caso se parte aquí.
     */
    private fun partir(sms: SmsManager, texto: String): ArrayList<String> = try {
        sms.divideMessage(texto)
    } catch (_: SecurityException) {
        ArrayList(if (texto.length <= UNA_PARTE) listOf(texto) else texto.chunked(CADA_PARTE))
    }

    private companion object {
        const val ESPERA_MS = 30_000L

        // Con tildes caben 70 caracteres en un SMS, o 67 si va en varias partes.
        const val UNA_PARTE = 70
        const val CADA_PARTE = 67
    }
}
