import Cocoa
import OSLog
import Combine
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SecretAgentKit
import Brief

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    private static var homeDirectory: String {
//        if UserDefaults.standard.bool(forKey: "usehomedirectory") {
            let folder = "/Users/max/.secretive"
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false)
            return folder
//        } else {
//            return FileManager.default.homeDirectoryForCurrentUser.path
//        }
    }
    private let updater = Updater(checkOnLaunch: false)
    private let notifier = Notifier()
    private let publicKeyFileStoreController = PublicKeyFileStoreController(homeDirectory: homeDirectory)
    private lazy var agent: Agent = {
        Agent(storeList: storeList, witness: notifier)
    }()
    private lazy var socketController: SocketController = {
        let path = (AppDelegate.homeDirectory as NSString).appendingPathComponent("socket.ssh") as String
        return SocketController(path: path)
    }()
    private var updateSink: AnyCancellable?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger().debug("SecretAgent finished launching")
        DispatchQueue.main.async {
            self.socketController.handler = self.agent.handle(reader:writer:)
        }
        NotificationCenter.default.addObserver(forName: .secretStoreReloaded, object: nil, queue: .main) { [self] _ in
            try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
        }
        try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
        notifier.prompt()
        updateSink = updater.$update.sink { update in
            guard let update = update else { return }
            self.notifier.notify(update: update, ignore: self.updater.ignore(release:))
        }
    }

}

