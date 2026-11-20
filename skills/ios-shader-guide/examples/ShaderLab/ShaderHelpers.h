// ShaderHelpers.h
// Shared helper functions for the ios-shader-guide recipes.
// License: MIT (see LICENSE at the repo root).
//
// Metal files cannot share non-inline functions across translation units, so the
// helpers are `static inline` in a header and each .metal file includes it.

#pragma once
#include <metal_stdlib>
using namespace metal;

#define TAU 6.28318530718f

// MARK: hash / noise ----------------------------------------------------------
// Sine-free hashes (Dave Hoskins style): same result on every GPU, no precision
// cliff for large inputs like the classic fract(sin(dot(...))) hash.

static inline float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031f);
    p3 += dot(p3, p3.yzx + 33.33f);
    return fract((p3.x + p3.y) * p3.z);
}

static inline float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031f, 0.1030f, 0.0973f));
    p3 += dot(p3, p3.yzx + 33.33f);
    return fract((p3.xx + p3.yz) * p3.zy);
}

static inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0f - 2.0f * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0f, 0.0f));
    float c = hash21(i + float2(0.0f, 1.0f));
    float d = hash21(i + float2(1.0f, 1.0f));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian motion: sum of noise at doubling frequency, halving amplitude.
// Range is roughly 0 ... 0.97 for 5 octaves.
static inline float fbm(float2 p) {
    float v = 0.0f;
    float amp = 0.5f;
    for (int i = 0; i < 5; i++) {
        v += amp * valueNoise(p);
        p *= 2.0f;
        amp *= 0.5f;
    }
    return v;
}

// F1 and F2 distances to the nearest feature points (cellular / Voronoi noise).
static inline float2 voronoi(float2 p) {
    float2 g = floor(p);
    float2 f = fract(p);
    float d1 = 8.0f;
    float d2 = 8.0f;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 o = float2(float(i), float(j));
            float2 r = o + hash22(g + o) - f;
            float d = dot(r, r);
            if (d < d1) { d2 = d1; d1 = d; }
            else if (d < d2) { d2 = d; }
        }
    }
    return sqrt(float2(d1, d2));
}

// MARK: color -----------------------------------------------------------------

// Inigo Quilez cosine palette: smooth, endless, one formula.
static inline float3 palette(float t) {
    return 0.5f + 0.5f * cos(TAU * (t + float3(0.0f, 0.33f, 0.67f)));
}

static inline half3 unpremultiply(half4 c) {
    return c.a > 0.0h ? c.rgb / c.a : half3(0.0h);
}

// MARK: geometry --------------------------------------------------------------

static inline float2 rotate2d(float2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Centered, aspect-correct coordinates: (0,0) is the middle, height spans -0.5...0.5.
// Note: y still grows downward, like SwiftUI.
static inline float2 centeredUV(float2 position, float2 size) {
    return (position - 0.5f * size) / size.y;
}

static inline float sdCircle(float2 p, float r) { return length(p) - r; }

static inline float sdRoundBox(float2 p, float2 halfSize, float r) {
    float2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0f)) + min(max(q.x, q.y), 0.0f) - r;
}

static inline float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0f, 1.0f);
    return length(pa - ba * h);
}

// Polynomial smooth minimum: blends two distances (metaball / gooey effect).
static inline float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0f) / k;
    return min(a, b) - h * h * k * 0.25f;
}
