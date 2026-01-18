//! # Wave
//!
//! The Wave module provides a comprehensive interface for working with PCM audio data in Zig.
//! It represents audio waveforms as arrays of f32 samples, supporting various operations
//! such as mixing, filtering, and file I/O.
//!
//! ## Basic Usage
//!
//! Creating a Wave from raw PCM data:
//!
//! ```zig
//! const std = @import("std");
//! const lightmix = @import("lightmix");
//! const Wave = lightmix.Wave;
//!
//! const allocator = std.heap.page_allocator;
//! const samples: []const f32 = &[_]f32{ 0.0, 0.5, 1.0, 0.5, 0.0 };
//!
//! const wave = Wave.init(samples, allocator, .{
//!     .sample_rate = 44100,
//!     .channels = 1,
//! });
//! defer wave.deinit();
//! ```
//!
//! ## Loading from WAV file
//!
//! ```zig
//! const wave = Wave.from_file_content(
//!     .i16,
//!     @embedFile("./assets/sine.wav"),
//!     allocator
//! );
//! defer wave.deinit();
//! ```
//!
//! ## Mixing Waves
//!
//! ```zig
//! const samples1: []const f32 = &[_]f32{ 0.5, 0.3, 0.1 };
//! const samples2: []const f32 = &[_]f32{ 0.2, 0.4, 0.3 };
//!
//! const wave1 = Wave.init(samples1, allocator, .{ .sample_rate = 44100, .channels = 1 });
//! defer wave1.deinit();
//!
//! const wave2 = Wave.init(samples2, allocator, .{ .sample_rate = 44100, .channels = 1 });
//! defer wave2.deinit();
//!
//! const mixed = wave1.mix(wave2, .{});
//! defer mixed.deinit();
//! ```

const std = @import("std");
const zigggwavvv = @import("zigggwavvv");
const testing = std.testing;

const Self = @This();

/// A wave samples structure that holds PCM audio samples as an array of f32 values.
/// Each sample represents the amplitude at a specific point in time.
/// The samples is stored in interleaved format for multi-channel audio
/// (e.g., for stereo: L, R, L, R, ...).
samples: []const f64,

/// The allocator used to manage the wave's samples memory.
/// This allocator is responsible for both allocating and freeing the samples array.
allocator: std.mem.Allocator,

/// The sample rate in Hz (samples per second).
/// Common values are 44100 (CD quality), 48000 (professional audio), or 96000 (high-resolution audio).
sample_rate: u32,

/// The number of audio channels.
/// 1 = mono, 2 = stereo, 6 = 5.1 surround, etc.
channels: u16,

/// Options for initializing a Wave.
pub const Options = struct {
    /// Sample rate in Hz (samples per second)
    sample_rate: u32,
    /// Number of audio channels (1 = mono, 2 = stereo, etc.)
    channels: u16,
};

