import SwiftUI
import FirebaseCore
import Network

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    private var monitor: NWPathMonitor?
    private var isConnected = false
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Configure Firebase
        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            print("GoogleService-Info.plist found at: \(filePath)")
            FirebaseApp.configure()
            
            #if DEBUG
            // Upload mock data in debug mode
            MockDataUploader.uploadMockDataIfNeeded()
            #endif
        } else {
            print("Error: GoogleService-Info.plist NOT found!")
            // Handle missing configuration gracefully
            return false
        }
        
        return true
    }
    
    private func setupNetworkMonitoring() {
        monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor?.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    print("Network connection established")
                } else {
                    print("Network connection lost")
                    // Post notification for network status
                    NotificationCenter.default.post(name: NSNotification.Name("NetworkStatusChanged"), 
                                                 object: nil, 
                                                 userInfo: ["connected": false])
                }
                
                // Log specific network issues
                if path.status == .unsatisfied {
                    if path.availableInterfaces.isEmpty {
                        print("No network interfaces available")
                    }
                    
                    if !path.supportsDNS {
                        print("DNS resolution not supported")
                    }
                    
                    if !path.supportsIPv4 && !path.supportsIPv6 {
                        print("Neither IPv4 nor IPv6 is supported")
                    }
                }
            }
        }
        
        monitor?.start(queue: queue)
    }
    
    deinit {
        monitor?.cancel()
    }
}

@main
struct newslensApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
