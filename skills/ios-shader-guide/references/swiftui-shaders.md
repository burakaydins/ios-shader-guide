# SwiftUI shader API (iOS 17+)

The signatures in this file were verified against Apple's documentation pages for `colorEffect`, `distortionEffect`, `layerEffect`, `Shader` and `Shader.Argument` (the "Copyright 2026" versions of the pages). Anything not verified is marked "not verified".

## Contents
1. Setup and platform support
2. The three modifiers and their MSL signatures
3. Using a shader as a `ShapeStyle`
4. Passing arguments from Swift
5. Animation and time
6. Touch interaction
7. Image (texture) argument
8. How to compute `maxSampleOffset`
9. Views that do not work
10. Banding, `dithersColor` and precompiling
11. Quick error table

## 1. Setup and platform support

- Add a `.metal` file to the project (File ▸ New ▸ File ▸ Metal File). Xcode compiles it into `default.metallib` at build time; MSL syntax errors show up in the build with line numbers.
- Call from Swift with `ShaderLibrary.functionName(...)`. The name is resolved at runtime in Swift; the compiler does not check it.
- Inside a Swift Package or framework: `ShaderLibrary.bundle(.module).functionName(...)`.
- **Platforms:** iOS 17, iPadOS 17, Mac Catalyst 17, macOS 14, tvOS 17, visionOS 1. watchOS is not listed on Apple's pages, so it is not supported.
- The Simulator and Xcode Previews run shaders; speed and heat only show on a real device.

## 2. The three modifiers and their MSL signatures

| Modifier | MSL signature | What it returns |
|---|---|---|
| `colorEffect(_:isEnabled:)` | `[[ stitchable ]] half4 f(float2 position, half4 color, args...)` | The pixel's new color |
| `distortionEffect(_:maxSampleOffset:isEnabled:)` | `[[ stitchable ]] float2 f(float2 position, args...)` | The **source position** for this destination pixel |
| `layerEffect(_:maxSampleOffset:isEnabled:)` | `[[ stitchable ]] half4 f(float2 position, SwiftUI::Layer layer, args...)` | The pixel's new color; read any position with `layer.sample(p)` |

