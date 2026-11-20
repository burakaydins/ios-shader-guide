# Shader paths beyond SwiftUI: RealityKit, ShaderGraph, MTKView

SwiftUI shader modifiers are for 2D views. If the user wants to customize the surface or geometry of a 3D entity, a different tool is needed. This file is enough to make that decision and take the first step; it does not teach all of RealityKit.

The information comes from these Apple pages: ShaderGraph (framework landing page), "Materials, textures, and shaders" (RealityKit) and "Modifying RealityKit rendering using custom materials". The code samples below were written for this skill and are **not compiled**; try them in Xcode.

## Contents
1. Which path for which job
2. Key differences between the paths
3. ShaderGraph (Reality Composer Pro)
4. RealityKit material types
5. `CustomMaterial`: surface and geometry with Metal
6. Choosing a lighting model
7. Common mistakes
8. How much SwiftUI shader knowledge carries over

## 1. Which path for which job

| Request | Path |
|---|---|
| An effect on a SwiftUI view (text, image, card) | SwiftUI shader modifiers (`SKILL.md`, `swiftui-shaders.md`) |
| Shape the look of a 3D model without code, edited by a designer | **ShaderGraph** (Reality Composer Pro) → `ShaderGraphMaterial` |
| Change a 3D model's surface or vertices with your own Metal code | **`CustomMaterial`** (surface shader + geometry modifier) |
| Plain color/texture, realistic PBR, unlit, video, portal, occlusion | Ready-made materials: `SimpleMaterial`, `PhysicallyBasedMaterial`, `UnlitMaterial`, `VideoMaterial`, `PortalMaterial`, `OcclusionMaterial` |
| Your own render loop, multi-pass work, compute | `MTKView` + Metal pipeline (`advanced-techniques.md` section 10) |
| A photo/video filter chain over 2D content | Core Image |

When the user says "shader", first ask or infer from context **where** it will run: a SwiftUI view, a RealityKit entity, or their own Metal view?

## 2. Key differences between the paths

