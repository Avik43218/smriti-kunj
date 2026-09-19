package com.example.patient_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivitySpeech"
        private const val CHANNEL_NAME = "com.smritikunj.patient_app/speech_recognition"
        private const val ALARM_CHANNEL_NAME = "com.smritikunj.patient_app/alarm"
        private const val ALARM_TAG = "MainActivityAlarm"
        private const val PERMISSION_REQUEST_CODE = 4201
    }

    private var methodChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isListening = false
    private var currentLanguage = "en-US"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        val alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL_NAME)
        alarmChannel.setMethodCallHandler { call, result ->
            handleAlarmMethodCall(call, result)
        }
    }

    private fun getOrCreateSpeechRecognizer(): SpeechRecognizer? {
        if (speechRecognizer != null) {
            return speechRecognizer
        }

        return try {
            // Query available recognition services on the device
            val services = packageManager.queryIntentServices(
                Intent(RecognitionService.SERVICE_INTERFACE),
                0
            )

            Log.d(TAG, "Found ${services.size} speech recognition service(s)")
            // Prefer Google Speech Recognition service if available, else system default
            val googleService = services.firstOrNull {
                it.serviceInfo.packageName.contains("google", ignoreCase = true)
            }

            val recognizer = if (googleService != null) {
                val componentName = ComponentName(googleService.serviceInfo.packageName, googleService.serviceInfo.name)
                Log.d(TAG, "Creating SpeechRecognizer with component: $componentName")
                SpeechRecognizer.createSpeechRecognizer(this, componentName)
            } else {
                Log.d(TAG, "Creating default SpeechRecognizer")
                SpeechRecognizer.createSpeechRecognizer(this)
            }

            recognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    isListening = true
                    notifyFlutter("onSpeechStateChanged", mapOf("state" to "ready"))
                }

                override fun onBeginningOfSpeech() {
                    isListening = true
                    notifyFlutter("onSpeechStateChanged", mapOf("state" to "listening"))
                }

                override fun onRmsChanged(rmsdB: Float) {
                    notifyFlutter("onRmsChanged", mapOf("rms" to rmsdB.toDouble()))
                }

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    isListening = false
                    notifyFlutter("onSpeechStateChanged", mapOf("state" to "processing"))
                }

                override fun onError(errorCode: Int) {
                    isListening = false
                    val errorMessage = getErrorDescription(errorCode)
                    Log.w(TAG, "SpeechRecognizer error: $errorCode - $errorMessage")
                    notifyFlutter("onSpeechError", mapOf(
                        "code" to errorCode,
                        "message" to errorMessage
                    ))
                }

                override fun onResults(results: Bundle?) {
                    isListening = false
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?: arrayListOf()
                    val scores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                        ?.map { it.toDouble() } ?: emptyList<Double>()

                    Log.d(TAG, "onResults: $matches")
                    notifyFlutter("onSpeechResult", mapOf(
                        "results" to matches,
                        "scores" to scores
                    ))
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?: arrayListOf()
                    notifyFlutter("onPartialResult", mapOf(
                        "results" to matches
                    ))
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            speechRecognizer = recognizer
            speechRecognizer
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing SpeechRecognizer", e)
            null
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                val available = SpeechRecognizer.isRecognitionAvailable(this)
                result.success(available)
            }
            "hasPermission" -> {
                val hasPerm = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED
                result.success(hasPerm)
            }
            "requestPermission" -> {
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(true)
                } else {
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        PERMISSION_REQUEST_CODE
                    )
                }
            }
            "startListening" -> {
                val language = call.argument<String>("language") ?: currentLanguage
                currentLanguage = language
                startListeningInternal(language, result)
            }
            "stopListening" -> {
                stopListeningInternal(result)
            }
            "cancel" -> {
                cancelInternal(result)
            }
            else -> result.notImplemented()
        }
    }

    private fun startListeningInternal(language: String, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("UNAVAILABLE", "Speech recognizer is not available on this device", null)
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "Microphone permission is required", null)
            return
        }

        mainHandler.post {
            try {
                val recognizer = getOrCreateSpeechRecognizer()
                if (recognizer == null) {
                    result.error("INIT_FAILED", "Failed to obtain SpeechRecognizer", null)
                    return@post
                }

                try {
                    recognizer.cancel()
                } catch (_: Exception) {}

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, language)
                    putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, language)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                }

                recognizer.startListening(intent)
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "startListening error", e)
                tearDownRecognizer()
                result.error("START_FAILED", "Failed to start speech recognition: ${e.message}", null)
            }
        }
    }

    private fun stopListeningInternal(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                isListening = false
                result.success(true)
            } catch (e: Exception) {
                result.error("STOP_FAILED", "Failed to stop listening: ${e.message}", null)
            }
        }
    }

    private fun cancelInternal(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                speechRecognizer?.cancel()
                isListening = false
                notifyFlutter("onSpeechStateChanged", mapOf("state" to "idle"))
                result.success(true)
            } catch (e: Exception) {
                result.error("CANCEL_FAILED", "Failed to cancel speech recognition: ${e.message}", null)
            }
        }
    }

    private fun tearDownRecognizer() {
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {
        } finally {
            speechRecognizer = null
            isListening = false
        }
    }

    private fun notifyFlutter(method: String, arguments: Any?) {
        mainHandler.post {
            methodChannel?.invokeMethod(method, arguments)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun handleAlarmMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAlarmSupported" -> {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                result.success(alarmManager != null)
            }
            "setDeviceAlarm" -> {
                val reminderId = call.argument<String>("reminderId") ?: call.argument<String>("id") ?: ""
                val label = call.argument<String>("label") ?: "Daily Reminder"
                val hour = (call.argument<Number>("hour"))?.toInt() ?: 8
                val minute = (call.argument<Number>("minute"))?.toInt() ?: 0
                val date = call.argument<String>("date")
                val isRecurring = call.argument<Boolean>("isRecurring") ?: true

                val success = scheduleAlarm(reminderId, label, hour, minute, date, isRecurring)
                result.success(mapOf(
                    "success" to success,
                    "reminderId" to reminderId,
                    "label" to label,
                    "hour" to hour,
                    "minute" to minute,
                    "everyday" to isRecurring
                ))
            }
            "setDailyAlarms" -> {
                val alarmsList = call.argument<List<Map<String, Any>>>("alarms") ?: emptyList()

                var scheduledCount = 0
                for (item in alarmsList) {
                    val reminderId = (item["reminderId"] as? String) ?: (item["id"] as? String) ?: ""
                    val label = (item["label"] as? String) ?: (item["title"] as? String) ?: "Daily Reminder"
                    val hour = (item["hour"] as? Number)?.toInt() ?: 8
                    val minute = (item["minute"] as? Number)?.toInt() ?: 0
                    val date = item["date"] as? String
                    val isRecurring = (item["isRecurring"] as? Boolean) ?: true

                    val success = scheduleAlarm(reminderId, label, hour, minute, date, isRecurring)
                    if (success) scheduledCount++
                }

                result.success(mapOf(
                    "success" to true,
                    "scheduledCount" to scheduledCount,
                    "everyday" to true
                ))
            }
            "cancelByRequestCode" -> {
                val requestCode = (call.argument<Number>("requestCode"))?.toInt()
                if (requestCode != null) {
                    val success = cancelAlarm(requestCode)
                    result.success(mapOf("success" to success, "requestCode" to requestCode))
                } else {
                    result.error("INVALID_ARGUMENT", "requestCode is required", null)
                }
            }
            "cancelOnce" -> {
                val reminderId = call.argument<String>("reminderId") ?: ""
                val date = call.argument<String>("date")
                val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: getRequestCode(reminderId, date)
                val success = cancelAlarm(requestCode)
                result.success(mapOf("success" to success, "requestCode" to requestCode))
            }
            "cancelRecurring" -> {
                val reminderId = call.argument<String>("reminderId") ?: ""
                val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: getRequestCode(reminderId, null)
                val success = cancelAlarm(requestCode)
                result.success(mapOf("success" to success, "requestCode" to requestCode))
            }
            "deleteAlarm" -> {
                val reminderId = call.argument<String>("reminderId") ?: ""
                val date = call.argument<String>("date")
                val recurringCode = (call.argument<Number>("requestCode"))?.toInt() ?: getRequestCode(reminderId, null)
                val successRecurring = cancelAlarm(recurringCode)
                if (!date.isNullOrEmpty()) {
                    cancelAlarm(getRequestCode(reminderId, date))
                }
                result.success(mapOf("success" to successRecurring, "requestCode" to recurringCode))
            }
            else -> result.notImplemented()
        }
    }

    private fun getRequestCode(reminderId: String, date: String? = null): Int {
        val key = if (!date.isNullOrEmpty()) "$reminderId$date" else reminderId
        return key.hashCode() and 0x7FFFFFFF
    }

    private fun scheduleAlarm(
        reminderId: String,
        label: String,
        hour: Int,
        minute: Int,
        date: String? = null,
        isRecurring: Boolean = true
    ): Boolean {
        return try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val requestCode = getRequestCode(reminderId, date)

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            val intent = Intent(this, AlarmReceiver::class.java).apply {
                action = "com.smritikunj.patient_app.ALARM_TRIGGER"
                putExtra("reminder_id", reminderId)
                putExtra("label", label)
                putExtra("hour", hour)
                putExtra("minute", minute)
                putExtra("request_code", requestCode)
                putExtra("is_recurring", isRecurring)
                putExtra("date", date)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }

            Log.d(ALARM_TAG, "Scheduled AlarmManager: '$label' (id=$reminderId, code=$requestCode) at ${calendar.time}")
            true
        } catch (e: Exception) {
            Log.e(ALARM_TAG, "Failed to schedule alarm for '$label': ${e.message}", e)
            false
        }
    }

    private fun cancelAlarm(requestCode: Int): Boolean {
        return try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, AlarmReceiver::class.java).apply {
                action = "com.smritikunj.patient_app.ALARM_TRIGGER"
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(ALARM_TAG, "Cancelled alarm with requestCode=$requestCode")
            } else {
                Log.d(ALARM_TAG, "No pending alarm found for requestCode=$requestCode")
            }
            true
        } catch (e: Exception) {
            Log.e(ALARM_TAG, "Failed to cancel alarm for requestCode=$requestCode: ${e.message}", e)
            false
        }
    }

    open class AlarmReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val reminderId = intent.getStringExtra("reminder_id") ?: ""
            val label = intent.getStringExtra("label") ?: "Reminder"
            val hour = intent.getIntExtra("hour", 8)
            val minute = intent.getIntExtra("minute", 0)
            val isRecurring = intent.getBooleanExtra("is_recurring", false)
            val requestCode = intent.getIntExtra("request_code", 0)

            Log.d("MainActivityAlarm", "Alarm triggered: id=$reminderId, label='$label', requestCode=$requestCode")

            if (isRecurring && reminderId.isNotEmpty()) {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                if (alarmManager != null) {
                    val nextCalendar = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, hour)
                        set(Calendar.MINUTE, minute)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                        add(Calendar.DAY_OF_YEAR, 1)
                    }

                    val nextPendingIntent = PendingIntent.getBroadcast(
                        context,
                        requestCode,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                nextCalendar.timeInMillis,
                                nextPendingIntent
                            )
                        } else {
                            alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                nextCalendar.timeInMillis,
                                nextPendingIntent
                            )
                        }
                        Log.d("MainActivityAlarm", "Rescheduled recurring alarm for tomorrow at ${nextCalendar.time}")
                    } catch (e: Exception) {
                        Log.e("MainActivityAlarm", "Failed to reschedule recurring alarm: ${e.message}", e)
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        tearDownRecognizer()
        super.onDestroy()
    }

    private fun getErrorDescription(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side recognition error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions (Microphone required)"
            SpeechRecognizer.ERROR_NETWORK -> "Network communication error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech match found"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognition engine is busy"
            SpeechRecognizer.ERROR_SERVER -> "Server recognition error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input detected within timeout"
            10 -> "Too many requests to speech recognizer"
            11 -> "Server disconnected"
            12 -> "Language not supported by recognizer"
            13 -> "Language data unavailable"
            14 -> "Cannot check speech recognition support"
            else -> "Speech recognition error ($errorCode)"
        }
    }
}
