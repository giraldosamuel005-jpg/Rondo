package co.edu.usc.rondo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // RF-15 / RF-16: SMS de alerta a los contactos, sin abrir la app de
        // mensajes (la persona puede estar inconsciente). Lo usa
        // lib/core/alertas/enviador_sms.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rondo/sms").setMethodCallHandler { llamada, resultado ->
            if (llamada.method != "enviar") {
                resultado.notImplemented()
                return@setMethodCallHandler
            }
            if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                resultado.error("sin-permiso", "Sin permiso de SMS", null)
                return@setMethodCallHandler
            }
            val numero = llamada.argument<String>("numero")
            val texto = llamada.argument<String>("texto")
            if (numero.isNullOrBlank() || texto.isNullOrBlank()) {
                resultado.error("datos", "Falta el número o el texto", null)
                return@setMethodCallHandler
            }
            try {
                val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    getSystemService(SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }
                // Con tildes cada SMS lleva 70 caracteres: se parte en varios.
                sms.sendMultipartTextMessage(numero, null, sms.divideMessage(texto), null, null)
                resultado.success(true)
            } catch (e: Exception) {
                resultado.error("fallo", e.message, null)
            }
        }
    }
}
