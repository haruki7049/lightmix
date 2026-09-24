# Examples Directory - Quick Start Guide

## 🚀 Quick Start

**Complete beginners? Start here:**

```bash
cd examples/01-getting-started/hello-wave
zig build run
# Play the generated result.wav file
```

## 📚 Learning Path

Follow this recommended order:

1. **01-getting-started/** - Your first sounds (2 examples)

   - Start with `hello-wave` - creates a simple sine wave
   - Then try `using-filters` - learn audio transformations with a self-written filter

1. **02-wave-basics/** - Understanding different sounds (5 examples)

   - Try all five: sine, square, sawtooth, triangle, noise
   - Listen to how each one sounds different!

1. **03-wave-operations/** - Combining sounds (3 examples)

   - `mixing-waves` - create a musical chord
   - `filtering` - apply several self-written filters in sequence
   - `frequency-changes` - change pitch

1. **04-composer/** - Making music (2 examples)

   - `simple-sequence` - create a melody
   - `overlapping-sounds` - layer sounds

1. **05-practical-examples/** - Real instruments (2 examples)

   - `guitar` - realistic string sound
   - `drum` - percussion synthesis

1. **06-advanced/** - Advanced techniques (4 examples)

   - `build-time-generation` - compile-time audio
   - `build-time-play`
   - `modular-composing` - organize complex projects
   - `runtime-play`

## 🎵 Example Categories

```
📦 examples/
│
├── 🌱 01-getting-started     - Absolute beginner friendly
├── 🎼 02-wave-basics         - Basic waveforms & sounds  
├── 🔧 03-wave-operations     - Transform & combine audio
├── 🎹 04-composer            - Sequence & layer sounds
├── 🎸 05-practical-examples  - Real synthesis techniques
└── 🚀 06-advanced            - Advanced features
```

## 🛠️ Handy API Features

- **Channel Helpers (`to_mono`, `to_stereo`)**:
  - `wave.to_mono()`: Downmix multi-channel audio to mono (1 channel).
  - `wave.to_stereo(pan)`: Upmix mono audio to stereo (2 channels) with panning (`-1.0` hard left, `0.0` center, `1.0` hard right).
- **WAV Header Chunks (`WavOptions`)**:
  - Customize build-time WAV generation in `build.zig` via `addWave` options: `.use_fact = true`, `.use_peak = true`, and `.peak_timestamp = <epoch_seconds>` (use `l.currentTimestamp(b)` to stamp the current time).

## ⚠️ Important

- **CHECK YOUR VOLUME** before playing generated audio files!
- All examples create `result.wav` in their directory
- Format: 16-bit mono PCM @ 44.1kHz
- Each example focuses on ONE concept

## 🎧 Playing Audio

After running an example:

- **Linux:** `aplay result.wav`
- **macOS:** `afplay result.wav`
- **Windows:** `start result.wav`
- **All:** VLC, Audacity, or any audio player

## 📖 Full Documentation

See `examples/README.md` for complete details.

## 🐛 Issues?

If an example doesn't work:

1. Check you're in the example's directory
1. Try `zig build clean` then `zig build run`
1. Make sure you have a compatible Zig version

## 🎓 What Each Example Teaches

Every example includes:

- ✅ Detailed comments explaining the code
- ✅ Top-level documentation describing the concept
- ✅ Clear, readable variable names
- ✅ Complete, runnable code
