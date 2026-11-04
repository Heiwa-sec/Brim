import AppKit
import SwiftUI

/// Owns one island: its panel, model and pointer handling for a single display.
@MainActor
final class IslandController {
    private var screen: NSScreen
    private let model: IslandModel
    private let panel = IslandPanel()
    private var monitors: [Any] = []
    private var hoverWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?

    init(screen: NSScreen, settings: DisplaySettings) {
        self.screen = screen
        model = IslandModel(geometry: screen.notchGeometry)
        model.hideUntilTop = settings.hideUntilTop
        model.onStateChange = { [weak self] in self?.resizePanel() }

        let host = NSHostingView(rootView: IslandView(model: model))
        host.sizingOptions = [] // the panel frame is ours; SwiftUI must not resize the window
        panel.contentView = host
        panel.setFrame(frame(for: model.state), display: false)
        panel.orderFrontRegardless()

        // Global monitors see pointer events over other apps, local ones over our own panel. Neither needs a permission for mouse events.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown]
        let handler: @Sendable (Bool) -> Void = { [weak self] isClick in
            MainActor.assumeIsolated { self?.handle(isClick: isClick) }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: mask) { handler($0.type == .leftMouseDown) } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: mask) { handler($0.type == .leftMouseDown); return $0 } as Any)
    }

    func update(screen: NSScreen, settings: DisplaySettings) {
        self.screen = screen
        model.geometry = screen.notchGeometry
        model.hideUntilTop = settings.hideUntilTop
        shrinkWork?.cancel()
        panel.setFrame(frame(for: model.state), display: true)
    }

    func tearDown() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        hoverWork?.cancel(); shrinkWork?.cancel()
        panel.orderOut(nil)
    }

    /// Screen-space frame of the island (including the top gap) in `state`.
    private func frame(for state: IslandState) -> NSRect {
        let g = model.geometry
        let size = IslandModel.size(for: state, geometry: g)
        let height = size.height + g.topInset
        return NSRect(x: g.centerX - size.width / 2, y: screen.frame.maxY - height, width: size.width, height: height)
    }

    /// Grows and renders the panel at full size first, then runs `change` on the next turn. Flipping the state in the
    /// same pass shows the old, small image centred in the bigger window for a frame, so the island seems to form mid-panel.
    private func grow(then change: @escaping @MainActor () -> Void) {
        shrinkWork?.cancel()
        panel.setFrame(frame(for: .expanded), display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        Task { @MainActor in change() }
    }

    /// Grow the panel at once so the spring has room; shrink only after it settles, so a collapsed panel never covers menu-bar items.
    private func resizePanel() {
        let target = frame(for: model.state)
        shrinkWork?.cancel()
        if target.width >= panel.frame.width && target.height >= panel.frame.height {
            panel.setFrame(target, display: true)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.panel.setFrame(self.frame(for: self.model.state), display: true)
        }
        shrinkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func handle(isClick: Bool) {
        let inside = frame(for: model.state).insetBy(dx: -1, dy: -1).contains(NSEvent.mouseLocation)
        if isClick {
            // a click on the island keeps it open; a click elsewhere releases it
            if inside { grow { [model] in model.pinned = true } } else { model.pinned = false }
            return
        }
        if !inside {
            hoverWork?.cancel(); hoverWork = nil
            model.hovering = false
        } else if !model.hovering && hoverWork == nil {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.hoverWork = nil
                self.grow { [model = self.model] in model.hovering = true }
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + DisplaySettings.hoverDelay, execute: work)
        }
    }
}
