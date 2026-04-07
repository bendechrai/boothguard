import AppKit
import SwiftUI
import BoothGuardCore

/// Hosts the SwiftUI preferences view in a regular window.
final class SettingsWindowController: NSWindowController {
    convenience init(settings: AppSettings, pinStore: PINStore) {
        let view = SettingsView(settings: settings, pinStore: pinStore)
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "BoothGuard Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 380))
        self.init(window: window)
    }

    func present() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject private var model: SettingsModel

    init(settings: AppSettings, pinStore: PINStore) {
        _model = ObservedObject(wrappedValue: SettingsModel(settings: settings, pinStore: pinStore))
    }

    var body: some View {
        Form {
            Section("PIN") {
                if model.hasPIN {
                    SecureField("Current PIN", text: $model.currentPIN)
                }
                SecureField("New PIN (4–8 digits)", text: $model.newPIN)
                SecureField("Confirm new PIN", text: $model.confirmPIN)
                Button("Save PIN") { model.savePIN() }
                    .disabled(!model.canSavePIN)
                if let error = model.pinError {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            Section("Lock screen") {
                TextField("Message", text: $model.lockMessage)
                Toggle("Lock all displays (not just built-in)", isOn: $model.lockAllScreens)
            }
            Section("System") {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

final class SettingsModel: ObservableObject {
    @Published var currentPIN = ""
    @Published var newPIN = ""
    @Published var confirmPIN = ""
    @Published var pinError: String?
    @Published var hasPIN: Bool
    @Published var lockMessage: String {
        didSet { settings.lockMessage = lockMessage }
    }
    @Published var lockAllScreens: Bool {
        didSet { settings.lockAllScreens = lockAllScreens }
    }
    @Published var launchAtLogin: Bool {
        didSet { settings.launchAtLogin = launchAtLogin }
    }

    private let settings: AppSettings
    private let pinStore: PINStore

    init(settings: AppSettings, pinStore: PINStore) {
        self.settings = settings
        self.pinStore = pinStore
        self.lockMessage = settings.lockMessage
        self.lockAllScreens = settings.lockAllScreens
        self.launchAtLogin = settings.launchAtLogin
        self.hasPIN = ((try? pinStore.load()) ?? nil) != nil
    }

    var canSavePIN: Bool {
        !newPIN.isEmpty && newPIN == confirmPIN && (!hasPIN || !currentPIN.isEmpty)
    }

    func savePIN() {
        pinError = nil
        if let err = PINValidation.validate(newPIN) {
            pinError = message(for: err)
            return
        }
        if newPIN != confirmPIN {
            pinError = "PINs do not match."
            return
        }
        if hasPIN {
            guard let stored = (try? pinStore.load()) ?? nil,
                  PINHasher.verify(pin: currentPIN, against: stored) else {
                pinError = "Current PIN is incorrect."
                return
            }
        }
        do {
            try pinStore.save(PINHasher.hash(pin: newPIN))
            hasPIN = true
            currentPIN = ""
            newPIN = ""
            confirmPIN = ""
        } catch {
            pinError = "Could not save PIN: \(error.localizedDescription)"
        }
    }

    private func message(for err: PINValidation.Error) -> String {
        switch err {
        case .tooShort: return "PIN must be at least \(PINValidation.minLength) digits."
        case .tooLong: return "PIN must be at most \(PINValidation.maxLength) digits."
        case .nonDigit: return "PIN must contain only digits."
        }
    }
}
