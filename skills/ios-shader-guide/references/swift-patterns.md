# Swift side: reusable patterns

All iOS 17+. Build in Xcode; if you could not compile, tell the user.

## Contents
1. `AnimatedShader`: the time source (with Reduce Motion and frame rate)
2. Touch and drag
3. Tap ripple, full example
4. Scroll-driven effect
5. Holographic card driven by tilt (CoreMotion)
6. Transition with a shader
7. Chaining effects
8. Preview, testing and `isEnabled`
9. Power and accessibility

## 1. `AnimatedShader`

`TimelineView(.animation)` redraws every frame. Give time as **seconds since the start**, not as `timeIntervalSinceReferenceDate` (Float precision, see `swiftui-shaders.md` section 5).

```swift
import SwiftUI

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
```

This file also exists as `examples/ShaderLab/AnimatedShader.swift` (an explicit `init` is written because the synthesized initializer was not trusted with `private` properties).

- `paused: reduceMotion`: if the user turned on "Reduce Motion", the animation stops and the first frame stays.
- `fps: 30` is a good default for light ambient effects, for battery and heat.
- On screens that stay open a very long time, wrapping time preserves precision: `.float(fmod(t, 3600))`; but the time-dependent terms of the shader must be periodic with that period or the pattern will jump at the wrap point; otherwise do not wrap.

## 2. Touch and drag

A shader is stateless; pass the touch point as an argument.

```swift
struct LensDemo: View {
    @State private var touch = CGPoint(x: 150, y: 150)

    var body: some View {
        Image("photo")
            .resizable().scaledToFit()
            .layerEffect(
                ShaderLibrary.lens(.float2(touch), .float(80), .float(0.5)),
                maxSampleOffset: CGSize(width: 80, height: 80)
            )
            .gesture(DragGesture(minimumDistance: 0).onChanged { touch = $0.location })
    }
}
```

The `location` of a `DragGesture` is in the local coordinate of the view the gesture is attached to. As long as the effect and gesture are applied to the same view it is in the same space as `position`; if you apply them to different views, map them with `.coordinateSpace(name:)`.

Note: `colorEffect` / `distortionEffect` / `layerEffect` may not work on views backed by UIKit or AppKit (e.g. some `List`, `TextField`, `Map`, `WebView` types); Apple says a warning log and a placeholder image are shown in that case. Apply the effect not to those views but to an `Image`/`Shape`/custom view above them.

## 3. Tap ripple, full example

MSL: `recipes.md` recipe 16.

```swift
struct RippleDemo: View {
    @State private var origin = CGPoint(x: 150, y: 150)
    @State private var startDate: Date?

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { context in
            let t = startDate.map { Float(context.date.timeIntervalSince($0)) } ?? 0
            Image("photo")
                .resizable().scaledToFill()
                .layerEffect(
                    ShaderLibrary.ripple(.float2(origin), .float(t),
                                         .float(14), .float(18), .float(5), .float(900)),
                    maxSampleOffset: CGSize(width: 14, height: 14),
                    isEnabled: startDate != nil && t < 3
                )
        }
        .gesture(SpatialTapGesture().onEnded { value in
            origin = value.location
            startDate = Date()
        })
    }
}
```

- `isEnabled` turns the effect off when the ripple is done (after 3 seconds); the shader does not run for nothing.
- To also stop the timeline when the ripple fades, set `startDate = nil` after 3 seconds (e.g. `.task(id: startDate) { try? await Task.sleep(for: .seconds(3)); startDate = nil }`).

## 4. Scroll-driven effect

The `proxy` inside `visualEffect` gives the view's position; you can pass it to the shader as an argument.

```swift
ScrollView {
    ForEach(0..<20) { i in
        CardView(index: i)
            .visualEffect { content, proxy in
                let y = Float(proxy.frame(in: .global).minY)
                return content.colorEffect(ShaderLibrary.shimmer(.float2(proxy.size), .float(y / 200), .float(0.2)))
            }
    }
}
```

This example drives `shimmer`'s `time` argument with the scroll position. Verify the signature and behavior of `proxy.frame(in:)` by building. In scrolling list cells `layerEffect` / `distortionEffect` can be expensive; measure first with a small list (see `performance-debugging.md`).

