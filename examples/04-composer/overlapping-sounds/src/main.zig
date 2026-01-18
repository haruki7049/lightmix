//! # Overlapping Sounds - Polyphony with Composer
//!
//! This example shows how to use Composer to create overlapping sounds,
//! simulating polyphonic music where multiple notes play simultaneously.
//!
//! ## What you'll learn:
//! - Creating overlapping audio with Composer
//! - Understanding polyphony vs monophony
//! - Building more complex arrangements

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;
const WaveInfo = Composer.WaveInfo;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const composer = Composer.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    // Create a longer sustaining note
    const long_c = generateLongNote(261.63, allocator);
    defer long_c.deinit();

    // Create shorter melody notes
    const e4 = generateNote(329.63, allocator);
    defer e4.deinit();
    const g4 = generateNote(392.00, allocator);
    defer g4.deinit();

    // Arrange with overlaps: bass note holds while melody plays
    var arrangement: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer arrangement.deinit(allocator);

    try arrangement.append(allocator, .{ .wave = long_c, .start_point = 0 });      // Bass starts at 0
    try arrangement.append(allocator, .{ .wave = e4, .start_point = 0 });          // Melody starts with bass
    try arrangement.append(allocator, .{ .wave = g4, .start_point = 22050 });      // Second melody note at 0.5s

    const composed = composer.appendSlice(arrangement.items);
    defer composed.deinit();

    const result = composed.finalize(.{});
    defer result.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try result.write(file, .i16);

    std.debug.print("✓ Created overlapping arrangement\n", .{});
}

fn generateNote(frequency: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;
    const num_samples: usize = 22050; // 0.5 seconds

    var samples_array: [22050]f32 = undefined;
    for (samples_array, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        const envelope = 1.0 - (t / 0.5);
        sample.* = 0.2 * @sin(radians_per_sec * t) * envelope;
    }

    return Wave.init(samples_array[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn generateLongNote(frequency: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;
    const num_samples: usize = 66150; // 1.5 seconds

    var samples_array: [66150]f32 = undefined;
    for (samples_array, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        const envelope = 1.0 - (t / 1.5);
        sample.* = 0.15 * @sin(radians_per_sec * t) * envelope;
    }

    return Wave.init(samples_array[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
