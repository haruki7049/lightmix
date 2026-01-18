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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const composer = Composer(f64).init(allocator, .{
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
    var arrangement: std.array_list.Aligned(Composer(f64).WaveInfo, null) = .empty;
    defer arrangement.deinit(allocator);

    try arrangement.append(allocator, .{ .wave = long_c, .start_point = 0 }); // Bass starts at 0
    try arrangement.append(allocator, .{ .wave = e4, .start_point = 0 }); // Melody starts with bass
    try arrangement.append(allocator, .{ .wave = g4, .start_point = 22050 }); // Second melody note at 0.5s

    const composed = composer.appendSlice(arrangement.items);
    defer composed.deinit();

    const result = composed.finalize(.{});
    defer result.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    try result.write(&writer.interface, .{
        .allocator = allocator,
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Created overlapping arrangement\n", .{});
}

fn generateNote(frequency: f64, allocator: std.mem.Allocator) Wave(f64) {
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [22050]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        const envelope = 1.0 - (t / 0.5);
        samples[i] = 0.2 * @sin(radians_per_sec * t) * envelope;
    }

    return Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn generateLongNote(frequency: f64, allocator: std.mem.Allocator) Wave(f64) {
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [66150]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        const envelope = 1.0 - (t / 1.5);
        samples[i] = 0.15 * @sin(radians_per_sec * t) * envelope;
    }

    return Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
