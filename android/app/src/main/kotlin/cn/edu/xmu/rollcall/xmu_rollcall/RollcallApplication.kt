package cn.edu.xmu.rollcall.xmu_rollcall

import android.app.Application
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine

class RollcallApplication : Application(), FlutterForegroundTaskLifecycleListener {
    private var workerPlugin: AndroidMonitorPlugin? = null

    override fun onCreate() {
        super.onCreate()
        // Register even when Android restores the service without creating an Activity.
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(this)
    }

    override fun onEngineCreate(flutterEngine: FlutterEngine?) {
        workerPlugin?.deactivate()
        val plugin = AndroidMonitorPlugin(worker = true)
        workerPlugin = plugin
        flutterEngine?.plugins?.add(plugin)
    }

    override fun onTaskDestroy() {
        workerPlugin?.deactivate()
        workerPlugin = null
    }

    override fun onEngineWillDestroy() = onTaskDestroy()
    override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}
    override fun onTaskRepeatEvent() {}
}
