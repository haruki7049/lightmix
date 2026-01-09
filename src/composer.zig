//! # Composer
//!
//! Composer is a powerful tool for combining multiple `Wave` objects with precise timing control.
//! It allows you to overlay, sequence, and mix audio waves at specific sample positions.
//!
//! ## Overview
//!
//! The Composer struct manages a collection of `WaveInfo` objects, each containing a `Wave`
//! and a start point that determines when the wave begins playing (measured in samples).
//! When finalized, all waves are mixed together into a single output `Wave`.
//!
//! ## Key Features
//!
//! - **Precise Timing**: Control exactly when each wave starts playing (sample-level accuracy)
//! - **Multiple Waves**: Combine unlimited number of waves
//! - **Automatic Padding**: Automatically pads waves with silence to align timing
//! - **Flexible Mixing**: Supports various mixing options through `Wave.mixOptions`
//!
//! ## Basic Usage
//!
//! ```zig
//! const std = @import("std");
//! const lightmix = @import("lightmix");
//! const Wave = lightmix.Wave;
//! const Composer = lightmix.Composer;
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!     const allocator = gpa.allocator();
//!
//!     // Create a composer with 44.1kHz sample rate and mono channel
//!     const composer = Composer.init(allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer composer.deinit();
//!
//!     // Create some wave data
//!     const data: []const f32 = &[_]f32{ 0.5, 0.3, 0.1, -0.1, -0.3, -0.5 };
//!     const wave = Wave.init(data, allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer wave.deinit();
//!
//!     // Add waves at different start points
//!     const composer2 = composer.append(.{ .wave = wave, .start_point = 0 });
//!     defer composer2.deinit();
//!     const composer3 = composer2.append(.{ .wave = wave, .start_point = 44100 });
//!     defer composer3.deinit();
//!
//!     // Finalize to create the mixed wave
//!     const result = composer3.finalize(.{});
//!     defer result.deinit();
//!
//!     // Write to file
//!     var file = try std.fs.cwd().createFile("output.wav", .{});
//!     defer file.close();
//!     try result.write(file, .i16);
//! }
//! ```
//!
//! ## Advanced Example: Creating a Melody
//!
//! ```zig
//! const std = @import("std");
//! const lightmix = @import("lightmix");
//! const Wave = lightmix.Wave;
//! const Composer = lightmix.Composer;
//! const WaveInfo = Composer.WaveInfo;
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!     const allocator = gpa.allocator();
//!
//!     // Generate tone waves at different frequencies
//!     const note_c = generateTone(261.63, 0.5, 44100, allocator); // C4
//!     defer note_c.deinit();
//!     const note_e = generateTone(329.63, 0.5, 44100, allocator); // E4
//!     defer note_e.deinit();
//!     const note_g = generateTone(392.00, 0.5, 44100, allocator); // G4
//!     defer note_g.deinit();
//!
//!     // Create composer
//!     const composer = Composer.init(allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer composer.deinit();
//!
//!     // Create a melody: C -> E -> G
//!     var notes = std.ArrayList(WaveInfo).init(allocator);
//!     defer notes.deinit();
//!     try notes.append(.{ .wave = note_c, .start_point = 0 });      // Start immediately
//!     try notes.append(.{ .wave = note_e, .start_point = 22050 });  // After 0.5 seconds
//!     try notes.append(.{ .wave = note_g, .start_point = 44100 });  // After 1.0 seconds
//!
//!     const composer2 = composer.appendSlice(notes.items);
//!     defer composer2.deinit();
//!
//!     // Finalize the composition
//!     const result = composer2.finalize(.{});
//!     defer result.deinit();
//! }
//!
//! fn generateTone(freq: f32, duration: f32, sample_rate: usize, allocator: std.mem.Allocator) Wave {
//!     const samples = @as(usize, @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate))));
//!     var data = allocator.alloc(f32, samples) catch @panic("Out of memory");
//!
//!     for (0..samples) |i| {
//!         const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
//!         data[i] = 0.5 * @sin(2.0 * std.math.pi * freq * t);
//!     }
//!
//!     return Wave.init(data, allocator, .{
//!         .sample_rate = sample_rate,
//!         .channels = 1,
//!     });
//! }
//! ```