Details (from Apple's documentation):

- `position` is the user-space coordinate of the destination pixel (the view's local coordinate; origin top-left, unit is the point, y grows downward).
- In `colorEffect`, `color` is a **premultiplied** color in the destination color space. If you forget it is multiplied by alpha you see halos or darkening on transparent edges.
- `distortionEffect` returns a source position, not a color: "for this destination pixel, which position should I read". That is why you shift `position` and return it when adding a wave.
- `SwiftUI::Layer` has a single member: `half4 sample(float2 position) const`. The result is linearly filtered, premultiplied RGBA. Apple's docs show the type in the `<SwiftUI/SwiftUI.h>` header; many examples use `<SwiftUI/SwiftUI_Metal.h>`. If one is not found, try the other.
- Apple describes `layerEffect` as "a filter on the raster layer created from the view". For `distortionEffect` a similar layer cost is expected, but that is not verified.
- `maxSampleOffset` (distortion): the maximum distance in each axis between the source pixel position and the destination pixel position. For `layerEffect`: if the shader samples the layer at positions other than the destination, the largest sampling distance.
- All three can also be used inside `visualEffect { content, proxy in ... }` together with `proxy.size`.

## 3. Using a shader as a `ShapeStyle`

`Shader` conforms to `ShapeStyle`: you can paint a shape or text with the color the shader produces. The required signature:

```metal
[[ stitchable ]] half4 name(float2 position, args...)
```

`position` is the user-space coordinate of the pixel being painted; the return value must be a premultiplied color in the destination color space (typically extended sRGB). For the bounds of the text or shape pass the `.boundingRect` argument (section 4).

```swift
Text("Shader").font(.largeTitle.bold())
    .foregroundStyle(ShaderLibrary.textGradient(.boundingRect, .float(t)))
```

Full recipe: `recipes.md` recipe 10.

## 4. Passing arguments from Swift

Arguments must match the shader function's parameters **after** `position` (and `color`/`layer`) in order and type. The table below is verified against the `Shader.Argument` page:

| Swift | MSL parameter |
|---|---|
| `.float(x)` | `float` |
| `.float2(x, y)` / `.float2(CGPoint)` / `.float2(CGSize)` | `float2` |
| `.float3(x, y, z)` | `float3` |
| `.float4(x, y, z, w)` | `float4` |
| `.color(Color)` | `half4`, **premultiplied** in the destination color space |
| `.colorArray([Color])` | `device const half4 *ptr, int count` (two parameters) |
| `.floatArray([Float])` | `device const float *ptr, int count` (two parameters) |
| `.data(Data)` | `device const void *ptr, int size_in_bytes` (two parameters) |
| `.image(Image)` | `texture2d<half>`; **only one image parameter is supported per `Shader` instance** |
| `.boundingRect` | `float4(x, y, width, height)`: the bounds of the shape or view the shader is attached to. Undefined for shaders with no natural bounds (e.g. `GraphicsContext` filters) |

Notes:

- The numeric factories are generic (`float<T>`); you can pass `Float`, `CGFloat` and `Double` variables without converting.
- No separate argument type is listed for `Int` or `Bool`. If you need an integer or a flag, pass it with `.float(...)` and use `int(x)` / `x > 0.5` in MSL.
- For array arguments you write **two** parameters in MSL (pointer + count); write one and the argument count no longer matches, so the effect does not work.
- `.color(...)` arrives premultiplied, so with a translucent color the rgb is already multiplied by alpha.

## 5. Animation and time

A shader is stateless; you pass the time. For a reusable `AnimatedShader` see `swift-patterns.md` section 1.

```swift
@State private var start = Date()

TimelineView(.animation) { context in
    let t = Float(context.date.timeIntervalSince(start))
    Rectangle()
        .visualEffect { content, proxy in
            content.colorEffect(ShaderLibrary.plasma(.float2(proxy.size), .float(t)))
        }
}
```

**Why not `timeIntervalSinceReferenceDate`?** That value is about 8×10⁸ seconds. A `Float` of that size is represented in steps of roughly 64 seconds, so the animation stays frozen for minutes and then jumps. Send the small time elapsed since a start point.

`TimelineView(.animation(minimumInterval: 1.0 / 30.0))` halves the frame rate; for light ambient effects it is a good default for battery and heat.

## 6. Touch interaction

Pass the touch point as an argument; full example in `swift-patterns.md` sections 2–3. `DragGesture().location` is in the local coordinate of the view the gesture is attached to; as long as the effect is applied to the same view it is in the same space as `position`.

## 7. Image (texture) argument

You can pass an image such as a noise texture to a shader. Apple's WWDC 2026 session "322" shows a similar approach with `layerEffect`; the code below is an example I wrote, adapted from that idea.

```swift
.layerEffect(
    ShaderLibrary.backgroundWarp(.float2(proxy.size), .image(Image("NoiseTexture"))),
    maxSampleOffset: CGSize(width: 100, height: 100)
)
```

```metal
[[ stitchable ]] half4 backgroundWarp(float2 position, SwiftUI::Layer layer,
                                      float2 size, texture2d<half> noiseTex) {
    constexpr sampler s(address::repeat, filter::linear);
    half4 n = noiseTex.sample(s, position / size);
    float2 offset = (float2(n.r, n.g) - 0.5f) * 200.0f;
    return layer.sample(position + offset);
}
```

Texture coordinates are normalized 0–1; `position / size` gives that. Because the offset is `(n − 0.5) * 200`, a pixel moves at most ±100 points per axis, so `maxSampleOffset` is 100. **You can use only one `.image` argument per Shader**; if you need two textures, generate the noise inside the shader or use `valueNoise` from `ShaderHelpers.h`.

## 8. How to compute `maxSampleOffset`

Rule: find, separately for x and y, **the farthest in points the shader will read a pixel from**.

- Wave: `position.y += sin(...) * 12` → `CGSize(width: 0, height: 12)`
- Chromatic aberration: `±amount` horizontally → `CGSize(width: amount, height: 0)`
- Pixelate: the cell size → `CGSize(width: cell, height: cell)`
- Swirl (rotation): the diameter → `2 × radius`
- Color effects that do not shift position (`colorEffect`) have no such parameter.

Too large costs performance; too small can make the effect wrong at the edges. How to measure: set the parameters to their extreme values and work out the largest read distance on each axis.

Apple's pages do not say whether an effect may spill outside the view bounds. For an effect that must go outside (glow, shadow) give the view `.padding`.

## 9. Views that do not work

All three modifier pages carry this warning: SwiftUI views backed by UIKit or AppKit views may not render into the filtered layer; in that case a warning is logged and a placeholder image is shown to highlight the error.

Practical consequence: if you see a pink/placeholder image on the view you applied the effect to, the view relies on a platform component (e.g. some `List`/`Form` cells, text fields, maps, web views). Apply the effect not to that component but to a pure SwiftUI view (`Image`, `Shape`, `Text`, a stack) above it. You cannot say for certain which view is affected; build and try.

## 10. Banding, `dithersColor` and precompiling

- **`Shader.dithersColor`**: for shaders that return a color, whether the returned color gets dither noise added or is simply rounded to the output bit depth. Apple says dither is usually needed to prevent visible banding in shaders that generate smooth gradients. `ShaderLibrary.plasma(...)` returns a `Shader`; to set the property you must first put it in a variable: `var s = ShaderLibrary.plasma(...); s.dithersColor = true`. How this property interacts with `colorEffect` is not made clear in the docs; build it and compare by eye.
- **`Shader.compile(as:)`**: `func compile(as: Shader.UsageType) async throws`. It compiles the shader asynchronously and lowers the chance of a stall on first use. Verify the exact names of the `UsageType` values and the method's iOS version from Apple's page; if you see a stutter on the first frame, warm up the shaders you will use at app launch this way.

## 11. Quick error table

| Symptom | Likely cause |
|---|---|
| Build error | MSL syntax; the `.metal` error shows with a line number in Xcode |
| Effect not showing | Name mismatch; `[[ stitchable ]]` missing; first parameter is not `float2 position`; argument count/type mismatch; array argument did not get two parameters |
| Placeholder / pink image | The view is backed by UIKit/AppKit (section 9) |
| Edges clipped | `maxSampleOffset` insufficient, or no `.padding` for a glow |
| Image upside down | It came from Shadertoy; flip the y axis |
| All black | Wrong variable instead of `layer.sample` in `layerEffect`; returning alpha 0; `NaN` (see `performance-debugging.md`) |
| Colors washed out/dark/haloed | Premultiplied alpha mix-up |
| Bands in a gradient | `dithersColor` (section 10) |
| Animation freezes and jumps | Time was given from the reference date (section 5) |

To see a value, temporarily turn it into a color: `return half4(half3(value), 1.0h);`. There is no `print` inside a shader; "debugging by color" is the main method (`performance-debugging.md`).