/// Initialize a Wave with wave samples (`[]const f32`).
///
/// This function creates a deep copy of the provided samples, so the original
/// samples can be safely modified or freed after initialization.
///
/// ## Parameters
/// - `samples`: The PCM audio samples as an array of f32 values (range: -1.0 to 1.0)
/// - `allocator`: The memory allocator to use for the wave's samples
/// - `options`: Configuration options including sample_rate and channels
///
/// ## Returns
/// A new Wave instance with ownership of a copy of the provided samples.
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     // Generate a simple sine wave
///     var samples: [44100]f32 = undefined;
///     for (0..samples.len) |i| {
///         const t = @as(f32, @floatFromInt(i)) / 44100.0;
///         samples[i] = @sin(t * 440.0 * 2.0 * std.math.pi);
///     }
///
///     const wave = Wave.init(&samples, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     });
///     defer wave.deinit();
/// }
/// ```
pub fn init(
    samples: []const f64,
    allocator: std.mem.Allocator,
    options: Options,
) Self {
    const owned_samples = allocator.alloc(f64, samples.len) catch @panic("Out of memory");
    @memcpy(owned_samples, samples);

    return Self{
        .samples = owned_samples,
        .allocator = allocator,

        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

/// Options for the mix operation.
pub const mixOptions = struct {
    /// Custom mixing function to combine two samples.
    /// The default implementation adds the two samples together.
    mixer: fn (f64, f64) f64 = default_mixing_expression,
};

/// Default mixing expression that adds two samples together.
/// This is the standard way to mix audio signals.
///
/// ## Parameters
/// - `left`: The first sample value
/// - `right`: The second sample value
///
/// ## Returns
/// The sum of the two samples
pub fn default_mixing_expression(left: f64, right: f64) f64 {
    const result: f64 = left + right;
    return result;
}

/// Mix a wave and another wave to create a combined output.
///
/// The waves must have the same length, sample_rate, and channels.
/// This constraint exists because timing alignment is application-specific
/// and cannot be automatically determined.
///
/// ## Parameters
/// - `self`: The first wave to mix
/// - `other`: The second wave to mix
/// - `options`: Mix options, including a custom mixer function if desired
///
/// ## Returns
/// A new Wave containing the mixed audio samples
///
/// ## Panics
/// - If the wave lengths, sample rates, or channels do not match
/// - If memory allocation fails
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     // Create two simple waves
///     const samples1: []const f32 = &[_]f32{ 0.5, 0.7, 0.3 };
///     const wave1 = Wave.init(samples1, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     });
///     defer wave1.deinit();
///
///     const samples2: []const f32 = &[_]f32{ 0.3, 0.2, 0.4 };
///     const wave2 = Wave.init(samples2, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     });
///     defer wave2.deinit();
///
///     // Mix them together
///     const mixed = wave1.mix(wave2, .{});
///     defer mixed.deinit();
///     // Result: [0.8, 0.9, 0.7]
/// }
/// ```
///
/// ## Custom Mixer Example
/// ```zig
/// // Use a custom mixing function for averaging instead of adding
/// fn average_mixer(left: f32, right: f32) f32 {
///     return (left + right) / 2.0;
/// }
///
/// const mixed = wave1.mix(wave2, .{ .mixer = average_mixer });
/// defer mixed.deinit();
/// ```
pub fn mix(self: Self, other: Self, options: mixOptions) Self {
    std.debug.assert(self.samples.len == other.samples.len);
    std.debug.assert(self.sample_rate == other.sample_rate);
    std.debug.assert(self.channels == other.channels);

    if (self.samples.len == 0)
        return Self{
            .samples = &[_]f64{},
            .allocator = self.allocator,

            .sample_rate = self.sample_rate,
            .channels = self.channels,
        };

    var samples: std.array_list.Aligned(f64, null) = .empty;

    for (0..self.samples.len) |i| {
        const left: f64 = self.samples[i];
        const right: f64 = other.samples[i];
        const result: f64 = options.mixer(left, right);

        samples.append(self.allocator, result) catch @panic("Out of memory");
    }

    const result: []const f64 = samples.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .samples = result,
        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

/// Replace the wave samples from a start position through the end of the wave with zeros.
///
/// This is useful for applying silence to the tail of a wave, creating fade-out effects,
/// or preparing buffers for further processing. The `end` parameter should match
/// the current length of the samples slice and is used for validation.
///
/// ## Parameters
/// - `self`: The wave to modify
/// - `start`: The starting sample index (inclusive)
/// - `end`: The expected total sample length (typically `self.samples.len`)
///
/// ## Returns
/// A new Wave with the specified region filled with zeros
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     const samples: []const f32 = &[_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
///     const wave = Wave.init(samples, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     });
///     defer wave.deinit();
///
///     // Fill from index 2 to 5 with zeros
///     const modified = try wave.fill_zero_to_end(2, 5);
///     defer modified.deinit();
///     // Result: [1.0, 2.0, 0.0, 0.0, 0.0]
/// }
/// ```
pub fn fill_zero_to_end(self: Self, start: usize, end: usize) !Self {
    // Initialization
    var result: std.array_list.Aligned(f64, null) = .empty;
    try result.appendSlice(self.allocator, self.samples);

    const delete_count: usize = result.items.len - start;

    for (0..delete_count) |_| {
        _ = result.pop();
    }

    std.debug.assert(start == result.items.len);

    for (delete_count..end) |_| {
        try result.append(self.allocator, 0.0);
    }

    std.debug.assert(result.items.len == end);

    return Self{
        .samples = try result.toOwnedSlice(self.allocator),
        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

/// Free the memory allocated for the Wave samples.
///
/// This function must be called when you're done using a Wave to prevent memory leaks.
/// It's recommended to use `defer wave.deinit()` immediately after creating a Wave.
///
/// ## Example
/// ```zig
/// const wave = Wave.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
/// defer wave.deinit(); // Automatically frees memory when scope exits
/// ```
pub fn deinit(self: Self) void {
    self.allocator.free(self.samples);
}

/// Create a Wave from WAV file binary samples.
///
/// This function can be used with Zig's `@embedFile` builtin to load
/// WAV files at compile time, or with runtime file samples.
///
/// ## Parameters
/// - `bit_type`: The bit depth of the WAV file (e.g., .i16, .i24, .f32)
/// - `content`: The raw binary content of the WAV file
/// - `allocator`: The memory allocator to use
///
/// ## Returns
/// A new Wave containing the decoded audio samples
///
/// ## Panics
/// - If the decoder cannot be created (invalid WAV format)
/// - If the bit type doesn't match the actual file bit depth
/// - If memory allocation fails
///
/// ## Example with Embedded File
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     // Load a WAV file at compile time
///     const wave = Wave.from_file_content(
///         .i16,
///         @embedFile("./assets/sine.wav"),
///         allocator
///     );
///     defer wave.deinit();
///
///     std.debug.print("Sample rate: {}\n", .{wave.sample_rate});
///     std.debug.print("Channels: {}\n", .{wave.channels});
///     std.debug.print("Samples: {}\n", .{wave.samples.len});
/// }
/// ```
///
/// ## Example with Runtime File
/// ```zig
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     // Read a WAV file at runtime
///     const file = try std.fs.cwd().openFile("audio.wav", .{});
///     defer file.close();
///
///     const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
///     defer allocator.free(content);
///
///     const wave = Wave.from_file_content(.i16, content, allocator);
///     defer wave.deinit();
/// }
/// ```
pub fn read(
    allocator: std.mem.Allocator,
    reader: anytype,
) anyerror!Self {
    const zigggwavvv_wave = try zigggwavvv.Wave(f64).read(allocator, reader);

    return Self{
        .samples = zigggwavvv_wave.samples,
        .allocator = allocator,
        .sample_rate = zigggwavvv_wave.sample_rate,
        .channels = zigggwavvv_wave.channels,
    };
}

/// Write the wave samples to a file in WAV format.
///
/// ## Parameters
/// - `self`: The wave to write
/// - `file`: An open file handle to write to
/// - `bits`: The bit depth to use for encoding (e.g., .i16, .i24, .f32)
///
/// ## Returns
/// An error if encoding or writing fails
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     // Create a wave
///     const samples: []const f32 = &[_]f32{ 0.0, 0.5, 1.0, 0.5, 0.0 };
///     const wave = Wave.init(samples, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     });
///     defer wave.deinit();
///
///     // Write to file
///     const file = try std.fs.cwd().createFile("output.wav", .{});
///     defer file.close();
///
///     try wave.write(file, .i16);
/// }
/// ```
pub fn write(self: Self, writer: anytype, options: WriteOptions) anyerror!void {
    const zigggwavvv_wave = zigggwavvv.Wave(f64).init(.{
        .format_code = options.format_code,
        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = options.bits,
        .samples = try options.allocator.dupe(f64, self.samples),
    });
    defer zigggwavvv_wave.deinit(options.allocator);

    try zigggwavvv_wave.write(writer, .{
        .allocator = options.allocator,
        .use_fact = options.use_fact,
        .use_peak = options.use_peak,
        .peak_timestamp = options.peak_timestamp,
    });
}

pub const WriteOptions = struct {
    allocator: std.mem.Allocator,
    use_fact: bool = false,
    use_peak: bool = false,
    peak_timestamp: u32 = 0,

    bits: u16,
    format_code: zigggwavvv.FormatCode,
};

/// Apply a filter function to the wave with custom arguments.
///
/// This function is useful for applying transformations that require additional parameters,
/// such as decay rates, gain adjustments, or frequency-specific operations.
///
/// **Important**: This function calls `self.deinit()` to free the original wave samples,
/// preventing memory leaks when chaining multiple filters.
///
/// ## Parameters
/// - `self`: The wave to filter (will be freed)
/// - `args_type`: The type of the arguments struct to pass to the filter function
/// - `filter_fn`: The filter function to apply
/// - `args`: The arguments to pass to the filter function
///
/// ## Returns
/// A new Wave with the filter applied
///
/// ## Panics
/// If the filter function returns an error
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// const GainArgs = struct {
///     gain: f32,
/// };
///
/// fn apply_gain(wave: Wave, args: GainArgs) !Wave {
///     var result: std.array_list.Aligned(f32, null) = .empty;
///
///     for (wave.samples) |sample| {
///         try result.append(wave.allocator, sample * args.gain);
///     }
///
///     return Wave{
///         .samples = try result.toOwnedSlice(wave.allocator),
///         .allocator = wave.allocator,
///         .sample_rate = wave.sample_rate,
///         .channels = wave.channels,
///     };
/// }
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     const samples: []const f32 = &[_]f32{ 1.0, 0.5, 0.25 };
///     const wave = Wave.init(samples, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     })
///         .filter_with(GainArgs, apply_gain, .{ .gain = 2.0 });
///     defer wave.deinit();
///     // Result: [2.0, 1.0, 0.5]
/// }
/// ```
pub fn filter_with(
    self: Self,
    comptime args_type: type,
    filter_fn: fn (self: Self, args: args_type) anyerror!Self,
    args: args_type,
) Self {
    // To destroy original samples array
    // If we don't do this, we may catch some memory leaks by not to free original samples array
    defer self.deinit();

    const result: Self = filter_fn(self, args) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter_with function...");
    };

    return result;
}

/// Apply a filter function to the wave without additional arguments.
///
/// This is a simpler version of `filter_with` for filters that don't need
/// extra parameters beyond the wave itself.
///
/// **Important**: This function calls `self.deinit()` to free the original wave samples,
/// preventing memory leaks when chaining multiple filters.
///
/// ## Parameters
/// - `self`: The wave to filter (will be freed)
/// - `filter_fn`: The filter function to apply
///
/// ## Returns
/// A new Wave with the filter applied
///
/// ## Panics
/// If the filter function returns an error
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const lightmix = @import("lightmix");
/// const Wave = lightmix.Wave;
///
/// fn normalize(wave: Wave) !Wave {
///     var max_val: f32 = 0.0;
///     for (wave.samples) |sample| {
///         max_val = @max(max_val, @abs(sample));
///     }
///
///     var result: std.array_list.Aligned(f32, null) = .empty;
///     for (wave.samples) |sample| {
///         const normalized = if (max_val > 0.0) sample / max_val else sample;
///         try result.append(wave.allocator, normalized);
///     }
///
///     return Wave{
///         .samples = try result.toOwnedSlice(wave.allocator),
///         .allocator = wave.allocator,
///         .sample_rate = wave.sample_rate,
///         .channels = wave.channels,
///     };
/// }
///
/// pub fn main() !void {
///     const allocator = std.heap.page_allocator;
///
///     const samples: []const f32 = &[_]f32{ 0.5, 1.0, 2.0, 1.5 };
///     const wave = Wave.init(samples, allocator, .{
///         .sample_rate = 44100,
///         .channels = 1,
///     })
///         .filter(normalize);
///     defer wave.deinit();
///     // Result: [0.25, 0.5, 1.0, 0.75]
/// }
/// ```
///
/// ## Chaining Filters Example
/// ```zig
/// const wave = Wave.init(samples, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// })
///     .filter(remove_dc_offset)
///     .filter(normalize)
///     .filter(apply_fade_in);
/// defer wave.deinit();
/// ```
pub fn filter(
    self: Self,
    filter_fn: fn (self: Self) anyerror!Self,
) Self {
    // To destroy original samples array
    // If we don't do this, we may catch some memory leaks by not to free original samples array
    defer self.deinit();

    const result: Self = filter_fn(self) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter function...");
    };

    return result;
}

test "read & deinit" {
    const allocator = testing.allocator;
    var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
    const wave = try Self.read(allocator, &reader);
    defer wave.deinit();

    try testing.expectEqual(wave.samples[0], 0.0);
    try testing.expectEqual(wave.samples[1], 0.05011139255958739);
    try testing.expectEqual(wave.samples[2], 0.1000396740623188);

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
}

test "init & deinit" {
    const allocator = testing.allocator;

    const generator = struct {
        fn sinewave() [44100]f64 {
            const sample_rate: f64 = 44100.0;
            const radins_per_sec: f64 = 440.0 * 2.0 * std.math.pi;

            var result: [44100]f64 = undefined;
            var i: usize = 0;

            while (i < result.len) : (i += 1) {
                result[i] = 0.5 * std.math.sin(@as(f64, @floatFromInt(i)) * radins_per_sec / sample_rate);
            }

            return result;
        }
    };

    const samples: [44100]f64 = generator.sinewave();
    const wave = Self.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
}

test "mix" {
    const allocator = testing.allocator;
    const generator = struct {
        fn sinewave() [44100]f64 {
            const sample_rate: f64 = 44100.0;
            const radins_per_sec: f64 = 440.0 * 2.0 * std.math.pi;

            var result: [44100]f64 = undefined;
            var i: usize = 0;

            while (i < result.len) : (i += 1) {
                result[i] = 0.5 * std.math.sin(@as(f64, @floatFromInt(i)) * radins_per_sec / sample_rate);
            }

            return result;
        }
    };

    const samples: [44100]f64 = generator.sinewave();
    const wave = Self.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const result: Self = wave.mix(wave, .{});
    defer result.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(result.samples[0], 0.0);
    try testing.expectEqual(result.samples[1], 0.06264832417874369);
    try testing.expectEqual(result.samples[2], 0.1250505236945281);
}

test "fill_zero_to_end" {
    const allocator = testing.allocator;
    const generator = struct {
        fn sinewave() [44100]f64 {
            const sample_rate: f64 = 44100.0;
            const radins_per_sec: f64 = 440.0 * 2.0 * std.math.pi;

            var result: [44100]f64 = undefined;
            var i: usize = 0;

            while (i < result.len) : (i += 1) {
                result[i] = 0.5 * std.math.sin(@as(f64, @floatFromInt(i)) * radins_per_sec / sample_rate);
            }

            return result;
        }
    };

    const samples: [44100]f64 = generator.sinewave();
    const wave = Self.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const filled_wave: Self = try wave.fill_zero_to_end(22050, 44100);
    defer filled_wave.deinit();

    try testing.expectEqual(filled_wave.sample_rate, 44100);
    try testing.expectEqual(filled_wave.channels, 1);

    try testing.expectEqual(filled_wave.samples[0], 0.0);
    try testing.expectEqual(filled_wave.samples[1], 0.031324162089371846);
    try testing.expectEqual(filled_wave.samples[2], 0.06252526184726405);

    try testing.expectEqual(filled_wave.samples[22049], -0.03132416208941618);
    try testing.expectEqual(filled_wave.samples[22050], 0.0);
    try testing.expectEqual(filled_wave.samples[22051], 0.0);
    try testing.expectEqual(filled_wave.samples[44099], 0.0);
}

test "filter_with" {
    const allocator = testing.allocator;
    const samples: []const f64 = &[_]f64{};
    const wave = Self.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    })
        .filter_with(ArgsForTesting, test_filter_with_args, .{ .samples = 3 });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(wave.samples.len, 3);
    try testing.expectEqual(wave.samples[0], 0.0);
    try testing.expectEqual(wave.samples[1], 0.0);
    try testing.expectEqual(wave.samples[2], 0.0);
}

fn test_filter_with_args(
    original_wave: Self,
    args: ArgsForTesting,
) !Self {
    var result: std.array_list.Aligned(f64, null) = .empty;

    for (0..args.samples) |_|
        try result.append(original_wave.allocator, 0.0);

    return Self{
        .samples = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

const ArgsForTesting = struct {
    samples: usize,
};

test "filter" {
    const allocator = testing.allocator;
    const samples: []const f64 = &[_]f64{};
    const wave = Self.init(samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    })
        .filter(test_filter_without_args);
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(wave.samples.len, 5);
    try testing.expectEqual(wave.samples[0], 0.0);
    try testing.expectEqual(wave.samples[1], 0.0);
    try testing.expectEqual(wave.samples[2], 0.0);
    try testing.expectEqual(wave.samples[3], 0.0);
    try testing.expectEqual(wave.samples[4], 0.0);
}

fn test_filter_without_args(original_wave: Self) !Self {
    var result: std.array_list.Aligned(f64, null) = .empty;

    for (0..5) |_|
        try result.append(original_wave.allocator, 0.0);

    return Self{
        .samples = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

test "filter memory leaks' check" {
    const allocator = testing.allocator;
    const samples: []const f64 = &[_]f64{};
    const wave = Self.init(samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    })
        .filter(test_filter_without_args)
        .filter(test_filter_without_args)
        .filter(test_filter_without_args)
        .filter(test_filter_without_args);
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(wave.samples.len, 5);
    try testing.expectEqual(wave.samples[0], 0.0);
    try testing.expectEqual(wave.samples[1], 0.0);
    try testing.expectEqual(wave.samples[2], 0.0);
    try testing.expectEqual(wave.samples[3], 0.0);
    try testing.expectEqual(wave.samples[4], 0.0);
}

test "init with empty samples" {
    const allocator = testing.allocator;
    const samples: []const f64 = &[_]f64{};
    const wave = Self.init(samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.samples.len, 0);
    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
}

test "init creates deep copy of samples" {
    const allocator = testing.allocator;
    var original_samples = [_]f64{ 1.0, 2.0, 3.0 };
    const wave = Self.init(&original_samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // Modify original samples
    original_samples[0] = 999.0;

    // Wave samples should be unchanged (deep copy was made)
    try testing.expectEqual(wave.samples[0], 1.0);
    try testing.expectEqual(wave.samples[1], 2.0);
    try testing.expectEqual(wave.samples[2], 3.0);
}

test "init with different channels" {
    const allocator = testing.allocator;
    const samples: []const f64 = &[_]f64{ 1.0, 2.0, 3.0, 4.0 };

    // Mono
    const wave_mono = Self.init(samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave_mono.deinit();
    try testing.expectEqual(wave_mono.channels, 1);

    // Stereo
    const wave_stereo = Self.init(samples, allocator, .{
        .sample_rate = 44100,
        .channels = 2,
    });
    defer wave_stereo.deinit();
    try testing.expectEqual(wave_stereo.channels, 2);
}

test "mix preserves wave properties" {
    const allocator = testing.allocator;
    const samples1: []const f64 = &[_]f64{ 1.0, 2.0, 3.0 };
    const samples2: []const f64 = &[_]f64{ 0.5, 1.0, 1.5 };

    const wave1 = Self.init(samples1, allocator, .{
        .sample_rate = 48000,
        .channels = 2,
    });
    defer wave1.deinit();

    const wave2 = Self.init(samples2, allocator, .{
        .sample_rate = 48000,
        .channels = 2,
    });
    defer wave2.deinit();

    const result = wave1.mix(wave2, .{});
    defer result.deinit();

    try testing.expectEqual(result.sample_rate, 48000);
    try testing.expectEqual(result.channels, 2);
    try testing.expectEqual(result.samples.len, 3);
    try testing.expectEqual(result.samples[0], 1.5);
    try testing.expectEqual(result.samples[1], 3.0);
    try testing.expectEqual(result.samples[2], 4.5);
}

test "read with different sample rates" {
    const allocator = testing.allocator;
    var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
    const wave = try Self.read(allocator, &reader);
    defer wave.deinit();

    // Verify the wave has valid properties
    try testing.expect(wave.sample_rate > 0);
    try testing.expect(wave.channels > 0);
    try testing.expect(wave.samples.len > 0);
}
