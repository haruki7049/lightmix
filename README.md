# lightmix

`lightmix` is an audio processing library written by Zig-lang.

## Why I create this

I created this project because I felt a disconnect between existing audio synthesis environments and the standard software development workflow I use every day.

- **From "Recording" to "Building"**:
  In many existing tools, exporting audio feels like a manual task. I often had to click a record button or write specific code to manage recording buffers, essentially capturing the output in real-time. I wanted a workflow where audio is treated as a build artifact—where running `zig build run` (or `zig build`) instantly produces a WAV file, just as it would a binary executable.
- **Integration with the Modern Toolchain**:
  I found it cumbersome to set up dedicated runtimes or specialized IDEs just to generate sound. I wanted to use my preferred editor and the standard Zig toolchain without any external dependencies or complex server setups.

**lightmix** is my attempt to bridge these two worlds. It allows me to "build" sound with the same precision, automation, and simplicity that I expect from any other software project.

## How to use

In `build.zig`, import lightmix from `build.zig.zon` using `b.dependency()`:

```zig
const lightmix = b.dependency("lightmix", .{});

const lib_mod = b.createModule(.{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .optimize = optimize,
});
lib_mod.addImport("lightmix", lightmix.module("lightmix")); // Add lightmix to your library or executable module.
```

You can find some examples in [./examples](./examples) directory. If you want to copy an example, edit `.lightmix = .{ .path = "../../.." }` in its `build.zig.zon`.

## Build-time Wave file generation

lightmix provides a helper function `addWaveInstallFile` in `build.zig` that allows you to generate and install Wave files during the build process.

### `createWave` function in `build.zig`

The `createWave` function is a build-time helper that allows you to generate Wave files as part of your build process. This means you can write a Zig function that generates audio, and the build system will automatically create the WAV file when you run `zig build`.

#### How to use `createWave`

1. First, create a module with a function that generates a Wave:

```zig
// In your src/root.zig or similar file
const std = @import("std");
const lightmix = @import("lightmix");

pub fn generate() !lightmix.Wave(f64) {
    const allocator = std.heap.page_allocator;

    // Generate your audio data (example: 1 second of silence)
    const data: [44100]f64 = [_]f64{0.0} ** 44100;

    // Wave.init() creates a deep copy of the data
    // The original data array can be safely discarded after this call
    const wave = try lightmix.Wave(f64).init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    return wave;
}
```

2. In your `build.zig`, use the `createWave` function:

```zig
const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});

    // Create your module that contains the wave generation function
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    // Use createWave to generate the wave file during build
    const wave_step = try l.createWave(b, mod, .{
        .func_name = "gen", // Name of your wave generation function (default is "gen")
        .wave = .{
            .name = "result.wav", // Output filename (optional, defaults to "result.wav")
            .format_code = .pcm, // Wave format code (e.g., .pcm, .ieee_float)
            .bits = 16, // The bits depth for this wave (e.g., 8, 16, 24, 32)
        },
        .path = .{ .custom = "share" }, // Install directory (optional, defaults to "share")
    });

    // Add to the install step so it runs during `zig build`
    b.getInstallStep().dependOn(wave_step);
}
```

3. Run `zig build` to generate the wave file. The file will be created in `zig-out/share/result.wav` (or your configured path).

#### `createWave` Options

- **`func_name`**: The name of the function in your module that generates the Wave. The function must have the signature `pub fn name() !lightmix.Wave(T)` where T is your chosen sample type (e.g., f64) (default: `"gen"`)
- **`path`**: The installation directory relative to the install prefix (default: `.{ .custom = "share" }`)
- **`wave.name`**: The output filename for the wave file (default: `"result.wav"`)
- **`wave.bits`**: The bit depth for the wave file, which is typed u16
- **`wave.format_code`**: Audio encoding format (e.g., .pcm, .ieee_float)

You can find a complete example in [./examples/Wave/generate_by_build_zig](./examples/Wave/generate_by_build_zig).

## lightmix's types

### `Wave`

`Wave` is a generic type function that accepts a sample type parameter. It contains PCM audio source with samples of the specified floating-point type.

**Supported sample types:** `f64`, `f80`, `f128`

⚠️ **Important Notes:**
- **`f32` is NOT supported** due to a limitation in the zigggwavvv 0.2.1 dependency
- `Wave.init()` creates a **deep copy** of the sample data - the caller retains ownership of the original samples
- The allocator passed to `init()` must remain valid for the entire lifetime of the Wave
- When mixing waves, both waves **must** have identical `sample_rate`, `channels`, and sample length, or the program will panic

```zig
const allocator = std.heap.page_allocator; // Use your allocator
const data: []const f64 = &[_]f64{ 0.0, 0.0, 0.0 }; // This array contains 3 float numbers, then this wave will be made from 3 samples.

const wave = try lightmix.Wave(f64).init(data, allocator, .{
    .sample_rate = 44100, // Samples per second.
    .channels = 1, // Channels for this Wave. If this wave has two channels, it means this wave is stereo.
});
defer wave.deinit(); // Wave samples are owned by the passed allocator, so you must free this wave.
```

You can write your `Wave` to a wave file, such as `result.wav`.

```zig
// First, create your Wave with a specific sample type
const wave = generate_wave(); // Returns a Wave(f64)

// Second, you must create a file, typed as `std.fs.File`.
var file = try std.fs.cwd().createFile("result.wav", .{});
defer file.close();

// Then, write down your wave!!
try wave.write(file.writer(), .{
    .allocator = allocator,
    .bits = 16, // Bit depth for the output file
    .format_code = .pcm, // Format code (e.g., .pcm or .ieee_float)
});
```