| | SwiftUI shader | RealityKit `CustomMaterial` |
|---|---|---|
| Where it runs | A view's raster layer | Every fragment of a 3D entity and (optionally) every vertex |
| Function marker | `[[ stitchable ]]` | `[[visible]]` |
| Parameter | `float2 position`, `half4 color` / `SwiftUI::Layer`, uniforms | A single parameter: `realitykit::surface_parameters` or `realitykit::geometry_parameters` |
| Return | A color (`half4`) or a position (`float2`) | `void`; results are written with `params.surface().set_...()` calls |
| Header | `<SwiftUI/SwiftUI_Metal.h>` | `<RealityKit/RealityKit.h>` |
| Uniforms | Arguments from Swift such as `.float(...)` | `params.uniforms()` (including elapsed time and any custom values on `CustomMaterial`) |
| Usage | `ShaderLibrary.f(...)` + modifier | `CustomMaterial.SurfaceShader(named:in:)` + `CustomMaterial(...)` |
| Platform | iOS 17 / macOS 14 / visionOS 1 ... (no watchOS) | `CustomMaterial`: iOS 15 and later (Apple's article) |

## 3. ShaderGraph (Reality Composer Pro)

- **What:** A node-based editor inside Reality Composer Pro where you build materials and effects by connecting nodes. According to Apple, it lets you create effects that would otherwise require writing Metal shaders. A node does the same job as a variable, constant or function in Metal; versions of the same node with different inputs/outputs resemble function overloading.
- **Output:** You apply the material to entities in a Reality Composer Pro scene; in code it loads as a `ShaderGraphMaterial` (its parameters can be changed at runtime). RealityKit also offers a `ShaderGraph` class that lets you build and edit node graphs in code.
- **Interoperability:** According to Apple, Shader Graph uses **MaterialX 1.38** conventions, so it is compatible with content creation apps that read and write MaterialX in USD files. There are some RealityKit-specific nodes; some of them can be downloaded as standard MaterialX definitions (Apple's "MaterialX definitions" package).
- **Platform (list on the framework page):** iOS 17, iPadOS 17, Mac Catalyst 17, macOS 15, tvOS 26, visionOS 1.
- **Node categories** (useful when telling the user "which node should I look for"): 2D-Procedural (gradient, noise, pattern), 2D-Texture, 3D-Procedural (3D noise), 3D-Texture, Adjustment, Application (system values such as time and the up vector), Compositing, Data, Geometric (access to scene geometry), Logic, Material (wraps node groups in a module), Math, Organization, Procedural (constant values), RealityKit (RealityKit surfaces/textures, geometry access and modification), Surface (the MaterialX preview surface).
- **When to choose it:** When a designer will edit the same material without code, when you work with a USD/MaterialX pipeline, or when you want quick visual experiments. A node graph may be awkward for expressing a detailed computation (a looping algorithm such as raymarching); in that case `CustomMaterial` fits better. This last sentence is a judgment, not stated in Apple's documentation.
- **Concept transfer:** The shader ideas in this skill (`mix`, `smoothstep`, noise, palette, SDF) apply in a node graph too; the nodes are the visual counterparts of these functions. Verify any specific node's name, input order or behavior from Apple's node page; this skill did not verify node by node.

## 4. RealityKit material types

From Apple's "Materials, textures, and shaders" page:

| Type | What for |
|---|---|
| `SimpleMaterial` | Basic color and texture; reacts to scene lights |
| `UnlitMaterial` | Does not react to lights; flat color, UI-like elements |
| `PhysicallyBasedMaterial` | Realistic surface: reflection, roughness, metallic, normal map, emission, clearcoat, anisotropy, sheen |
| `PortalMaterial` | Turns a piece of mesh into a portal opening onto another world |
| `VideoMaterial` | Animated texture (video) |
| `OcclusionMaterial` | Invisible; hides objects behind it |
| `ShaderGraphMaterial` | A material from a Reality Composer Pro shader graph or a MaterialX shader |
| `CustomMaterial` | A material driven by your own Metal shader functions |

On the texture side there are `TextureResource`, `LowLevelTexture` (updating a texture on the GPU, e.g. a dynamic height/normal map) and `DrawableQueue`. `PhysicallyBasedDecalComponent` applies a projected decal to the scene; Apple notes it is available on devices that support the Apple6 GPU family.

## 5. `CustomMaterial`: surface and geometry with Metal

According to Apple's article, `CustomMaterial` supports two kinds of Metal function:

- **Surface shader:** Runs for every fragment (a pixel-sized piece) RealityKit draws and determines that fragment's properties. RealityKit's built-in fragment shader calls your function.
- **Geometry modifier (optional):** Runs for every vertex; by moving vertices it changes the entity's size or shape dynamically.

### Rules (from Apple's article)

- You can name the function anything, but you must put **`[[visible]]`** in front of it.
- Surface shader: no return value, **a single parameter `realitykit::surface_parameters`**.
- Geometry modifier: no return value, **a single parameter `realitykit::geometry_parameters`**.
- Header: `#include <RealityKit/RealityKit.h>` (and `<metal_stdlib>`, `using namespace metal;`).
- A surface shader's input access methods: `uniforms()` (constant values: elapsed time, custom values on `CustomMaterial`, coordinate transform matrices), `geometry()` (per-vertex values: position, color, normal, UV; interpolated across the triangle), `textures()` (textures mapped by UV), `surface()` (write/read the output).
- Write output with `params.surface().set_...()` (e.g. `set_base_color`). The lighting model determines which `set_` functions are supported; **if you do not call at least one supported `set_`, nothing is drawn.**
- In a geometry modifier, move vertices with `params.geometry().set_model_position_offset(...)` or `set_world_position_offset(...)`. This affects only drawing; it does not change the entity's actual position in the scene, collision or physics.
- If you push vertices outside the entity's bounding box, increase `ModelComponent.boundsMargin`; otherwise RealityKit may wrongly treat the entity as invisible (culling).
- For entities loaded from a USDZ or `.reality` file you need to flip the UV y axis (`uv.y = 1.0 - uv.y`). This is a trap similar to the y flip in Shadertoy.
- Apple's supplementary document: the "Metal RealityKit APIs" PDF (the full reference of the custom shader API). Verify function names and types there.

### Example: pulsing color + breathing geometry (the author's example, not compiled)

```metal
#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

[[visible]]
void pulseSurface(realitykit::surface_parameters params)
{
    float t = params.uniforms().time();
    half pulse = half(0.5f + 0.5f * sin(t * 2.0f));
    params.surface().set_base_color(half3(pulse, 0.3h, 1.0h - pulse));
}

[[visible]]
void breatheGeometry(realitykit::geometry_parameters params)
{
    float t = params.uniforms().time();
    float3 offset = float3(0.0f, 0.02f * sin(t * 3.0f), 0.0f);
    params.geometry().set_model_position_offset(offset);
}
```

That `time()` and `set_base_color` can be called with these types was inferred from usage in Apple's article; verify by compiling.

### Swift side (following the pattern Apple shows)

```swift
import RealityKit
import Metal

func makePulsingSphere() throws -> ModelEntity {
    guard let device = MTLCreateSystemDefaultDevice(),
          let library = device.makeDefaultLibrary() else {
        throw NSError(domain: "Shader", code: 1)
    }
    let surface = CustomMaterial.SurfaceShader(named: "pulseSurface", in: library)
    let geometry = CustomMaterial.GeometryModifier(named: "breatheGeometry", in: library)

    let material = try CustomMaterial(surfaceShader: surface,
                                      geometryModifier: geometry,
                                      lightingModel: .lit)
    let mesh = MeshResource.generateSphere(radius: 0.2)
    let entity = ModelEntity(mesh: mesh, materials: [material])
    // the geometry modifier moves vertices, so give the bounding box some margin
    entity.components[ModelComponent.self]?.boundsMargin = 0.05
    return entity
}
```

The type and scale of `boundsMargin` were not verified from Apple's page; tune the value in your own scene. To customize an existing model's material while keeping it, Apple shows the `CustomMaterial(from: material, surfaceShader:)` initializer (for entities loaded from USDZ the original material properties are preserved).

## 6. Choosing a lighting model

| Model | What it does | Supported outputs |
|---|---|---|
| `.lit` | Uses PBR, without clearcoat | All except `set_clearcoat()` and `set_clearcoat_roughness()` |
| `.clearcoat` | PBR, including clearcoat | All |
| `.unlit` | No shading or lighting calculation (like `UnlitMaterial`) | Only `set_emissive_color()` |

For unlit, "glowing" effects (hologram, energy field) use `.unlit` with `set_emissive_color`; for a realistic surface use `.lit`.

## 7. Common mistakes

- **Nothing is drawn.** The surface shader has no supported `set_` call, or the lighting model does not support that output (`.unlit` supports only emissive).
- **Function not found.** `[[visible]]` is missing, the name does not match, or the wrong Metal library was loaded (`makeDefaultLibrary()` returns the app's own library).
- **Texture is upside down.** For USDZ/`.reality` entities use `uv.y = 1.0 - uv.y`.
- **The entity disappears.** The geometry modifier pushes vertices outside the bounding box; increase `boundsMargin`.
- **Physics or collision did not change.** A geometry modifier changes only drawing.
- **SwiftUI code was copied over.** `[[ stitchable ]]` and `SwiftUI::Layer` are invalid in RealityKit; the signature is completely different.

## 8. How much SwiftUI shader knowledge carries over

Carries over: the MSL language, the `half`/`float` distinction, `mix`/`smoothstep`/`fract`, noise and palette functions (you can include the `static inline` helpers in `ShaderHelpers.h` from a RealityKit `.metal` file too), the SDF idea, performance principles (constant loops, cheap functions), the Xcode Metal debugger (`performance-debugging.md` section 9).

Does not carry over: the modifier types (`colorEffect` etc.), the `position`/`size` uniforms, y-axis rules (here there are UV and world space), `ShaderLibrary` and the `Shader.Argument` factories. In RealityKit you pass your own custom values through `CustomMaterial`'s custom parameters (the `custom` value, textures); for details see Apple's article and the "Metal RealityKit APIs" PDF.
