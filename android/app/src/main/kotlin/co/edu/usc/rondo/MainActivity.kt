package co.edu.usc.rondo

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterShellArgs
import java.lang.ref.WeakReference

// RF-02: la huella (local_auth) necesita una FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // El motor se crea antes que la pantalla, y la sobrevive (ver Motor).
        Motor.obtener(this, FlutterShellArgs.fromIntent(intent).toArray())
        super.onCreate(savedInstanceState)
        actual = WeakReference(this)
        aplicarBloqueo()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        aplicarBloqueo()
    }

    override fun getCachedEngineId(): String = Motor.ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    private fun aplicarBloqueo() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(sobreBloqueo)
            setTurnScreenOn(sobreBloqueo)
        } else {
            @Suppress("DEPRECATION")
            val banderas = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (sobreBloqueo) window.addFlags(banderas) else window.clearFlags(banderas)
        }
    }

    companion object {
        private var sobreBloqueo = false
        private var actual: WeakReference<MainActivity>? = null

        fun mostrarSobreBloqueo(valor: Boolean) {
            sobreBloqueo = valor
            actual?.get()?.let { pantalla -> pantalla.runOnUiThread { pantalla.aplicarBloqueo() } }
        }
    }
}