### `Composer`

`Composer` is a generic type function that accepts a sample type parameter (same as Wave). It contains a `Composer(T).WaveInfo` array, which contains a `Wave(T)` and the timing when it plays.

⚠️ **Important Notes:**
- `append()` and `appendSlice()` modify the Composer in-place
- `finalize()` creates temporary padded copies of all waves, which may use significant memory for large compositions
- All waves in a Composer must have the same `sample_rate` and `channels` as the Composer itself

**Example using `init()` and `append()`:**

```zig
const allocator = std.heap.page_allocator; // Use your allocator
const wave = generate_wave(); // Returns a Wave(f64)

const Composer = lightmix.Composer(f64);
var composer = Composer.init(allocator, .{
    .sample_rate = 44100, // Samples per second.
    .channels = 1, // Channels for the Wave. If this composer has two channels, it means the wave is stereo.
});
defer composer.deinit();

// Append waves at different time points (append modifies in-place)
try composer.append(.{ .wave = wave, .start_point = 0 });
try composer.append(.{ .wave = wave, .start_point = 44100 }); // Play same wave 1 second later

const result = try composer.finalize(.{}); // Finalize to create a Wave(f64)
defer result.deinit(); // Don't forget to free the Wave data.
```

**Example using `init_with()` for batch initialization:**

```zig
const allocator = std.heap.page_allocator; // Use your allocator
const wave = generate_wave(); // Returns a Wave(f64)

const Composer = lightmix.Composer(f64);
const info: []const Composer.WaveInfo = &[_]Composer.WaveInfo{
    .{ .wave = wave, .start_point = 0 },
    .{ .wave = wave, .start_point = 44100 },
};
const composer = try Composer.init_with(info, allocator, .{
    .sample_rate = 44100, // Samples per second.
    .channels = 1, // Channels for the Wave. If this composer has two channels, it means the wave is stereo.
});
defer composer.deinit(); // Composer.info is also owned by the passed allocator, so you must free this composer.

const result = try composer.finalize(.{}); // Let's finalize to create a Wave(f64)!!
defer result.deinit(); // Don't forget to free the Wave data.
```

## Common Patterns

### Creating Silence or Padding

```zig
// Method 1: Using fill_zero_to_end to add silence at the end
const wave = try Wave(f64).init(samples, allocator, .{
    .sample_rate = 44100,
    .channels = 1,
});
defer wave.deinit();

// Keep first 1 second, add 1 second of silence
const padded = try wave.fill_zero_to_end(44100, 88200);
defer padded.deinit();

// Method 2: Create pure silence
const silence_duration = 44100; // 1 second at 44.1kHz
var silent_samples = try allocator.alloc(f64, silence_duration);
defer allocator.free(silent_samples);
@memset(silent_samples, 0.0);

const silence = try Wave(f64).init(silent_samples, allocator, .{
    .sample_rate = 44100,
    .channels = 1,
});
defer silence.deinit();
```

### Custom Mixer Functions

By default, `mix()` adds samples together. You can provide a custom mixer function:

```zig
// Average two signals instead of adding them
fn averageMixer(left: f64, right: f64) f64 {
    return (left + right) / 2.0;
}

const mixed = try wave1.mix(wave2, .{ .mixer = averageMixer });
defer mixed.deinit();

// Multiplicative mixing (ring modulation)
fn multiplyMixer(left: f64, right: f64) f64 {
    return left * right;
}

const ring_mod = try wave1.mix(wave2, .{ .mixer = multiplyMixer });
defer ring_mod.deinit();
```

### Overlapping Waves in Composer

Create polyphonic or layered audio by starting waves at the same time:

```zig
var composer = Composer(f64).init(allocator, .{
    .sample_rate = 44100,
    .channels = 1,
});
defer composer.deinit();

// Play three notes simultaneously (chord)
try composer.append(.{ .wave = note_c, .start_point = 0 });
try composer.append(.{ .wave = note_e, .start_point = 0 });
try composer.append(.{ .wave = note_g, .start_point = 0 });

const chord = try composer.finalize(.{});
defer chord.deinit();
```

### When to Use Composer vs Manual Mix

**Use `Composer` when:**
- You need to sequence sounds at different time points
- You want to overlap multiple waves that start at different times
- You're creating musical arrangements or compositions

**Use `Wave.mix()` directly when:**
- Both waves start at the same time and have the same length
- You need custom mixing behavior (like ring modulation)
- You want more control over the mixing process
- Performance is critical (avoids Composer's padding overhead)

### Error Handling

```zig
const wave = Wave(f64).init(samples, allocator, .{
    .sample_rate = 44100,
    .channels = 1,
}) catch |err| {
    std.debug.print("Failed to create wave: {}\n", .{err});
    return err;
};
defer wave.deinit();

// Always check that waves are compatible before mixing
if (wave1.sample_rate != wave2.sample_rate or
    wave1.channels != wave2.channels or
    wave1.samples.len != wave2.samples.len) {
    std.debug.print("Waves are not compatible for mixing\n", .{});
    return error.IncompatibleWaves;
}

const mixed = try wave1.mix(wave2, .{});
defer mixed.deinit();
```

## Zig version

0.15.2

This project will follows Ziglang's minor version.

## API Documentations

https://haruki7049.github.io/lightmix
