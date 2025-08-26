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

## Zig version

0.14.1
