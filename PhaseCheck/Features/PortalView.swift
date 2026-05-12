import SwiftUI
@preconcurrency import WebKit

struct PortalView: View {
    let address: String
    
    var body: some View {
        NavigationView {
            PortalContainer(address: address)
                .navigationBarHidden(true)
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color.black.ignoresSafeArea(.all))
    }
}

struct PortalContainer: View {
    let address: String
    @State private var browser = WKWebView()
    @State private var canGoBack = false
    @State private var canGoForward = false
    @AppStorage("anchor") var anchor: String = ""
    @AppStorage("anchored") var anchored: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            PortalWrapper(
                browser: $browser,
                address: address,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                anchor: $anchor,
                anchored: $anchored
            )
            
            HStack {
                Spacer()
                
                Button(action: {
                    if browser.canGoBack { browser.goBack() }
                }) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                
                Spacer()
                
                Button(action: {
                    if browser.canGoForward { browser.goForward() }
                }) {
                    Image(systemName: "chevron.forward")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                
                Spacer()
            }
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea(.all))
    }
}

struct PortalWrapper: UIViewRepresentable {
    @Binding var browser: WKWebView
    let address: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var anchor: String
    @Binding var anchored: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.setValue(false, forKey: "textInteractionEnabled")

        HTTPCookieStorage.shared.cookies?.forEach {
            dataStore.httpCookieStore.setCookie($0)
        }

        let wk = WKWebView(frame: .zero, configuration: config)
        wk.navigationDelegate = context.coordinator
        wk.uiDelegate = context.coordinator
        wk.allowsBackForwardNavigationGestures = true
        wk.scrollView.pinchGestureRecognizer?.isEnabled = false

        wk.evaluateJavaScript("navigator.userAgent") { (result, error) in
            if let currentUserAgent = result as? String {
                let cleanUA = currentUserAgent
                    .replacingOccurrences(of: "([^\\s]+)AppleWebKit", with: "AppleWebKit", options: .regularExpression)
                    .replacingOccurrences(of: "Version\\/\\d+\\.\\d+\\s+", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "; wv", with: "")
                wk.customUserAgent = cleanUA
            }
        }

        if let url = URL(string: address) {
            wk.load(URLRequest(url: url))
        }

        DispatchQueue.main.async {
            self.browser = wk
        }

        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: PortalWrapper
        var lastRedirectURL: URL?
        
        init(_ parent: PortalWrapper) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if let url = webView.url {
                self.lastRedirectURL = url
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let disableZoomJS = """
                var meta = document.querySelector('meta[name=viewport]');
                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head.appendChild(meta);
                }
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            """
            webView.evaluateJavaScript(disableZoomJS, completionHandler: nil)

            DispatchQueue.main.async {
                if let url = webView.url?.absoluteString, !self.parent.anchored {
                    self.parent.anchored = true
                    self.parent.anchor = url
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
                if let url = lastRedirectURL {
                    let request = URLRequest(url: url)
                    webView.load(request)
                }
            }
        }
        
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""

            if ["http", "https", "about", "file"].contains(scheme) {
                if url.host?.contains("apps.apple.com") == true {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
                
                self.lastRedirectURL = url
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("Failed to open deeplink: \(url)")
                }
            }
        }
        
        @available(iOS 15, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
        
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
