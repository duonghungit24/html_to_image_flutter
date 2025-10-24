// import Flutter
// import UIKit
// import WebKit

// public class HtmlToImageFlutterPlugin: NSObject, FlutterPlugin {
//     var webView: WKWebView!
//     var urlObservation: NSKeyValueObservation?

//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let channel = FlutterMethodChannel(name: "html_to_image_flutter", binaryMessenger: registrar.messenger())
//         let instance = HtmlToImageFlutterPlugin()
//         registrar.addMethodCallDelegate(instance, channel: channel)
//     }

//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         guard let arguments = call.arguments as? [String: Any],
//               let content = arguments["content"] as? String else {
//             result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'content'", details: nil))
//             return
//         }

//         let delay = arguments["delay"] as? Double ?? 200.0

//         switch call.method {
//         case "convertToImage":
//             self.webView = WKWebView(frame: .zero)
//             self.webView.isHidden = true
//             self.webView.tag = 100

//             // Ensure viewport for full width scaling
//             let htmlWithViewport = """
//             <html>
//             <head>
//               <meta name="viewport" content="width=device-width, initial-scale=1.0">
//               <style>
//                 body { margin: 0; padding: 0; }
//               </style>
//             </head>
//             <body>
//               \(content)
//             </body>
//             </html>
//             """

//             self.webView.loadHTMLString(htmlWithViewport, baseURL: nil)

//             var bytes = FlutterStandardTypedData(bytes: Data())

//             urlObservation = webView.observe(\.isLoading, changeHandler: { (webView, change) in
//                 DispatchQueue.main.asyncAfter(deadline: .now() + (delay / 1000)) {
//                     if #available(iOS 11.0, *) {
//                         self.webView.scrollView.contentInsetAdjustmentBehavior = .never

//                         let contentSize = self.webView.scrollView.contentSize
//                         let width = contentSize.width
//                         let height = contentSize.height

//                         self.webView.frame = CGRect(x: 0, y: 0, width: width, height: height)

//                         let configuration = WKSnapshotConfiguration()
//                         configuration.rect = CGRect(origin: .zero, size: contentSize)

//                         self.webView.takeSnapshot(with: configuration) { (image, error) in
//                             guard let image = image, let data = image.jpegData(compressionQuality: 1.0) else {
//                                 result(bytes)
//                                 self.dispose()
//                                 return
//                             }
//                             bytes = FlutterStandardTypedData(bytes: data)
//                             result(bytes)
//                             self.dispose()
//                         }
//                     } else {
//                         result(bytes)
//                         self.dispose()
//                     }
//                 }
//             })
//             break

//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }

//     func dispose() {
//         if let viewWithTag = self.webView.viewWithTag(100) {
//             viewWithTag.removeFromSuperview()

//             if #available(iOS 9.0, *) {
//                 WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
//                     records.forEach { record in
//                         WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
//                     }
//                 }
//             }
//         }
//         self.webView = nil
//     }
// }

// import Flutter
// import UIKit
// import WebKit

// public class HtmlToImageFlutterPlugin: NSObject, FlutterPlugin {
//     var webView: WKWebView?
//     var channel: FlutterMethodChannel?

//     public static func register(with registrar: FlutterPluginRegistrar) {
//         let channel = FlutterMethodChannel(name: "html_to_image_flutter", binaryMessenger: registrar.messenger())
//         let instance = HtmlToImageFlutterPlugin()
//         instance.channel = channel
//         registrar.addMethodCallDelegate(instance, channel: channel)
//     }

//     public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         guard let arguments = call.arguments as? [String: Any],
//               let content = arguments["content"] as? String else {
//             result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'content'", details: nil))
//             return
//         }

//         // delay in ms (fallback) - used as maximum wait for images load
//         let delayMs = arguments["delay"] as? Double ?? 800.0

//         switch call.method {
//         case "convertToImage":
//             createAndLoadWebView(htmlContent: content, maxDelayMs: delayMs, flutterResult: result)
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }

//     private func createAndLoadWebView(htmlContent: String, maxDelayMs: Double, flutterResult: @escaping FlutterResult) {
//         dispose()

//         // configure webView
//         let config = WKWebViewConfiguration()
//         config.suppressesIncrementalRendering = false

