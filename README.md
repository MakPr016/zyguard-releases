```
_____                                    __
╱__  ╱  __  ______ ___  ______ __________╱ ╱
  ╱ ╱  ╱ ╱ ╱ ╱ __ `╱ ╱ ╱ ╱ __ `╱ ___╱ __  ╱ 
 ╱ ╱__╱ ╱_╱ ╱ ╱_╱ ╱ ╱_╱ ╱ ╱_╱ ╱ ╱  ╱ ╱_╱ ╱  
╱____╱╲__, ╱╲__, ╱╲__,_╱╲__,_╱_╱   ╲__,_╱   
     ╱____╱╱____╱
```

Zyguard is a from-scratch LLM inference engine written in Rust, running entirely on Vulkan compute shaders via `wgpu` — no OpenVINO, no llama.cpp, no CUDA. Every kernel (matrix-vector multiply, normalization, rotary embeddings, the causal convolution, attention) is hand-written WGSL, verified against Hugging Face `transformers`. It ships a terminal chat UI (`zyguard-tui`), a CLI (`zyguard`) and a local HTTP API server (`zyguard-server`), which download and run these models locally on your GPU:

| Model | Download | On disk |
| --- | --- | --- |
| [LFM2.5-350M](https://huggingface.co/LiquidAI/LFM2.5-350M) (recommended) | 0.7 GB | 1.1 GB |
| [LFM2.5-350M-Thinking](https://huggingface.co/KoarAI/LFM2.5-350M-Thinking) | 0.7 GB | 1.1 GB |
| [LFM2.5-1.2B-Instruct](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct) | 2.3 GB | 3.7 GB |
| [LFM2.5-2.6B](https://huggingface.co/LiquidAI/LFM2.5-2.6B) | 5.4 GB | 8.4 GB |
| [Gemma 4 E2B (instruct)](https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF) | 5 GB | 5.3 GB |
| [Spark-X2.5-4B](https://huggingface.co/XHToken/Spark-X2.5-4B) | 8 GB | 5.3 GB |

Pick one from **+ Download a model** in `zyguard-tui`; it is downloaded, converted and loaded automatically (`o` opens the models folder). `zyguard launch claude` runs Claude Code against a local model. Runs on Windows and Linux; built and validated on an Intel Arc 140V, where the 2.6B model decodes at ~28 tok/s in Q8_0.

## About this repo

This repo hosts **compiled releases and issue tracking only** — the source code is currently private. If you're looking for `src/`, it isn't here.

## Install

The current release is the `v0.1.0-beta.2.8` pre-release ([release notes](https://github.com/MakPr016/zyguard-releases/releases/tag/v0.1.0-beta.2.8)).

**One command (recommended):**

```powershell
irm https://raw.githubusercontent.com/MakPr016/zyguard-releases/main/install.ps1 | iex
```

or from `cmd.exe` with `curl`:

```bat
curl -fsSL https://raw.githubusercontent.com/MakPr016/zyguard-releases/main/install.ps1 -o "%TEMP%\zyguard-install.ps1" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\zyguard-install.ps1"
```

Installs `zyguard`, `zyguard-tui` and `zyguard-server` from the newest release into `%LOCALAPPDATA%\Programs\zyguard` and adds that folder to your user PATH (open a new terminal afterwards). The download is checked against the SHA-256 GitHub records for it before anything is unpacked. Run it again to upgrade. Set `ZYGUARD_VERSION=0.1.0-beta.2.8` to install a specific release, or `ZYGUARD_INSTALL_DIR` to install somewhere else. [`install.ps1`](install.ps1) is in this repo if you want to read it first.

**Linux** (x86_64 or aarch64, glibc 2.28+: Amazon Linux 2023, Ubuntu 20.04+, Debian 10+, RHEL 8+):

```sh
curl -fsSL https://raw.githubusercontent.com/MakPr016/zyguard-releases/main/install.sh | sh
```

Installs the same three programs into `~/.local/bin`, with the same SHA-256 check and the same `ZYGUARD_VERSION` / `ZYGUARD_INSTALL_DIR` variables ([`install.sh`](install.sh)). You also need the Vulkan loader and a GPU driver: `sudo apt install libvulkan1 mesa-vulkan-drivers` (Debian/Ubuntu) or `sudo dnf install vulkan-loader mesa-vulkan-drivers` (Amazon Linux/Fedora); on NVIDIA machines the NVIDIA driver provides Vulkan. Models are stored in `~/.local/share/zyguard/models`. On a headless server, run `zyguard-server` for the HTTP API.

**Scoop:**

```powershell
scoop bucket add zyguard https://github.com/MakPr016/zyguard-releases
scoop install zyguard
```

**Windows installer:** the older [`zyguard-setup-0.1.0-beta.1.exe`](https://github.com/MakPr016/zyguard-releases/releases/download/v0.1.0-beta.1/zyguard-setup-0.1.0-beta.1.exe) is still available; newer releases ship as a zip only, so prefer one of the options above.

**winget:**

Public submission to `microsoft/winget-pkgs` is pending — `winget install zyguard` isn't available yet.

## Known limitations

Real, current caveats — worth reading before you install:

- **Linux builds are new and GPU-untested.** They start and find their folders on Amazon Linux 2023 and Ubuntu 20.04, but no model has been run on a Linux GPU yet, NVIDIA included. No macOS build.
- **A GPU is required.** Software Vulkan (Mesa's llvmpipe) is below the engine's 512 MiB storage-buffer minimum, so CPU-only machines are rejected at start-up.
- **Validated hardware is narrow.** Built and measured on an Intel Arc 140V (Lunar Lake iGPU). The pre-flight check will accept other Vulkan-capable GPUs that meet its requirements, but warns on anything other than Intel Arc since nothing else has been run for real.
- **Subgroup widths ≥ 64 lanes are logically covered but not run on real silicon.** Every reduction kernel is written to be correct for any subgroup size, and this was checked on hardware down to 4-lane and up to 32-lane subgroups plus a synthetic 64-lane-equivalent test — but no actual 64-lane hardware (AMD wave64, Qualcomm) has run this code.
- **Cross-drive model migration is mock-tested, not hardware-tested.** If your existing models folder and `%LOCALAPPDATA%` are on different drives, the one-time migration falls back to a copy instead of an instant rename. If it fails partway, your original folder is left untouched — nothing is deleted until the copy is verified complete.
- **No `--version` flag** on either binary yet.
- **winget isn't live yet** — see Install above.
- Model-specific: LFM2.5-350M's plain greedy decode reliably collapses into repeated tokens (e.g. `"TheTheThe..."`) after a handful of steps — this is the *model's* documented behavior (matches Hugging Face `transformers` bit-for-bit), not a bug in this engine. `--repeat-penalty`/`--no-repeat-ngram-size` avoids it.
- Tool calling adds its schemas to the prompt: with every tool group on, the first message of a conversation takes ~5-9 s longer to start on the 2.6B (later messages reuse the processed prompt). Left off by default for this reason; `--tools web` etc. keeps it smaller.

## Reporting issues

This is a closed-source beta — the [Issues tab](https://github.com/MakPr016/zyguard-releases/issues) is the feedback channel. Please include your OS/GPU, install method, and steps to reproduce (see the bug report template).

## License

The distributed binaries are covered by the [MIT license](LICENSE) in this repo.
