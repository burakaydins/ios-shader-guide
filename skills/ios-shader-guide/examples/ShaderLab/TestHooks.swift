// TestHooks.swift
// Optional launch arguments for testing (off by default):
//   -demo <name>   open a demo directly, e.g. -demo plasma (names: Demo raw values)
//   -showFPS       show a frame-rate meter on demo screens and print one line per second to stdout
// In Xcode: Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments.
// License: MIT (see LICENSE at the repo root).

import SwiftUI
import QuartzCore

enum LaunchOptions {
    static let arguments = ProcessInfo.processInfo.arguments

    static var initialDemo: Demo? {
        guard let i = arguments.firstIndex(of: "-demo"), i + 1 < arguments.count else { return nil }
        return Demo(rawValue: arguments[i + 1])
    }

    static var showFPS: Bool { arguments.contains("-showFPS") }
}

/// Counts display-link callbacks on the main thread. A drop means the main thread
/// (SwiftUI updates, including shader argument changes) could not keep up.
/// It does not see GPU time directly; use Instruments for that.
@MainActor
final class FrameCounter: ObservableObject {
    @Published var fps: Int = 0
    private var link: CADisplayLink?
    private var frames = 0
    private var windowStart: CFTimeInterval = 0
    private let label: String

    init(label: String) { self.label = label }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if windowStart == 0 { windowStart = link.timestamp }
        frames += 1
        let elapsed = link.timestamp - windowStart
        if elapsed >= 1 {
            fps = Int((Double(frames) / elapsed).rounded())
            print("FPS \(label) \(fps)")
            frames = 0
            windowStart = link.timestamp
        }
    }
}

struct FPSMeter: View {
    @StateObject private var counter: FrameCounter

    init(label: String) {
        _counter = StateObject(wrappedValue: FrameCounter(label: label))
    }

    var body: some View {
        Text("\(counter.fps) fps")
            .font(.caption.monospacedDigit().bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.6), in: Capsule())
            .foregroundStyle(.white)
            .padding(8)
            .onAppear { counter.start() }
            .onDisappear { counter.stop() }
    }
}
