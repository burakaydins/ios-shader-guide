// AnimatedShader.swift
// License: MIT (see LICENSE at the repo root).

import SwiftUI

/// Gives its content the number of seconds since the view appeared, as a Float.
/// Pauses when the user turned on Reduce Motion. Pass `fps: 30` for light ambient effects.
struct AnimatedShader<Content: View>: View {
    private let fps: Double
    private let content: (Float) -> Content

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(fps: Double = 60, @ViewBuilder content: @escaping (Float) -> Content) {
        self.fps = fps
        self.content = content
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / fps, paused: reduceMotion)) { context in
            content(Float(context.date.timeIntervalSince(start)))
        }
    }
}
