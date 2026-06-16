package com.example.routine_tracker

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.zelv.track/intent"
    private var pendingIntentData: HashMap<String, String?>? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingIntent" -> {
                    result.success(pendingIntentData)
                    pendingIntentData = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        parseIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        parseIntent(intent)
        // If Flutter is already running, push it immediately
        methodChannel?.invokeMethod("onIntent", pendingIntentData)
        pendingIntentData = null
    }

    private fun parseIntent(intent: Intent?) {
        val action = intent?.action ?: return
        pendingIntentData = when (action) {
            "com.zelv.track.TICK_HABIT" -> hashMapOf(
                "type"       to "tick_habit",
                "habit_name" to (intent.getStringExtra("habit_name") ?: "")
            )
            "com.zelv.track.ADD_SHOPPING" -> hashMapOf(
                "type"      to "add_shopping",
                "item_name" to (intent.getStringExtra("item_name") ?: ""),
                "shop_name" to (intent.getStringExtra("shop_name") ?: "")
            )
            "com.zelv.track.OPEN_SCREEN" -> hashMapOf(
                "type"        to "open_screen",
                "screen_name" to (intent.getStringExtra("screen_name") ?: "")
            )
            "com.zelv.track.TICK_SUBTASK" -> hashMapOf(
                "type"         to "tick_subtask",
                "subtask_name" to (intent.getStringExtra("subtask_name") ?: "")
            )
            "com.zelv.track.ADD_SUBTASK" -> hashMapOf(
                "type"         to "add_subtask",
                "subtask_name" to (intent.getStringExtra("subtask_name") ?: ""),
                "group_name"   to (intent.getStringExtra("group_name") ?: "")
            )
            "com.zelv.track.ADD_TASK_GROUP" -> hashMapOf(
                "type"         to "add_task_group",
                "group_name"   to (intent.getStringExtra("group_name") ?: ""),
                "project_name" to (intent.getStringExtra("project_name") ?: "")
            )
            "com.zelv.track.CREATE_PROJECT" -> hashMapOf(
                "type"         to "create_project",
                "project_name" to (intent.getStringExtra("project_name") ?: "")
            )
            else -> null
        }
    }
}
