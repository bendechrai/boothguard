import AppKit

/// The semi-transparent panel shown over the built-in display while the
/// machine is locked. External monitors are intentionally untouched.
final class LockOverlay {

    private var panels: [NSPanel] = []
    private var iconViews: [LockIconView] = []
    private var hintLabels: [NSTextField] = []

    var message: String = "This device is locked"
    var lockAllScreens: Bool = false

    var isVisible: Bool { !panels.isEmpty }

    func show() {
        guard panels.isEmpty else { return }
        let screens = targetScreens()
        for screen in screens {
            let panel = makePanel(for: screen)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func hide() {
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
        iconViews.removeAll()
        hintLabels.removeAll()
    }

    func showCooldown(remaining: TimeInterval) {
        let secs = Int(remaining.rounded(.up))
        let text = "Too many attempts. Try again in \(secs)s."
        for label in hintLabels { label.stringValue = text }
    }

    func showHint(_ text: String) {
        for label in hintLabels { label.stringValue = text }
    }

    func shake() {
        for view in iconViews { view.shake() }
    }

    // MARK: - Helpers

    private func targetScreens() -> [NSScreen] {
        if lockAllScreens { return NSScreen.screens }
        let mainID = CGMainDisplayID()
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let builtIn = NSScreen.screens.first { screen in
            (screen.deviceDescription[key] as? CGDirectDisplayID) == mainID
        }
        return [builtIn ?? NSScreen.main ?? NSScreen.screens[0]]
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.setFrame(screen.frame, display: true)

        let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        content.wantsLayer = true

        let icon = LockIconView(frame: NSRect(x: 0, y: 0, width: 96, height: 96))
        icon.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(icon)

        let title = NSTextField(labelWithString: message)
        title.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        title.textColor = .white
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(title)

        let hint = NSTextField(labelWithString: "Enter PIN to unlock")
        hint.font = NSFont.systemFont(ofSize: 13)
        hint.textColor = NSColor.white.withAlphaComponent(0.7)
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hint)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: -40),
            icon.widthAnchor.constraint(equalToConstant: 96),
            icon.heightAnchor.constraint(equalToConstant: 96),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 24),
            title.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -48),
            hint.centerXAnchor.constraint(equalTo: content.centerXAnchor)
        ])

        panel.contentView = content
        iconViews.append(icon)
        hintLabels.append(hint)
        return panel
    }
}

/// Minimal lock-glyph view with a shake-on-failure animation.
final class LockIconView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath()
        let body = NSRect(x: bounds.midX - 30, y: bounds.midY - 36, width: 60, height: 50)
        path.appendRoundedRect(body, xRadius: 8, yRadius: 8)

        let shackleRect = NSRect(x: bounds.midX - 22, y: bounds.midY + 4, width: 44, height: 36)
        let shackle = NSBezierPath()
        shackle.appendArc(
            withCenter: NSPoint(x: shackleRect.midX, y: shackleRect.minY),
            radius: shackleRect.width / 2,
            startAngle: 0,
            endAngle: 180
        )
        shackle.lineWidth = 6

        NSColor.white.setFill()
        path.fill()
        NSColor.white.setStroke()
        shackle.stroke()
    }

    func shake() {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.duration = 0.06
        animation.repeatCount = 4
        animation.autoreverses = true
        animation.fromValue = (layer?.position.x ?? 0) - 8
        animation.toValue = (layer?.position.x ?? 0) + 8
        wantsLayer = true
        layer?.add(animation, forKey: "shake")
    }
}
