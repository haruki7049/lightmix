# Contributing to lightmix

Thank you for your interest in contributing to lightmix! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Project Philosophy & Scope](#project-philosophy--scope)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [How to Contribute](#how-to-contribute)
- [Coding Guidelines](#coding-guidelines)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Versioning and Releasing](#versioning-and-releasing)
- [Documentation](#documentation)
- [Audio-Specific Guidelines](#audio-specific-guidelines)

## Code of Conduct

See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). We use [Contributor Covenant](https://www.contributor-covenant.org/version/2/0/code_of_conduct.html).

## Project Philosophy & Scope

Before contributing new features, please understand `lightmix`'s core architectural principles and scope boundaries:

1. **Audio as a Deterministic Build Artifact**:
   The primary mission is generating audio deterministically at build time (`zig build`), suitable for CI pipelines, automated game asset compilation, and headless environments. Output must be bit-identical and reproducible.
1. **Minimalist Core (Unix Philosophy)**:
   - **In Scope**: Foundational primitives for waveform data structures (`Wave(T)`), timeline mixing (`Composer(T)`), WAV encoding/decoding, and build integration (`addWave`).
   - **Out of Scope (Non-Goals)**: Heavy DSP effect suites (reverb, chorus, flanger, etc.) and specialized synthesizer instrument presets. These belong in higher-level libraries or application code.
1. **Playback is Auxiliary**:
   Real-time audio playback (`play()`, `addPlay`) is strictly a local developer preview helper. Changes to the core synthesis and build pipeline must never introduce runtime audio server dependencies or break headless CI execution.
1. **Flat Generic Typing**:
   `lightmix` treats floating-point sample types (`f32`, `f64`, `f80` and `f128`) flatly via `comptime T: type`. Do not hardcode or prioritize a specific sample type in core structures.
1. **In-Memory Buffer Model**:
   Waveforms are held in memory buffers (`Wave(T)`). Simplicity, safety, and deterministic calculation take priority over premature streaming pipelines.
1. **Stateless Randomness**:
   `lightmix` does not embed internal pseudo-random number generators (PRNG). Callers pass generated noise buffers directly (e.g., using `std.Random.DefaultPrng`), guaranteeing full caller control over random seeds and determinism.
1. **Crash Noise & Clipping as Sound Sources**:
   Overdriven signals, clipping, and crash noise are treated as valid sound sources in themselves. Core operations never sanitize, auto-normalize, or fail on out-of-bounds sample values; raw sample data is preserved as-is, deferring quantization behavior entirely to underlying format codecs (such as `zigggwavvv`). As a codec-level exception, a PCM write clamps finite out-of-range samples to `[-1.0, 1.0]` but fails with `NonFiniteSample` for `NaN` and infinite samples, which cannot be quantized (IEEE float formats store them as they are).
1. **Multi-Format Ingestion**:
   In addition to pure algorithmic synthesis, importing external audio sources (`Wave(T).read`) is an essential supported workflow. Currently, standard uncompressed WAV is implemented, with pure Zig decoding for compressed formats (FLAC, Ogg Vorbis) planned on the roadmap (#138, #301).
1. **Unified Export & Cross-Format Metadata**:
   Audio export should be abstracted uniformly across formats (`wave.write(...)`), accompanied by format-agnostic metadata support (such as game audio loop points).
1. **Strict Property Matching**:
   No hidden resampling or channel coercion. Property mismatches must produce explicit errors (`error.MismatchedWaveProperties`), requiring caller-directed conversion. The one exception is `Wave(T).play()`, a preview helper that adapts channels to the output device by default; `playWithOptions(.{ .channels = .strict })` opts back in to strict matching, and the sample rate is never adapted.
1. **Pure Zig (Zero C Dependencies)**:
   All core capabilities and future format codecs must be implemented in Pure Zig to guarantee instant cross-compilation without C toolchains or host SDK issues.
1. **Future Unmanaged Memory Evolution**:
   A planned transition toward modern Zig 0.16 `Unmanaged` patterns (allocator-per-operation) is on the architectural roadmap, deferring implementation to a scheduled breaking-change cycle.
1. **Parallelism via Build System**:
   Keep core data structures synchronous. Parallel generation across multiple audio assets is managed by `zig build -j` rather than internal threading complexity.
1. **Aggressive Deprecation & Zig 1.0 Milestone**:
   Deprecated features are pruned quickly to stay aligned with modern Zig idioms. Releasing `lightmix 1.0.0` is anchored to Zig's official `1.0.0` milestone.

## Getting Started

1. **Fork the repository** on GitHub
1. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/lightmix.git
   cd lightmix
   ```
1. **Set up the development environment** (see below)
1. **Create a new branch** for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Environment

### Required Tools

- **Zig 0.16.0** - This project tracks Zig's minor version
- **Git** for version control

### Optional but Recommended

- **Nix** (with flakes enabled) for reproducible development environment
- **direnv** for automatic environment loading
- **Audio player** (`sox`, VLC, or similar) for testing audio output

### Setup with Nix

If you have Nix with flakes:

```bash
# Automatic setup with direnv
echo "use flake" > .envrc
direnv allow

# Or manually enter the dev shell
nix develop
```

### Setup without Nix

1. Install Zig 0.16.0 from [ziglang.org](https://ziglang.org/download/)
1. Verify installation:
   ```bash
   zig version  # Should show 0.16.0
   ```

### Building and Testing

```bash
# Run all tests
zig build test

# Build the library
zig build

# Generate documentation
zig build docs

# Run examples
cd examples/01-getting-started/hello-wave
zig build run
```

## How to Contribute

### Types of Contributions

We welcome:

- **Bug fixes** - Fix issues in the core library or examples
- **New features** - Add new audio processing capabilities
- **Examples** - Create educational examples demonstrating library features
- **Documentation** - Improve docs, comments, or README files
- **Tests** - Add test coverage for existing functionality
- **Performance improvements** - Optimize audio processing algorithms

### Finding Something to Work On

- Check the [issue tracker](https://github.com/haruki7049/lightmix/issues) for open issues
- Look for issues labeled `good first issue` or `help wanted`
- Review the examples directory for areas that need more coverage
- Propose new features by opening an issue first

## Coding Guidelines

### General Principles

1. **Clarity over cleverness** - Write code that's easy to understand
1. **Type safety** - Leverage Zig's type system for compile-time safety
1. **Memory safety** - Properly manage allocations and prevent leaks
1. **Documentation** - Document public APIs and complex algorithms

### Code Style

- **Comments**: Write comments in **English**
  - Documentation comments (`///` and `//!`) must be in English
  - Regular inline comments (`//`) should also be in English
- **Formatting**: Use `zig fmt` before committing
  - Run `zig fmt .` in the project root, and `zig fmt --check .` to verify it without changing files
- **Naming**:
  - `camelCase` for functions and variables
  - `PascalCase` for types
  - `SCREAMING_SNAKE_CASE` for constants
- **Indentation**: 4 spaces (handled by `zig fmt`)

### Documentation Comments

Use documentation comments for all public APIs:

```zig
/// Creates a new Wave instance from sample data.
///
/// The function creates a deep copy of the sample data, so the caller
/// retains ownership of the original samples slice.
///
/// ## Parameters
/// - `samples`: Slice of sample data to copy
/// - `allocator`: Memory allocator for internal allocations
/// - `options`: Initialization options (sample rate and channel count)
///
/// ## Returns
/// A new Wave instance containing a copy of the sample data
///
/// ## Errors
/// - `InvalidChannelCount`: If `options.channels` is zero
/// - `InvalidSampleRate`: If `options.sample_rate` is zero
/// - `UnalignedChannelOffset`: If `samples.len` is not a multiple of `options.channels`
/// - Allocator error (errors.OutOfMemory)
pub fn init(
    samples: []const T,
    allocator: std.mem.Allocator,
    options: InitOptions,
) (MixErrors || std.mem.Allocator.Error)!Self {
    // Implementation
}
```

### Generic Programming

When creating generic functions:

- Use `comptime` parameters for type flexibility
- Document type constraints clearly
- Provide usage examples

````zig
/// Wave type function: Creates a Wave type for the specified sample type.
///
/// ## Type Parameter
/// - `T`: The sample data type (a floating-point type: f32, f64, f80 or f128)
///
/// ## Usage
/// ```zig
/// const Wave = lightmix.Wave;
/// const wave = try Wave(f64).init(samples, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer wave.deinit();
/// ```
pub fn inner(comptime T: type) type {
    return struct {
        // Implementation
    };
}
````

### Memory Management

- **Always provide `deinit` functions** for types that allocate memory
- **Document ownership** clearly in function comments
- **Use `defer` appropriately** in examples and tests
- **Test for memory leaks** using `std.testing.allocator`

```zig
test "no memory leaks" {
    const allocator = std.testing.allocator;
    const wave = try Wave(f64).init(samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();
    // Test code
}
```

## Testing

### Writing Tests

- **Unit tests**: Place in the same file as the code being tested
- **Integration tests**: Place in `tests/` directory
- **Example tests**: Each example should run without errors

### Test Organization

```zig
// In src/wave.zig
test "init creates deep copy of samples" {
    const allocator = testing.allocator;
    var original_samples = [_]T{ 1.0, 2.0, 3.0 };
    const wave = try Self.init(&original_samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // Modify original samples
    original_samples[0] = 999.0;

    // Wave samples should be unchanged
    try testing.expectEqual(wave.samples[0], 1.0);
}
```

### Running Tests

```bash
# Run all tests (unit and integration tests)
zig build test

# Show how many tests ran
zig build test --summary all
```

`zig test src/wave.zig` does not work: the source files import the `zigggwavvv` module, which only `build.zig` provides. Use `zig build test`. Tests run with `std.testing.allocator`, which reports memory leaks.

## Submitting Changes

### Before Submitting

1. **Run tests**: `zig build test`
1. **Format code**: `zig fmt .`, then check it with `zig fmt --check .` (the CI runs the check)
1. **Build the documentation**: `zig build docs`
1. **Update documentation** if needed
1. **Add tests** for new functionality
1. **Test examples** if they're affected

### Commit Messages

Write clear, descriptive commit messages:

```
Add filter composition example

- Create new example in examples/03-wave-operations/
- Demonstrate using multiple self-written filters in sequence
- Include documentation about function composition
```

### Pull Request Process

1. **Push your branch** to your fork
1. **Open a Pull Request** against `main`
1. **Describe your changes**:
   - What problem does this solve?
   - How did you test it?
   - Any breaking changes?
1. **Respond to review feedback**
1. **Keep your PR up to date** with main

### PR Title Format

- `feat: Add new feature`
- `fix: Fix bug description`
- `docs: Update documentation`
- `test: Add tests for X`
- `refactor: Improve code structure`
- `perf: Optimize performance of X`
- `build: Update build.zig, build.zig.zon or a dependency`
- `ci: Change a GitHub Actions workflow`
- `chore: Routine maintenance`
- `style: Change formatting without changing behavior`
- `revert: Revert an earlier change`

A pull request title must start with one of these types, with an optional scope (`feat(wave): ...`) and `!` for a breaking change (`feat(wave)!: ...`). The check is `.github/workflows/pr-conventional-commits-validation.yml`.

## Versioning and Releasing

### Versioning

This project follows [Semantic Versioning](https://semver.org/). The `version` in `build.zig.zon` is the single source of truth for the version, and the tag and the GitHub Release have the same name. Zig accepts only a full version (`0.26.0`, `1.0.0-rc.1`), so use `{major}.{minor}.{patch}` or `{major}.{minor}.{patch}-{preRelease}` and don't prefix it with `v`: `1.0.0`, not `v1.0.0`. Build metadata (`+...`) is not used.

#### Before 1.0.0 (`0.x`)

Semantic Versioning allows anything to change in a `0.x` version. The `1.0.0` release is anchored to the `1.0.0` release of Zig (#89). Until then, `minor` carries every change that a caller can notice, and `patch` carries the rest:

| Change | Release |
| --- | --- |
| Removing or changing a public declaration, a function signature, a type, or behavior that callers rely on (a pull request marked with `!`) | minor |
| Requiring a newer Zig minor version (`minimum_zig_version` in `build.zig.zon`) | minor |
| Adding a public declaration, a function, or a field with a default (`feat`) | minor |
| Adding a member to a public error set | minor |
| Fixing a bug without changing the documented behavior (`fix`) | patch |
| A change without an effect on the public API (`docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`) | patch |

Adding a member to an error set breaks a `switch` over it that has no `else` prong, so it goes to `minor` as well.

Every `0.x` release is marked as a pre-release on GitHub, and so is every version with a pre-release part, for example `1.0.0-rc.1`.

#### From 1.0.0

The usual rules apply: a change in the first row above, or raising `minimum_zig_version`, is a `major` release; a `feat` or a new error set member is a `minor` release; the rest is a `patch` release.

### Releasing

A release is made by merging a change of `version` in `build.zig.zon` to `main`. A workflow (`.github/workflows/release.yml`) does the rest.

Each minor release has a tracking issue, `feat(release): track tasks for minor release X.Y.0`, with the label `lightmix version`. It lists the issues that are done, the issues that moved out of the release, and the breaking changes so far.

#### Before releasing

- The CI is green on the latest commit of `main`.
- Every change that should be in the release is merged, and the open issues are checked against the tracking issue.
- The breaking changes are listed: pull requests marked with `!` or with the label `breaking change`, and the "Breaking changes so far" part of the tracking issue.
- The migration guide is drafted when there are breaking changes (see "Migration guide").

#### Steps

1. Choose the version following the table in "Versioning". Use a pre-release version for a release candidate, for example `1.0.0-rc.1` (then `1.0.0-rc.2`, and so on).
1. Open a pull request that only changes `version` in `build.zig.zon`, with the title `feat(lightmix version): Bump up to X.Y.Z` and the label `lightmix version`, and merge it. See "Pull Request Process" for the conventions.
1. The workflow reads the version and checks that it is valid. If a tag with that name already exists, it stops. Otherwise it runs `zig build test` and `zig build`, creates the tag on the merged commit, and creates the GitHub Release with the generated "What's Changed" notes. The release is marked as a pre-release for a `0.x` version and for a version that contains `-`.
1. Check the workflow run in the Actions tab, and check the new release.
1. Add the migration guide to the release when there are breaking changes.

A change of `build.zig.zon` that does not change `version` (for example an update of a dependency) also starts the workflow, and it does nothing, because the tag of that version already exists.

#### Migration guide

For a release with breaking changes, add a section with the breaking changes and the migration steps to the release body. It is not stored in the repository.

1. Collect the breaking changes: the "Breaking changes so far" part of the tracking issue, the pull requests marked with `!`, and the pull requests with the label `breaking change`. Read each pull request, because its description has the details.
1. An AI assistant drafts the guide, and the maintainer reviews it before it is published. For each breaking change it says what changed, who is affected, and how to migrate, with a before and an after example when a signature or a behavior changed. The changes that callers meet at compile time come first, then the changes in behavior.
1. Add the guide after the workflow created the release. The workflow writes only the generated notes, and these commands keep them. They write three files, so run them in a temporary directory outside the repository (`cd "$(mktemp -d)"`), or the files stay in the working tree as untracked files:

```bash
version=X.Y.Z # the version of the release, for example 0.26.0
gh release view "$version" --json body --jq .body > generated.md
# write the reviewed migration guide to migration.md, then:
{ cat migration.md; echo; cat generated.md; } > body.md
gh release edit "$version" --notes-file body.md
```

#### Undoing a release

If a release was created by mistake, delete it together with its tag, then fix the problem and merge a new change:

```bash
version=X.Y.Z # the version of the release to undo, for example 0.26.0
gh release delete "$version" --cleanup-tag --yes
```

Do not reuse a version whose contents may already have been fetched by others: publish the next version instead.

#### If the workflow fails

Open the failed run in the Actions tab and read the error.

- The version is not valid: fix `version` in a new pull request.
- The tests failed: fix the problem on `main` first.
- The tag or the release could not be created: check the workflow permissions in the repository settings (Settings, Actions, General) and the rules that protect branches and tags, because they can stop a workflow from creating a tag.

After fixing the cause, run the workflow again from the Actions tab on `main` ("Run workflow"). It does nothing if the version is already released.

## Documentation

### Types of Documentation

1. **API Documentation** - Document all public functions, types, and constants
1. **Examples** - Create runnable examples with detailed comments
1. **README** - Keep README.md up to date with new features
1. **Build-time Docs** - Run `zig build docs` to generate API docs

### Example Documentation

When creating examples:

- **Add top-level documentation** (`//!`) explaining the concept
- **Include inline comments** for complex code sections
- **Provide context** about what the example demonstrates
- **Show expected output** or results

```zig
//! # Filter Composition Example
//!
//! This example demonstrates how to apply multiple self-written filters in sequence.
//! We apply decay and volume reduction to create a fade-out effect.
//!
//! ## What you'll learn:
//! - Writing filters as plain functions
//! - Creating composite effects
//! - Choosing between returning a new wave and in-place changes

const std = @import("std");
const lightmix = @import("lightmix");

pub fn main() !void {
    // Example implementation with comments
}
```

## Audio-Specific Guidelines

### Deterministic & Headless Synthesis

- **Deterministic Output**: Ensure all synthesis routines produce bit-identical output across supported operating systems and CPU architectures.
- **Headless Compatibility**: Standard build and test steps must never assume physical audio hardware or active sound daemons (ALSA, PulseAudio, PipeWire, CoreAudio).
- **Playback as Helper**: The `play()` and `addPlay` utilities are preview helpers; never introduce playback dependencies into core synthesis or file generation logic.

### Sample Rates

- **Default to 44100 Hz** in examples (CD quality)
- **Support common rates**: 22050, 44100, 48000, 96000 Hz
- **Document rate requirements** clearly

### Audio Formats

- **Prefer PCM formats** for examples
- **Support standard bit depths**: 16, 24, 32 bits
- **Document format limitations**

### Testing Audio Output

When contributing audio generation code:

1. **Listen to the output** - Does it sound correct?
1. **Check for clipping** - Ensure samples stay within [-1.0, 1.0]
1. **Verify silence** - Silent sections should be exactly 0.0
1. **Test edge cases** - Empty waves, single samples, etc.

### Performance Considerations

- **Avoid unnecessary allocations** in tight loops
- **Use `comptime` for static computations**
- **Profile performance-critical code**
- **Document time complexity** for algorithms

### Example Audio Files

When adding test audio files:

- **Keep files small** (< 1 MB preferred)
- **Use standard formats** (WAV, 16-bit PCM)
- **Document file contents** in comments
- **Add to `.gitignore` if generated**

## Questions?

If you have questions:

- **Open an issue** for discussion
- **Check existing issues** and PRs
- **Review examples** for patterns and conventions

## License

By contributing to lightmix, you agree that your contributions will be licensed under the [MIT License](./LICENSE).

______________________________________________________________________

Thank you for contributing to lightmix! 🎵