const std = @import("std");
const lightmix_wav = @import("lightmix_wav");
const testing = std.testing;
const Wave = @import("./root.zig").Wave;

const Self = @This();

/// WaveInfo represents a single wave with its start position in the composition.
///
/// This struct pairs a `Wave` with a `start_point` that determines when the wave
/// begins playing in the final composition. The start_point is measured in samples,
/// so for a 44.1kHz sample rate, a start_point of 44100 means the wave starts
/// playing after 1 second.
///
/// ## Fields
///
/// - `wave`: The Wave object to be included in the composition
/// - `start_point`: The sample position where this wave should start (0-based)
///
/// ## Example
///
/// ```zig
/// const wave = Wave.init(data, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
///
/// // Play this wave starting at sample 0 (immediately)
/// const info1 = WaveInfo{ .wave = wave, .start_point = 0 };
///
/// // Play this wave starting at sample 44100 (after 1 second at 44.1kHz)
/// const info2 = WaveInfo{ .wave = wave, .start_point = 44100 };
///
/// // Play this wave starting at sample 22050 (after 0.5 seconds at 44.1kHz)
/// const info3 = WaveInfo{ .wave = wave, .start_point = 22050 };
/// ```
pub const WaveInfo = struct {
    wave: Wave,
    start_point: usize,

    fn to_wave(self: WaveInfo, allocator: std.mem.Allocator) Wave {
        var padding_data: []f128 = allocator.alloc(f128, self.start_point) catch @panic("Out of memory");

        for (0..padding_data.len) |i| {
            padding_data[i] = 0.0;
        }

        const slices: []const []const f128 = &[_][]const f128{ padding_data, self.wave.data };
        const data = std.mem.concat(allocator, f128, slices);

        const result: Wave = Wave.init(data, allocator, .{
            .sample_rate = self.wave.sample_rate,
            .channels = self.wave.channels,
        });

        return result;
    }
};

/// Array of WaveInfo objects that will be composed together.
info: []const WaveInfo,

/// Allocator used for memory management.
allocator: std.mem.Allocator,

/// Sample rate for the output wave (samples per second).
/// Common values: 44100 (CD quality), 48000 (professional audio), 22050, etc.
sample_rate: u32,

/// Number of audio channels in the output wave.
/// 1 = mono, 2 = stereo
channels: u16,

/// Configuration options for creating a Composer.
///
/// ## Example
///
/// ```zig
/// const options = Composer.Options{
///     .sample_rate = 44100,  // CD quality
///     .channels = 2,          // Stereo
/// };
/// ```
pub const initOptions = struct {
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
};

pub const initWithOptions = struct {
    info: []const WaveInfo,
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
};

