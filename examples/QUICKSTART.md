# Examples Directory - Quick Start Guide

## 🎯 What's New?

The examples have been reorganized into a clear, progressive learning structure!

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
   - Then try `using-filters` - learn audio transformations

2. **02-wave-basics/** - Understanding different sounds (5 examples)
   - Try all five: sine, square, sawtooth, triangle, noise
   - Listen to how each one sounds different!

3. **03-wave-operations/** - Combining sounds (3 examples)
   - `mixing-waves` - create a musical chord
   - `filtering` - chain effects
   - `frequency-changes` - change pitch

4. **04-composer/** - Making music (2 examples)
   - `simple-sequence` - create a melody
   - `overlapping-sounds` - layer sounds

5. **05-practical-examples/** - Real instruments (2 examples)
   - `guitar` - realistic string sound
   - `drum` - percussion synthesis

6. **06-advanced/** - Advanced techniques (2 examples)
   - `build-time-generation` - compile-time audio
   - `modular-architecture` - organize complex projects

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

📚 Legacy examples (Wave/, Composer/, etc.) preserved for reference
```

## ⚠️ Important

- **CHECK YOUR VOLUME** before playing generated audio files!
- All examples create `result.wav` in their directory
- Format: 16-bit mono PCM @ 44.1kHz
- Each example focuses on ONE concept

## 🎧 Playing Audio

After running an example:

**Linux:** `aplay result.wav`  
**macOS:** `afplay result.wav`  
**Windows:** `start result.wav`  
**All:** VLC, Audacity, or any audio player

## 📖 Full Documentation

See `examples/README.md` for complete details.

## 🐛 Issues?

If an example doesn't work:
1. Check you're in the example's directory
2. Try `zig build clean` then `zig build run`
3. Make sure you have a compatible Zig version

## 🎓 What Each Example Teaches

Every example includes:
- ✅ Detailed comments explaining the code
- ✅ Top-level documentation describing the concept
- ✅ Clear, readable variable names
- ✅ Complete, runnable code

Have fun learning audio programming! 🎵
