package co.edu.usc.rondo

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * El motor de Flutter (todo el código Dart de Rondó) vive aparte de la pantalla.
 *
 * Así, si la persona quita la app de las recientes, la pantalla se destruye
 * pero el motor sigue: [ServicioFondo] lo mantiene vivo y Rondó sigue vigilando
 * caídas o esperando alertas. Al volver a abrir, la pantalla se conecta al
 * mismo motor.
 */
object Motor {
    const val ID = "rondo"

    @Synchronized
    fun obtener(contexto: Context, argumentos: Array<String>? = null): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }

        val app = contexto.applicationContext
        val motor = FlutterEngine(app, argumentos)
        val mensajero = motor.dartExecutor.binaryMessenger
        MethodChannel(mensajero, "rondo/sms").setMethodCallHandler(CanalSms(app))
        MethodChannel(mensajero, "rondo/fondo").setMethodCallHandler(CanalFondo(app))
        motor.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, motor)
        return motor
    }
}
