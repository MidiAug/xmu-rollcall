package cn.edu.xmu.rollcall.xmu_rollcall

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class AppUpdateInstaller(private val activity: Activity) : MethodChannel.MethodCallHandler {
    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "installApk") { result.notImplemented(); return }
        try {
            val path = call.argument<String>("path") ?: error("安装包路径缺失")
            val file = File(path).canonicalFile
            val root = File(activity.cacheDir, "updates").canonicalFile
            require(file.path.startsWith(root.path + File.separator) && file.isFile && file.extension == "apk") {
                "安装包不在更新缓存中，请重新下载"
            }
            val pm = activity.packageManager
            val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
            val archive = pm.getPackageArchiveInfo(file.path, flags) ?: error("安装包无法解析，请重新下载")
            val installed = pm.getPackageInfo(activity.packageName, flags)
            require(archive.packageName == activity.packageName) { "安装包与当前应用不匹配，请查看发布页" }
            val newer = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode > installed.longVersionCode
                        else archive.versionCode > installed.versionCode
            require(newer) { "安装包构建号未递增，无法覆盖更新" }
            require(compatibleSignature(installed, archive)) { "新版签名与当前应用不兼容，请联系维护者；不要卸载现有应用" }
            if (Build.VERSION.SDK_INT >= 26 && !pm.canRequestPackageInstalls()) {
                activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                result.success("permission_required")
                return
            }
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
            activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            })
            result.success("launched")
        } catch (error: Exception) {
            result.error("update_install", error.message ?: "无法打开系统安装器", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun compatibleSignature(installed: PackageInfo, archive: PackageInfo): Boolean {
        if (Build.VERSION.SDK_INT >= 28) {
            val current = installed.signingInfo?.apkContentsSigners ?: return false
            val candidate = archive.signingInfo ?: return false
            if (candidate.hasMultipleSigners() || installed.signingInfo?.hasMultipleSigners() == true) {
                return current.toSet() == candidate.apkContentsSigners.toSet()
            }
            return current.isNotEmpty() && candidate.signingCertificateHistory?.toList()?.containsAll(current.toList()) == true
        }
        return !installed.signatures.isNullOrEmpty() && installed.signatures?.toSet() == archive.signatures?.toSet()
    }
}
