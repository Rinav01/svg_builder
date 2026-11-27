package com.example.svg_builder

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var layoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val decor = window?.decorView
        disableStylusHandwritingInitiator(decor)
        if (decor != null) {
            layoutListener = ViewTreeObserver.OnGlobalLayoutListener {
                disableStylusHandwritingInitiator(decor)
            }
            decor.viewTreeObserver.addOnGlobalLayoutListener(layoutListener)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            disableStylusHandwritingInitiator(window?.decorView)
        }
    }

    override fun onDestroy() {
        val decor = window?.decorView
        if (decor != null && layoutListener != null) {
            decor.viewTreeObserver.removeOnGlobalLayoutListener(layoutListener)
        }
        super.onDestroy()
    }

    private fun disableStylusHandwritingInitiator(view: View?) {
        if (view == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            view.isAutoHandwritingEnabled = false
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                disableStylusHandwritingInitiator(view.getChildAt(i))
            }
        }
    }
}
