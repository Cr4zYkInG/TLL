import SwiftUI
import WebKit

/**
 * HTMLView — A view-only renderer for notes containing rich HTML 
 * (typically synced from the ThinkLikeLaw website).
 */
#if canImport(UIKit)
struct HTMLView: UIViewRepresentable {
    let htmlContent: String
    let paperColor: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        webView.isUserInteractionEnabled = true
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        loadStyledHTML(in: uiView)
    }
}
#elseif canImport(AppKit)
struct HTMLView: NSViewRepresentable {
    let htmlContent: String
    let paperColor: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        webView.setValue(false, forKey: "drawsBackground") // Equivalent to isOpaque = false on macOS
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        loadStyledHTML(in: nsView)
    }
}
#endif

extension HTMLView {
    func loadStyledHTML(in webView: WKWebView) {
        // Determine text color based on paper background
        let textColor = (paperColor == "dark") ? "#FFFFFF" : "#1C1C1E"
        
        // Injecting basic styles to match app theme
        let styledHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 19px;
                    line-height: 1.7;
                    letter-spacing: -0.01em;
                    color: \(textColor) !important;
                    background-color: transparent;
                    margin: 0;
                    padding: 35px;
                    transition: opacity 0.3s ease-in;
                }
                h1, h2, h3, h4, h5, h6, p, li, span, div, font {
                    color: \(textColor) !important;
                }
                h1, h2, h3 {
                    font-family: "Outfit", sans-serif;
                    margin-top: 1.8em;
                    margin-bottom: 0.8em;
                    font-weight: 700;
                    letter-spacing: -0.02em;
                }
                p {
                    margin-bottom: 1.2em;
                }
                
                /* Selection style */
                ::selection {
                    background: rgba(0, 122, 255, 0.2);
                }
                
                /* Ensure links are always visible */
                a { 
                    color: #007AFF !important; 
                    text-decoration: none;
                    border-bottom: 1px solid rgba(0, 122, 255, 0.3);
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}
