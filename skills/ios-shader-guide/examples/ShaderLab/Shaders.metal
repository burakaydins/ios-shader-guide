// Shaders.metal
// All recipes of the ios-shader-guide skill in one file.
// This file is the single source of truth: tools/build_recipes.py copies the
// blocks between `// <recipe:NAME>` and `// </recipe:NAME>` into the docs.
//
// NOT compiled by the author of the skill (no Metal toolchain available when it
// was written). Build it in Xcode and report any error. See TESTING.md.
//
// License: MIT (see LICENSE at the repo root).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "ShaderHelpers.h"
using namespace metal;

// =============================================================================
// colorEffect:  half4 f(float2 position, half4 color, args...)
// =============================================================================

// <recipe:plasma>
[[ stitchable ]] half4 plasma(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / size;
    float v = sin(uv.x * 10.0f + time)
            + sin(uv.y * 10.0f + time * 1.3f)
            + sin((uv.x + uv.y) * 10.0f + time * 0.7f);
    float3 col = palette(v / 3.0f);
    return half4(half3(col), 1.0h) * color.a;
}
// </recipe:plasma>

// <recipe:aurora>
[[ stitchable ]] half4 aurora(float2 position, half4 color, float2 size, float time) {
    float2 p = position / size.y * 2.0f;
    float t = time * 0.15f;
    // domain warping: use noise to bend the coordinates of more noise
    float2 q = float2(fbm(p + t), fbm(p + float2(5.2f, 1.3f) - t));
    float n = fbm(p + 2.0f * q + t * 0.5f);
    float3 col = mix(float3(0.02f, 0.05f, 0.15f), float3(0.10f, 0.90f, 0.60f), smoothstep(0.2f, 0.8f, n));
    col = mix(col, float3(0.60f, 0.30f, 0.90f), smoothstep(0.5f, 1.0f, q.x * q.y * 2.0f));
    return half4(half3(col), 1.0h) * color.a;
}
// </recipe:aurora>

// <recipe:vignette>
[[ stitchable ]] half4 vignette(float2 position, half4 color, float2 size, float strength) {
    float2 uv = position / size - 0.5f;
    float v = 1.0f - smoothstep(0.2f, 0.8f, length(uv));   // 1 in the center, 0 at the corners
    half k = half(mix(1.0f, v, strength));
    return half4(color.rgb * k, color.a);
}
// </recipe:vignette>

// <recipe:shimmer>
[[ stitchable ]] half4 shimmer(float2 position, half4 color, float2 size, float time, float width) {
    float x = position.x / size.x;
    float center = fract(time * 0.4f) * 1.4f - 0.2f;          // sweeps from -0.2 to 1.2
    float band = 1.0f - smoothstep(0.0f, width, abs(x - center));
    return half4(color.rgb + half3(half(band)) * color.a, color.a);
}
// </recipe:shimmer>

// <recipe:duotone>
[[ stitchable ]] half4 duotone(float2 position, half4 color, half4 shadow, half4 highlight) {
    half3 rgb = unpremultiply(color);
    half lum = dot(rgb, half3(0.299h, 0.587h, 0.114h));
    half3 mapped = mix(shadow.rgb, highlight.rgb, lum);
    return half4(mapped * color.a, color.a);
}
// </recipe:duotone>

// <recipe:filmGrain>
[[ stitchable ]] half4 filmGrain(float2 position, half4 color, float time, float intensity) {
    float n = hash21(position + floor(time * 24.0f) * 17.0f);   // new grain 24 times a second
    half g = half((n - 0.5f) * intensity);
    return half4(color.rgb + g * color.a, color.a);
}
// </recipe:filmGrain>

// <recipe:scanlines>
[[ stitchable ]] half4 scanlines(float2 position, half4 color, float spacing, float strength) {
    float line = 0.5f + 0.5f * sin(position.y * TAU / spacing);
    half k = half(1.0f - strength * line);
    return half4(color.rgb * k, color.a);
}
// </recipe:scanlines>

// <recipe:holo>
[[ stitchable ]] half4 holo(float2 position, half4 color, float2 size, float2 tilt) {
    float2 uv = position / size;
    float t = (uv.x + uv.y) * 1.5f + tilt.x * 1.2f + tilt.y * 0.6f;
    half3 rainbow = half3(palette(t));
    float grain = step(0.985f, hash21(floor(position / 3.0f)));      // glitter specks
    float glint = grain * (0.5f + 0.5f * sin(tilt.x * 6.0f + uv.x * 20.0f));
    half3 sheen = rainbow * 0.30h + half3(half(glint));
    return half4(color.rgb + sheen * color.a, color.a);
}
// </recipe:holo>

