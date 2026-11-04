import Foundation

/// Runs the vendored mediaremote-adapter. Apple's own `/usr/bin/perl` is allowed to use MediaRemote, which macOS
/// locks for ordinary apps, so the script loads our helper framework from inside that process and streams JSON to us.
final class MediaAdapter: @unchecked Sendable {
    enum Event: Sendable {
        case info(NowPlayingInfo?) // nil: nothing is playing
        case ended                 // the process exited on its own
    }

    private let queue = DispatchQueue(label: "dev.brim.Brim.mediaadapter")
    private var process: Process?
    private var state: [String: Any] = [:]
    private var buffer = Data()
    private var stopped = false

    private static var script: String? { Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl") }
    private static var framework: String? {
        Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework").path
    }

    func start(_ handler: @escaping @Sendable (Event) -> Void) {
        queue.async { self.launch(handler) }
    }

    func stop() {
        queue.async {
            self.stopped = true
            self.process?.terminate()
            self.process = nil
        }
    }

    /// Fire-and-forget command, e.g. `["send", "2"]` or `["seek", "30000000"]` (microseconds).
    static func run(_ arguments: [String]) {
        guard let script, let framework else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script, framework] + arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    private func launch(_ handler: @escaping @Sendable (Event) -> Void) {
        guard let script = Self.script, let framework = Self.framework else { handler(.ended); return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script, framework, "stream", "--micros", "--debounce=50"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return } // EOF; the termination handler reports it
            self?.queue.async { self?.consume(data, handler) }
        }
        task.terminationHandler = { [weak self] _ in
            self?.queue.async {
                guard let self, !self.stopped else { return }
                handler(.ended)
            }
        }
        do { try task.run(); process = task } catch { handler(.ended) }
    }

    /// Splits stdout into lines; each line is one JSON message.
    private func consume(_ data: Data, _ handler: @Sendable (Event) -> Void) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = message["payload"] as? [String: Any] else { continue }
            NowPlayingMerge.apply(payload, diff: message["diff"] as? Bool ?? false, to: &state)
            handler(.info(NowPlayingInfo(json: state)))
        }
    }
}
