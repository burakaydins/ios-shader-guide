// ContentView.swift
// A list of demos, one per recipe in references/recipes.md..
// License: MIT (see LICENSE at the repo root).

import SwiftUI

// MARK: - Navigation

enum Demo: String, CaseIterable, Identifiable {
    // generators
    case plasma, aurora, voronoi, metaballs, sphere
    // color effects
    case vignette, shimmer, duotone, grain, scanlines, holo, dissolve, textGradient
    // layer effects
    case chromatic, pixelate, ripple, lens, glitch, glow
    // distortion effects
    case wave, swirl
    // UI parts
    case dotGrid, progressRing
    // debugging
    case debugUV, debugGrid, debugAlpha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plasma: "plasma"
        case .aurora: "aurora"
        case .voronoi: "voronoiCells"
        case .metaballs: "metaballs"
        case .sphere: "sphereMarch"
        case .vignette: "vignette"
        case .shimmer: "shimmer"
        case .duotone: "duotone"
        case .grain: "filmGrain"
        case .scanlines: "scanlines"
        case .holo: "holo"
        case .dissolve: "dissolve"
        case .textGradient: "textGradient (ShapeStyle)"
        case .chromatic: "chromaticAberration"
        case .pixelate: "pixelate"
        case .ripple: "ripple (tap)"
        case .lens: "lens (drag)"
        case .glitch: "glitch"
        case .glow: "glow"
        case .wave: "wave"
        case .swirl: "swirl (drag)"
        case .dotGrid: "dotGrid"
        case .progressRing: "progressRing"
        case .debugUV: "debugUV"
        case .debugGrid: "debugGrid"
        case .debugAlpha: "debugAlpha"
        }
    }

    static let groups: [(String, [Demo])] = [
        ("Generators (colorEffect)", [.plasma, .aurora, .voronoi, .metaballs, .sphere]),
        ("Color effects", [.vignette, .shimmer, .duotone, .grain, .scanlines, .holo, .dissolve, .textGradient]),
        ("Layer effects", [.chromatic, .pixelate, .ripple, .lens, .glitch, .glow]),
        ("Distortion effects", [.wave, .swirl]),
        ("UI parts", [.dotGrid, .progressRing]),
        ("Debugging", [.debugUV, .debugGrid, .debugAlpha]),
    ]
}

struct ContentView: View {
    @State private var path: [Demo] = LaunchOptions.initialDemo.map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(Demo.groups, id: \.0) { group in
                    Section(group.0) {
                        ForEach(group.1) { demo in
                            NavigationLink(demo.title, value: demo)
                        }
                    }
                }
            }
            .navigationTitle("ShaderLab")
            .navigationDestination(for: Demo.self) { demo in
                DemoScreen(demo: demo)
                    .navigationTitle(demo.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

struct DemoScreen: View {
    let demo: Demo

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.08))
            .overlay(alignment: .topTrailing) {
                if LaunchOptions.showFPS { FPSMeter(label: demo.rawValue) }
            }
    }

    @ViewBuilder private var content: some View {
        switch demo {
        case .plasma: PlasmaDemo()
        case .aurora: AuroraDemo()
        case .voronoi: VoronoiDemo()
        case .metaballs: MetaballsDemo()
        case .sphere: SphereDemo()
        case .vignette: VignetteDemo()
        case .shimmer: ShimmerDemo()
        case .duotone: DuotoneDemo()
        case .grain: GrainDemo()
        case .scanlines: ScanlinesDemo()
        case .holo: HoloDemo()
        case .dissolve: DissolveDemo()
        case .textGradient: TextGradientDemo()
        case .chromatic: ChromaticDemo()
        case .pixelate: PixelateDemo()
        case .ripple: RippleDemo()
        case .lens: LensDemo()
        case .glitch: GlitchDemo()
        case .glow: GlowDemo()
        case .wave: WaveDemo()
        case .swirl: SwirlDemo()
        case .dotGrid: DotGridDemo()
        case .progressRing: ProgressRingDemo()
        case .debugUV: DebugUVDemo()
        case .debugGrid: DebugGridDemo()
        case .debugAlpha: DebugAlphaDemo()
        }
    }
}

// MARK: - Shared sample content

