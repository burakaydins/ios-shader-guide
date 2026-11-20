# Galleries, official sources and learning resources

Before giving the user links, verify they are still current if web search is available; this list can age. Do not guess about licenses: show each source's own license.

## Official Apple sources

| Source | What for |
|---|---|
| `developer.apple.com/documentation/swiftui/shader` | The `Shader` type: `ShapeStyle` conformance, `dithersColor`, `compile(as:)` |
| `.../swiftui/shader/argument` | Argument factories (`float`, `color`, `image`, `boundingRect`, arrays) |
| `.../swiftui/view/coloreffect(_:isenabled:)`, `.../distortioneffect(_:maxsampleoffset:isenabled:)`, `.../layereffect(_:maxsampleoffset:isenabled:)` | Signatures and descriptions of the three modifiers |
| WWDC 2026 session 322, "Compose advanced graphics effects with SwiftUI" | The `distortionEffect` vs `layerEffect` distinction, a `layerEffect` shader that samples a texture, chaining shaders as part of a "creative pipeline" |
| WWDC 2024, "Create custom visual effects with SwiftUI" | The previous year's SwiftUI visual effects session (listed as a related video on the WWDC26 page) |
| `developer.apple.com/documentation/xcode/inspecting-shaders` | The Xcode Shader editor and line-by-line profile (see `performance-debugging.md` section 9) |
| `.../xcode/capturing-a-metal-workload-in-xcode`, `.../xcode/building-your-project-with-embedded-shader-sources`, `.../xcode/debugging-the-shaders-within-a-draw-command-or-compute-dispatch` | Capture, embedding source, the shader debugger |
| `developer.apple.com/documentation/shadergraph` | ShaderGraph node categories (for 3D materials, see `realitykit-shadergraph.md`) |
| `developer.apple.com/documentation/realitykit/scene-content-materials-and-shaders` | RealityKit material and shader types |
| `.../realitykit/modifying-realitykit-rendering-using-custom-materials` | `CustomMaterial` surface shader and geometry modifier |
| Metal Shading Language Specification (`developer.apple.com/metal`) | The official MSL reference |

Apple's documentation pages need JavaScript; as a shortcut to plain text, appending `.md` to the address (e.g. `.../swiftui/shader.md`) often works.

## Inspiration and ready-made shader galleries

| Source | What for | Watch out |
|---|---|---|
| Shadertoy (shadertoy.com) | Thousands of browser shaders, GLSL | Licenses vary per shader; unless stated, generally CC BY-NC-SA 3.0 (no commercial use). Multipass ones do not port to SwiftUI |
| Inferno (github.com/twostraws/Inferno) | A ready collection of Metal shaders for SwiftUI by Paul Hudson; includes explanations of how a shader works per pixel and the three modifiers | Verify the license and current iOS support from the repo |
| Hacking with Swift, "How to create Metal shaders for SwiftUI" (Paul Hudson, Advanced SwiftUI) | How shaders work, basic data types, time-driven shaders with `TimelineView` | May be paid (Plus) content |
| Apple sample code and WWDC sessions | Official usage examples | Apple's sample code comes with its own license |

## For learning

| Source | What for |
|---|---|
| The Book of Shaders (thebookofshaders.com) | Shader thinking from zero; in GLSL, but the concepts carry over to MSL unchanged |
| Inigo Quilez articles (iquilezles.org) | SDF, palettes, noise, raymarching; the palette and SDF in `concepts.md` come from here |
| "Metal in SwiftUI: How to Write Shaders" (levelup.gitconnected.com) | `SwiftUI::Layer`, sampling, a "retro filter" project, the step to the Book of Shaders |
| "SwiftUI: Get Start With Metal Shader Using Layer Effect Modifiers" (levelup.gitconnected.com) | Introduction to the three modifiers |

## Existing skills

Other people have written skills on this topic too; if the user asks "are there other skills", you can mention these (tell them to read the contents before installing): `swiftui-graphics` (genjutsu: SwiftUI Metal shaders, `visualEffect`, Canvas, Liquid Glass), `axiom-graphics` (Axiom: Metal migration, GLSL/HLSL → MSL tables, RealityKit, display performance), `swiftui-animation`, `metal-shader-expert`. What sets this skill apart: the Shadertoy → SwiftUI porting workflow, a runnable `ShaderLab` example project, and verified API notes. Those descriptions were read, not their contents, so do not claim they lack anything.

## When the user asks "which shader should I start with"

Suggest the ladder in `concepts.md` section 9: vignette or shimmer → wave → chromatic aberration → plasma → aurora. All the code is in `recipes.md` and runs in the `examples/ShaderLab` project.

## Attribution and license

When you adapt someone else's shader, put the author name, source link and license in a comment at the top of the code (template: `shadertoy-to-msl.md` section 10). If the app is commercial and the license does not allow commercial use, tell the user plainly and suggest rewriting the effect conceptually with their own formulas (ideas and techniques are free, the code itself is not). Do not give legal opinions.
