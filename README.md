# ios-shader-guide

An Agent Skill for SwiftUI and Metal shaders (for Claude Code, Claude.ai and other agents that read the `SKILL.md` format). Everything is written in English; Claude replies in whatever language the user writes in.

<p align="center"><img src="docs/demo.gif" width="300" alt="plasma and holographic card demos running in ShaderLab"></p>

![All 26 ShaderLab demos](docs/demos.jpg)

What it does:

- **Explains** how a shader runs per pixel, coordinates, and building blocks such as `mix`/`smoothstep`/noise/SDF, with a learning ladder.
- **Writes** shaders for `colorEffect`, `distortionEffect`, `layerEffect` and `ShapeStyle`: 21 ready recipes (plasma, aurora, ripple, glitch, glow, holographic card, transition effect, progress ring, raymarched sphere...) plus Swift patterns for touch, tilt, transitions and animation.
- **Ports** Shadertoy/GLSL shaders to MSL + SwiftUI: conversion table, y axis, `mod`/`atan`/`inout`, license warning, attribution template, two worked examples.
- **Debugs and speeds up:** an "effect not showing" decision tree, a compile-error dictionary, debug-by-color shaders, and line-by-line inspection and profiling with the Xcode Metal debugger.
- **Routes** to RealityKit `CustomMaterial`, ShaderGraph (Reality Composer Pro) or `MTKView` when SwiftUI is not enough.

## Install

With the skills CLI:

```bash
npx skills add burakaydins/ios-shader-guide --skill ios-shader-guide
```

Manually: copy the `skills/ios-shader-guide` folder into `~/.claude/skills/` (personal) or a project's `.claude/skills/`. Copy the whole folder; `SKILL.md`, `references/`, `examples/` and `tools/` work together.

## Contents

```
skills/ios-shader-guide/
├── SKILL.md                      workflows, tool choice, fixed API facts
├── TESTING.md                    set up the demo project, expected looks, pre-release checklist
├── references/
│   ├── concepts.md               how a shader works + learning ladder
│   ├── msl-primer.md             MSL for Swift developers
│   ├── swiftui-shaders.md        verified API signatures, argument types, maxSampleOffset
│   ├── recipes.md                21 recipes (generated)
│   ├── swift-patterns.md         AnimatedShader, touch, ripple, CoreMotion, transitions
│   ├── shadertoy-to-msl.md       GLSL → MSL (generated)
│   ├── advanced-techniques.md    SDF, raymarching, noise, UI pieces (generated)
│   ├── performance-debugging.md  speed, debugging, Xcode Metal debugger (generated)
│   ├── realitykit-shadergraph.md RealityKit CustomMaterial, ShaderGraph
│   └── galleries.md              official sources, galleries, learning resources
├── examples/ShaderLab/           runnable demo project (ShaderLab.xcodeproj) with every recipe
└── tools/                        doc generator, argument checker, rough syntax checker
```

## Test status

Tested on 2026-11-21 with Xcode 26.3 (17C529), iOS 26.2 Simulator (iPhone 17 Pro) and an iPhone 13 on iOS 26.7.3.

| Topic | Status |
|---|---|
| `.metal` code | Compiles with the Xcode 26.3 Metal toolchain; all three files link into one library without name collisions |
| Swift demo code | Builds for iOS 17+ (`ShaderLab.xcodeproj`, Debug and Release) |
| Swift arguments vs. shader parameters | All 26 calls match in count, order and type (`tools/check_arguments.py`) |
| Looks | All 26 demos checked on the Simulator against `TESTING.md` section 2 (two geometry bugs and the ripple timing were fixed during testing) |
| Performance | iPhone 13 (60 Hz): every demo held 60 fps on the main thread over 10 seconds (`-showFPS`, `TESTING.md` section 1). This counts display-link frames, not GPU time; use Instruments for GPU cost. Older devices not measured |
| API signatures, RealityKit `CustomMaterial`, ShaderGraph | Verified against Apple documentation pages |
| Xcode Metal debugger steps | Taken from Apple's articles; **not tried on a SwiftUI shader** |

## Contributing and doc generation

`recipes.md`, `shadertoy-to-msl.md`, `advanced-techniques.md` and `performance-debugging.md` take their code from `examples/ShaderLab/*.metal`. To change code, edit the `.metal` file and run:

```bash
python3 skills/ios-shader-guide/tools/build_recipes.py
python3 skills/ios-shader-guide/tools/check_arguments.py
```

Then build `examples/ShaderLab/ShaderLab.xcodeproj` in Xcode. On a machine without Xcode, `tools/syntax_check.py` gives a rough syntax check.

## Sources

Apple documentation (SwiftUI `Shader`, `colorEffect`, `distortionEffect`, `layerEffect`, `Shader.Argument`; Xcode "Inspecting shaders" and related articles; RealityKit and ShaderGraph pages) is summarized in paraphrase; the copyright belongs to Apple. The repo contains no third-party shader code; the Shadertoy-style examples were written for this skill. Inigo Quilez's cosine palette, SDF and smooth-min ideas, and Dave Hoskins-style sine-free hashes are common techniques in the shader community; the code was rewritten for this repo.

## License

MIT, see `LICENSE`.
