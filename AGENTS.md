# Agent Guidelines for `lightmix`

This document provides context, instructions, and conventions for AI agents (such as Antigravity, Gemini, Claude, Cursor, ChatGPT, etc.) working on the `lightmix` repository.

______________________________________________________________________

## 1. Project Overview

`lightmix` is an audio synthesis and processing library written in Zig.

- **Core Philosophy**: Treat audio generation as a deterministic build artifact. Running `zig build` or `zig build run` produces WAV audio files directly during the build process, eliminating the need for real-time audio recording or external sound server dependencies.
- **Architectural Principles & Scope**:
  - **Minimalist Core (Unix Philosophy)**: Focus strictly on low-level primitives: `Wave(T)` (waveform buffer & manipulation), `Composer(T)` (timeline arrangement & mixing), accurate WAV I/O, and `addWave` build-system integration.
  - **Non-Goals**: High-level DSP effect suites (reverb, delay, chorus, flanger) and synthesizer instrument presets belong in separate higher-level libraries or application code.
  - **Auxiliary Playback**: `play()` and `addPlay` are developer preview helpers only. They must never introduce hard audio server dependencies or interfere with headless CI execution.
  - **Flat Generic Typing**: Generic over `comptime T: type` (`f64`, `f80`, `f128`, and future `f32`). Do not hardcode or favor any single floating-point precision.
  - **In-Memory Buffer Model**: Full sample buffers are held in memory (`Wave(T)`) for deterministic safety and simplicity, avoiding premature streaming complexity.
- **Target Language Version**: Zig `0.16.0`.

______________________________________________________________________

## 2. Directory Structure

- `src/`
  - `root.zig`: Library root entry point.
  - `wave.zig`: Waveform data structures (`Wave`), synthesis routines, and sample manipulation.
  - `composer.zig`: Audio mixing, track composition, and audio timeline building.
  - `assets/`: Embedded/bundled audio resources and standard formats.
- `tests/`
  - `wave.zig`: Integration and unit test suite for wave features.
  - `composer.zig`: Integration tests for composition and track mixing.
- `examples/`: Categorized runnable example projects demonstrating `lightmix` usage.
- `build.zig` & `build.zig.zon`: Build definition script and package metadata.
- `flake.nix` & `shell.nix`: Nix development shell configurations.

______________________________________________________________________

## 3. Mandatory Commands & Verification Workflow

Before marking any task as complete, AI agents **MUST** execute the relevant commands below and verify clean execution:

| Task | Command | Description |
| :--- | :--- | :--- |
| **Run All Tests** | `zig build test` | Executes full test suite (unit + integration tests) |
| **Run Specific Test File** | `zig test src/wave.zig` | Fast iteration for individual files |
| **Check Code Formatting** | `zig fmt --check .` | Verifies code formatting without modifying files |
| **Format Code** | `zig fmt .` | Auto-formats all Zig code in the repository |
| **Generate Documentation** | `zig build docs` | Builds API documentation to check for doc errors |
| **Build Library** | `zig build` | Builds the library and default artifacts |

______________________________________________________________________

## 4. Coding & Documentation Guidelines

### Language Policy for Comments

- **ALL comments MUST be in English.**
  - Documentation comments (`///` and `//!`) must be written in English.
  - Regular inline comments (`//`) must also be in English.

### Formatting & Code Style

- **Formatter**: Always format Zig files with `zig fmt .` prior to finishing changes.
- **Naming Conventions**:
  - `camelCase` for functions and variables.
  - `PascalCase` for structs, unions, enums, and type-generating functions.
  - `SCREAMING_SNAKE_CASE` for constants.
- **Indentation**: 4 spaces (enforced automatically by `zig fmt`).

### Memory Management & Safety

- **Deallocation**: Any type that allocates memory **must** provide a `deinit()` method.
- **Ownership**: Document buffer ownership clearly in function docstrings.
- **Leak Checking**: Always test dynamic allocations with `std.testing.allocator`.
- **Resource Cleanup**: Use `defer` and `errdefer` appropriately to ensure proper cleanup on early returns or errors.

### Generic Programming

- Use `comptime T: type` for generic numeric sample representations (e.g., `f64`, `f80`, `f128`).
- Explicitly document type parameter requirements and constraints.

### Audio Domain Rules

- **Sample Rate**: Default to **44100 Hz** in examples and standard templates.
- **Sample Range**: Audio sample amplitudes should target normalized range `[-1.0, 1.0]`.
- **Silence**: Silent sections must strictly equal `0.0`.
- **Clipping**: Verify that synthesized signal operations prevent unwanted overflow/clipping.

______________________________________________________________________

## 5. Git & Release Conventions

### Pull Request Titles

Follow the conventional commits format:

- `feat:` New audio feature or API capability.
- `fix:` Bug fix in library or examples.
- `docs:` Documentation improvements or comment updates.
- `test:` Test coverage additions.
- `refactor:` Code refactoring without changing external functionality.
- `perf:` Audio processing algorithm performance optimizations.

### Branching & Pull Request Workflow

- **Dedicated Branches**: Always create and work on a dedicated branch (e.g., `feat/wave-size` or `fix/composer-leak`). Do not commit directly to `main`.
- **PR Creation**: Create PRs using `gh pr create`. Reference issues in the body using standard keywords (e.g., `Closes #140`).
- **PR Merge Prohibition**: **NEVER MERGE Pull Requests.** PRs must remain open for maintainer review. Merging is strictly reserved for human maintainers unless the user explicitly commands the agent to merge a specific PR.

### GitHub Projects Registration

Whenever creating an Issue or Pull Request using the `gh` CLI, agents **MUST** register the created item to the project at `https://github.com/users/haruki7049/projects/11` (`lightmix GitHub Project`).

- **Via `--project` flag when creating**:
  ```bash
  gh issue create --project "lightmix GitHub Project" ...
  gh pr create --project "lightmix GitHub Project" ...
  ```
- **Via `gh project item-add` after creation**:
  ```bash
  gh project item-add 11 --owner haruki7049 --url <ISSUE_OR_PR_URL>
  ```

### Version Tagging

- Use Semantic Versioning **without** a `v` prefix (e.g., `1.0.0`, not `v1.0.0`).

______________________________________________________________________

## 6. Agent Behavioral Rules

1. **Verify Before Declaring Success**: Never claim a feature or fix is complete without running `zig build test` and `zig fmt --check .`.
1. **No Symptom Swallowing**: Fix root causes of failing tests; never comment out assertions or swallow error returns.
1. **Preserve English Comment Rule**: Ensure any new code comments or documentation additions strictly adhere to the English language requirement.
1. **Strict PR Merge Prohibition**: Always leave created Pull Requests open. Never attempt to merge a Pull Request unless explicitly instructed by the user.
1. **No Unsolicited Actions on Other Branches/PRs**: Never modify, rebase, or resolve conflicts on PRs or branches without explicit user instructions.
1. **Always Register to GitHub Project**: When creating Issues or Pull Requests with `gh`, always add them to `https://github.com/users/haruki7049/projects/11` (`lightmix GitHub Project`).
1. **Adhere to Minimalist Scope**: Never add complex DSP effects (reverb, delay, flanger, etc.) or synthesizer instrument presets to the core library. Keep additions focused on fundamental waveform manipulation, mixing, and build-time generation.
1. **Preserve Headless Execution**: Ensure all build steps, examples, and tests run cleanly in headless environments without physical audio devices or sound daemons. Playback utilities (`play()`) must remain strictly auxiliary preview helpers.
