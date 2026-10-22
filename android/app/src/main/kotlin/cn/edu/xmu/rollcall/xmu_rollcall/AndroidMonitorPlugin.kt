package cn.edu.xmu.rollcall.xmu_rollcall

import android.app.Notification
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Small public-API adapter, installed in both UI and foreground-task engines. */
class AndroidMonitorPlugin(private val worker: Boolean = false) :
    FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var active = true
    private var lastCountdown: List<Any?>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "xmu_rollcall/monitor")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        deactivate()
        channel.setMethodCallHandler(null)
    }

    fun deactivate() { active = false }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "updateCountdown" -> result.success(updateCountdown(call))
                "backgroundSettings" -> {
                    val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "batteryExempt" to power.isIgnoringBatteryOptimizations(context.packageName)
                    ))
                }
                "openAppDetails" -> {
                    open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:${context.packageName}")))
                    result.success(null)
                }
                "openChannelSettings" -> {
                    val appSettings = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    val channelId = call.argument<String>("channelId")
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channelId != null) {
                        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    } else appSettings
                    try { open(intent) } catch (_: ActivityNotFoundException) { open(appSettings) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("monitor_platform_error", error.message, null)
        }
    }

    private fun open(intent: Intent) {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun updateCountdown(call: MethodCall): Boolean {
        // An engine being destroyed must never recreate or change the next run's notice.
        if (!worker || !active) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.activeNotifications.firstOrNull { it.id == 2601 && it.tag == null }
            ?: return false
        if (existing.notification.flags and Notification.FLAG_FOREGROUND_SERVICE == 0) return false
        val deadline = call.argument<Number>("deadlineMs")?.toLong()
        val title = call.argument<String>("title") ?: return false
        val text = call.argument<String>("text") ?: return false
        val countdown = deadline != null && deadline > System.currentTimeMillis()
        val signature = listOf(title, text, deadline, countdown)
        if (signature == lastCountdown &&
            existing.notification.`when` == (deadline ?: 0L) &&
            existing.notification.extras.getString(Notification.EXTRA_TEXT) == text &&
            existing.notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER) == countdown
        ) return true

        // Recover the service-owned notice: preserve its content intent, icon and Stop action.
        // Android renders the ticking clock; Dart does not repost a notification every second.
        val notification = NotificationCompat.Builder(context, existing.notification)
            .apply {
                // The recovery constructor retains this extra in some AndroidX versions.
                // Remove it so an old false value cannot override setUsesChronometer(true).
                extras.remove(Notification.EXTRA_SHOW_CHRONOMETER)
            }
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setWhen(deadline ?: 0L)
            .setShowWhen(countdown)
            .setUsesChronometer(countdown)
            .setChronometerCountDown(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setOngoing(true)
            .build()
        notification.flags = notification.flags or Notification.FLAG_FOREGROUND_SERVICE
        manager.notify(2601, notification)
        lastCountdown = signature
        return true
    }
}
