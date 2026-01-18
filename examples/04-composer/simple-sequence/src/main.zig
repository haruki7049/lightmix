//! # Simple Sequence - Using Composer
//!
//! This example introduces the Composer, which allows you to arrange multiple
//! waves in time. We'll create a simple melody by sequencing sine waves.
//!
//! ## What you'll learn:
//! - How to use the Composer API
//! - Sequencing waves with start_point
//! - Creating simple melodies
//!
//! ## The melody:
//! We'll play C-D-E-C in sequence (first 4 notes of "Frère Jacques")

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;
const WaveInfo = Composer.WaveInfo;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create composer
    const composer = Composer.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    // Generate notes (quarter notes at 120 BPM = 0.5 seconds each)
    const c4 = generateNote(261.63, allocator); // C4
    defer c4.deinit();
    const d4 = generateNote(293.66, allocator); // D4
    defer d4.deinit();
    const e4 = generateNote(329.63, allocator); // E4
    defer e4.deinit();

    // Arrange notes in sequence
    var notes_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer notes_list.deinit(allocator);

    try notes_list.append(allocator, .{ .wave = c4, .start_point = 0 });      // 0.0s
    try notes_list.append(allocator, .{ .wave = d4, .start_point = 22050 });  // 0.5s
    try notes_list.append(allocator, .{ .wave = e4, .start_point = 44100 });  // 1.0s
    try notes_list.append(allocator, .{ .wave = c4, .start_point = 66150 });  // 1.5s

    const composed = composer.appendSlice(notes_list.items);
    defer composed.deinit();

    const result = composed.finalize(.{});
    defer result.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try result.write(file, .i16);

    std.debug.print("✓ Created simple melody: C-D-E-C\n", .{});
}

fn generateNote(frequency: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;
    const num_samples: usize = 22050; // 0.5 seconds

    var samples_array: [22050]f32 = undefined;
    for (samples_array, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        const envelope = 1.0 - (t / 0.5); // Simple decay
        sample.* = 0.3 * @sin(radians_per_sec * t) * envelope;
    }

    return Wave.init(samples_array[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
