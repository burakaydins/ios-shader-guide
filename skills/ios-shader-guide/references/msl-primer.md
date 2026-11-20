# Metal Shading Language (MSL) quick guide for Swift developers

MSL is a C++14-based language. The points below are what surprise people coming from Swift most. Official reference: Apple's "Metal Shading Language Specification".

## Contents
1. Your first shader file
2. Types
3. Vector operations and swizzling
4. `half` and `float`
5. Address spaces: `thread`, `constant`, `device`
6. Literals and suffixes
7. Commonly used built-in functions
8. Differences from Swift and restrictions
9. Command-line compile note

## 1. Your first shader file

```metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 tint(float2 position, half4 color, half4 tintColor, float amount) {
    return mix(color, tintColor * color.a, half(amount));
}
```

- `#include <metal_stdlib>`: the standard library (`mix`, `sin`, `clamp`...).
- `using namespace metal;`: so you do not have to write the `metal::` prefix.
- `[[ stitchable ]]`: marks the function so SwiftUI can find and bind it at runtime. Without it `ShaderLibrary.tint(...)` is not found.
- Parameter order depends on the modifier type's signature (see `swiftui-shaders.md`).

## 2. Types

| Kind | MSL | Note |
|---|---|---|
| Integer | `int`, `uint`, `short`, `ushort`, `char` | vectors like `int2`, `uint3` exist |
| Real number | `float` (32-bit), `half` (16-bit) | there is **no** `double` |
| Boolean | `bool` | `bool2/3/4` are the vector results of comparisons |
| Vector | `float2`, `float3`, `float4`, `half2/3/4`, `int2`... | |
| Matrix | `float2x2`, `float3x3`, `float4x4`, `half4x4` | column-major |
| Texture | `texture2d<half>`, `texture2d<float>` | for SwiftUI `.image(...)` use `texture2d<half>` |
| Sampler | `sampler`, `constexpr sampler s(address::repeat, filter::linear)` | |

## 3. Vector operations and swizzling

```metal
float3 a = float3(1.0, 2.0, 3.0);
float2 b = a.xy;            // first two components
float3 c = a.zyx;           // reorder
float4 d = float4(a, 1.0);  // build from a vector + scalar
half4  e = half4(half3(a), 1.0h);
float3 f = a * 2.0;         // component-wise
float  g = dot(a, a);       // scalar
a.xy += b;                  // partial assignment
```

`xyzw` and `rgba` name the same components (`color.rgb` = `color.xyz`). Do not mix the two sets in one expression (`v.xg` is an error).

A scalar-with-vector operation broadcasts the scalar: `float3 + float` is valid. But mixing `half3` with `float3` needs an explicit conversion: `float3(h)` / `half3(f)`.

## 4. `half` and `float`

- `half` is 16-bit, enough for color, and generally faster on Apple GPUs.
- **Use `float` for positions, time and large numbers.** The largest `half` value is about 65504 and it has roughly 3 decimal digits of precision; pixel coordinates and products with time easily overflow or get coarse.
- In SwiftUI signatures `color` and the return value are `half4`; it is common to do intermediate math in `float3` and return `half3(...)` at the end.

## 5. Address spaces: `thread`, `constant`, `device`

- Ordinary variables inside a function live in the `thread` address space (private to each pixel).
- Passing by reference (GLSL's `out`/`inout`): `void f(thread float& x)`, `thread float3& color`.
- Global **constants** are declared with `constant`: `constant float kPi = 3.14159265;`. There are no writable global **variables**.
- `device const float *ptr`: a pointer to memory arriving from Swift via `.floatArray` / `.data` (see `swiftui-shaders.md` section 4).

## 6. Literals and suffixes

- `1.0` and `1.0f` are `float`; `1.0h` is `half`. Write `half4(1.0h)`, not `half4(1.0)`: an unsuffixed literal is `float` and needs an explicit conversion.
- Writing `0.5f` in code samples makes the intent clear (this skill's `Shaders.metal` does so).
- Built-in constants such as `M_PI_F` exist in `metal_math`; for readability it is common to define your own `TAU` or `PI` macro.

## 7. Commonly used built-in functions

| Group | Functions |
|---|---|
| Math | `sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `sqrt`, `rsqrt`, `abs`, `floor`, `ceil`, `fract`, `fmod`, `sign` |
| Clamping | `min`, `max`, `clamp`, `saturate` (clamp to 0–1) |
| Blending | `mix(a, b, t)`, `step(edge, x)`, `smoothstep(e0, e1, x)` |
| Vector | `length`, `distance`, `dot`, `cross`, `normalize`, `reflect`, `refract` |
| Selection | `select(a, b, cond)` (b if cond is true) |

`fract(x) = x - floor(x)`; `fmod(x, y)` gives a different result from GLSL `mod` for negative x (see `shadertoy-to-msl.md`).

## 8. Differences from Swift and restrictions

- **No recursion.** A function cannot call itself; turn it into a loop.
- **No `print`.** Debugging is done with color (`performance-debugging.md`).
- **No dynamic memory, classes, closures or `String`.** Structs exist, but in SwiftUI signatures you only pass scalars, vectors, textures and pointers.
- **Two `.metal` files declaring a helper with the same name collide.** Make helpers `static inline` and include them from a shared `.h` file (`ShaderHelpers.h` does this).
- **Use before declaration:** as in C++, you must declare before use; put helpers above.
- **Behave as if loops need constant bounds.** The compiler may unroll loops; loops with 1000+ iterations lengthen both compile time and runtime.
- **`switch`, `if`, `for`, `while`** exist; on the GPU, if neighboring pixels take different branches both branches may run (see `performance-debugging.md`).
- Output values can be `NaN` or `inf` (e.g. `normalize(float2(0))`, `0/0`); the result is usually black or odd pixels. Guard before normalizing a zero-length vector.

## 9. Command-line compile note

If Xcode is installed on a Mac you can check a `.metal` file's syntax like this:

```bash
xcrun -sdk iphoneos metal -c Shader.metal -o /tmp/Shader.air
```

The way the SwiftUI header (`<SwiftUI/SwiftUI_Metal.h>`) is found can differ in this command from an Xcode build; if you get "header not found" on the command line, that is not a shader bug, build in Xcode. This command was not run when this skill was written.
