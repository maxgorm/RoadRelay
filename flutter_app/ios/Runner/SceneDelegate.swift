import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        let flutterEngine = FlutterEngine(name: "main")
        flutterEngine.run()
        
        GeneratedPluginRegistrant.register(with: flutterEngine)
        
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        window?.rootViewController = flutterViewController
        window?.makeKeyAndVisible()
        
        // Setup CarPlay bridge
        CarPlayBridge.shared.setup(with: flutterViewController)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is released by the system
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene moves from inactive to active
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from active to inactive
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called when the scene transitions from background to foreground
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called when the scene transitions from foreground to background
    }
}