//         let wk = WKWebView(frame: .zero, configuration: config)
//         wk.navigationDelegate = self
//         wk.isOpaque = false
//         wk.backgroundColor = .white
//         wk.scrollView.backgroundColor = .white
//         wk.scrollView.isScrollEnabled = false
//         wk.translatesAutoresizingMaskIntoConstraints = false

//         self.webView = wk

//         // Wrap content in minimal html with viewport and reset styles
//         let htmlWithViewport = """
//         <html>
//         <head>
//           <meta name="viewport" content="width=device-width, initial-scale=1.0">
//           <meta charset="utf-8"/>
//           <style>
//             html, body { margin:0; padding:0; background:#fff; }
//             img { max-width: 100%; display:block; }
//             * { box-sizing: border-box; }
//           </style>
//         </head>
//         <body>
//           \(htmlEscapeIfNeeded(htmlWith: htmlContent))
//         </body>
//         </html>
//         """

//         // load html
//         wk.loadHTMLString(htmlWithViewport, baseURL: nil)

//         // store callback in an associated object via delegation (we'll call it after navigation didFinish)
//         pendingResult = flutterResult
//         pendingMaxDelayMs = maxDelayMs
//     }

//     // MARK: - Helpers & state
//     private var pendingResult: FlutterResult? = nil
//     private var pendingMaxDelayMs: Double = 800.0

//     private func dispose() {
//         if let wk = self.webView {
//             wk.stopLoading()
//             wk.navigationDelegate = nil
//             wk.removeFromSuperview()
//             self.webView = nil
//         }
//         pendingResult = nil
//     }

//     // Ensure HTML inserted does not accidentally break JS string if already contains </body> etc.
//     private func htmlEscapeIfNeeded(htmlWith html: String) -> String {
//         // If html likely already a full document (starts with <!DOCTYPE or <html), insert as-is.
//         let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
//         if trimmed.lowercased().hasPrefix("<!doctype") || trimmed.lowercased().hasPrefix("<html") {
//             return html
//         } else {
//             return html
//         }
//     }

//     // Crop bottom white space from UIImage by scanning pixels row-by-row
//     private func cropBottomWhite(from image: UIImage, whiteThreshold: UInt8 = 245, padding: Int = 2) -> UIImage {
//         guard let cgImage = image.cgImage else { return image }
//         let width = cgImage.width
//         let height = cgImage.height
//         let colorSpace = CGColorSpaceCreateDeviceRGB()
//         let bytesPerPixel = 4
//         let bytesPerRow = bytesPerPixel * width
//         let bitsPerComponent = 8
//         guard let context = CGContext(data: nil,
//                                       width: width,
//                                       height: height,
//                                       bitsPerComponent: bitsPerComponent,
//                                       bytesPerRow: bytesPerRow,
//                                       space: colorSpace,
//                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
//         else { return image }

//         context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
//         guard let pixelBuffer = context.data else { return image }

//         let ptr = pixelBuffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

//         // scan from bottom up to find first non-white row
//         var cropBottom = height
//         outer: for row in stride(from: height - 1, through: 0, by: -1) {
//             let rowStart = row * bytesPerRow
//             for col in 0..<width {
//                 let idx = rowStart + col * bytesPerPixel
//                 let r = ptr[idx]
//                 let g = ptr[idx + 1]
//                 let b = ptr[idx + 2]
//                 let a = ptr[idx + 3]
//                 // treat pixel as non-white if alpha significant and any channel below threshold
//                 if a > 10 && (r < whiteThreshold || g < whiteThreshold || b < whiteThreshold) {
//                     cropBottom = row + 1
//                     break outer
//                 }
//             }
//         }

//         // safety: if cropBottom equals height -> no crop; else crop and return new UIImage
//         if cropBottom >= height {
//             return image
//         } else {
//             // add small padding
//             let finalBottom = max(1, cropBottom - padding)
//             let cropRect = CGRect(x: 0, y: 0, width: width, height: finalBottom)
//             if let croppedCg = cgImage.cropping(to: cropRect) {
//                 return UIImage(cgImage: croppedCg, scale: image.scale, orientation: image.imageOrientation)
//             } else {
//                 return image
//             }
//         }
//     }
// }

