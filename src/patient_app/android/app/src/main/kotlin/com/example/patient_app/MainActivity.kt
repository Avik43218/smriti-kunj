package com.example.patient_app

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
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

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivitySpeech"
        private const val CHANNEL_NAME = "com.smritikunj.patient_app/speech_recognition"
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
