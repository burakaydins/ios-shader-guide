// ShadertoyPorts.metal
// Worked Shadertoy/GLSL -> MSL conversions used in references/shadertoy-to-msl.md.
// The GLSL originals shown in the docs were written for this guide (not copied
// from Shadertoy), so they carry no third-party license.
//
// License: MIT (see LICENSE at the repo root).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "ShaderHelpers.h"
using namespace metal;

// <recipe:shadertoyDefault>
[[ stitchable ]] half4 shadertoyDefault(float2 position, half4 color, float2 size, float time) {
    float2 fragCoord = float2(position.x, size.y - position.y);   // flip y: Shadertoy origin is bottom-left
    float2 uv = fragCoord / size;
    float3 col = 0.5f + 0.5f * cos(time + uv.xyx + float3(0.0f, 2.0f, 4.0f));
    return half4(half3(col), 1.0h);
}
// </recipe:shadertoyDefault>

// <recipe:kaleido>
constant float kPi = 3.14159265f;

// GLSL mod(): x - y * floor(x / y). MSL fmod() truncates and differs for negative x.
static inline float glslMod(float x, float y) { return x - y * floor(x / y); }

static inline float ring(float2 p, float r, float w) {
    // GLSL original: smoothstep(w, 0.0, abs(length(p) - r))   <- reversed edges are undefined
    return 1.0f - smoothstep(0.0f, w, abs(length(p) - r));
}

// GLSL `inout vec2 p` becomes a thread reference.
static inline void fold(thread float2& p, float n) {
    float a = atan2(p.y, p.x);                     // GLSL atan(y, x)
    float seg = 2.0f * kPi / n;
    a = glslMod(a + seg * 0.5f, seg) - seg * 0.5f;
    p = length(p) * float2(cos(a), sin(a));
}

[[ stitchable ]] half4 kaleido(float2 position, half4 color, float2 size, float time) {
    float2 fragCoord = float2(position.x, size.y - position.y);
    float2 p = (fragCoord - 0.5f * size) / size.y;
    fold(p, 6.0f);
    p -= float2(0.25f, 0.0f);
    float v = ring(p, 0.12f + 0.03f * sin(time), 0.02f);
    float3 col = 0.5f + 0.5f * cos(time + p.xyx * 6.0f + float3(0.0f, 2.0f, 4.0f));
    return half4(half3(col * v), 1.0h);
}
// </recipe:kaleido>

// <recipe:shadertoyWrapper>
// Pattern for big shaders: keep the original body almost untouched in a plain
// function, then add one thin stitchable wrapper that supplies the Shadertoy inputs.
static inline float4 mainImageBody(float2 fragCoord, float2 iResolution, float iTime) {
    float2 uv = fragCoord / iResolution;
    return float4(uv, 0.5f + 0.5f * sin(iTime), 1.0f);
}

[[ stitchable ]] half4 wrappedShader(float2 position, half4 color, float2 size, float time) {
    float2 fragCoord = float2(position.x, size.y - position.y);   // y flip lives in ONE place
    return half4(mainImageBody(fragCoord, size, time));
}
// </recipe:shadertoyWrapper>