/// A colorful, pure-SwiftUI source for layer/distortion/color effects.
/// (Effects do not work reliably on views backed by UIKit/AppKit, so no List/TextField here.)
struct SampleArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.pink, .orange, .yellow],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                Image(systemName: "bolt.fill").font(.system(size: 90))
                Text("Shader Lab").font(.system(size: 40, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

/// Slider with a label, used by the parametric demos.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(value, specifier: "%.2f")")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Slider(value: $value, in: range)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

// MARK: - Generators

struct PlasmaDemo: View {
    var body: some View {
        AnimatedShader { t in
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.plasma(.float2(proxy.size), .float(t)))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

struct AuroraDemo: View {
    var body: some View {
        AnimatedShader(fps: 30) { t in
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.aurora(.float2(proxy.size), .float(t)))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

struct VoronoiDemo: View {
    var body: some View {
        AnimatedShader(fps: 30) { t in
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.voronoiCells(.float2(proxy.size), .float(t)))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

struct MetaballsDemo: View {
    var body: some View {
        AnimatedShader { t in
            Rectangle().fill(.black)
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.metaballs(.float2(proxy.size), .float(t), .color(.cyan)))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

struct SphereDemo: View {
    var body: some View {
        AnimatedShader(fps: 30) { t in
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.sphereMarch(.float2(proxy.size), .float(t)))
                }
        }
        .frame(width: 300, height: 300)          // raymarching is expensive: keep it small
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Color effects

struct VignetteDemo: View {
    @State private var strength = 0.8

    var body: some View {
        let s = Float(strength)
        VStack {
            Spacer()
            SampleArt()
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.vignette(.float2(proxy.size), .float(s)))
                }
            Spacer()
            LabeledSlider(title: "strength", value: $strength, range: 0...1)
        }
    }
}

struct ShimmerDemo: View {
    var body: some View {
        AnimatedShader { t in
            Text("Premium")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.shimmer(.float2(proxy.size), .float(t), .float(0.15)))
                }
        }
    }
}

struct DuotoneDemo: View {
    var body: some View {
        SampleArt()
            .colorEffect(ShaderLibrary.duotone(.color(.indigo), .color(.yellow)))
    }
}

struct GrainDemo: View {
    var body: some View {
        AnimatedShader(fps: 24) { t in
            SampleArt()
                .colorEffect(ShaderLibrary.filmGrain(.float(t), .float(0.15)))
        }
    }
}

struct ScanlinesDemo: View {
    var body: some View {
        SampleArt()
            .colorEffect(ShaderLibrary.scanlines(.float(3), .float(0.3)))
    }
}

struct HoloDemo: View {
    @State private var tilt = CGSize.zero

    var body: some View {
        let tx = Float(tilt.width)
        let ty = Float(tilt.height)
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.indigo.gradient)
            .frame(width: 260, height: 380)
            .visualEffect { content, proxy in
                content.colorEffect(ShaderLibrary.holo(.float2(proxy.size), .float2(tx, ty)))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        tilt = CGSize(width: max(-1, min(1, value.translation.width / 100)),
                                      height: max(-1, min(1, value.translation.height / 100)))
                    }
                    .onEnded { _ in
                        withAnimation(.spring) { tilt = .zero }
                    }
            )
            .overlay(alignment: .bottom) {
                Text("drag the card").font(.caption).foregroundStyle(.white.opacity(0.6)).padding()
            }
    }
}

// Animatable wrapper so `progress` interpolates inside withAnimation (see swift-patterns.md, section 6).
struct DissolveEffect: ViewModifier, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = Float(progress)
        content.visualEffect { c, proxy in
            c.colorEffect(ShaderLibrary.dissolve(.float2(proxy.size), .float(p), .float(6), .color(.orange)))
        }
    }
}

struct DissolveDemo: View {
    @State private var gone = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            SampleArt()
                .modifier(DissolveEffect(progress: gone ? 1 : 0))
            Spacer()
            Button(gone ? "Bring back" : "Dissolve") {
                withAnimation(.easeInOut(duration: 1.6)) { gone.toggle() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 24)
        }
    }
}

struct TextGradientDemo: View {
    var body: some View {
        AnimatedShader { t in
            Text("Shader")
                .font(.system(size: 72, weight: .heavy))
                .foregroundStyle(ShaderLibrary.textGradient(.boundingRect, .float(t)))
        }
    }
}

// MARK: - Layer effects

struct ChromaticDemo: View {
    @State private var amount = 4.0

    var body: some View {
        let a = Float(amount)
        VStack {
            Spacer()
            SampleArt()
                .layerEffect(ShaderLibrary.chromaticAberration(.float(a)),
                             maxSampleOffset: CGSize(width: amount, height: 0))
            Spacer()
            LabeledSlider(title: "amount (pt)", value: $amount, range: 0...16)
        }
    }
}

struct PixelateDemo: View {
    @State private var cell = 8.0

    var body: some View {
        let c = Float(cell)
        VStack {
            Spacer()
            SampleArt()
                .layerEffect(ShaderLibrary.pixelate(.float(c)),
                             maxSampleOffset: CGSize(width: cell, height: cell))
            Spacer()
            LabeledSlider(title: "cell (pt)", value: $cell, range: 2...40)
        }
    }
}

struct RippleDemo: View {
    @State private var origin = CGPoint(x: 160, y: 160)
    @State private var startDate: Date?

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { context in
            let t = startDate.map { Float(context.date.timeIntervalSince($0)) } ?? 0
            SampleArt()
                .layerEffect(
                    ShaderLibrary.ripple(.float2(origin), .float(t),
                                         .float(12), .float(14), .float(1.5), .float(400)),   // amplitude pt, frequency, decay per s, speed pt/s
                    maxSampleOffset: CGSize(width: 12, height: 12),
                    isEnabled: startDate != nil && t < 3
                )
                .gesture(SpatialTapGesture().onEnded { value in
                    origin = value.location
                    startDate = Date()
                })
        }
    }
}