## 5. Holographic card driven by tilt (CoreMotion)

```swift
import CoreMotion
import Observation

@Observable
final class TiltModel {
    var tilt = CGSize.zero
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let a = motion?.attitude else { return }
            // roll/pitch are in radians; squeeze about ±0.6 rad into -1...1
            self?.tilt = CGSize(width: max(-1, min(1, a.roll / 0.6)),
                                height: max(-1, min(1, a.pitch / 0.6)))
        }
    }
    func stop() { manager.stopDeviceMotionUpdates() }
}

struct HoloCard: View {
    @State private var model = TiltModel()

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.indigo.gradient)
            .frame(width: 280, height: 400)
            .visualEffect { c, proxy in
                c.colorEffect(ShaderLibrary.holo(.float2(proxy.size),
                                                 .float2(model.tilt.width, model.tilt.height)))
            }
            .onAppear { model.start() }
            .onDisappear { model.stop() }
    }
}
```

The Simulator has no motion sensor; try this example on a real device, and test in the Simulator with the drag gesture (`recipes.md` recipe 8). Stopping updates in `onDisappear` matters. Verify from Apple's CoreMotion documentation whether device motion needs an `Info.plist` usage description; this was not checked when the skill was written.

## 6. Transition with a shader

Combine `ViewModifier` with `Animatable` and `progress` is interpolated by the SwiftUI animation.

```swift
struct DissolveModifier: ViewModifier, Animatable {
    var progress: Double                       // 0 = visible, 1 = gone
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { c, proxy in
            c.colorEffect(ShaderLibrary.dissolve(.float2(proxy.size),
                                                 .float(Float(progress)),
                                                 .float(6),
                                                 .color(.orange)))
        }
    }
}

extension AnyTransition {
    static var shaderDissolve: AnyTransition {
        .modifier(active: DissolveModifier(progress: 1),
                  identity: DissolveModifier(progress: 0))
    }
}

// usage
if show {
    CardView()
        .transition(.shaderDissolve)
}
// withAnimation(.easeInOut(duration: 0.8)) { show.toggle() }
```

`Double` is used for `animatableData`; instead of relying on whether `Float` is `VectorArithmetic`, the value is converted with `Float(progress)` when sent to the shader.

## 7. Chaining effects

Each effect applies to the output of the previous one; order matters.

```swift
Image("photo")
    .resizable().scaledToFit()
    .colorEffect(ShaderLibrary.duotone(.color(.indigo), .color(.yellow)))   // color first
    .layerEffect(ShaderLibrary.chromaticAberration(.float(3)),
                 maxSampleOffset: CGSize(width: 3, height: 0))               // then split channels
    .colorEffect(ShaderLibrary.vignette(.float2(size), .float(0.7)))         // darken last
```

Every `layerEffect` / `distortionEffect` can add a layer cost; keep the chain short.

## 8. Preview, testing and `isEnabled`

- Because the shader lives in a `.metal` file it also runs in `#Preview`; frame rate and heat only show on a real device.
- Toggling the effect with `isEnabled:` is handy for comparison: `.colorEffect(shader, isEnabled: showEffect)`.
- A shader typo (name mismatch) is not caught at compile time; `ShaderLibrary.functionName` is resolved dynamically. If an effect never shows, check the name first, then the argument count and types.
- Inside a Swift Package: `ShaderLibrary.bundle(.module).functionName(...)`.

## 9. Power and accessibility

- Reduce Motion: done inside `AnimatedShader` (section 1). For flashing or fast-moving effects (glitch, flash) check it separately as well.
- Low Power Mode: if `ProcessInfo.processInfo.isLowPowerModeEnabled` is on, lower `fps` or turn off the decorative effect.
- If an effect makes text that carries content unreadable (distortion, glitch), leave a readable copy of the text with an accessibility label. An effect is a visual embellishment; it does not change the `accessibilityLabel`.
- Thermal state: when `ProcessInfo.processInfo.thermalState` is `.serious` or `.critical`, simplifying heavy shaders (aurora, sphereMarch) is good practice.
