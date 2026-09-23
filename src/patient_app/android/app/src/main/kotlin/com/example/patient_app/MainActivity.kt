package com.example.patient_app

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
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
        private const val NOTIF_PERMISSION_REQUEST_CODE = 4202

        // Fresh channel ID per requirements — never rename once created
        const val ALARM_NOTIFICATION_CHANNEL_ID = "smritikunj_reminder_v1"
        const val ALARM_NOTIFICATION_CHANNEL_NAME = "Medication & Daily Reminders"

        const val ACTION_ALARM_TRIGGER = "com.smritikunj.patient_app.ALARM_TRIGGER"
        const val ACTION_REMINDER_DONE = "com.smritikunj.patient_app.ACTION_REMINDER_DONE"

        fun getRequestCode(reminderId: String, date: String? = null): Int {
            val key = if (!date.isNullOrEmpty()) "$reminderId$date" else reminderId
            return key.hashCode() and 0x7FFFFFFF
        }

        fun getEscalationCode(requestCode: Int): Int = (requestCode xor 0x22222222) and 0x7FFFFFFF
        fun getMissedCode(requestCode: Int): Int = (requestCode xor 0x44444444) and 0x7FFFFFFF

        fun scheduleExactAlarm(
            context: Context,
            alarmManager: AlarmManager,
            triggerAtMillis: Long,
            pendingIntent: PendingIntent
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }
        }

        fun cancelSpecificAlarm(context: Context, alarmManager: AlarmManager, requestCode: Int) {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(ALARM_TAG, "Cancelled alarm intent for requestCode=$requestCode")
            }
        }

        fun isReminderCompleted(context: Context, reminderId: String): Boolean {
            var completed = false
            try {
                val dbFile = context.getDatabasePath("smriti_kunj_sessions.db")
                if (!dbFile.exists()) return false
                val db = SQLiteDatabase.openDatabase(
                    dbFile.absolutePath,
                    null,
                    SQLiteDatabase.OPEN_READONLY
                )
                val cursor = db.rawQuery(
                    "SELECT is_completed, status FROM patient_reminders WHERE id = ?",
                    arrayOf(reminderId)
                )
                if (cursor.moveToFirst()) {
                    val isComp = cursor.getInt(cursor.getColumnIndexOrThrow("is_completed"))
                    val statusIdx = cursor.getColumnIndex("status")
                    val status = if (statusIdx >= 0) cursor.getString(statusIdx) else null
                    completed = (isComp == 1) || (status == "done")
                }
                cursor.close()
                db.close()
            } catch (e: Exception) {
                Log.e(ALARM_TAG, "Error checking completion status for $reminderId: ${e.message}", e)
            }
            return completed
        }

        fun markReminderMissed(context: Context, reminderId: String) {
            Thread {
                try {
                    val dbFile = context.getDatabasePath("smriti_kunj_sessions.db")
                    if (!dbFile.exists()) return@Thread
                    val db = SQLiteDatabase.openDatabase(
                        dbFile.absolutePath,
                        null,
                        SQLiteDatabase.OPEN_READWRITE
                    )
                    try {
                        db.execSQL("ALTER TABLE patient_reminders ADD COLUMN status TEXT NOT NULL DEFAULT 'upcoming'")
                    } catch (_: Exception) {}

                    val values = ContentValues().apply {
                        put("is_completed", 0)
                        put("status", "missed")
                    }
                    val rows = db.update(
                        "patient_reminders",
                        values,
                        "id = ?",
                        arrayOf(reminderId)
                    )
                    db.close()
                    Log.d(ALARM_TAG, "Marked reminder $reminderId missed in SQLite (rows=$rows)")
                } catch (e: Exception) {
                    Log.e(ALARM_TAG, "Failed to mark reminder $reminderId missed: ${e.message}", e)
                }
            }.start()
        }

        fun markReminderDone(context: Context, reminderId: String) {
            Thread {
                try {
                    val dbFile = context.getDatabasePath("smriti_kunj_sessions.db")
                    if (!dbFile.exists()) return@Thread
                    val db = SQLiteDatabase.openDatabase(
                        dbFile.absolutePath,
                        null,
                        SQLiteDatabase.OPEN_READWRITE
                    )
                    try {
                        db.execSQL("ALTER TABLE patient_reminders ADD COLUMN status TEXT NOT NULL DEFAULT 'upcoming'")
                    } catch (_: Exception) {}

                    val values = ContentValues().apply {
                        put("is_completed", 1)
                        put("status", "done")
                    }
                    val rows = db.update(
                        "patient_reminders",
                        values,
                        "id = ?",
                        arrayOf(reminderId)
                    )
                    db.close()
                    Log.d(ALARM_TAG, "Marked reminder $reminderId done in SQLite (rows=$rows)")
                } catch (e: Exception) {
                    Log.e(ALARM_TAG, "Failed to mark reminder $reminderId done: ${e.message}", e)
                }
            }.start()
        }
    }

    private var methodChannel: MethodChannel? = null
    private var alarmMethodChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isListening = false
    private var currentLanguage = "en-US"
    private var isOnboardingInProgress = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        alarmMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL_NAME)
        alarmMethodChannel?.setMethodCallHandler { call, result ->
            handleAlarmMethodCall(call, result)
        }

        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        if (route == "/reminders") {
            mainHandler.postDelayed({
                alarmMethodChannel?.invokeMethod("onNavigate", mapOf("route" to "/reminders"))
            }, 300)
        }
    }

    // ── Stepwise Permission Onboarding Flow ──────────────────────────────────
    // Checks permissions and displays a 1-line plain-language explainer dialog
    // before each corresponding system prompt.
    override fun onResume() {
        super.onResume()
        notifyAlarmPermissionsStatus(allGranted = areAllAlarmPermissionsGranted())
        // Continue the onboarding sequence if the user just returned from Settings
        if (isOnboardingInProgress) {
            mainHandler.postDelayed({
                checkAndRequestNextPermission()
            }, 350)
        }
    }

    private fun areAllAlarmPermissionsGranted(): Boolean {
        return isNotifGranted() && isExactGranted() && isBatteryGranted()
    }

    private fun isNotifGranted(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun isExactGranted(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            (getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
    }

    private fun isBatteryGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager == null || powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun notifyAlarmPermissionsStatus(allGranted: Boolean) {
        mainHandler.post {
            alarmMethodChannel?.invokeMethod(
                "onPermissionsStatus",
                mapOf(
                    "allGranted" to allGranted,
                    "notif" to isNotifGranted(),
                    "exact" to isExactGranted(),
                    "battery" to isBatteryGranted()
                )
            )
        }
    }

    private fun checkAndRequestNextPermission() {
        val ctx = this

        // Step 1: POST_NOTIFICATIONS (Android 13+)
        if (!isNotifGranted()) {
            isOnboardingInProgress = true
            showPermissionExplainer(
                title = "Allow Notifications",
                oneLineReason = "Smriti Kunj needs notification permission to alert you when it's time for medication."
            ) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        NOTIF_PERMISSION_REQUEST_CODE
                    )
                }
            }
            return
        }

        // Step 2: SCHEDULE_EXACT_ALARM (Android 12+)
        if (!isExactGranted()) {
            isOnboardingInProgress = true
            showPermissionExplainer(
                title = "Allow Exact Alarms",
                oneLineReason = "Smriti Kunj needs exact alarm permission so your reminders ring at the exact minute."
            ) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.fromParts("package", packageName, null)
                        })
                    } catch (e: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            })
                        } catch (_: Exception) {}
                    }
                }
            }
            return
        }

        // Step 3: Battery Optimization Exemption (Android 6+)
        if (!isBatteryGranted()) {
            isOnboardingInProgress = true
            showPermissionExplainer(
                title = "Allow Background Running",
                oneLineReason = "Smriti Kunj needs background running permission so your alarms are never delayed by battery saving."
            ) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        })
                    } catch (e: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        } catch (_: Exception) {}
                    }
                }
            }
            return
        }

        // All granted
        isOnboardingInProgress = false
        notifyAlarmPermissionsStatus(allGranted = true)
    }

    private fun showPermissionExplainer(
        title: String,
        oneLineReason: String,
        onProceed: () -> Unit
    ) {
        val ctx = this
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(64, 52, 64, 44)
            setBackgroundColor(Color.parseColor("#FFFBF5EA")) // cream
        }

        val titleView = TextView(ctx).apply {
            text = title
            textSize = 20f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(Color.parseColor("#2E2A24"))
        }

        val reasonView = TextView(ctx).apply {
            text = oneLineReason
            textSize = 15f
            setTextColor(Color.parseColor("#6B625A"))
            setPadding(0, 20, 0, 32)
            setLineSpacing(5f, 1f)
        }

        val btn = Button(ctx).apply {
            text = "Continue"
            textSize = 16f
            setTypeface(null, android.graphics.Typeface.BOLD)
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#B5562F")) // terracotta
        }

        root.addView(titleView)
        root.addView(reasonView)
        root.addView(btn)

        val dialog = android.app.AlertDialog.Builder(ctx)
            .setView(root)
            .setCancelable(false)
            .create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btn.setOnClickListener {
            dialog.dismiss()
            onProceed()
        }
        dialog.show()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
            }
            NOTIF_PERMISSION_REQUEST_CODE -> {
                // Notifications step complete, continue to exact alarm or battery step
                mainHandler.postDelayed({
                    checkAndRequestNextPermission()
                }, 300)
            }
        }
    }

    // ── Speech Recognizer Implementation ─────────────────────────────────────
    private fun getOrCreateSpeechRecognizer(): SpeechRecognizer? {
        if (speechRecognizer != null) {
            return speechRecognizer
        }

        return try {
            val services = packageManager.queryIntentServices(
                Intent(RecognitionService.SERVICE_INTERFACE),
                0
            )

            Log.d(TAG, "Found ${services.size} speech recognition service(s)")
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

    // ── Alarm MethodChannel Handlers ─────────────────────────────────────────
    private fun handleAlarmMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAlarmSupported" -> {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                result.success(alarmManager != null)
            }
            "checkPermissions" -> {
                result.success(mapOf(
                    "allGranted" to areAllAlarmPermissionsGranted(),
                    "notif" to isNotifGranted(),
                    "exact" to isExactGranted(),
                    "battery" to isBatteryGranted()
                ))
            }
            "requestPermissions" -> {
                checkAndRequestNextPermission()
                result.success(null)
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
                action = ACTION_ALARM_TRIGGER
                putExtra("reminder_id", reminderId)
                putExtra("label", label)
                putExtra("hour", hour)
                putExtra("minute", minute)
                putExtra("request_code", requestCode)
                putExtra("is_recurring", isRecurring)
                putExtra("trigger_type", "primary")
                putExtra("date", date)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            scheduleExactAlarm(this, alarmManager, calendar.timeInMillis, pendingIntent)

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
            cancelSpecificAlarm(this, alarmManager, requestCode)
            cancelSpecificAlarm(this, alarmManager, getEscalationCode(requestCode))
            cancelSpecificAlarm(this, alarmManager, getMissedCode(requestCode))

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(requestCode)

            Log.d(ALARM_TAG, "Cancelled alarm + escalation + missed for requestCode=$requestCode")
            true
        } catch (e: Exception) {
            Log.e(ALARM_TAG, "Failed to cancel alarm for requestCode=$requestCode: ${e.message}", e)
            false
        }
    }

    // ── AlarmReceiver: Fires Scheduled Notifications & Escalations ───────────
    open class AlarmReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val reminderId = intent.getStringExtra("reminder_id") ?: ""
            val label = intent.getStringExtra("label") ?: "Medication Reminder"
            val hour = intent.getIntExtra("hour", 8)
            val minute = intent.getIntExtra("minute", 0)
            val isRecurring = intent.getBooleanExtra("is_recurring", false)
            val requestCode = intent.getIntExtra("request_code", 0)
            val triggerType = intent.getStringExtra("trigger_type") ?: "primary"
            val date = intent.getStringExtra("date")

            Log.d(ALARM_TAG, "AlarmReceiver fired: id=$reminderId, label='$label', code=$requestCode, triggerType=$triggerType")

            when (triggerType) {
                "escalation" -> {
                    if (isReminderCompleted(context, reminderId)) {
                        Log.d(ALARM_TAG, "Escalation alarm: reminder '$label' ($reminderId) already done. Skipping.")
                        return
                    }
                    Log.d(ALARM_TAG, "Escalation alarm: reminder '$label' ($reminderId) still pending. Re-firing heads-up notification.")
                    postHeadsUpNotification(context, reminderId, label, hour, minute, requestCode)
                }
                "missed_timeout" -> {
                    if (isReminderCompleted(context, reminderId)) {
                        Log.d(ALARM_TAG, "Missed timeout alarm: reminder '$label' ($reminderId) already done. Skipping.")
                        return
                    }
                    Log.d(ALARM_TAG, "Missed timeout alarm: marking reminder '$label' ($reminderId) as missed in SQLite.")
                    markReminderMissed(context, reminderId)
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    nm?.cancel(requestCode)
                }
                else -> { // "primary"
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

                    // 1. Reschedule recurring alarm for tomorrow at the original time
                    if (isRecurring && reminderId.isNotEmpty() && alarmManager != null) {
                        val nextCalendar = Calendar.getInstance().apply {
                            set(Calendar.HOUR_OF_DAY, hour)
                            set(Calendar.MINUTE, minute)
                            set(Calendar.SECOND, 0)
                            set(Calendar.MILLISECOND, 0)
                            add(Calendar.DAY_OF_YEAR, 1)
                        }
                        val nextIntent = Intent(context, AlarmReceiver::class.java).apply {
                            action = ACTION_ALARM_TRIGGER
                            putExtra("reminder_id", reminderId)
                            putExtra("label", label)
                            putExtra("hour", hour)
                            putExtra("minute", minute)
                            putExtra("request_code", requestCode)
                            putExtra("is_recurring", true)
                            putExtra("trigger_type", "primary")
                            putExtra("date", date)
                        }
                        val nextPendingIntent = PendingIntent.getBroadcast(
                            context,
                            requestCode,
                            nextIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        try {
                            scheduleExactAlarm(context, alarmManager, nextCalendar.timeInMillis, nextPendingIntent)
                            Log.d(ALARM_TAG, "Rescheduled recurring alarm for tomorrow at ${nextCalendar.time}")
                        } catch (e: Exception) {
                            Log.e(ALARM_TAG, "Failed to reschedule recurring alarm: ${e.message}", e)
                        }
                    }

                    // 2. Schedule 10-minute escalation alarm
                    if (alarmManager != null && reminderId.isNotEmpty()) {
                        val escCode = getEscalationCode(requestCode)
                        val escTime = System.currentTimeMillis() + (10 * 60 * 1000L) // +10 minutes
                        val escIntent = Intent(context, AlarmReceiver::class.java).apply {
                            action = ACTION_ALARM_TRIGGER
                            putExtra("reminder_id", reminderId)
                            putExtra("label", label)
                            putExtra("hour", hour)
                            putExtra("minute", minute)
                            putExtra("request_code", requestCode)
                            putExtra("is_recurring", false)
                            putExtra("trigger_type", "escalation")
                            putExtra("date", date)
                        }
                        val escPendingIntent = PendingIntent.getBroadcast(
                            context,
                            escCode,
                            escIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        try {
                            scheduleExactAlarm(context, alarmManager, escTime, escPendingIntent)
                            Log.d(ALARM_TAG, "Scheduled 10-min escalation alarm (code=$escCode)")
                        } catch (e: Exception) {
                            Log.e(ALARM_TAG, "Failed to schedule escalation alarm: ${e.message}", e)
                        }

                        // 3. Schedule 30-minute auto-missed timeout alarm
                        val missedCode = getMissedCode(requestCode)
                        val missedTime = System.currentTimeMillis() + (30 * 60 * 1000L) // +30 minutes
                        val missedIntent = Intent(context, AlarmReceiver::class.java).apply {
                            action = ACTION_ALARM_TRIGGER
                            putExtra("reminder_id", reminderId)
                            putExtra("label", label)
                            putExtra("hour", hour)
                            putExtra("minute", minute)
                            putExtra("request_code", requestCode)
                            putExtra("is_recurring", false)
                            putExtra("trigger_type", "missed_timeout")
                            putExtra("date", date)
                        }
                        val missedPendingIntent = PendingIntent.getBroadcast(
                            context,
                            missedCode,
                            missedIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        try {
                            scheduleExactAlarm(context, alarmManager, missedTime, missedPendingIntent)
                            Log.d(ALARM_TAG, "Scheduled 30-min auto-missed timeout alarm (code=$missedCode)")
                        } catch (e: Exception) {
                            Log.e(ALARM_TAG, "Failed to schedule auto-missed timeout alarm: ${e.message}", e)
                        }
                    }

                    // 4. Post high-priority heads-up notification with Done action
                    if (!isReminderCompleted(context, reminderId)) {
                        postHeadsUpNotification(context, reminderId, label, hour, minute, requestCode)
                    }
                }
            }
        }

        private fun postHeadsUpNotification(
            context: Context,
            reminderId: String,
            label: String,
            hour: Int,
            minute: Int,
            requestCode: Int
        ) {
            ensureNotificationChannel(context)
            val timeStr = String.format("%02d:%02d", hour, minute)
            val notificationId = requestCode

            // Tap notification body: opens app to /reminders route
            val contentIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("route", "/reminders")
            }
            val contentPendingIntent = PendingIntent.getActivity(
                context,
                requestCode,
                contentIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Done action button: triggers ReminderActionReceiver directly in background
            val doneIntent = Intent(context, ReminderActionReceiver::class.java).apply {
                action = ACTION_REMINDER_DONE
                putExtra("reminder_id", reminderId)
                putExtra("request_code", requestCode)
                putExtra("notification_id", notificationId)
            }
            val donePendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                doneIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val doneAction = NotificationCompat.Action.Builder(
                android.R.drawable.checkbox_on_background,
                "Done",
                donePendingIntent
            ).build()

            val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val notification = NotificationCompat.Builder(context, ALARM_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(label)
                .setContentText("Medication reminder at $timeStr")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setSound(alarmSound)
                .setVibrate(longArrayOf(0, 500, 200, 500))
                .setContentIntent(contentPendingIntent)
                .addAction(doneAction)
                .build()

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(notificationId, notification)

            Log.d(ALARM_TAG, "Posted heads-up notification for '$label' (notificationId=$notificationId)")
        }

        private fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    ALARM_NOTIFICATION_CHANNEL_ID,
                    ALARM_NOTIFICATION_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Urgent alerts for daily medication and routines"
                    enableLights(true)
                    lightColor = Color.RED
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                    val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    val audioAttributes = AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                    setSound(alarmSound, audioAttributes)
                    // Note: setBypassDnd intentionally NOT called per requirements
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.createNotificationChannel(channel)
            }
        }
    }

    // ── ReminderActionReceiver: Handles "Done" Button Directly in Background ──
    open class ReminderActionReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val reminderId = intent.getStringExtra("reminder_id") ?: ""
            val requestCode = intent.getIntExtra("request_code", 0)
            val notificationId = intent.getIntExtra("notification_id", requestCode)

            Log.d(ALARM_TAG, "ReminderActionReceiver: Done tapped for id=$reminderId, code=$requestCode")

            // 1. Cancel notification
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(notificationId)

            // 2. Cancel pending escalation and auto-missed timeout alarms
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager != null && requestCode != 0) {
                cancelSpecificAlarm(context, alarmManager, getEscalationCode(requestCode))
                cancelSpecificAlarm(context, alarmManager, getMissedCode(requestCode))
            }

            // 3. Write is_completed = 1, status = 'done' directly to SQLite in background
            if (reminderId.isNotEmpty()) {
                markReminderDone(context, reminderId)
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