/// Initialize a new empty Composer.
///
/// Creates a Composer with no waves. Use `append()` or `appendSlice()` to add waves.
/// Don't forget to call `deinit()` when done to free allocated memory.
///
/// ## Parameters
///
/// - `allocator`: Memory allocator for managing internal data structures
/// - `options`: Configuration specifying sample_rate and channels
///
/// ## Returns
///
/// A new Composer instance with no waves.
///
/// ## Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
/// const composer = Composer.init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// // Now add waves using append() or appendSlice()
/// ```
pub fn init(
    options: initOptions,
) Self {
    return Self{
        .info = &[_]WaveInfo{},
        .allocator = options.allocator,
        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

/// Free memory allocated by this Composer.
///
/// Call this when you're done with the Composer to prevent memory leaks.
/// This only frees the Composer's internal data structures, not the Wave objects
/// referenced by WaveInfo. You must call deinit() on those separately.
///
/// ## Example
///
/// ```zig
/// const composer = Composer.init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit(); // Automatically cleanup
/// ```
pub fn deinit(self: Self) void {
    self.allocator.free(self.info);
}

/// Initialize a Composer with an initial collection of WaveInfo objects.
///
/// This is convenient when you already have all your waves ready and want to
/// create a Composer in one step.
///
/// ## Parameters
///
/// - `info`: Slice of WaveInfo objects to include in the composition
/// - `allocator`: Memory allocator for managing internal data structures
/// - `options`: Configuration specifying sample_rate and channels
///
/// ## Returns
///
/// A new Composer instance containing the provided waves.
///
/// ## Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
///
/// // Create some waves
/// const wave1 = Wave.init(data1, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer wave1.deinit();
///
/// const wave2 = Wave.init(data2, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer wave2.deinit();
///
/// // Create composer with both waves
/// const info = &[_]WaveInfo{
///     .{ .wave = wave1, .start_point = 0 },
///     .{ .wave = wave2, .start_point = 22050 },
/// };
///
/// const composer = Composer.init_with(info, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// const result = composer.finalize(.{});
/// defer result.deinit();
/// ```
pub fn init_with(
    options: initWithOptions,
) Self {
    var list: std.array_list.Aligned(WaveInfo, null) = .empty;
    list.appendSlice(options.allocator, options.info) catch @panic("Out of memory");

    return Self{
        .info = list.toOwnedSlice(options.allocator) catch @panic("Out of memory"),
        .allocator = options.allocator,
        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

/// Add a single WaveInfo to the composition.
///
/// Creates a new Composer with the added wave. The original Composer remains unchanged.
/// Remember to call deinit() on the returned Composer.
///
/// ## Parameters
///
/// - `self`: The current Composer instance
/// - `waveinfo`: The WaveInfo to add to the composition
///
/// ## Returns
///
/// A new Composer instance with the added wave.
///
/// ## Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
/// const composer = Composer.init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// const wave = Wave.init(data, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer wave.deinit();
///
/// // Add wave at start
/// const composer2 = composer.append(.{ .wave = wave, .start_point = 0 });
/// defer composer2.deinit();
///
/// // Add same wave 1 second later
/// const composer3 = composer2.append(.{ .wave = wave, .start_point = 44100 });
/// defer composer3.deinit();
/// ```
pub fn append(self: Self, waveinfo: WaveInfo) Self {
    var d: std.array_list.Aligned(WaveInfo, null) = .empty;
    d.appendSlice(self.allocator, self.info) catch @panic("Out of memory");
    d.append(self.allocator, waveinfo) catch @panic("Out of memory");

    const result: []const WaveInfo = d.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .allocator = self.allocator,
        .info = result,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

/// Add multiple WaveInfo objects to the composition at once.
///
/// More efficient than calling append() multiple times. Creates a new Composer
/// with all the added waves. The original Composer remains unchanged.
///
/// ## Parameters
///
/// - `self`: The current Composer instance
/// - `append_list`: Slice of WaveInfo objects to add
///
/// ## Returns
///
/// A new Composer instance with all the added waves.
///
/// ## Example
///
/// ```zig
/// const allocator = std.heap.page_allocator;
/// const composer = Composer.init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// const wave = Wave.init(data, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer wave.deinit();
///
/// // Create array of wave infos
/// var wave_list = std.ArrayList(WaveInfo).init(allocator);
/// defer wave_list.deinit();
/// try wave_list.append(.{ .wave = wave, .start_point = 0 });
/// try wave_list.append(.{ .wave = wave, .start_point = 22050 });
/// try wave_list.append(.{ .wave = wave, .start_point = 44100 });
///
/// // Add all waves at once
/// const composer2 = composer.appendSlice(wave_list.items);
/// defer composer2.deinit();
/// ```
pub fn appendSlice(self: Self, append_list: []const WaveInfo) Self {
    var d: std.array_list.Aligned(WaveInfo, null) = .empty;
    d.appendSlice(self.allocator, self.info) catch @panic("Out of memory");
    d.appendSlice(self.allocator, append_list) catch @panic("Out of memory");

    const result: []const WaveInfo = d.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .allocator = self.allocator,
        .info = result,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

/// Finalize the composition and create the mixed output Wave.
///
/// This is the final step in the composition process. It:
/// 1. Calculates the total length needed for the output
/// 2. Pads each wave with silence to align timing
/// 3. Mixes all waves together using the specified options
/// 4. Returns the final composed Wave
///
/// The returned Wave must be freed with deinit() when done.
///
/// ## Parameters
///
/// - `self`: The Composer instance to finalize
/// - `options`: Wave.mixOptions controlling how waves are mixed together
///
/// ## Returns
///
/// A new Wave containing the mixed audio from all WaveInfo objects.
///
/// ## Example: Basic Finalization
///
/// ```zig
/// const composer = Composer.init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// // ... add waves ...
///
/// const result = composer.finalize(.{});
/// defer result.deinit();
///
/// // Write to file
/// var file = try std.fs.cwd().createFile("output.wav", .{});
/// defer file.close();
/// try result.write(file, .i16);
/// ```
///
/// ## Example: Layering Multiple Sounds
///
/// ```zig
/// // Create a drum beat with kick, snare, and hi-hat
/// const kick = generateKickDrum(allocator);
/// defer kick.deinit();
/// const snare = generateSnare(allocator);
/// defer snare.deinit();
/// const hihat = generateHiHat(allocator);
/// defer hihat.deinit();
///
/// const composer = Composer.init(allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer composer.deinit();
///
/// var beats = std.ArrayList(WaveInfo).init(allocator);
/// defer beats.deinit();
///
/// // Kick on beats 1 and 3
/// try beats.append(.{ .wave = kick, .start_point = 0 });
/// try beats.append(.{ .wave = kick, .start_point = 44100 });
///
/// // Snare on beats 2 and 4
/// try beats.append(.{ .wave = snare, .start_point = 22050 });
/// try beats.append(.{ .wave = snare, .start_point = 66150 });
///
/// // Hi-hat on every eighth note
/// for (0..8) |i| {
///     try beats.append(.{ .wave = hihat, .start_point = i * 11025 });
/// }
///
/// const composer2 = composer.appendSlice(beats.items);
/// defer composer2.deinit();
///
/// const drum_pattern = composer2.finalize(.{});
/// defer drum_pattern.deinit();
/// ```
pub fn finalize(self: Self, options: Wave.mixOptions) Wave {
    var end_point: usize = 0;

    // Calculate the length for emitted wave
    for (self.info) |waveinfo| {
        const ep = waveinfo.start_point + waveinfo.wave.data.len;

        if (end_point < ep)
            end_point = ep;
    }

    var padded_waveinfo_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer padded_waveinfo_list.deinit(self.allocator);

    // Filter each WaveInfo to append padding both of start and last
    for (self.info) |waveinfo| {
        const padded_at_start: []const f128 = padding_for_start(waveinfo.wave.data, waveinfo.start_point, self.allocator);
        defer self.allocator.free(padded_at_start);

        const padded_at_start_and_last: []const f128 = padding_for_last(padded_at_start, end_point, self.allocator);
        defer self.allocator.free(padded_at_start_and_last);

        const wave: Wave = Wave.init(.{
            .data = padded_at_start_and_last,
            .allocator = self.allocator,
            .sample_rate = self.sample_rate,
            .channels = self.channels,
        });

        const wi: WaveInfo = WaveInfo{
            .wave = wave,
            .start_point = waveinfo.start_point,
        };

        padded_waveinfo_list.append(self.allocator, wi) catch @panic("Out of memory");
    }

    const padded_waveinfo_slice: []const WaveInfo = padded_waveinfo_list.toOwnedSlice(self.allocator) catch @panic("Out of memory");
    defer self.allocator.free(padded_waveinfo_slice);

    const empty_data: []const f128 = generate_soundless_data(end_point, self.allocator);
    defer self.allocator.free(empty_data);

    var result: Wave = Wave.init(.{
        .data = empty_data,
        .allocator = self.allocator,
        .sample_rate = self.sample_rate,
        .channels = self.channels,
    });

    for (padded_waveinfo_slice) |waveinfo| {
        const wave = result.mix(waveinfo.wave, options);
        result.deinit();
        waveinfo.wave.deinit();
        result = wave;
    }

    return result;
}

/// Internal helper: Pad the start of wave data with silence.
///
/// Prepends `start_point` samples of silence (0.0) to the beginning of the data.
/// This is used to delay when a wave starts playing in the composition.
///
/// ## Parameters
///
/// - `data`: Original wave data
/// - `start_point`: Number of silent samples to prepend
/// - `allocator`: Allocator for the result
///
/// ## Returns
///
/// New slice with silence prepended. Caller must free.
fn padding_for_start(data: []const f128, start_point: usize, allocator: std.mem.Allocator) []const f128 {
    const padding_length: usize = start_point;
    var padding: std.array_list.Aligned(f128, null) = .empty;
    defer padding.deinit(allocator);

    // Append padding
    for (0..padding_length) |_|
        padding.append(allocator, 0.0) catch @panic("Out of memory");

    // Append data slice
    padding.appendSlice(allocator, data) catch @panic("Out of memory");

    const result: []const f128 = padding.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

/// Internal helper: Pad the end of wave data with silence.
///
/// Appends silence (0.0) to the end of the data to reach the specified end_point.
/// This ensures all waves have the same length before mixing.
///
/// ## Parameters
///
/// - `data`: Original wave data (already padded at start if needed)
/// - `end_point`: Target total length
/// - `allocator`: Allocator for the result
///
/// ## Returns
///
/// New slice with silence appended. Caller must free.
fn padding_for_last(data: []const f128, end_point: usize, allocator: std.mem.Allocator) []const f128 {
    std.debug.assert(data.len <= end_point);

    const padding_length: usize = end_point - data.len;
    var padding: std.array_list.Aligned(f128, null) = .empty;
    defer padding.deinit(allocator);

    // Append data slice
    padding.appendSlice(allocator, data) catch @panic("Out of memory");

    // Append padding
    for (0..padding_length) |_|
        padding.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f128 = padding.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

/// Internal helper: Generate an array of silent samples.
///
/// Creates a wave data array filled with zeros (silence) of the specified length.
/// Used as the base for mixing all waves together.
///
/// ## Parameters
///
/// - `length`: Number of samples to generate
/// - `allocator`: Allocator for the result
///
/// ## Returns
///
/// Slice of zeros with the specified length. Caller must free.
fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) []const f128 {
    var list: std.array_list.Aligned(f128, null) = .empty;
    defer list.deinit(allocator);

    // Append empty wave
    for (0..length) |_|
        list.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f128 = list.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

test "padding_for_start" {
    const allocator = testing.allocator;
    const data: []const f128 = &[_]f128{ 1.0, 1.0 };
    const start_point: usize = 10;

    const result: []const f128 = padding_for_start(data, start_point, allocator);
    defer allocator.free(result);

    try testing.expectEqual(data.len + start_point, result.len);

    const expected: []const f128 = &[_]f128{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0 };
    for (0..result.len) |i| {
        try testing.expectApproxEqAbs(expected[i], result[i], 0.001);
    }
}

test "init & deinit" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();
}

test "init_with & deinit" {
    const allocator = testing.allocator;

    var reader = std.Io.Reader.fixed(@embedFile("assets/sine.wav"));
    const wave = Wave.read(&reader, allocator);
    defer wave.deinit();

    const info: []const WaveInfo = &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } };

    const composer = Self.init_with(.{
        .info = info,
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();
}

test "append" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var reader = std.Io.Reader.fixed(@embedFile("assets/sine.wav"));
    const wave = Wave.read(&reader, allocator);
    defer wave.deinit();

    const appended_composer = composer.append(.{ .wave = wave, .start_point = 0 });
    defer appended_composer.deinit();

    try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{.{ .wave = wave, .start_point = 0 }});
}

test "appendSlice" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var reader = std.Io.Reader.fixed(@embedFile("assets/sine.wav"));
    const wave = Wave.read(&reader, allocator);
    defer wave.deinit();

    var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer append_list.deinit(allocator);
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });

    const appended_composer = composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } });
}

test "finalize" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var data: []f128 = try allocator.alloc(f128, 44100);
    defer allocator.free(data);

    for (0..data.len) |i| {
        data[i] = 1.0;
    }

    const wave = Wave.init(.{
        .data = data,
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer append_list.deinit(allocator);
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
    try append_list.append(allocator, .{ .wave = wave, .start_point = 44100 });

    const appended_composer = composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = appended_composer.finalize(.{});
    defer result.deinit();

    try testing.expectEqual(result.data.len, 88200);

    try testing.expectEqual(result.sample_rate, 44100);
    try testing.expectEqual(result.channels, 1);
}
