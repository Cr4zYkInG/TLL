import Foundation
#if !os(macOS)
import WatchConnectivity
#endif
import Combine

#if !os(macOS)
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var lastReceivedMessage: [String: Any] = [:]
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    /**
     * Send critical deadlines to the watch
     */
    func syncDeadlines(deadlines: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        
        WCSession.default.transferUserInfo(["deadlines": deadlines])
    }
    
    /**
     * Broadcast an alert to the watch (e.g., "Scholar Broadcast Received")
     */
    func sendAlertToWatch(title: String, body: String) {
        guard WCSession.default.activationState == .activated else { return }
        
        WCSession.default.sendMessage(["alert": ["title": title, "body": body]], replyHandler: nil)
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = message
            
            // Handle Watch-triggered actions
            if let action = message["action"] as? String {
                self.handleWatchAction(action)
            }
        }
    }
    
    private func handleWatchAction(_ action: String) {
        switch action {
        case "start_recording":
            // Trigger Lecture Recorder (e.g., via a global notification or manager)
            NotificationCenter.default.post(name: NSNotification.Name("WatchTriggeredRecording"), object: nil)
        default:
            break
        }
    }
}
#else
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    @Published var lastReceivedMessage: [String: Any] = [:]
    func syncDeadlines(deadlines: [String: Any]) {}
    func sendAlertToWatch(title: String, body: String) {}
}
#endif
