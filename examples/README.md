# lightmix Examples

This directory contains examples to help you learn audio programming with lightmix.

## 📚 New Examples Structure (Recommended)

We've reorganized the examples into a clear, educational progression:

### 01-getting-started/
**Perfect for first-time users** - Start here!
- `hello-wave` - Create your first sine wave
- `using-filters` - Learn to apply audio filters

### 02-wave-basics/
**Understanding fundamental waveforms**
- `sine-wave` - Pure tone generation
- `square-wave` - Buzzy, 8-bit style waves
- `sawtooth-wave` - Bright harmonic-rich waves
- `triangle-wave` - Mellow waveforms  
- `noise` - White, pink, and brown noise

### 03-wave-operations/
**Manipulating and combining waves**
- `mixing-waves` - Combine waves into chords
- `filtering` - Chain multiple filters
- `frequency-changes` - Pitch shifting

### 04-composer/
**Arranging sounds in time**
- `simple-sequence` - Create melodies
- `overlapping-sounds` - Layer sounds (polyphony)

### 05-practical-examples/
**Real-world synthesis**
- `guitar` - Karplus-Strong string synthesis
- `drum` - Snare drum synthesis

### 06-advanced/
**Advanced techniques**
- `build-time-generation` - Compile-time audio
- `modular-architecture` - Organize complex projects

## 🚀 How to Run Examples

Each example is a complete Zig project. Navigate to any example directory and run:

```bash
cd examples/01-getting-started/hello-wave
zig build run
```

This creates a `result.wav` file in that directory.

**⚠️ Please check your volume! The wave files are not normalized.**

## 📖 Learning Path

1. Start with **01-getting-started/** for the basics
2. Explore **02-wave-basics/** to understand different sounds
3. Try **03-wave-operations/** to learn transformations
4. Move to **04-composer/** for musical sequences
5. Study **05-practical-examples/** for real synthesis techniques
6. Experiment with **06-advanced/** for advanced features

## 📁 Legacy Examples

The original examples are still available for reference:
- `Wave/` - Various wave generation examples
- `Composer/` - Composer usage examples
- `drum/` - Drum synthesis
- `guitar/` - Guitar synthesis
- `advances/` - Advanced modular example

These are not actively maintained. The new structure above is recommended.
