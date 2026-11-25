package co.edu.usc.rondo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Al prender el celular (o actualizar la app), Rondó vuelve a quedar pendiente. */
class ArranqueReceiver : BroadcastReceiver() {
    override fun onReceive(contexto: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        if (!ServicioFondo.preferencias(contexto).getBoolean("activo", false)) return
        try {
            ContextCompat.startForegroundService(contexto, Intent(contexto, ServicioFondo::class.java))
        } catch (_: Exception) {
            // Android no lo dejó arrancar: quedará activo al abrir la app.
        }
    }
}
