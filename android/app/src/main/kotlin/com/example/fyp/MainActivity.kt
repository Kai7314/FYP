package com.example.fyp

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val emergencySmsChannelName = "com.example.fyp/emergency_sms"
    private val smsPermissionRequestCode = 9401
    private var pendingSms: PendingSms? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            emergencySmsChannelName
        ).setMethodCallHandler { call, result ->
            if (call.method != "sendSms") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val phone = call.argument<String>("phone")?.trim().orEmpty()
            val message = call.argument<String>("message")?.trim().orEmpty()
            sendEmergencySms(phone, message, result)
        }
    }

    private fun sendEmergencySms(
        phone: String,
        message: String,
        result: MethodChannel.Result
    ) {
        if (phone.isBlank()) {
            result.success(mapOf("sent" to false, "error" to "Missing phone number."))
            return
        }
        if (message.isBlank()) {
            result.success(mapOf("sent" to false, "error" to "Missing SMS message."))
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingSms = PendingSms(phone, message)
            pendingResult = result
            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), smsPermissionRequestCode)
            return
        }

        dispatchSms(phone, message, result)
    }

    private fun dispatchSms(phone: String, message: String, result: MethodChannel.Result) {
        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val messageParts = smsManager.divideMessage(message)
            smsManager.sendMultipartTextMessage(phone, null, messageParts, null, null)
            result.success(mapOf("sent" to true))
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "sent" to false,
                    "error" to (error.message ?: error.javaClass.simpleName)
                )
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermissionRequestCode) return

        val sms = pendingSms
        val result = pendingResult
        pendingSms = null
        pendingResult = null

        if (sms == null || result == null) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            dispatchSms(sms.phone, sms.message, result)
        } else {
            result.success(
                mapOf(
                    "sent" to false,
                    "error" to "SMS permission was denied."
                )
            )
        }
    }

    private data class PendingSms(
        val phone: String,
        val message: String
    )
}
