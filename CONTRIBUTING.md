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
- [Tagging Rules](#tagging-rules)
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
   `lightmix` treats floating-point sample types (`f64`, `f80`, `f128`, and future `f32`) flatly via `comptime T: type`. Do not hardcode or prioritize a specific sample type in core structures.
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
   No hidden resampling or channel coercion. Property mismatches must produce explicit errors (`error.MismatchedWaveProperties`), requiring caller-directed conversion.
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
  - Run `zig fmt .` in the project root
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
pub fn init(
    samples: []const T,
    allocator: std.mem.Allocator,
    options: InitOptions,
) std.mem.Allocator.Error!Self {
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
/// - `T`: The sample data type (typically f64, f80, or f128)
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
# Run all tests
zig build test

# Run specific test file
zig test src/wave.zig

# Run with memory leak detection
zig test src/wave.zig --test-filter "no memory leaks"
```

## Submitting Changes

### Before Submitting

1. **Run tests**: `zig build test`
1. **Format code**: `zig fmt .`
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

## Tagging Rules

- Use [Semantic Versioning](https://semver.org/).
- Use `{major}.{minor}.{patch}`, `{major}.{minor}.{patch}-{preRelease}`, or `{major}.{minor}.{patch}+{buildMetadata}`.
- Don't prefix the tag with `v`. Use `1.0.0`, not `v1.0.0`.

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
