```
_____                                    __
╱__  ╱  __  ______ ___  ______ __________╱ ╱
  ╱ ╱  ╱ ╱ ╱ ╱ __ `╱ ╱ ╱ ╱ __ `╱ ___╱ __  ╱ 
 ╱ ╱__╱ ╱_╱ ╱ ╱_╱ ╱ ╱_╱ ╱ ╱_╱ ╱ ╱  ╱ ╱_╱ ╱  
╱____╱╲__, ╱╲__, ╱╲__,_╱╲__,_╱_╱   ╲__,_╱   
     ╱____╱╱____╱
```

Zyguard is a from-scratch LLM inference engine written in Rust, running entirely on Vulkan compute shaders via `wgpu` — no OpenVINO, no llama.cpp, no CUDA. Every kernel (matrix-vector multiply, normalization, rotary embeddings, the causal convolution, attention) is hand-written WGSL, verified against Hugging Face `transformers`. It ships a terminal chat UI (`zyguard-tui`) and a CLI (`zyguard`), both able to download and run [LiquidAI's LFM2.5](https://huggingface.co/LiquidAI/LFM2.5-350M) models (350M or 2.6B) locally on your GPU. Currently Windows-only, built and validated on an Intel Arc 140V, where the 2.6B model decodes at ~28 tok/s in Q8_0.

## About this repo

This repo hosts **compiled releases and issue tracking only** — the source code is currently private. If you're looking for `src/`, it isn't here.

## Install

This is the `v0.1.0-beta.1` pre-release.

**Windows installer:**

Download [`zyguard-setup-0.1.0-beta.1.exe`](https://github.com/MakPr016/zyguard-releases/releases/download/v0.1.0-beta.1/zyguard-setup-0.1.0-beta.1.exe) from the [latest release](https://github.com/MakPr016/zyguard-releases/releases/tag/v0.1.0-beta.1) and run it. Installs both binaries, adds a Start Menu shortcut, and offers to add `zyguard` to your PATH.

**Scoop:**

```powershell
scoop bucket add zyguard https://github.com/MakPr016/zyguard-releases
scoop install zyguard
```

**Cargo:**

```powershell
cargo install zyguard --version 0.1.0-beta.1
```

**winget:**

Public submission to `microsoft/winget-pkgs` is pending — `winget install zyguard` isn't available yet.

## Known limitations

Real, current caveats — worth reading before you install:

- **Windows only.** No macOS/Linux build.
- **Validated hardware is narrow.** Built and measured on an Intel Arc 140V (Lunar Lake iGPU). The pre-flight check will accept other Vulkan-capable GPUs that meet its requirements, but warns on anything other than Intel Arc since nothing else has been run for real.
- **Subgroup widths ≥ 64 lanes are logically covered but not run on real silicon.** Every reduction kernel is written to be correct for any subgroup size, and this was checked on hardware down to 4-lane and up to 32-lane subgroups plus a synthetic 64-lane-equivalent test — but no actual 64-lane hardware (AMD wave64, Qualcomm) has run this code.
- **Cross-drive model migration is mock-tested, not hardware-tested.** If your existing models folder and `%LOCALAPPDATA%` are on different drives, the one-time migration falls back to a copy instead of an instant rename. If it fails partway, your original folder is left untouched — nothing is deleted until the copy is verified complete.
- **No `--version` flag** on either binary yet.
- **winget isn't live yet** — see Install above.
- Model-specific: LFM2.5-350M's plain greedy decode reliably collapses into repeated tokens (e.g. `"TheTheThe..."`) after a handful of steps — this is the *model's* documented behavior (matches Hugging Face `transformers` bit-for-bit), not a bug in this engine. `--repeat-penalty`/`--no-repeat-ngram-size` avoids it.
- Tool calling is CPU-only and adds meaningful latency (~5-6s more time-to-first-token on the 2.6B) — left off by default for this reason.

## Reporting issues

This is a closed-source beta — the [Issues tab](https://github.com/MakPr016/zyguard-releases/issues) is the feedback channel. Please include your OS/GPU, install method, and steps to reproduce (see the bug report template).

## License

The distributed binaries are covered by the [MIT license](LICENSE) in this repo.
