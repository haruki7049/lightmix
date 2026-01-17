# Modular Composing Example

This example demonstrates how to generate audio using a modular architecture with lightmix.

## Overview

This project shows how to separate music theory and synthesis concepts into independent packages and combine them to generate audio.

- **temperaments**: Package defining tuning systems
- **synths**: Package providing audio synthesis engines

By combining these packages, you can build a flexible and maintainable audio generation system.

## Project Structure

```
modular-composing/
├── build.zig              # Build configuration
├── build.zig.zon         # Dependency definitions
├── src/
│   └── root.zig          # Main entry point
└── packages/
    ├── temperaments/     # Tuning system package
    │   ├── src/
    │   │   ├── root.zig
    │   │   └── twelve_equal_temperament.zig
    │   ├── build.zig
    │   └── build.zig.zon
    └── synths/           # Synthesizer package
        ├── src/
        │   ├── synths.zig
        │   └── synths/
        │       └── sine.zig
        ├── build.zig
        └── build.zig.zon
```

## Package Descriptions

### temperaments

Provides tuning systems (scale tuning systems). Currently implements Twelve Equal Temperament.

Key features:
- Convert MIDI numbers to frequencies
- Manipulate pitches by semitones
- Manage note names and octaves

### synths

Provides synthesizer engines. Currently implements a sine wave oscillator.

Key features:
- Generate sine waves at specified pitches
- Customize sample rate and channel count

## Usage

Run the following command in this directory to generate a `result.wav` file:

```bash
zig build
```

The generated file is an audio file containing a sine wave playing C4 (middle C) for 1 second.

## Extension Methods

This example can be extended in the following ways:

1. **Add new tuning systems**: Add new tuning systems to the `temperaments` package (e.g., just intonation, Pythagorean tuning)
2. **Add new synthesizers**: Add new waveforms to the `synths` package (e.g., square wave, sawtooth wave, triangle wave)
3. **Create complex music**: Combine multiple notes to create chords and melodies

## Technical Features

- **Modular design**: Each feature is implemented as an independent package
- **Leverage Zig build system**: Manage package dependencies with `build.zig`
- **Type safety**: Safe implementation leveraging Zig's powerful type system
- **Build-time generation**: Generate WAV files at compile time

## Requirements

- Zig 0.15.2 or later
- lightmix library

## License

This project is part of the lightmix project and is subject to the same license.
