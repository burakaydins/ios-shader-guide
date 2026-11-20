#!/usr/bin/env python3
"""Check that every ShaderLibrary call in the Swift demo passes arguments that
match the [[ stitchable ]] function's parameters, in count, order and type.

SwiftUI does not check this at compile time; a mismatch makes the effect
silently disappear at runtime. Run from the repo root:

    python3 skills/ios-shader-guide/tools/check_arguments.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "examples" / "ShaderLab"

# Shader.Argument case -> the MSL parameter types it binds to
ARG_TYPES = {
    "float": ["float"],
    "float2": ["float2"],
    "float3": ["float3"],
    "float4": ["float4"],
    "color": ["half4"],
    "boundingRect": ["float4"],
    "image": ["texture2d<half>"],
    "floatArray": ["device const float *", "int"],
    "colorArray": ["device const half4 *", "int"],
    "data": ["device const void *", "int"],
}


def norm(t: str) -> str:
    t = re.sub(r"\s+", " ", t.strip())
    t = t.replace(" *", " *").replace("const device", "device const")
    return t


def metal_signatures():
    sigs = {}
    pat = re.compile(r"\[\[\s*stitchable\s*\]\]\s*(\w+)\s+(\w+)\s*\(([^)]*)\)", re.S)
    for f in ROOT.glob("*.metal"):
        for ret, name, params in pat.findall(f.read_text()):
            plist = []
            for p in params.split(","):
                p = p.strip()
                if not p:
                    continue
                typ = norm(p.rsplit(" ", 1)[0]) if not p.endswith("*") else norm(p)
                plist.append(typ)
            sigs[name] = (ret, plist)
    return sigs


def split_args(s: str):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def swift_calls():
    calls = []
    for f in ROOT.glob("*.swift"):
        text = f.read_text()
        for m in re.finditer(r"ShaderLibrary\.(\w+)\(", text):
            i, depth = m.end(), 1
            while depth:
                depth += {"(": 1, ")": -1}.get(text[i], 0)
                i += 1
            args = split_args(text[m.end():i - 1])
            before = text[max(0, m.start() - 40):m.start()]
            kind = "shapeStyle"
            for k in ("colorEffect", "layerEffect", "distortionEffect"):
                if k in before:
                    kind = k
            line = text.count("\n", 0, m.start()) + 1
            calls.append((f.name, line, m.group(1), kind, args))
    return calls


EXPECTED_HEAD = {
    "colorEffect": ("half4", ["float2", "half4"]),
    "layerEffect": ("half4", ["float2", "SwiftUI::Layer"]),
    "distortionEffect": ("float2", ["float2"]),
    "shapeStyle": ("half4", ["float2"]),
}


def main():
    sigs = metal_signatures()
    problems = 0
    for fname, line, name, kind, args in swift_calls():
        where = f"{fname}:{line} {name} ({kind})"
        if name not in sigs:
            print(f"MISSING  {where}: no [[ stitchable ]] function with this name")
            problems += 1
            continue
        ret, params = sigs[name]
        want_ret, head = EXPECTED_HEAD[kind]
        if ret != want_ret or params[:len(head)] != head:
            print(f"HEAD     {where}: expected {want_ret} f({', '.join(head)}, ...), got {ret} f({', '.join(params)})")
            problems += 1
            continue
        got = []
        for a in args:
            case = re.match(r"\.(\w+)", a)
            if not case or case.group(1) not in ARG_TYPES:
                print(f"UNKNOWN  {where}: argument {a!r}")
                problems += 1
                break
            got += ARG_TYPES[case.group(1)]
        else:
            rest = params[len(head):]
            if got != rest:
                print(f"MISMATCH {where}:\n  Swift passes: {got}\n  MSL expects:  {rest}")
                problems += 1
            else:
                print(f"ok       {where}")
    print(f"\n{problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
