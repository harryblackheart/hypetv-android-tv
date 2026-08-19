package tv.hype.hypetv

import android.content.ActivityNotFoundException
import android.content.Intent
import android.app.PictureInPictureParams
import android.util.Rational
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hypetv/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> installApk(call.argument("path"), result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hypetv/player")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPip" -> enterPip(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun enterPip(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("PIP_UNAVAILABLE", "Picture-in-picture requires Android 8 or newer.", null)
            return
        }
        try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
            result.success(null)
        } catch (error: Exception) {
            result.error("PIP_FAILED", error.message ?: "Picture-in-picture could not start.", null)
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("INVALID_APK", "The downloaded APK path was empty.", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
            ) {
                val packageSettings = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
                try {
                    startActivity(packageSettings)
                } catch (_: ActivityNotFoundException) {
                    startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                }
                result.error(
                    "INSTALL_PERMISSION_REQUIRED",
                    "Allow HypeTV to install unknown apps, then press Update now again.",
                    null
                )
                return
            }

            val file = File(path)
            if (!file.exists() || file.length() == 0L) {
                result.error("INVALID_APK", "The downloaded update file is missing.", null)
                return
            }
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file
            )

            val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = uri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                putExtra(Intent.EXTRA_RETURN_RESULT, false)
            }

            val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            when {
                installIntent.resolveActivity(packageManager) != null -> startActivity(installIntent)
                fallbackIntent.resolveActivity(packageManager) != null -> startActivity(fallbackIntent)
                else -> {
                    result.error(
                        "NO_PACKAGE_INSTALLER",
                        "This Android TV does not expose a package installer for in-app updates.",
                        null
                    )
                    return
                }
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("INSTALL_FAILED", error.message ?: "Update installer failed.", null)
        }
    }
}
