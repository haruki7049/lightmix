# lightmix

`lightmix` is an audio processing library written by Zig-lang.

## Why I create this

I created this project because I felt a disconnect between existing audio synthesis environments and the standard software development workflow I use every day.

- **From "Recording" to "Building"**:
  In many existing tools, exporting audio feels like a manual task. I often had to click a record button or write specific code to manage recording buffers, essentially capturing the output in real-time. I wanted a workflow where audio is treated as a build artifact—where running `zig build` (or `zig build run`) instantly produces a WAV file, just as it would a binary executable.
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

You can find some examples in [./examples](./examples) directory. If you want to copy a example, edit `.lightmix = .{ .path = "../../.." }` on it's `build.zig.zon`.

## lightmix's types

### `Wave`

Contains a PCM audio source.

```zig
const allocator = std.heap.page_allocator; // Use your allocator
const data: []const f32 = &[_]{ 0.0, 0.0, 0.0 }; // This array contains 3 float number, then this wave will make from 3 samples.

const wave: lightmix.Wave = Wave.init(data, allocator, .{
    .sample_rate = 44100, // Samples per second.
    .channels = 1, // Channels for this Wave. If this wave have two channels, it means this wave is stereo.
});
defer wave.deinit(); // Wave.data is owned data by passed allocator, then you must `free` this wave.
```

You can write your `Wave` to your wave file, such as `result.wav`.

```zig
// First, create your `Wave`.
const wave: lightmix.Wave = generate_wave();

// Second, you must create a file, typed as `std.fs.File`.
var file = try std.fs.cwd().createFile("result.wav", .{});
defer file.close();

// Then, write down your wave!!
try wave.write(file, .i16);
```

### `Composer`

Contains a `Composer.WaveInfo` array, which contains a `Wave` and the timing when it plays.

```zig
const allocator = std.heap.page_allocator; // Use your allocator
const wave: lightmix.Wave = generate_wave();

const info: []const lightmix.Composer.WaveInfo = &[_]WaveInfo{
    .{ .wave = wave, .start_point = 0 },
    .{ .wave = wave, .start_point = 44100 },
};
const composer: lightmix.Composer = Composer.init_with(info, allocator, .{
    .sample_rate = 44100, // Samples per second.
    .channels = 1, // Channels for the Wave. If this composer have two channels, it means the wave is stereo.
});
defer composer.deinit(); // Composer.info is also owned data by passed allocator, then you must `free` this wave.

const wave: lightmix.Wave = composer.finalize(); // Let's finalize to create a `Wave`!!
defer wave.deinit(); // Don't forget to free the `Wave` data.
```

## Zig version

0.15.2

This project will follows Ziglang's minor version.

## API Documentations

https://haruki7049.github.io/lightmix