// // MARK: - WKNavigationDelegate
// extension HtmlToImageFlutterPlugin: WKNavigationDelegate {

//     public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//         // Called when initial load finished. Now wait for images/resources to be loaded (poll JS), or timeout.
//         guard let result = pendingResult else { return }
//         let maxDelay = pendingMaxDelayMs
//         waitForImagesLoadAndSnapshot(webView: webView, maxDelayMs: maxDelay, flutterResult: result)
//     }

//     private func waitForImagesLoadAndSnapshot(webView: WKWebView, maxDelayMs: Double, flutterResult: @escaping FlutterResult) {
//         let start = Date()
//         let timeout = maxDelayMs / 1000.0

//         func checkAndProceed() {
//             // JS to check: document.readyState and all images complete
//             let checkJS = """
//             (function() {
//               var imgs = Array.from(document.images || []);
//               var allComplete = imgs.every(function(i){ return i.complete && (i.naturalWidth || i.naturalHeight); });
//               return { ready: document.readyState, imgsComplete: allComplete, width: document.body.scrollWidth, height: document.body.scrollHeight };
//             })();
//             """

//             webView.evaluateJavaScript(checkJS) { (value, error) in
//                 if let dict = value as? [String: Any],
//                    let ready = dict["ready"] as? String,
//                    let imgsComplete = dict["imgsComplete"] as? Bool,
//                    let widthVal = dict["width"],
//                    let heightVal = dict["height"] {

//                     // parse sizes as numbers
//                     var widthFloat: CGFloat = 0
//                     var heightFloat: CGFloat = 0
//                     if let w = widthVal as? CGFloat { widthFloat = w }
//                     else if let w = widthVal as? Double { widthFloat = CGFloat(w) }
//                     else if let w = widthVal as? Int { widthFloat = CGFloat(w) }

//                     if let h = heightVal as? CGFloat { heightFloat = h }
//                     else if let h = heightVal as? Double { heightFloat = CGFloat(h) }
//                     else if let h = heightVal as? Int { heightFloat = CGFloat(h) }

//                     let readyOK = (ready == "complete" || ready == "interactive")
//                     if readyOK && imgsComplete {
//                         // proceed to snapshot with measured width/height
//                         self.takeSnapshot(webView: webView, contentWidth: widthFloat, contentHeight: heightFloat, flutterResult: flutterResult)
//                         return
//                     }
//                 }

//                 // timeout check
//                 if Date().timeIntervalSince(start) > timeout {
//                     // fallback: take snapshot with scrollView.contentSize if JS check didn't pass
//                     let fallbackSize = webView.scrollView.contentSize
//                     self.takeSnapshot(webView: webView, contentWidth: fallbackSize.width, contentHeight: fallbackSize.height, flutterResult: flutterResult)
//                     return
//                 }

//                 // retry after small delay
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
//                     checkAndProceed()
//                 }
//             }
//         }

//         // initial slight delay then check
//         DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
//             checkAndProceed()
//         }
//     }

//     private func takeSnapshot(webView: WKWebView, contentWidth: CGFloat, contentHeight: CGFloat, flutterResult: @escaping FlutterResult) {
//         // defensive: ensure reasonable size
//         var width = max(1, contentWidth)
//         var height = max(1, contentHeight)

//         // cap max height to avoid huge images (optional) - you can adjust or remove
//         let maxHeight: CGFloat = 4000
//         if height > maxHeight { height = maxHeight }

//         // set frame to measured size
//         webView.frame = CGRect(x: 0, y: 0, width: width, height: height)

//         let configuration = WKSnapshotConfiguration()
//         configuration.rect = CGRect(x: 0, y: 0, width: width, height: height)
//         configuration.snapshotWidth = NSNumber(value: Float(width))

//         // take snapshot on main thread
//         DispatchQueue.main.async {
//             webView.takeSnapshot(with: configuration) { [weak self] (image, error) in
//                 guard let strongSelf = self else { return }
//                 guard let image = image else {
//                     // return empty bytes or error
//                     let empty = FlutterStandardTypedData(bytes: Data())
//                     flutterResult(FlutterError(code: "SNAPSHOT_FAILED", message: error?.localizedDescription ?? "Snapshot failed", details: nil))
//                     strongSelf.dispose()
//                     return
//                 }

