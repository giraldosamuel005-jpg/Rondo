package co.edu.usc.rondo

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Lo que Dart le pide al celular para el segundo plano (lib/core/fondo/). */
class CanalFondo(private val contexto: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(llamada: MethodCall, resultado: MethodChannel.Result) {
        try {
            when (llamada.method) {
                "iniciar" -> {
                    ServicioFondo.guardar(
                        contexto,
                        titulo = llamada.argument<String>("titulo") ?: "Rondó",
                        texto = llamada.argument<String>("texto") ?: "",
                        ubicacion = llamada.argument<Boolean>("ubicacion") ?: false,
                        despierto = llamada.argument<Boolean>("despierto") ?: false,
                    )
                    ContextCompat.startForegroundService(contexto, Intent(contexto, ServicioFondo::class.java))
                    resultado.success(true)
                }
                "detener" -> {
                    ServicioFondo.olvidar(contexto)
                    contexto.stopService(Intent(contexto, ServicioFondo::class.java))
                    resultado.success(true)
                }
                // La alerta se ve aunque el celular esté bloqueado; el resto
                // de la app, no.
                "sobreBloqueo" -> {
                    MainActivity.mostrarSobreBloqueo(llamada.argument<Boolean>("valor") ?: false)
                    resultado.success(true)
                }
                else -> resultado.notImplemented()
            }
        } catch (e: Exception) {
            // Por ejemplo, Android no deja iniciar el servicio desde el fondo.
            resultado.error("fondo", e.message, null)
        }
    }
}
