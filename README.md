# lightmix

`lightmix` is an audio processing library written by Zig-lang.

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
    .bits = 16, // Bits for this wave.
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
try wave.write(file);
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
const composer: lightmix.Composer = Composer.init_with(info, allocator, .
    .sample_rate = 44100, // Samples per second.
    .channels = 1, // Channels for the Wave. If this composer have two channels, it means the wave is stereo.
    .bits = 16, // Bits for the wave.
});
defer composer.deinit(); // Composer.info is also owned data by passed allocator, then you must `free` this wave.

const wave: lightmix.Wave = composer.finalize(); // Let's finalize to create a `Wave`!!
defer wave.deinit(); // Don't forget to free the `Wave` data.
```

## Zig version

0.14.1
