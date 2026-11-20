#!/usr/bin/env python3
"""Rough syntax check of the .metal recipes WITHOUT a Metal compiler.

It rewrites MSL into OpenCL C (which has float2/float3/..., swizzles, mix,
smoothstep, ...) and runs `clang -fsyntax-only` on the result.

What this catches : typos, unbalanced braces, undeclared identifiers, wrong
                    number of arguments, most vector/scalar type errors.
What it CANNOT do : replace Xcode. `half` is mapped to `float`, so half/float
                    mixing errors are NOT detected, and SwiftUI/MSL specifics
                    ([[stitchable]], SwiftUI::Layer) are only stubbed.
Always build in Xcode for the real answer.

Usage: python3 tools/syntax_check.py examples/ShaderLab/Shaders.metal
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PRELUDE = r"""
#define half float
#define half2 float2
#define half3 float3
#define half4 float4
#define fract(x) ((x) - floor(x))
#define abs(x) fabs(x)
#define saturate(x) clamp((x), 0.0f, 1.0f)
typedef struct { int dummy; } Layer;
float4 layer_sample(Layer l, float2 p) { return (float4)(0.0f); }
"""

def convert(src: str, base: Path) -> str:
    # inline local headers
    def inline(m):
        return convert(( base / m.group(1)).read_text(), base)
    src = re.sub(r'#include\s+"([^"]+)"', inline, src)
    src = re.sub(r'#include\s+<[^>]+>', '', src)
    src = re.sub(r'#pragma once', '', src)
    src = src.replace('using namespace metal;', '')
    src = src.replace('[[ stitchable ]]', '')
    src = src.replace('SwiftUI::Layer', 'Layer')
    # `thread float2& p` (by-reference) -> by value. Syntax only; the reference
    # semantics are not checked by this approximation.
    src = re.sub(r'\bthread\s+(\w+)\s*&\s*', r'\1 ', src)
    src = re.sub(r'\blayer\.sample\(', 'layer_sample(layer, ', src)
    src = re.sub(r'\b(\d+\.\d*|\.\d+)h\b', r'\1f', src)           # 1.0h -> 1.0f
    # constructors / casts:  float3(...) -> (float3)(...)
    src = re.sub(r'(?<![\w.])(half|float|int|uint)([234]?)\s*\(',
                 lambda m: f'(({m.group(1)}{m.group(2)}))(' if False else f'({m.group(1)}{m.group(2)})(', src)
    return src

def main():
    path = Path(sys.argv[1]).resolve()
    out = PRELUDE + convert(path.read_text(), path.parent)
    # function definitions like `float hash21(float2 p)` were hit by the cast regex
    # only when written as `float(`; declarations are untouched.
    with tempfile.NamedTemporaryFile('w', suffix='.cl', delete=False) as f:
        f.write(out)
        tmp = f.name
    cmd = ['clang', '-x', 'cl', '-cl-std=CL2.0', '-Xclang', '-finclude-default-header',
           '-fsyntax-only', '-Wno-everything', tmp]
    r = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(r.stderr.replace(tmp, 'converted.cl'))
    if r.returncode == 0:
        print('syntax check: OK (approximation, build in Xcode to be sure)')
    else:
        print(f'syntax check: FAILED (converted file kept at {tmp})')
    sys.exit(r.returncode)

if __name__ == '__main__':
    main()