// <recipe:dissolve>
// progress 0 = fully visible, 1 = fully gone. `rim` is a premultiplied color
// (Swift: .color(.orange)) used for the burning edge.
[[ stitchable ]] half4 dissolve(float2 position, half4 color, float2 size,
                                float progress, float scale, half4 rim) {
    float n = fbm(position / size.y * scale);
    float thr = mix(-0.1f, 1.05f, progress);
    float keep = smoothstep(thr, thr + 0.06f, n);
    float edge = smoothstep(thr - 0.01f, thr + 0.02f, n)
               * (1.0f - smoothstep(thr + 0.02f, thr + 0.07f, n));
    half4 base = color * half(keep);
    half4 burn = rim * half(edge) * color.a;
    return min(base + burn, half4(1.0h));
}
// </recipe:dissolve>

// <recipe:textGradient>
// Used as a ShapeStyle (Text.foregroundStyle / Shape.fill). Note the signature:
// no `color` parameter. `bounds` is `.boundingRect` = float4(x, y, width, height).
[[ stitchable ]] half4 textGradient(float2 position, float4 bounds, float time) {
    float2 uv = (position - bounds.xy) / bounds.zw;
    float3 col = palette(uv.x * 0.8f + uv.y * 0.3f + time * 0.2f);
    return half4(half3(col), 1.0h);
}
// </recipe:textGradient>

// <recipe:metaballs>
[[ stitchable ]] half4 metaballs(float2 position, half4 color, float2 size, float time, half4 tint) {
    float2 p = centeredUV(position, size);
    float d = 10.0f;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 c = 0.28f * float2(sin(time * (0.50f + 0.13f * fi) + fi * 2.1f),
                                  cos(time * (0.40f + 0.11f * fi) + fi * 1.7f));
        d = smin(d, sdCircle(p - c, 0.09f + 0.015f * fi), 0.12f);
    }
    float aa = 1.5f / size.y;                          // about one and a half points, in uv units
    float shape = 1.0f - smoothstep(-aa, aa, d);
    return tint * half(shape);                         // tint is premultiplied
}
// </recipe:metaballs>

// <recipe:voronoiCells>
[[ stitchable ]] half4 voronoiCells(float2 position, half4 color, float2 size, float time) {
    float2 p = position / size.y * 6.0f;
    p += 0.25f * float2(sin(time * 0.4f), cos(time * 0.3f));
    float2 d = voronoi(p);
    float edge = smoothstep(0.0f, 0.06f, d.y - d.x);   // 0 on cell borders
    float3 col = palette(d.x * 0.8f + time * 0.05f) * (0.35f + 0.65f * edge);
    return half4(half3(col), 1.0h);
}
// </recipe:voronoiCells>

// <recipe:sphereMarch>
static inline float sceneSDF(float3 p, float time) {
    float r = 1.0f + 0.12f * sin(time * 2.0f + p.y * 3.0f);   // wobbling sphere
    return length(p) - r;
}

[[ stitchable ]] half4 sphereMarch(float2 position, half4 color, float2 size, float time) {
    float2 p = centeredUV(position, size);
    p.y = -p.y;                                    // 3D wants y up
    float3 ro = float3(0.0f, 0.0f, -3.0f);         // ray origin (camera)
    float3 rd = normalize(float3(p, 1.6f));        // ray direction
    float t = 0.0f;
    bool hit = false;
    for (int i = 0; i < 48; i++) {                 // fixed, small step budget
        float d = sceneSDF(ro + rd * t, time);
        if (d < 0.002f) { hit = true; break; }
        t += d;
        if (t > 8.0f) { break; }
    }
    float3 bg = mix(float3(0.05f, 0.06f, 0.12f), float3(0.15f, 0.12f, 0.25f), position.y / size.y);
    if (!hit) { return half4(half3(bg), 1.0h); }

    float3 pos = ro + rd * t;
    float2 e = float2(0.002f, 0.0f);
    float3 n = normalize(float3(
        sceneSDF(pos + e.xyy, time) - sceneSDF(pos - e.xyy, time),
        sceneSDF(pos + e.yxy, time) - sceneSDF(pos - e.yxy, time),
        sceneSDF(pos + e.yyx, time) - sceneSDF(pos - e.yyx, time)));
    float3 lightDir = normalize(float3(0.6f, 0.8f, -0.5f));
    float diff = max(dot(n, lightDir), 0.0f);
    float rim = pow(1.0f - max(dot(n, -rd), 0.0f), 3.0f);
    float3 col = palette(0.55f + 0.2f * n.y + 0.1f * time) * (0.15f + 0.85f * diff) + rim * 0.4f;
    return half4(half3(col), 1.0h);
}
// </recipe:sphereMarch>

