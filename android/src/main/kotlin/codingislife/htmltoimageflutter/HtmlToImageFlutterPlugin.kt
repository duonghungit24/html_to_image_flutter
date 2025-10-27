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
        val args = call.arguments as Map<*, *>

        if (method != "convertToImage") {
            result.notImplemented()
            return
        }

        val rawContent = args["content"] as String
        val delay = (args["delay"] as Int?) ?: 500
        val widthArg = args["width"] as Int?
        val displaySize = getDisplaySize()
        val targetWidth = (widthArg ?: displaySize.width)

        webView = WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            settings.allowFileAccess = true
            settings.allowContentAccess = true
            isHorizontalScrollBarEnabled = false
            isVerticalScrollBarEnabled = false
            settings.setSupportZoom(false)
            settings.displayZoomControls = false
            settings.textZoom = 100
            webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            setInitialScale(100)
        }
        WebView.enableSlowWholeDocumentDraw()

        val scaleFactor = 2 // tăng độ nét x2 như iOS
        val effectiveWidth = targetWidth * scaleFactor

      val fullHtml = """
        <html>
        <head>
            <meta name="viewport" content="width=${targetWidth}px, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                html, body {
                    margin: 0;
                    padding-top: 6px; /* tránh cắt top */
                    width: ${targetWidth}px;
                    max-width: ${targetWidth}px;
                    background: #fff;
                    overflow: hidden;
                    -webkit-print-color-adjust: exact !important;
                    print-color-adjust: exact !important;
                }

                * {
                    box-sizing: border-box;
                    image-rendering: -webkit-optimize-contrast;
                    -webkit-font-smoothing: none;
                    font-smooth: never;
                    text-rendering: geometricPrecision;
                }

                table {
                    border-collapse: separate !important; /* ✅ không dùng collapse nữa */
                    border-spacing: 0 !important;         /* ✅ để các ô vẫn liền nhau */
                }

                th, td {
                    border: 1px solid #000 !important;
                }

                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
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
                    waitAndCapture(view, delay, effectiveWidth, result)
                }
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                result.error("WEBVIEW_ERROR", "Failed to load: ${error?.description}", null)
            }
        }

        webView.loadDataWithBaseURL(null, fullHtml, "text/html", "UTF-8", null)
    }

    private fun waitAndCapture(webView: WebView, delay: Int, width: Int, result: MethodChannel.Result) {
        // Gọi đệ quy tối đa 3 lần nếu render chưa xong
        fun tryCapture(attempt: Int) {
            Handler(Looper.getMainLooper()).postDelayed({
                webView.evaluateJavascript(
                    """
                    (function() {
                        return {
                            ready: document.readyState,
                            width: document.body.scrollWidth,
                            height: document.body.scrollHeight
                        };
                    })();
                    """
                ) { value ->
                    try {
                        val json = JSONArray("[$value]").getJSONObject(0)
                        val ready = json.getString("ready")
                        val htmlWidth = json.getDouble("width").toInt().absoluteValue
                        val htmlHeight = json.getDouble("height").toInt().absoluteValue

                        if (ready != "complete" || htmlHeight == 0) {
                            if (attempt < 3) {
                                tryCapture(attempt + 1)
                            } else {
                                result.error("INVALID_STATE", "Document not ready or height=0", null)
                            }
                            return@evaluateJavascript
                        }

                        val bitmap = captureWebView(webView, htmlWidth, htmlHeight)
                        if (bitmap == null) {
                            if (attempt < 3) {
                                tryCapture(attempt + 1)
                            } else {
                                result.error("BITMAP_NULL", "Bitmap capture failed", null)
                            }
                            return@evaluateJavascript
                        }

                        // Nếu toàn trắng => chưa vẽ xong, thử lại
                        if (isMostlyWhite(bitmap) && attempt < 3) {
                            tryCapture(attempt + 1)
                            return@evaluateJavascript
                        }

                        result.success(bitmap.toByteArray())

                    } catch (e: Exception) {
                        result.error("EVALUATION_ERROR", e.message, null)
                    }
                }
            }, delay.toLong())
        }

        tryCapture(0)
    }

    private fun captureWebView(webView: WebView, width: Int, height: Int): Bitmap? {
        return try {
            if (width <= 0 || height <= 0) return null
            webView.measure(
                View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
            )
            webView.layout(0, 0, width, height)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            webView.draw(canvas)
            bitmap
        } catch (e: Exception) {
            null
        }
    }


    private fun isMostlyWhite(bitmap: Bitmap): Boolean {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        var darkCount = 0
        for (i in pixels.indices step 5000) {
            val p = pixels[i]
            if (p != -1 && p != 0) darkCount++
            if (darkCount > 10) return false
        }
        return true
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
        webView = WebView(activity.applicationContext)
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

fun Bitmap.toByteArray(): ByteArray {
    return ByteArrayOutputStream().use {
        compress(Bitmap.CompressFormat.PNG, 100, it)
        it.toByteArray()
    }
}
