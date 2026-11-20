---
name: ios-shader-guide
description: Shader guide for iOS, SwiftUI and Metal. Explains how shaders work, writes Metal Shading Language (MSL) shaders from scratch, ports Shadertoy/GLSL shaders to SwiftUI, and debugs shader errors and performance (including the Xcode Metal debugger). Use whenever the user mentions shader, Metal, MSL, .metal, colorEffect, distortionEffect, layerEffect, ShaderLibrary, stitchable, Shadertoy, GLSL, fragment shader, noise, fbm, SDF, raymarching, RealityKit CustomMaterial, ShaderGraph, or wants a custom visual effect in SwiftUI (wave, glow, glitch, pixelate, chromatic aberration, ripple, holographic card, aurora, gradient text), even if the word "shader" never appears.
license: MIT
compatibility: SwiftUI shader modifiers need iOS 17+, macOS 14+, tvOS 17+, visionOS 1+ (not watchOS). Xcode is required; this skill ships no compiler.
---

# iOS Shader Guide

In SwiftUI a shader is a small Metal function that runs on the GPU for every pixel. This skill covers five jobs: **explaining**, **writing from scratch**, **porting** (Shadertoy/GLSL → MSL + SwiftUI), **debugging and speeding up**, and **choosing the right tool** (SwiftUI, RealityKit, ShaderGraph, MTKView). Reply in the language the user writes in; code, API names and identifiers stay in English.

## Work out what is being asked

| Request | Start here |
|---|---|
| "What is a shader / how does it work / where do I start" | `references/concepts.md` (section 9: learning ladder) |
| "Make effect X in SwiftUI" (wave, glow, glitch, pixelate...) | "Writing from scratch" below + `references/recipes.md` (21 ready recipes) |
| "Convert this Shadertoy/GLSL code to Swift" | `references/shadertoy-to-msl.md` |
| Touch, scroll, tilt, transitions, animation plumbing | `references/swift-patterns.md` |
| SDF, raymarching, noise, UI pieces, banding | `references/advanced-techniques.md` |
| "It doesn't work / blank screen / slow / getting hot" | `references/performance-debugging.md` |
| API signatures, argument types, `maxSampleOffset` | `references/swiftui-shaders.md` |
| Swift developer who does not know MSL | `references/msl-primer.md` |
| 3D object, RealityKit, ShaderGraph, Reality Composer Pro | `references/realitykit-shadergraph.md` |
| Galleries, inspiration, official sources, other skills | `references/galleries.md` |

Do not read big files end to end; open the relevant section. Every file starts with a table of contents.

## Choose the right tool

The default for most requests is the SwiftUI shader modifiers (iOS 17+). Switch only in the cases below, and say why in one sentence.

| Situation | Tool |
|---|---|
| Per-pixel effect on a view (color, distortion, filter) | `colorEffect` / `distortionEffect` / `layerEffect` |
| Paint text or a shape with a shader | Pass the shader as a `ShapeStyle`: `.foregroundStyle(ShaderLibrary.f(...))` |
| Animated background | Same, plus `TimelineView(.animation)` (`AnimatedShader`, `swift-patterns.md` section 1) |
| Only a soft color blend (iOS 18+) | `MeshGradient`, no shader needed |
| Drawing many shapes | `Canvas` |
| Surface or vertices of a 3D object | RealityKit `CustomMaterial` or ShaderGraph (`realitykit-shadergraph.md`) |
| Multiple passes (Shadertoy "Buffer A/B"), compute, feedback, own render loop | `MTKView` + Metal pipeline (SwiftUI modifiers are not enough) |
| Photo/video filter chains | Core Image (`CIKernel`) |

## Fixed API facts

These were verified against Apple's documentation. Do not write something else from memory.

