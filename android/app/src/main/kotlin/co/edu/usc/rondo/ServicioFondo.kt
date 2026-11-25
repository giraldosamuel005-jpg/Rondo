package co.edu.usc.rondo

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Servicio en primer plano: mantiene vivo a Rondó con la app cerrada o la
 * pantalla apagada. Muestra una notificación fija (Android lo exige, y así la
 * persona sabe que Rondó está pendiente).
 *
 * - Persona: sigue leyendo los sensores (RF-06) y compartiendo lo que decidió.
 * - Cuidador: sigue escuchando las alertas de las personas que cuida (RF-15).
 *
 * El trabajo lo hace el código Dart en [Motor]; esto solo evita que Android lo
 * apague. Si Android lo mata por falta de memoria, o se reinicia el celular,
 * vuelve a arrancar solo.
 */
class ServicioFondo : Service() {
    private var despierto: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val datos = preferencias(this)
        ponerEnPrimerPlano(
            titulo = datos.getString("titulo", "Rondó")!!,
            texto = datos.getString("texto", "")!!,
            ubicacion = datos.getBoolean("ubicacion", false),
        )
        if (!datos.getBoolean("activo", false)) {
            stopSelf()
            return START_NOT_STICKY
        }
        mantenerDespierto(datos.getBoolean("despierto", false))
        Motor.obtener(this) // Si Android mató el proceso, arranca Dart otra vez
        return START_STICKY
    }

    override fun onDestroy() {
        mantenerDespierto(false)
        super.onDestroy()
    }

    private fun ponerEnPrimerPlano(titulo: String, texto: String, ubicacion: Boolean) {
        val aviso = notificacion(titulo, texto)
        val conUbicacion = ubicacion && puedeUbicacion()
        val base = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE ->
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            else -> 0
        }
        if (conUbicacion && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                ServiceCompat.startForeground(this, ID, aviso, base or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
                return
            } catch (_: SecurityException) {
                // Arrancó desde el fondo (reinicio del celular): Android no deja
                // usar la ubicación así. Sigue sin ella hasta que abran la app.
            }
        }
        ServiceCompat.startForeground(this, ID, aviso, base)
    }

    private fun puedeUbicacion() = listOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    ).any { ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }

    private fun notificacion(titulo: String, texto: String): Notification {
        val gestor = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            gestor.createNotificationChannel(
                NotificationChannel(CANAL, "Rondó pendiente", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Muestra que Rondó sigue pendiente con la app cerrada."
                    setShowBadge(false)
                },
            )
        }
        val abrir = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CANAL)
            .setSmallIcon(R.drawable.ic_stat_rondo)
            .setContentTitle(titulo)
            .setContentText(texto)
            .setContentIntent(abrir)
            .setOngoing(true)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    /** Con la pantalla apagada, sin esto el procesador se duerme y no hay lecturas. */
    private fun mantenerDespierto(valor: Boolean) {
        val actual = despierto
        if (valor && actual == null) {
            despierto = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "rondo:ronda")
                .apply {
                    setReferenceCounted(false)
                    acquire()
                }
        } else if (!valor && actual != null) {
            if (actual.isHeld) actual.release()
            despierto = null
        }
    }

    companion object {
        private const val ID = 7001
        private const val CANAL = "ronda"

        fun preferencias(contexto: Context) =
            contexto.getSharedPreferences("rondo.fondo", Context.MODE_PRIVATE)

        /** Se guarda para poder arrancar igual después de un reinicio. */
        fun guardar(contexto: Context, titulo: String, texto: String, ubicacion: Boolean, despierto: Boolean) {
            preferencias(contexto).edit()
                .putBoolean("activo", true)
                .putString("titulo", titulo)
                .putString("texto", texto)
                .putBoolean("ubicacion", ubicacion)
                .putBoolean("despierto", despierto)
                .apply()
        }

        fun olvidar(contexto: Context) = preferencias(contexto).edit().clear().apply()
    }
}
