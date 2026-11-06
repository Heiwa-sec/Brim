import AppKit
import SwiftUI

/// Owns one island: its panel, model and pointer handling for a single display.
@MainActor
final class IslandController {
    private var screen: NSScreen
    private let model: IslandModel
    private let host: ModuleHost
    private let panel = IslandPanel()
    private var monitors: [Any] = []
    private var hoverWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    private var scrollTotal: CGFloat = 0
    private var scrollSpent = false
    private var leftSinceDismiss = false
    private var defaultsObserver: NSObjectProtocol?

    init(screen: NSScreen, settings: DisplaySettings, host: ModuleHost) {
        self.screen = screen
        self.host = host
        model = IslandModel(geometry: screen.notchGeometry)
        model.hideUntilTop = settings.hideUntilTop
        model.onStateChange = { [weak self] in self?.resizePanel() }

        let host = NSHostingView(rootView: IslandView(model: model, host: host))
        host.sizingOptions = [] // the panel frame is ours; SwiftUI must not resize the window
        panel.contentView = host
        panel.setFrame(frame(for: model.state), display: false)
        panel.orderFrontRegardless()

        trackActivity()
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyKeepOpen() }
        }
        applyKeepOpen()

        // Global monitors see pointer events over other apps, local ones over our own panel. Neither needs a permission for mouse events.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        let handler: @Sendable (Bool) -> Void = { [weak self] isClick in
            MainActor.assumeIsolated { self?.handle(isClick: isClick) }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: mask) { handler($0.type == .leftMouseDown) } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: mask) { handler($0.type == .leftMouseDown); return $0 } as Any)
        // Two-finger sideways scrolls switch tabs; vertical scrolls (the lyrics) pass through untouched.
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let (dx, dy, phase, momentum) = (event.scrollingDeltaX, event.scrollingDeltaY, event.phase, event.momentumPhase)
            MainActor.assumeIsolated { self?.scroll(dx: dx, dy: dy, phase: phase, momentum: momentum) }
            return event
        } as Any)
    }

    /// Mirrors the host's live-activity count into the model; re-arms itself because observation fires once per change.
    private func trackActivity() {
        withObservationTracking {
            model.activityCount = host.activityCount
            let tab = host.resolve(model.tab)
            model.expandedColumns = max(1, host.views(in: tab).count)
            model.lyricsAvailable = tab == .nowPlaying && host.lyrics?.lines.isEmpty == false
            panel.acceptsKeys = tab == .todo
            if host.wantsExpanded {
                if !model.banner { model.tab = .nowPlaying; grow { [model] in model.banner = true } } // a banner always shows in Now Playing
            } else { model.banner = false }
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackActivity() }
        }
    }

    /// One tab step per swipe: a gesture counts once its sideways travel passes 50 pt, and not again until a new gesture begins.
    private func scroll(dx: CGFloat, dy: CGFloat, phase: NSEvent.Phase, momentum: NSEvent.Phase) {
        guard model.state == .expanded, frame(for: .expanded).contains(NSEvent.mouseLocation) else { return }
        if phase.contains(.began) || phase.contains(.mayBegin) { scrollTotal = 0; scrollSpent = false }
        guard !scrollSpent, abs(dx) > abs(dy) else { return }
        scrollTotal += dx
        let wheel = phase.isEmpty && momentum.isEmpty // a mouse wheel has no gesture phases
        guard wheel || abs(scrollTotal) > 50 else { return }
        scrollSpent = !wheel
        let tabs = host.tabs
        guard let i = tabs.firstIndex(of: host.resolve(model.tab)) else { return }
        // Natural scrolling: fingers moving left (negative) bring the next tab in from the right.
        let next = min(max(i + (scrollTotal < 0 ? 1 : -1), 0), tabs.count - 1)
        model.tab = tabs[next]
        scrollTotal = 0
    }

    private func applyKeepOpen() {
        let on = DisplaySettings.keepOpen
        guard on != model.keepOpen else { return }
        if on { grow { [model] in model.keepOpen = true; model.dismissed = false } } else { model.keepOpen = false }
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
        defaultsObserver.map(NotificationCenter.default.removeObserver)
        hoverWork?.cancel(); shrinkWork?.cancel()
        panel.orderOut(nil)
    }

    /// Screen-space frame of the island (including the top gap) in `state`.
    private func frame(for state: IslandState, lyricsOnly: Bool? = nil) -> NSRect {
        let g = model.geometry
        let size = IslandModel.size(for: state, geometry: g, columns: model.expandedColumns, lyricsOnly: lyricsOnly ?? model.narrowLyrics)
        let height = size.height + g.topInset
        return NSRect(x: g.centerX - size.width / 2, y: screen.frame.maxY - height, width: size.width, height: height)
    }

    /// Grows and renders the panel at full size first, then runs `change` on the next turn. Flipping the state in the
    /// same pass shows the old, small image centred in the bigger window for a frame, so the island seems to form mid-panel.
    private func grow(then change: @escaping @MainActor () -> Void) {
        shrinkWork?.cancel()
        panel.setFrame(frame(for: .expanded, lyricsOnly: false), display: true)
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
        if model.dismissed { // closed with the button: stays closed until the pointer has left and come back
            if !inside { leftSinceDismiss = true }
            guard inside, leftSinceDismiss else { return }
            model.dismissed = false
            leftSinceDismiss = false
        }
        if isClick {
            // a click on the island keeps it open; a click elsewhere releases it
            // grow() lays out and draws the whole island synchronously, ahead of the click: only do that when it is not open yet.
            if inside { if model.state == .expanded { model.pinned = true } else { grow { [model] in model.pinned = true } } } else { model.pinned = false }
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
