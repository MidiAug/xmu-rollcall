package cn.edu.xmu.rollcall.xmu_rollcall

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Keep external share targets in their own task on Android/HyperOS.
    // The chooser still returns its result to this activity.
    private fun isolateShare(intent: Intent) {
        if (intent.action == Intent.ACTION_CHOOSER) {
            @Suppress("DEPRECATION")
            val target = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            if (target != null && (target.action == Intent.ACTION_SEND ||
                target.action == Intent.ACTION_SEND_MULTIPLE)) {
                target.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                intent.putExtra(Intent.EXTRA_INTENT, target)
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun startActivityForResult(intent: Intent, requestCode: Int) {
        isolateShare(intent)
        super.startActivityForResult(intent, requestCode)
    }

    override fun startActivity(intent: Intent) {
        isolateShare(intent)
        super.startActivity(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AndroidMonitorPlugin())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xmu_rollcall/update")
            .setMethodCallHandler(AppUpdateInstaller(this))
    }
}