// =============================================================================
// layerEffect:  half4 f(float2 position, SwiftUI::Layer layer, args...)
// =============================================================================

// <recipe:chromaticAberration>
[[ stitchable ]] half4 chromaticAberration(float2 position, SwiftUI::Layer layer, float amount) {
    half4 r = layer.sample(position + float2(amount, 0.0f));
    half4 g = layer.sample(position);
    half4 b = layer.sample(position - float2(amount, 0.0f));
    return half4(r.r, g.g, b.b, max(r.a, max(g.a, b.a)));
}
// </recipe:chromaticAberration>

// <recipe:pixelate>
[[ stitchable ]] half4 pixelate(float2 position, SwiftUI::Layer layer, float cell) {
    float2 snapped = (floor(position / cell) + 0.5f) * cell;
    return layer.sample(snapped);
}
// </recipe:pixelate>

// <recipe:ripple>
[[ stitchable ]] half4 ripple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
                              float amplitude, float frequency, float decay, float speed) {
    float2 d = position - origin;
    float dist = length(d);
    float2 dir = dist > 0.001f ? d / dist : float2(0.0f);       // guard: normalize(0) is NaN
    float t = max(0.0f, time - dist / speed);                   // the wave front reaches this pixel at dist/speed
    float amount = amplitude * sin(frequency * t) * exp(-decay * t);
    half4 c = layer.sample(position + dir * amount);
    c.rgb += c.a * half(0.3f * amount / max(amplitude, 0.0001f));   // light crest, dark trough
    return c;
}
// </recipe:ripple>

// <recipe:lens>
[[ stitchable ]] half4 lens(float2 position, SwiftUI::Layer layer, float2 center, float radius, float strength) {
    float2 d = position - center;
    float r = length(d);
    float k = smoothstep(0.0f, radius, r);               // 0 in the middle, 1 at the rim
    float scale = mix(1.0f - strength, 1.0f, k);         // below 1 reads from nearer the center = magnify
    float2 src = r < radius ? center + d * scale : position;
    half4 c = layer.sample(src);
    float rim = smoothstep(radius - 2.0f, radius, r) * (1.0f - smoothstep(radius, radius + 1.5f, r));
    c.rgb += c.a * half(rim * 0.3f);
    return c;
}
// </recipe:lens>

// <recipe:glitch>
[[ stitchable ]] half4 glitch(float2 position, SwiftUI::Layer layer, float time, float intensity) {
    float slice = floor(position.y / 10.0f);
    float tick = floor(time * 12.0f);
    float gate = step(0.92f, hash21(float2(slice, tick)));                       // ~8% of slices tear
    float shift = (hash21(float2(slice + 17.0f, tick)) - 0.5f) * 2.0f * intensity * gate;
    half4 r = layer.sample(position + float2(shift + 2.0f * gate, 0.0f));
    half4 g = layer.sample(position + float2(shift, 0.0f));
    half4 b = layer.sample(position + float2(shift - 2.0f * gate, 0.0f));
    return half4(r.r, g.g, b.b, max(r.a, max(g.a, b.a)));
}
// </recipe:glitch>

// <recipe:glow>
// glowColor is premultiplied (that is how Shader.Argument.color is delivered).
[[ stitchable ]] half4 glow(float2 position, SwiftUI::Layer layer, half4 glowColor, float radius) {
    half4 base = layer.sample(position);
    half acc = 0.0h;
    const int rings = 2;
    const int taps = 12;
    for (int ring = 1; ring <= rings; ring++) {
        float rr = radius * float(ring) / float(rings);
        for (int i = 0; i < taps; i++) {
            float a = TAU * float(i) / float(taps);
            acc += layer.sample(position + rr * float2(cos(a), sin(a))).a;
        }
    }
    acc /= half(rings * taps);
    half4 halo = glowColor * acc;
    return base + halo * (1.0h - base.a);              // halo only where the view itself is not opaque
}
// </recipe:glow>

// =============================================================================
// distortionEffect:  float2 f(float2 position, args...)  (returns the SOURCE position)
// =============================================================================

// <recipe:wave>
[[ stitchable ]] float2 wave(float2 position, float time, float amplitude, float frequency) {
    position.y += sin(position.x * frequency + time) * amplitude;
    return position;
}
// </recipe:wave>

// <recipe:swirl>
[[ stitchable ]] float2 swirl(float2 position, float2 center, float radius, float angle) {
    float2 d = position - center;
    float r = length(d);
    if (r >= radius) { return position; }
    float t = 1.0f - r / radius;                 // 1 at the center, 0 at the rim
    float a = angle * t * t;
    return center + rotate2d(d, a);
}
// </recipe:swirl>
