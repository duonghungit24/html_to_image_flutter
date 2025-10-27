package codingislife.htmltoimageflutter

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.View
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import kotlin.math.absoluteValue

class HtmlToImageFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity
    private lateinit var context: Context
    private lateinit var webView: WebView

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "html_to_image_flutter")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val method = call.method
        val arguments = call.arguments as Map<*, *>
        val rawContent = arguments["content"] as String
        val delay = arguments["delay"] as Int? ?: 500
        val width = arguments["width"] as Int?

        if (method == "convertToImage") {
            webView = WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.databaseEnabled = true
                settings.useWideViewPort = true
                settings.loadWithOverviewMode = true
                settings.allowFileAccess = true
                settings.allowContentAccess = true
                isHorizontalScrollBarEnabled = false
                isVerticalScrollBarEnabled = false
                setInitialScale(100)
            }
            WebView.enableSlowWholeDocumentDraw()

            val displaySize = getDisplaySize()
            val targetWidth = width ?: displaySize.width

            // ✅ HTML FIX: tăng độ đậm chữ, chống mờ, chống đen
            val fullHtml = """
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
                    <style>
                        html, body {
                            margin: 0;
                            padding: 0;
                            background: #ffffff;
                            color: #000000;
                            font-family: -apple-system, Roboto, "Helvetica Neue", Arial, sans-serif;
                            -webkit-font-smoothing: none;
                            text-rendering: geometricPrecision;
                            image-rendering: -webkit-optimize-contrast;
                            transform: scale(1.0001);
                            font-weight: 600;
                            letter-spacing: 0px;
                        }
                        body, p, span, div, td, th {
                            color: #000 !important;
                            font-weight: 700 !important;
                        }
                        img {
                            image-rendering: crisp-edges !important;
                            -webkit-optimize-contrast: 1.5;
                            max-width: 100%;
                            height: auto;
                            display: block;
                        }
                        table {
                            border-collapse: collapse;
                            width: 100%;
                        }
                        td, th {
                            border: 1px solid #99999955;
                            padding: 6px 8px;
                            text-align: left;
                        }
                        * {
                            box-sizing: border-box;
                        }
                    </style>
                </head>
                <body>
                    $rawContent
                </body>
                </html>
            """.trimIndent()

            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    CoroutineScope(Dispatchers.IO).launch {
                        checkContentRendered(view, delay.toLong(), result, targetWidth)
                    }
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: WebResourceRequest?,
                    error: WebResourceError?
                ) {
                    result.error("WEBVIEW_ERROR", "Failed to load content: ${error?.description}", null)
                }
            }

            webView.measure(
                View.MeasureSpec.makeMeasureSpec(targetWidth, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
            )
            webView.layout(0, 0, targetWidth, webView.measuredHeight)
            webView.loadDataWithBaseURL(null, fullHtml, "text/html", "UTF-8", null)
        } else {
            result.notImplemented()
        }
    }

    private fun checkContentRendered(
        webView: WebView,
        delay: Long,
        result: MethodChannel.Result,
        targetWidth: Int
    ) {
        Handler(Looper.getMainLooper()).postDelayed({
            webView.evaluateJavascript(
                """
                (function() {
                    var imgs = document.images;
                    for (var i = 0; i < imgs.length; i++) {
                        if (!imgs[i].complete) return JSON.stringify({ready: false});
                    }
                    return JSON.stringify({
                        ready: true,
                        width: document.body.scrollWidth,
                        height: document.body.scrollHeight
                    });
                })();
                """
            ) { value ->
                try {
                    val json = org.json.JSONObject(value)
                    val ready = json.optBoolean("ready", false)
                    val contentWidth = json.optDouble("width", 0.0).absoluteValue.toInt()
                    val contentHeight = json.optDouble("height", 0.0).absoluteValue.toInt()

                    if (!ready && delay < 4000) {
                        checkContentRendered(webView, delay + 500, result, targetWidth)
                        return@evaluateJavascript
                    }

                    if (contentWidth <= 0 || contentHeight <= 0) {
                        result.error("INVALID_SIZE", "Invalid size: $contentWidth x $contentHeight", null)
                        return@evaluateJavascript
                    }

                    webView.measure(
                        View.MeasureSpec.makeMeasureSpec(contentWidth, View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(contentHeight, View.MeasureSpec.EXACTLY)
                    )
                    webView.layout(0, 0, contentWidth, contentHeight)

                    // ✅ Xuất ảnh độ phân giải cao gấp đôi
                    val bitmap = webView.toBitmap(contentWidth * 2.0, contentHeight * 2.0)
                    if (bitmap != null) {
                        result.success(bitmap.toByteArray())
                    } else {
                        result.error("BITMAP_ERROR", "Failed to capture bitmap", null)
                    }
                } catch (e: Exception) {
                    result.error("EVALUATION_ERROR", "JS eval failed: ${e.message}", null)
                }
            }
        }, delay)
    }

    @Suppress("DEPRECATION")
    private fun getDisplaySize(): Size {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = activity.windowManager.currentWindowMetrics.bounds
            Size(bounds.width(), bounds.height())
        } else {
            val display = activity.windowManager.defaultDisplay
            Size(display.width, display.height)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        webView = WebView(activity.applicationContext).apply {
            minimumHeight = 1
            minimumWidth = 1
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

fun WebView.toBitmap(width: Double, height: Double): Bitmap? {
    val w = width.absoluteValue.toInt()
    val h = height.absoluteValue.toInt()
    if (w <= 0 || h <= 0) return null
    measure(
        View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY)
    )
    layout(0, 0, w, h)
    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    canvas.drawColor(android.graphics.Color.WHITE) // ✅ tránh nền đen
    draw(canvas)
    return bitmap
}

fun Bitmap.toByteArray(): ByteArray {
    return ByteArrayOutputStream().use {
        compress(Bitmap.CompressFormat.PNG, 100, it)
        it.toByteArray()
    }
}