struct LensDemo: View {
    @State private var touch = CGPoint(x: 160, y: 160)

    var body: some View {
        SampleArt()
            .layerEffect(ShaderLibrary.lens(.float2(touch), .float(80), .float(0.5)),
                         maxSampleOffset: CGSize(width: 80, height: 80))
            .gesture(DragGesture(minimumDistance: 0).onChanged { touch = $0.location })
    }
}

struct GlitchDemo: View {
    var body: some View {
        AnimatedShader { t in
            SampleArt()
                .layerEffect(ShaderLibrary.glitch(.float(t), .float(18)),
                             maxSampleOffset: CGSize(width: 18 + 2, height: 0))
        }
    }
}

struct GlowDemo: View {
    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 90))
            .foregroundStyle(.yellow)
            .padding(48)                                   // room for the halo
            .layerEffect(ShaderLibrary.glow(.color(.yellow), .float(20)),
                         maxSampleOffset: CGSize(width: 20, height: 20))
    }
}

// MARK: - Distortion effects

struct WaveDemo: View {
    var body: some View {
        AnimatedShader { t in
            SampleArt()
                .distortionEffect(ShaderLibrary.wave(.float(t), .float(12), .float(0.05)),
                                  maxSampleOffset: CGSize(width: 0, height: 12))
        }
    }
}

struct SwirlDemo: View {
    @State private var touch = CGPoint(x: 160, y: 160)

    var body: some View {
        SampleArt()
            .distortionEffect(ShaderLibrary.swirl(.float2(touch), .float(120), .float(3)),
                              maxSampleOffset: CGSize(width: 240, height: 240))
            .gesture(DragGesture(minimumDistance: 0).onChanged { touch = $0.location })
    }
}

// MARK: - UI parts

struct DotGridDemo: View {
    var body: some View {
        Rectangle().fill(.black)
            .colorEffect(ShaderLibrary.dotGrid(.float(24), .float(2.5), .color(.white.opacity(0.35))))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
    }
}

struct ProgressRingDemo: View {
    @State private var progress = 0.65

    var body: some View {
        let p = Float(progress)
        VStack {
            Spacer()
            Rectangle().fill(.black)
                .frame(width: 160, height: 160)
                .colorEffect(ShaderLibrary.progressRing(.float2(160, 160), .float(p), .float(14),
                                                        .color(.white.opacity(0.15)), .color(.green)))
            Spacer()
            LabeledSlider(title: "progress", value: $progress, range: 0...1)
        }
    }
}

// MARK: - Debugging

struct DebugUVDemo: View {
    var body: some View {
        // Expect: top-left black, top-right red, bottom-left green, bottom-right yellow.
        Rectangle()
            .frame(width: 300, height: 300)
            .visualEffect { content, proxy in
                content.colorEffect(ShaderLibrary.debugUV(.float2(proxy.size)))
            }
    }
}

struct DebugGridDemo: View {
    var body: some View {
        SampleArt()
            .colorEffect(ShaderLibrary.debugGrid(.float(40)))
    }
}

struct DebugAlphaDemo: View {
    var body: some View {
        Text("alpha")
            .font(.system(size: 80, weight: .black))
            .foregroundStyle(.white)
            .padding(24)
            .colorEffect(ShaderLibrary.debugAlpha())
    }
}
