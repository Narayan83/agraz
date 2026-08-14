package com.agraz.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Backward-compatible edge-to-edge on pre-Android 15 (Play Console guidance).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