//                 // crop bottom white if needed
//                 let cropped = strongSelf.cropBottomWhite(from: image, whiteThreshold: 245, padding: 2)

//                 // convert to jpeg (you can choose PNG if you prefer)
//                 guard let data = cropped.jpegData(compressionQuality: 1.0) else {
//                     flutterResult(FlutterError(code: "ENCODE_FAILED", message: "Cannot encode image", details: nil))
//                     strongSelf.dispose()
//                     return
//                 }

//                 let bytes = FlutterStandardTypedData(bytes: data)
//                 flutterResult(bytes)
//                 strongSelf.dispose()
//             }
//         }
//     }
// }


import Flutter
import UIKit
import WebKit

public class HtmlToImageFlutterPlugin: NSObject, FlutterPlugin {
    var webView: WKWebView?
    var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "html_to_image_flutter", binaryMessenger: registrar.messenger())
        let instance = HtmlToImageFlutterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let content = arguments["content"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing 'content'", details: nil))
            return
        }

        let delayMs = arguments["delay"] as? Double ?? 800.0
        let targetWidthPx = arguments["targetWidthPx"] as? CGFloat ?? 384 // mặc định 58mm in ~384px

        switch call.method {
        case "convertToImage":
            createAndLoadWebView(htmlContent: content, maxDelayMs: delayMs, targetWidthPx: targetWidthPx, flutterResult: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createAndLoadWebView(htmlContent: String, maxDelayMs: Double, targetWidthPx: CGFloat, flutterResult: @escaping FlutterResult) {
        dispose()

        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false

        let wk = WKWebView(frame: .zero, configuration: config)
        wk.navigationDelegate = self
        wk.isOpaque = false
        wk.backgroundColor = .white
        wk.scrollView.backgroundColor = .white
        wk.scrollView.isScrollEnabled = false
        wk.translatesAutoresizingMaskIntoConstraints = false
        self.webView = wk

        let htmlWithViewport = """
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta charset="utf-8"/>
          <style>
            html, body { margin:0; padding:0; background:#fff; }
            img { max-width: 100%; display:block; }
            * { box-sizing: border-box; }
          </style>
        </head>
        <body>
          \(htmlEscapeIfNeeded(htmlWith: htmlContent))
        </body>
        </html>
        """

        wk.loadHTMLString(htmlWithViewport, baseURL: nil)
        pendingResult = flutterResult
        pendingMaxDelayMs = maxDelayMs
        pendingTargetWidthPx = targetWidthPx
    }

    private var pendingResult: FlutterResult? = nil
    private var pendingMaxDelayMs: Double = 800.0
    private var pendingTargetWidthPx: CGFloat = 384

    private func dispose() {
        if let wk = self.webView {
            wk.stopLoading()
            wk.navigationDelegate = nil
            wk.removeFromSuperview()
            self.webView = nil
        }
        pendingResult = nil
    }

    private func htmlEscapeIfNeeded(htmlWith html: String) -> String {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("<!doctype") || trimmed.lowercased().hasPrefix("<html") {
            return html
        } else {
            return html
        }
    }

    private func cropBottomWhite(from image: UIImage, whiteThreshold: UInt8 = 245, padding: Int = 2) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelBuffer = context.data else { return image }

        let ptr = pixelBuffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        var cropBottom = height
        outer: for row in stride(from: height - 1, through: 0, by: -1) {
            let rowStart = row * bytesPerRow
            for col in 0..<width {
                let idx = rowStart + col * bytesPerPixel
                let r = ptr[idx]
                let g = ptr[idx + 1]
                let b = ptr[idx + 2]
                let a = ptr[idx + 3]
                if a > 10 && (r < whiteThreshold || g < whiteThreshold || b < whiteThreshold) {
                    cropBottom = row + 1
                    break outer
                }
            }
        }

        if cropBottom >= height {
            return image
        } else {
            let finalBottom = max(1, cropBottom - padding)
            let cropRect = CGRect(x: 0, y: 0, width: width, height: finalBottom)
            if let croppedCg = cgImage.cropping(to: cropRect) {
                return UIImage(cgImage: croppedCg, scale: image.scale, orientation: image.imageOrientation)
            } else {
                return image
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension HtmlToImageFlutterPlugin: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let result = pendingResult else { return }
        let maxDelay = pendingMaxDelayMs
        let targetWidth = pendingTargetWidthPx
        waitForImagesLoadAndSnapshot(webView: webView, maxDelayMs: maxDelay, targetWidth: targetWidth, flutterResult: result)
    }

    private func waitForImagesLoadAndSnapshot(webView: WKWebView, maxDelayMs: Double, targetWidth: CGFloat, flutterResult: @escaping FlutterResult) {
        let start = Date()
        let timeout = maxDelayMs / 1000.0

        func checkAndProceed() {
            let checkJS = """
            (function() {
              var imgs = Array.from(document.images || []);
              var allComplete = imgs.every(function(i){ return i.complete && (i.naturalWidth || i.naturalHeight); });
              return { ready: document.readyState, imgsComplete: allComplete, width: document.body.scrollWidth, height: document.body.scrollHeight };
            })();
            """

            webView.evaluateJavaScript(checkJS) { (value, error) in
                if let dict = value as? [String: Any],
                   let ready = dict["ready"] as? String,
                   let imgsComplete = dict["imgsComplete"] as? Bool,
                   let widthVal = dict["width"],
                   let heightVal = dict["height"] {

                    var widthFloat: CGFloat = 0
                    var heightFloat: CGFloat = 0
                    if let w = widthVal as? CGFloat { widthFloat = w }
                    else if let w = widthVal as? Double { widthFloat = CGFloat(w) }
                    else if let w = widthVal as? Int { widthFloat = CGFloat(w) }

                    if let h = heightVal as? CGFloat { heightFloat = h }
                    else if let h = heightVal as? Double { heightFloat = CGFloat(h) }
                    else if let h = heightVal as? Int { heightFloat = CGFloat(h) }

                    let readyOK = (ready == "complete" || ready == "interactive")
                    if readyOK && imgsComplete {
                        // tính scale để fit targetWidth
                        let scale = targetWidth / widthFloat
                        let scaleJS = """
                        document.body.style.transformOrigin = 'top left';
                        document.body.style.transform = 'scale(\(scale))';
                        document.body.style.width = '\(widthFloat)px';
                        """
                        webView.evaluateJavaScript(scaleJS) { _, _ in
                            self.takeSnapshot(webView: webView,
                                              contentWidth: widthFloat * scale,
                                              contentHeight: heightFloat * scale,
                                              flutterResult: flutterResult)
                        }
                        return
                    }
                }

                if Date().timeIntervalSince(start) > timeout {
                    let fallbackSize = webView.scrollView.contentSize
                    self.takeSnapshot(webView: webView,
                                      contentWidth: fallbackSize.width,
                                      contentHeight: fallbackSize.height,
                                      flutterResult: flutterResult)
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    checkAndProceed()
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            checkAndProceed()
        }
    }

    private func takeSnapshot(webView: WKWebView, contentWidth: CGFloat, contentHeight: CGFloat, flutterResult: @escaping FlutterResult) {
        var width = max(1, contentWidth)
        var height = max(1, contentHeight)
        let maxHeight: CGFloat = 4000
        if height > maxHeight { height = maxHeight }
        webView.frame = CGRect(x: 0, y: 0, width: width, height: height)

        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: width, height: height)
        configuration.snapshotWidth = NSNumber(value: Float(width))

        DispatchQueue.main.async {
            webView.takeSnapshot(with: configuration) { [weak self] (image, error) in
                guard let strongSelf = self else { return }
                guard let image = image else {
                    flutterResult(FlutterError(code: "SNAPSHOT_FAILED", message: error?.localizedDescription ?? "Snapshot failed", details: nil))
                    strongSelf.dispose()
                    return
                }

                let cropped = strongSelf.cropBottomWhite(from: image, whiteThreshold: 245, padding: 2)
                guard let data = cropped.jpegData(compressionQuality: 1.0) else {
                    flutterResult(FlutterError(code: "ENCODE_FAILED", message: "Cannot encode image", details: nil))
                    strongSelf.dispose()
                    return
                }

                let bytes = FlutterStandardTypedData(bytes: data)
                flutterResult(bytes)
                strongSelf.dispose()
            }
        }
    }
}
