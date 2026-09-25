# lightmix Examples

Welcome to the lightmix examples! This directory contains a comprehensive set of examples organized by difficulty and concept, designed to help you learn audio programming with lightmix step by step.

## 📚 Example Categories

### 01-getting-started/

**Perfect for first-time users**

Start here if you're new to lightmix! These examples introduce the basics with clear, simple code.

- **hello-wave** - Create your first sine wave and save it to a WAV file
- **using-filters** - Learn how to transform audio with a filter function you write yourself

**What you'll learn:** Basic Wave creation, saving audio files, applying a simple self-written filter

### 02-wave-basics/

**Understanding fundamental waveforms**

Learn about the building blocks of sound synthesis. Each example generates a different basic waveform.

- **sine-wave** - Pure tone with no harmonics (smooth, clean sound)
- **square-wave** - Rich in odd harmonics (buzzy, 8-bit sound)
- **sawtooth-wave** - Bright with all harmonics (brass, string-like)
- **triangle-wave** - Mellow with odd harmonics (softer than square)
- **noise** - White, pink, and brown noise generation

**What you'll learn:** Wave generation algorithms, harmonics, audio characteristics of different waveforms

### 03-wave-operations/

**Manipulating and combining waves**

Once you can generate waves, learn how to transform and combine them.

- **mixing-waves** - Combine multiple waves to create chords and complex sounds
- **filtering** - Apply several self-written filters in sequence
- **frequency-changes** - Change pitch by altering frequency

**What you'll learn:** Wave mixing, filter composition, additive synthesis, pitch relationships

### 04-composer/

**Arranging sounds in time**

The Composer lets you sequence and layer multiple audio sources.

- **simple-sequence** - Create a simple melody by sequencing notes
- **overlapping-sounds** - Layer sounds on top of each other (polyphony)

**What you'll learn:** Using the Composer API, timing control, creating musical arrangements

### 05-practical-examples/

**Real-world instrument synthesis**

See how to combine techniques to create realistic instrument sounds.

- **guitar** - Karplus-Strong plucked string synthesis
- **drum** - Snare drum using noise + tone synthesis

**What you'll learn:** Physical modeling, combining noise and tones, percussion synthesis

### 06-advanced/

**Advanced techniques**

Ready for more? These examples show advanced lightmix features.

- **build-time-generation** - Generate audio files at compile-time during `zig build`
- **build-time-play** - Generate and play audio files directly at build-time with `zig build play`
- **runtime-play** - Play synthesized audio waveforms in real-time through standard audio output
- **modular-composing** - Organize complex audio projects with modular packages and custom synths

**What you'll learn:** Build system integration, build-time audio generation and playback, real-time audio playback, code organization with modular packages

## 🚀 How to Run Examples

Each example is a complete Zig project with its own `build.zig`. To run any example:

```bash
cd examples/01-getting-started/hello-wave
zig build run
```

Most examples write `result.wav` to the example directory. Some differ:

- `noise`, `frequency-changes` and `guitar` write several named files (for example `white_noise.wav`, `a4_original.wav` and `guitar_a2.wav`).
- `build-time-generation` and `modular-composing` write the file while building, to `zig-out/share/result.wav`.
- `build-time-play` and `runtime-play` play the audio instead of writing a file.

### Build-Time Generation

The `06-advanced/build-time-generation` example is special - it generates audio during the build:

```bash
cd examples/06-advanced/build-time-generation
zig build  # Note: just 'build', not 'build run'
```

## ⚠️ Important Notes

### Volume Warning

**Please check your volume before playing the generated WAV files!** The examples do not normalize or limit audio levels. Start with low volume and adjust as needed.

### Sample Rate

Most examples use 44100 Hz (CD quality), which is standard for audio files.

### File Formats

The examples that write WAV files use 16-bit PCM (`.bits = 16` with `.format_code = .pcm`), which is widely compatible. `.format_code = .ieee_float` (with `.bits = 32` or `64`) writes floating-point WAV files, but no example uses it. Most examples are mono (`.channels = 1`).

## 📖 Learning Path

We recommend following this order:

1. **Start with 01-getting-started/** - Get comfortable with the basics
1. **Explore 02-wave-basics/** - Understand different waveforms and their sounds
1. **Try 03-wave-operations/** - Learn to combine and transform waves
1. **Move to 04-composer/** - Start creating musical sequences
1. **Study 05-practical-examples/** - See real synthesis techniques in action
1. **Experiment with 06-advanced/** - Explore advanced features

## 🎵 Understanding the Code

Each example includes:

- **Detailed comments** explaining what the code does
- **Top-level documentation** (`//!`) describing the concept
- **Clear variable names** to make the code readable
- **Complete, runnable code** - no dependencies on other examples

## 🔊 Listening to Results

After generating WAV files, you can play them with:

- **Linux:** `aplay result.wav` or `ffplay result.wav`
- **macOS:** `afplay result.wav`
- **Windows:** `start result.wav` or use Windows Media Player
- **All platforms:** VLC, Audacity, or any audio player

## 🐛 Troubleshooting

**"Out of memory" errors:**

- The examples use `page_allocator` for simplicity
- For production code, consider using `GeneralPurposeAllocator` or an arena

**"File not found" errors:**

- Make sure you're in the example's directory when running `zig build run`
- Most examples create `result.wav` in the current working directory; see "How to Run Examples" for the ones that do not

**Build errors:**

- Ensure you're using a compatible Zig version (check the main README.md)
- Delete the build output with `rm -rf .zig-cache zig-out` and then run `zig build run` again (Zig has no `zig build clean` step)

## 📚 Further Learning

After working through these examples, check out:

- The main lightmix documentation in `src/root.zig`
- API documentation for Wave and Composer modules
- The test files `tests/wave.zig` and `tests/composer.zig` for more usage patterns (the `tests/build_*.zig` files are programs that `build.zig` runs, not usage examples)

## 🤝 Contributing

Found a bug in an example? Have an idea for a new example? Contributions are welcome! Please open an issue or pull request on the GitHub repository.