| Modifier | MSL signature |
|---|---|
| `colorEffect(_:isEnabled:)` | `[[ stitchable ]] half4 f(float2 position, half4 color, args...)` |
| `distortionEffect(_:maxSampleOffset:isEnabled:)` | `[[ stitchable ]] float2 f(float2 position, args...)`: returns the **source position** |
| `layerEffect(_:maxSampleOffset:isEnabled:)` | `[[ stitchable ]] half4 f(float2 position, SwiftUI::Layer layer, args...)` |
| `Shader` (as a `ShapeStyle`) | `[[ stitchable ]] half4 f(float2 position, args...)` (no `color`) |

- `position` is the view's local coordinate, in **points**, origin **top-left**.
- `color`, the result of `layer.sample()`, and a `.color(...)` argument are all **premultiplied** alpha.
- A `Shader` can take only **one** `.image` argument. `.floatArray`, `.colorArray` and `.data` expand to **two** MSL parameters (pointer + count). There are no `Int`/`Bool` arguments; pass `.float(...)`.
- Effects may not work on views backed by UIKit/AppKit (a placeholder image appears).
- Platforms: iOS/iPadOS 17, macOS 14, tvOS 17, visionOS 1; no watchOS.

## Writing from scratch

1. **Describe the effect in one sentence and pick the type.** Does it change color (`colorEffect`), shift where a pixel is read from (`distortionEffect`), or read neighboring pixels (`layerEffect`)? Picking the wrong type is the most common design mistake. First check whether `recipes.md` has a similar recipe; adapt it rather than starting blank.
2. **Decide the uniforms.** A shader is stateless; time, size, touch point and colors must all be passed from Swift. For time, send seconds since the start, not `timeIntervalSinceReferenceDate` (Float precision makes the animation freeze and jump).
3. **Write the `.metal` file.** `#include <metal_stdlib>`, `#include <SwiftUI/SwiftUI_Metal.h>`, `using namespace metal;`. The function must be `[[ stitchable ]]`. For noise, palette, SDF and similar helpers use `examples/ShaderLab/ShaderHelpers.h`; make shared helpers `static inline` (the same name in two files collides).
4. **Write the Swift side.** `ShaderLibrary.functionName(.float(...), ...)`: the arguments must match the parameters after `position`/`color`/`layer` **in order and type**.
5. **Compute `maxSampleOffset`** (`layerEffect`/`distortionEffect`): the farthest, in points, the effect reads a pixel from, separately for x and y. If the effect spills outside the view bounds (glow, shadow), add `.padding` to the view.
6. **Deliver in this order:** the `.metal` file, the Swift view, a 3–5 sentence "what it does", and a list of tunable parameters **with units** (points, 0–1, radians, seconds), plus a cost warning if relevant.
7. **Accessibility and power:** respect Reduce Motion for continuous animation (`AnimatedShader` does), and lower the frame rate for heavy effects.

## Porting (Shadertoy/GLSL → SwiftUI)

1. **Check the license.** On Shadertoy the default license, unless stated otherwise, is generally CC BY-NC-SA 3.0 (no commercial use, attribution and share-alike required). Warn the user if the app is commercial; read the license in the code header; options: ask the author, pick a freely licensed shader, or rewrite the idea in your own code. Do not give legal opinions.
2. **Decide whether it is portable.** A single-pass `mainImage` ports. `Buffer A–D`, audio, video, cube maps and anything reading the previous frame via `iFrame` do not; they need `MTKView`. Say so up front instead of converting for nothing.
3. **Apply the conversion table** (`shadertoy-to-msl.md` section 2): type names, `mod`, `atan`, `out`/`inout`, globals, reversed-edge `smoothstep`.
4. **Flip the y axis once, at the entry point.** Shadertoy's origin is bottom-left; SwiftUI's is top-left.
5. **For big shaders use the wrapper pattern** (`shadertoy-to-msl.md` section 5): keep the original body almost untouched and add a thin `[[ stitchable ]]` wrapper.
6. **`position` is in points, not pixels.** Multiply pixel-based constants by `displayScale`.
7. Give everything you converted, naming the lines you changed, so the user can compare with the original. Add an attribution header (template: section 10).

