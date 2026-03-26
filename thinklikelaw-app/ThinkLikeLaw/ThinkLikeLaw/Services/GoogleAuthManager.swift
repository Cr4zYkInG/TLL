import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/**
 * GoogleAuthManager — Handles the Google OAuth flow on iOS.
 * Requires GoogleSignIn SDK.
 */
class GoogleAuthManager {
    weak var authState: AuthState?
    
    init(authState: AuthState) {
        self.authState = authState
    }
    
    func startGoogleSignInFlow() {
        #if canImport(GoogleSignIn)
        print("GoogleAuth: Starting flow for Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("GoogleAuth: Client ID: \(GIDSignIn.sharedInstance.configuration?.clientID ?? "not configured")")
        
        let completion: (GIDSignInResult?, Error?) -> Void = { [weak self] result, error in
            if let error = error {
                print("Google Sign-In Error: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Google Sign-In Error: No identity token found.")
                return
            }
            
            Task { [weak self] in
                await self?.authState?.handleGoogleSignIn(idToken: idToken)
            }
        }
        
        #if canImport(UIKit)
        guard let topController = getTopViewController() else {
            print("Google Sign-In Error: Could not find top view controller.")
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: topController, completion: completion)
        
        #elseif canImport(AppKit)
        guard let window = NSApplication.shared.windows.first else {
            print("Google Sign-In Error: Could not find top window.")
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: window, completion: completion)
        #else
        print("Google Sign-In is not currently supported on this platform.")
        #endif
        #endif
    }
    
    #if canImport(UIKit)
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        return topController
    }
    #endif
}
