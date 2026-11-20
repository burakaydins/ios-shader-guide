// Advanced.metal
// Building blocks and small UI shaders used in references/advanced-techniques.md.
//
// License: MIT (see LICENSE at the repo root).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "ShaderHelpers.h"
using namespace metal;

// <recipe:coordHelpers>
// Polar coordinates: x = distance from the origin, y = angle in -pi...pi.
static inline float2 toPolar(float2 p) { return float2(length(p), atan2(p.y, p.x)); }

// Repeat space: returns coordinates local to each cell, centered on (0,0).
// The cell index is floor(p / cell).
static inline float2 tileLocal(float2 p, float2 cell) { return (fract(p / cell) - 0.5f) * cell; }

// Mirror space around the axes: abs(p) is enough; kept here for readability.
static inline float2 mirrorXY(float2 p) { return abs(p); }

// Triangle wave 0...1...0 with period 1 (ping-pong a value).
static inline float pingPong(float t) { return 1.0f - abs(fract(t * 0.5f) * 2.0f - 1.0f); }
// </recipe:coordHelpers>

// <recipe:sdfOps>
static inline float sdBox(float2 p, float2 halfSize) {
    float2 q = abs(p) - halfSize;
    return length(max(q, 0.0f)) + min(max(q.x, q.y), 0.0f);
}
static inline float sdRing(float2 p, float radius, float halfWidth) {
    return abs(length(p) - radius) - halfWidth;
}

static inline float opUnion(float a, float b)     { return min(a, b); }
static inline float opIntersect(float a, float b) { return max(a, b); }
static inline float opSubtract(float a, float b)  { return max(a, -b); }   // a minus b
static inline float opOnion(float d, float t)     { return abs(d) - t; }   // hollow out a shape

// Turn a distance into an anti-aliased fill / stroke. `aa` is one pixel in the
// same units as `d` (for uv scaled by size.y, use 1.5 / size.y).
static inline float fillAA(float d, float aa)             { return 1.0f - smoothstep(-aa, aa, d); }
static inline float strokeAA(float d, float w, float aa)  { return 1.0f - smoothstep(w - aa, w + aa, abs(d)); }
// </recipe:sdfOps>

// <recipe:ign>
// Interleaved gradient noise: cheap per-pixel dither pattern, range 0...1.
// Add (ign(position) - 0.5) / 255.0 to a color to break up banding in gradients.
static inline float ign(float2 position) {
    return fract(52.9829189f * fract(dot(position, float2(0.06711056f, 0.00583715f))));
}
// </recipe:ign>

// <recipe:dotGrid>
[[ stitchable ]] half4 dotGrid(float2 position, half4 color, float spacing, float radius, half4 dotColor) {
    float2 cellPos = tileLocal(position, float2(spacing));
    float d = length(cellPos) - radius;
    float cover = fillAA(d, 0.75f);                                  // about 1.5 pt wide edge
    return dotColor * half(cover) + color * half(1.0f - cover);      // dotColor is premultiplied
}
// </recipe:dotGrid>

// <recipe:progressRing>
// progress 0...1, clockwise from 12 o'clock. Colors are premultiplied (.color(...)).
[[ stitchable ]] half4 progressRing(float2 position, half4 color, float2 size, float progress,
                                    float thickness, half4 trackColor, half4 fillColor) {
    float2 p = position - 0.5f * size;
    float radius = 0.5f * min(size.x, size.y) - thickness;
    float d = sdRing(p, radius, 0.5f * thickness);
    float cover = fillAA(d, 0.75f);
    float angle = fract(atan2(p.x, -p.y) / TAU);       // 0 at the top, grows clockwise on screen
    half filled = half(step(angle, progress));
    half4 ring = mix(trackColor, fillColor, filled);
    return ring * half(cover) + color * half(1.0f - cover);
}
// </recipe:progressRing>

// <recipe:raymarchScene>
static inline float sdBox3(float3 p, float3 halfSize) {
    float3 q = abs(p) - halfSize;
    return length(max(q, 0.0f)) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

// A scene made of several shapes: min = union, smin = blobby union,
// max(a, -b) = subtract b from a. Add more terms here and the raymarcher
// (see sphereMarch) draws them without further changes.
static inline float sceneSDFMulti(float3 p, float time) {
    float sphere = length(p - float3(0.9f * sin(time), 0.0f, 0.0f)) - 0.6f;
    float box = sdBox3(p - float3(-0.9f * sin(time), 0.0f, 0.0f), float3(0.45f));
    float floorPlane = p.y + 1.0f;
    return min(smin(sphere, box, 0.4f), floorPlane);
}
// </recipe:raymarchScene>

// <recipe:debugShaders>
// Debug by color: apply one of these in place of your effect to SEE a value.
// Swift:  content.colorEffect(ShaderLibrary.debugUV(.float2(proxy.size)))

[[ stitchable ]] half4 debugUV(float2 position, half4 color, float2 size) {
    float2 uv = position / size;                       // red = x, green = y, origin top-left
    return half4(half(uv.x), half(uv.y), 0.0h, 1.0h);
}

[[ stitchable ]] half4 debugAlpha(float2 position, half4 color) {
    return half4(half3(color.a), 1.0h);                // white = opaque, black = transparent
}

// Shows a number as a gray ramp: 0 -> black, 1 -> white. Magenta = NaN or inf.
// Pass your computed value as `value` from a copy of your shader to inspect it.
static inline half4 debugRamp(float value) {
    if (!isfinite(value)) { return half4(1.0h, 0.0h, 1.0h, 1.0h); }
    return half4(half3(half(saturate(value))), 1.0h);
}

[[ stitchable ]] half4 debugGrid(float2 position, half4 color, float spacing) {
    // distance (in points) to the nearest grid line
    float2 g = abs(fract(position / spacing + 0.5f) - 0.5f) * spacing;
    float lineMask = 1.0f - smoothstep(0.0f, 1.0f, min(g.x, g.y));
    return mix(color, half4(1.0h, 0.2h, 0.2h, 1.0h), half(lineMask));
}
// </recipe:debugShaders>
