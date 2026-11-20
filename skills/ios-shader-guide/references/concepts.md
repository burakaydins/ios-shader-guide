# How a shader works

When the user asks "how does it work", explain in this order; each step builds on the previous one. Avoid needless jargon; if the user is new, explain terms such as "fragment" and "uniform" in one sentence the first time they appear. For a beginner, show one simple example first (e.g. `vignette`), then move on to the concepts.

## Contents
1. The basic idea
2. The flow in SwiftUI
3. Coordinate system
4. Four building-block functions
5. Randomness and noise
6. Drawing shapes: SDF
7. Color palettes
8. Domain warping
9. Learning ladder
10. Common misunderstandings

## 1. The basic idea

A CPU does work sequentially. A GPU, with thousands of small cores, runs the same small function **for every pixel at the same time**. The shader is that function. Each pixel asks itself: "What color should I be?"

Consequences:
- Pixels know nothing about each other. One pixel's result cannot be passed to another; shared information comes from outside (uniforms).
- The function is stateless. There is no "previous frame". For animation you pass the time in from outside.
- Everything is built with formulas: a wave is `sin`, a circle is `length`, a soft transition is `smoothstep`.

Analogy: picture a mosaic wall and you are writing a rule that says each tile's color; the tiles cannot see each other, they only know their own position and the shared notes (time, size).

## 2. The flow in SwiftUI

1. SwiftUI draws the view (colors/layers are ready).
2. The shader you gave to the modifier runs for every pixel.
3. Inputs: `position` (this pixel's location), `color` or `layer` depending on the type, and the **uniforms** you pass from Swift (time, size, touch point...).
4. Output: a new color (`colorEffect`, `layerEffect`) or a position to read from (`distortionEffect`).

"Uniform" = a value given to the shader from outside, the same for all pixels in that frame.

Tell the three types apart by intuition:
- `colorEffect`: "paint this pixel's color" (sees only its own color).
- `distortionEffect`: "which point of the image should this pixel be taken from" (shifts the position, not the color).
- `layerEffect`: "look anywhere in the image and build a new color from what you see" (reads neighboring pixels).

## 3. Coordinate system

`position` is in points and starts at the top-left. Most formulas are normalized so they do not depend on the screen:

```metal
float2 uv = position / size;                       // 0..1, top-left (0,0), bottom-right (1,1)
float2 p  = (position - 0.5 * size) / size.y;      // center (0,0), height -0.5..0.5, aspect ratio preserved
```

The second is essential when drawing circles: with `uv` the circle turns into an oval because x and y scale differently. Since `p.y` grows downward, flip the sign for directional shapes (an arrow pointing up). `centeredUV` in `ShaderHelpers.h` does this.

## 4. Four building-block functions

| Function | What it does | Intuition |
|---|---|---|
| `mix(a, b, t)` | Linear blend between `a` and `b` | t=0 → a, t=1 → b |
| `step(e, x)` | 0 if x < e, otherwise 1 | hard threshold |
| `smoothstep(e0, e1, x)` | 0 below e0, 1 above e1, smooth in between | edge softening. **`e0 < e1` is required** |
| `fract(x)` | fractional part (x − floor(x)) | repeating pattern, a 0..1 sawtooth |

Combine these with `sin`, `abs`, `clamp`, `length` and `dot` and you get most effects you see.

## 5. Randomness and noise

There are no random numbers in a shader; instead a "hash" is used, a formula that scrambles its input into 0..1. The same input always gives the same value (deterministic), so it does not flicker from frame to frame; if you want flicker, feed time into the input.

This skill's helpers live in `ShaderHelpers.h` (all `static inline`):

- `hash21(float2)`, `hash22(float2)`: sine-free hashes. The classic `fract(sin(dot(p, ...)) * 43758.5)` hash can give GPU-dependent results with large inputs; the sine-free form avoids that.
- `valueNoise(float2)`: smoothly blends random values at integer grid corners.
- `fbm(float2)`: a sum of noise at different scales (5 octaves): cloud, smoke, marble.
- `voronoi(float2)`: distance to the nearest two "feature points": cells, cracks, underwater light.

The code is in `recipes.md` and `advanced-techniques.md`; it is not repeated here so two copies cannot drift apart.

`valueNoise`'s 2D grid: `floor(p)` gives the cell, `fract(p)` gives the position inside the cell; the corner hashes are blended with `mix`; `u = f*f*(3-2f)` is a `smoothstep` curve, so transitions are smooth.

## 6. Drawing shapes: SDF

An SDF (signed distance function) is the signed distance from a point to a shape: negative inside, positive outside.

```metal
float d = sdCircle(p, 0.25);                      // ShaderHelpers.h
float shape = 1.0 - smoothstep(-aa, aa, d);       // aa ≈ 1.5 / size.y: about 1 pixel of softening
```

You combine shapes with `min` (union), `max` (intersection) and `max(a, -b)` (subtraction). Circles, boxes, lines and complex logos are drawn with the same logic. Library: `advanced-techniques.md` section 2.

## 7. Color palettes

Instead of picking colors by hand, one formula produces a beautiful, continuous palette (Inigo Quilez's cosine palette). It lives in `ShaderHelpers.h` as `palette(float t)`:

```metal
float3 palette(float t) {
    return 0.5f + 0.5f * cos(TAU * (t + float3(0.0f, 0.33f, 0.67f)));
}
```

Feed `t` with time, noise or distance and the color flows. If the design color is fixed, skip the palette and pass the color from Swift with `.color(...)`.

## 8. Domain warping

Distort a function's input with another noise before calling it:

```metal
float n = fbm(p + fbm(p + time * 0.1));
```

Most background "lava lamp" effects and organic fluid looks are this single line. If the user says "fluid, liquid, aurora", start from `recipes.md` recipe 2.

## 9. Learning ladder

If the user wants to learn from scratch, suggest this order; each step uses the one before:

1. `vignette` (one formula, `colorEffect`): `uv`, `length`, `smoothstep`.
2. `shimmer` and `scanlines`: a time uniform, `fract`, `sin`.
3. `wave` (`distortionEffect`): "shifting the position, not the color".
4. `chromaticAberration` and `pixelate` (`layerEffect`): `layer.sample`, `maxSampleOffset`.
5. `plasma`: `palette`, stacked sines.
6. `metaballs`: SDF and `smin`.
7. `aurora`: noise, `fbm`, domain warping.
8. `sphereMarch`: raymarching.
9. Port a Shadertoy shader (`shadertoy-to-msl.md`).

At each step suggest the user change one parameter and watch the result; shader intuition comes from playing, not reading. The `examples/ShaderLab` project was written for this.

## 10. Common misunderstandings

- **"A shader redraws the view."** No: SwiftUI draws the view and the shader applies a filter to that output (Apple's description: a filter on the raw layer).
- **"The shader knows the time itself."** No, time comes from Swift every frame.
- **"`position` is pixels."** No, it is points. On a Retina screen one point is several pixels.
- **"`if` is bad."** Partly: if neighboring pixels take different branches the GPU may run both; a simple `if` is not a problem. Measure, do not guess.
- **"More octaves is prettier."** Every octave adds cost; 3–4 octaves is often enough.
- **"Shaders work everywhere."** SwiftUI shaders may not work on UIKit/AppKit-backed views (`swiftui-shaders.md` section 9).
