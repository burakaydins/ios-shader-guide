# ios-shader-guide

An Agent Skill for SwiftUI and Metal shaders (for Claude Code, Claude.ai and other agents that read the `SKILL.md` format). Everything is written in English; Claude replies in whatever language the user writes in.

What it does:

- **Explains** how a shader runs per pixel, coordinates, and building blocks such as `mix`/`smoothstep`/noise/SDF, with a learning ladder.
- **Writes** shaders for `colorEffect`, `distortionEffect`, `layerEffect` and `ShapeStyle`: 21 ready recipes (plasma, aurora, ripple, glitch, glow, holographic card, transition effect, progress ring, raymarched sphere...) plus Swift patterns for touch, tilt, transitions and animation.
- **Ports** Shadertoy/GLSL shaders to MSL + SwiftUI: conversion table, y axis, `mod`/`atan`/`inout`, license warning, attribution template, two worked examples.
- **Debugs and speeds up:** an "effect not showing" decision tree, a compile-error dictionary, debug-by-color shaders, and line-by-line inspection and profiling with the Xcode Metal debugger.
- **Routes** to RealityKit `CustomMaterial`, ShaderGraph (Reality Composer Pro) or `MTKView` when SwiftUI is not enough.

## Install

With your own repo name (once you publish this repo):

```bash
npx skills add <user>/<repo> --skill ios-shader-guide
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
├── examples/ShaderLab/           runnable demo project with every recipe
└── tools/                        doc generator, rough syntax checker
```

## Test status

| Topic | Status |
|---|---|
| API signatures (`colorEffect`, `distortionEffect`, `layerEffect`, `Shader`, `Shader.Argument`) | Verified against Apple documentation pages |
| RealityKit `CustomMaterial` rules, ShaderGraph facts | Verified against Apple documentation pages |
| Xcode Metal debugger steps | Taken from Apple's articles; the articles do not mention SwiftUI shaders, **not tried on a SwiftUI shader** |
| `.metal` code | Rough syntax check only (converted to OpenCL C and run through clang). **Not compiled in Xcode** |
| Swift demo code | **Not compiled** |
| Performance | **Not measured**; no fps numbers are promised |

When you test, update this table with the real status (including device, iOS and Xcode versions).

## Contributing and doc generation

`recipes.md`, `shadertoy-to-msl.md`, `advanced-techniques.md` and `performance-debugging.md` take their code from `examples/ShaderLab/*.metal`. To change code, edit the `.metal` file and run:

```bash
python3 skills/ios-shader-guide/tools/build_recipes.py
python3 skills/ios-shader-guide/tools/syntax_check.py skills/ios-shader-guide/examples/ShaderLab/Shaders.metal
```

## Sources

Apple documentation (SwiftUI `Shader`, `colorEffect`, `distortionEffect`, `layerEffect`, `Shader.Argument`; Xcode "Inspecting shaders" and related articles; RealityKit and ShaderGraph pages) is summarized in paraphrase; the copyright belongs to Apple. The repo contains no third-party shader code; the Shadertoy-style examples were written for this skill. Inigo Quilez's cosine palette, SDF and smooth-min ideas, and Dave Hoskins-style sine-free hashes are common techniques in the shader community; the code was rewritten for this repo.

## License

MIT, see `LICENSE`.