## Debugging shortcut

1. First the **decision tree in `performance-debugging.md` section 7**: name, `[[ stitchable ]]`, parameter order, right modifier, UIKit-backed view, alpha.
2. Then **debug with color**: `debugUV`, `debugAlpha`, `debugGrid`, `debugRamp` (section 5). There is no `print` inside a shader.
3. For compile error text use the dictionary in `performance-debugging.md` section 6.
4. For a heavy or slow effect use Xcode's Metal debugger: step through the shader line by line and see per-line cost (section 9). Give the user the steps one by one: embed source in the build, GPU Frame Capture, Metal Capture, Shader Debugger.

## Common mistakes

- **The effect never shows.** Does the function name match Swift exactly? Is `[[ stitchable ]]` there? Is the first parameter `float2 position`? Do argument count and types match (array arguments need two parameters)? On a mismatch the effect is usually silently not applied.
- **Placeholder / pink image.** The view is backed by UIKit/AppKit; apply the effect to a pure SwiftUI view.
- **Edges are clipped.** `maxSampleOffset` is too small, or `.padding` was not given for a glow.
- **Black/empty `layerEffect`.** A `layerEffect` has no `color`, it has `SwiftUI::Layer`; read with `layer.sample(position)`.
- **Transparent areas turn black or get a halo.** Premultiplied alpha: multiply the result by `color.a`, or use `unpremultiply` (ShaderHelpers.h).
- **`smoothstep(0.8, 0.2, x)` gives random results.** `edge0 < edge1` is required; to invert write `1.0 - smoothstep(0.2, 0.8, x)`.
- **Animation freezes and jumps.** Time was sent from a huge reference point; send the time since start.
- **Collision with another `.metal` file.** Make helpers `static inline` and include them from a shared `.h`.
- **Leftover GLSL `mod`.** `fmod` differs for negative values; use `glslMod`.
- **The effect is very slow / the device heats up.** `performance-debugging.md` section 2: shrink the area, lower `fps`, shorten loops, stop with `isEnabled`, use `half`.
- **`NaN`.** Expressions such as `normalize(0)` and `0/0` produce black or broken pixels; never leave them unguarded.
- **The effect stutters in a `List` cell or scrolling list.** `layerEffect`/`distortionEffect` can be expensive in lists; shrink the effect, reduce how many there are, measure.

## Be honest about verification

The environment this skill runs in usually has no Xcode and no Metal compiler. If you could not compile the shader, do not say "it compiles"; say "it needs to be compiled in Xcode; send the error text if you get one". If you can run commands on the user's Mac, first try `xcrun -sdk iphoneos metal -c file.metal -o /tmp/x.air`. If it says the Metal Toolchain is missing (Xcode 26 and later ship it separately), the fix is `xcodebuild -downloadComponent MetalToolchain` (about 700 MB; ask before downloading). If the SwiftUI header is not found, that is not a shader bug, build in Xcode. To check that Swift arguments match the shader parameters, use the approach in `tools/check_arguments.py`. On Linux you can only run a rough syntax check (`tools/syntax_check.py`); it does not replace Xcode. State performance claims (fps, heat) only from numbers measured on a real device. When unsure about an Apple API detail (a newer version, a new signature), verify it from Apple's documentation (plain text via the `...documentation/...md` form); do not speak confidently from memory.

## Files in this skill

- `references/`: the documents in the table above. `recipes.md`, `shadertoy-to-msl.md`, `advanced-techniques.md` and `performance-debugging.md` are generated; change the code in `examples/ShaderLab/*.metal`.
- `examples/ShaderLab/`: a runnable demo project with every recipe (create a new iOS App in Xcode and add the files; steps in `TESTING.md`).
- `tools/`: `build_recipes.py` (generates the docs), `syntax_check.py` (rough syntax check).
