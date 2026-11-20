# Testing guide

The code in this skill was **not compiled or run** in the environment where it was written: there was no Xcode and no Metal compiler. The only check done was converting the `.metal` files to OpenCL C and scanning them with `clang -fsyntax-only` (`tools/syntax_check.py`); this catches typos, undeclared identifiers and most vector/scalar type mismatches. It does not check `half`/`float` mixing, `[[ stitchable ]]` binding, or anything SwiftUI-specific. Follow the steps below on your own Mac before publishing.

## 1. Set up the ShaderLab project (10 minutes)

1. In Xcode: **File ▸ New ▸ Project ▸ iOS ▸ App** (Interface: SwiftUI, Language: Swift). Set the minimum deployment target to **iOS 17**.
2. Delete the `…App.swift` and `ContentView.swift` files the template created.
3. Drag the files from `examples/ShaderLab/` into the project ("Copy items if needed", add to target):
   `ShaderLabApp.swift`, `ContentView.swift`, `AnimatedShader.swift`, `Shaders.metal`, `ShadertoyPorts.metal`, `Advanced.metal`, `ShaderHelpers.h`.
4. Build (⌘B). If there is a compile error, record the **error text and the line** (section 4).
5. Run on a real iPhone. The Simulator runs it, but says nothing about speed or heat.

If the header is not found (`SwiftUI/SwiftUI_Metal.h`): Apple's `layerEffect` page says the type is defined in `<SwiftUI/SwiftUI.h>`; change the `#include` line in the `.metal` files to that and note the result.

## 2. Expected look of each demo

Run each one and tick it off. "Expected" is the author's intent; if you see something different, open a bug report.

| Demo | Expected | ✔ |
|---|---|---|
| plasma | A smooth, flowing rainbow pattern | |
| aurora | Green/purple, slowly drifting cloud-like pattern; frame rate may drop | |
| voronoiCells | Colored cells, dark borders, slow drift | |
| metaballs | 5 cyan blobs on black that merge as they approach | |
| sphereMarch | A wobbling lit sphere on a dark purple gradient | |
| vignette | Edges darken; slider at 0 does nothing | |
| shimmer | A light band sweeps left to right across white text; the band does not light up outside the text | |
| duotone | Image in indigo (shadows) and yellow (highlights) | |
| filmGrain | Fine, flickering grain | |
| scanlines | Dark horizontal lines, every 3 points | |
| holo | Dragging the card shifts a rainbow sheen, with glitter specks | |
| dissolve | The button dissolves the image along a noise pattern, with an orange burning edge; bringing it back works | |
| textGradient | "Shader" painted with a moving color blend | |
| chromaticAberration | Red/blue separation at edges; none at slider 0; edges not clipped | |
| pixelate | Blocky image; the slider value is the cell size | |
| ripple | A wave spreads from where you tap and fades (~3 s) | |
| lens | A circle under your finger magnifies 2x | |
| glitch | Horizontal bands shift, with color separation | |
| glow | A soft yellow halo around the yellow bolt; the halo is not cut off by the view | |
| wave | The image ripples horizontally | |
| swirl | A whirlpool around your finger | |
| dotGrid | Evenly spaced white dots on black | |
| progressRing | A green ring filling clockwise from 12 o'clock; the slider changes it | |
| debugUV | Top-left black, top-right red, bottom-left green, bottom-right yellow | |
| debugGrid | Red grid lines every 40 points | |
| debugAlpha | Text white, surroundings black (alpha view) | |

## 3. Especially doubtful points

The places the author is least sure about; look at these specifically:

- **`colorEffect` on a fully transparent base** (`progressRing` and `metaballs` use a black base). Try whether the shader is called on `Color.clear`.
- **`glow`**: whether the effect may spill outside the view bounds is undocumented; try it without `.padding(48)` and confirm the halo gets clipped.
- **`dithersColor`** (`swiftui-shaders.md` section 10): compare banding in `plasma` with and without it.
- **`proxy.frame(in:)`** (`swift-patterns.md` section 4): does the scroll example compile?
- **`AnimatedShader`**: with Settings ▸ Accessibility ▸ Motion ▸ Reduce Motion on, does the animation stop?
- **Performance**: for `aurora`, `voronoiCells`, `sphereMarch` and `glow`, note the device model and the frame rate you felt. This skill promises no fps value; your measurement goes into the README.
- **Xcode Metal debugger**: do the steps in `performance-debugging.md` section 9 actually work on a SwiftUI shader? (Apple's articles do not mention SwiftUI.) If not, that section needs fixing.

## 4. Bug report format

Send me this and I will fix it:

```
Xcode version / iOS version / device:
File and line:
Error text (verbatim):
Which demo / what was expected / what happened:
```

For runtime problems (effect not showing, looks wrong) apply the decision tree in `performance-debugging.md` section 7 first.

## 5. Skill trigger test

After adding the skill to Claude, try these prompts in a fresh chat.

**The skill should engage:**

1. "How do I make a light sweep across a card in SwiftUI?"
2. "Convert this Shadertoy code to Swift: …(a mainImage)"
3. "Write a Metal shader that adds a glitch effect to a photo."
4. "colorEffect runs but the screen is blank, why?"
5. "What is a shader? I want to learn from scratch."
6. "My SwiftUI ripple effect drops frames on iPhone 12, how do I profile the shader?"
7. "I want to make a sphere wobble with RealityKit CustomMaterial."

**The skill should not engage** (generic SwiftUI or other topics):

8. "How do I add a swipe action to a List in SwiftUI?"
9. "What is the difference between Core Data and SwiftData?"
10. "How do I write a regex in a Python script?"

**Expected behavior:**

- For 2: gives a license warning, flips the y axis, converts `mod`/`atan`, and lists the changes.
- For 3: picks `layerEffect`, gives `.metal` + Swift + parameter units, and says it was not compiled.
- For 4: asks from the decision tree (`[[ stitchable ]]`, name, parameter order, UIKit-backed view) or gives a checklist.
- For 7: uses `[[visible]]` and `realitykit::surface_parameters` instead of SwiftUI modifiers.

If you see an unexpected trigger or a miss, edit the `description` field in `SKILL.md` and retry; triggering depends mostly on that field.

## 6. Pre-release checklist

- [ ] Every demo in section 2 is ticked and bugs are fixed.
- [ ] Fixes were made in `examples/ShaderLab/*.metal` and `python3 tools/build_recipes.py` was run (the docs take their code from there).
- [ ] The "test status" table in the README is updated with the real state (device, iOS, Xcode versions).
- [x] The copyright holder name in `LICENSE` is filled in.
- [ ] No third-party shader code (Shadertoy etc.) got into the repo; the examples in `ShadertoyPorts.metal` were written for this skill.
- [ ] Information taken from Apple documentation is only paraphrased, with no long quotations (see "Sources" in the README).
- [ ] The repo is public and the install command in the README works with your own repo name.
