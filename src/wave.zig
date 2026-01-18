const std = @import("std");
const zigggwavvv = @import("zigggwavvv");
const testing = std.testing;

/// Wave type function: Creates a Wave type for the specified sample type.
///
/// Wave represents audio waveform data with methods for manipulation, mixing, and I/O.
///
/// ## Type Parameter
/// - `T`: The sample data type (typically f64, f80, or f128 for floating-point audio)
///
/// ## Usage
/// ```zig
/// const Wave = lightmix.Wave;
/// const wave = Wave(f64).init(samples, allocator, .{
///     .sample_rate = 44100,
///     .channels = 1,
/// });
/// defer wave.deinit();
/// ```
pub fn inner(comptime T: type) type {
    return struct {
        const Self = @This();

        samples: []const T,
        allocator: std.mem.Allocator,
        sample_rate: u32,
        channels: u16,

        /// Options for initializing a Wave instance.
        pub const InitOptions = struct {
            sample_rate: u32,
            channels: u16,
        };

        /// Creates a new Wave instance from the provided sample data.
        ///
        /// The function creates a deep copy of the sample data, so the caller
        /// retains ownership of the original samples slice.
        ///
        /// ## Parameters
        /// - `samples`: Slice of sample data to copy
        /// - `allocator`: Memory allocator for internal allocations
        /// - `options`: Initialization options (sample rate and channel count)
        ///
        /// ## Returns
        /// A new Wave instance containing a copy of the sample data
        pub fn init(
            samples: []const T,
            allocator: std.mem.Allocator,
            options: InitOptions,
        ) Self {
            const owned_samples = allocator.alloc(T, samples.len) catch @panic("Out of memory");
            @memcpy(owned_samples, samples);

            return Self{
                .samples = owned_samples,
                .allocator = allocator,

                .sample_rate = options.sample_rate,
                .channels = options.channels,
            };
        }

        /// Options for mixing two waves together.
        pub const mixOptions = struct {
            mixer: fn (T, T) T = default_mixing_expression,
        };

        /// Default mixing function that adds two samples together.
        ///
        /// ## Parameters
        /// - `left`: Sample value from the first wave
        /// - `right`: Sample value from the second wave
        ///
        /// ## Returns
        /// The sum of the two sample values
        pub fn default_mixing_expression(left: T, right: T) T {
            const result: T = left + right;
            return result;
        }

        /// Mixes this wave with another wave, combining their samples.
        ///
        /// Both waves must have the same length, sample rate, and channel count.
        /// The mixing is performed sample-by-sample using the provided mixer function.
        ///
        /// ## Parameters
        /// - `self`: The first wave to mix
        /// - `other`: The second wave to mix
        /// - `options`: Mixing options (includes the mixer function)
        ///
        /// ## Returns
        /// A new Wave containing the mixed result
        ///
        /// ## Panics
        /// Panics if the waves have different lengths, sample rates, or channel counts
        pub fn mix(self: Self, other: Self, options: mixOptions) Self {
            std.debug.assert(self.samples.len == other.samples.len);
            std.debug.assert(self.sample_rate == other.sample_rate);
            std.debug.assert(self.channels == other.channels);

            if (self.samples.len == 0)
                return Self{
                    .samples = &[_]T{},
                    .allocator = self.allocator,

                    .sample_rate = self.sample_rate,
                    .channels = self.channels,
                };

            var samples: std.array_list.Aligned(T, null) = .empty;

            for (0..self.samples.len) |i| {
                const left: T = self.samples[i];
                const right: T = other.samples[i];
                const result: T = options.mixer(left, right);

                samples.append(self.allocator, result) catch @panic("Out of memory");
            }

            const result: []const T = samples.toOwnedSlice(self.allocator) catch @panic("Out of memory");

            return Self{
                .samples = result,
                .allocator = self.allocator,

                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };
        }

        /// Truncates the wave at a start point and fills with zeros to the end point.
        ///
        /// This is useful for creating silence or padding at the end of a wave.
        ///
        /// ## Parameters
        /// - `self`: The wave to modify
        /// - `start`: Sample index where truncation begins
        /// - `end`: Sample index where the new wave ends (filled with zeros)
        ///
        /// ## Returns
        /// A new Wave with samples from 0 to `start`, then zeros from `start` to `end`
        pub fn fill_zero_to_end(self: Self, start: usize, end: usize) !Self {
            // Initialization
            var result: std.array_list.Aligned(T, null) = .empty;
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
        /// Frees the memory allocated for the wave's sample data.
        ///
        /// This must be called when you're done with a Wave instance to avoid memory leaks.
        pub fn deinit(self: Self) void {
            self.allocator.free(self.samples);
        }

        /// Reads wave data from a WAV file reader.
        ///
        /// ## Parameters
        /// - `allocator`: Memory allocator for sample data
        /// - `reader`: A reader interface for reading WAV file data
        ///
        /// ## Returns
        /// A new Wave instance containing the audio data from the file
        ///
        /// ## Errors
        /// Returns errors from the underlying WAV parser or allocation failures
        pub fn read(
            allocator: std.mem.Allocator,
            reader: anytype,
        ) anyerror!Self {
            const zigggwavvv_wave = try zigggwavvv.Wave(T).read(allocator, reader);

            return Self{
                .samples = zigggwavvv_wave.samples,
                .allocator = allocator,
                .sample_rate = zigggwavvv_wave.sample_rate,
                .channels = zigggwavvv_wave.channels,
            };
        }
        /// Writes wave data to a WAV file writer.
        ///
        /// ## Parameters
        /// - `self`: The wave to write
        /// - `writer`: A writer interface for writing WAV file data
        /// - `options`: Write options (format, bits per sample, etc.)
        ///
        /// ## Errors
        /// Returns errors from the underlying WAV writer or I/O failures
        pub fn write(self: Self, writer: anytype, options: WriteOptions) anyerror!void {
            const zigggwavvv_wave = zigggwavvv.Wave(T).init(.{
                .format_code = options.format_code,
                .sample_rate = self.sample_rate,
                .channels = self.channels,
                .bits = options.bits,
                .samples = try options.allocator.dupe(T, self.samples),
            });
            defer zigggwavvv_wave.deinit(options.allocator);

            try zigggwavvv_wave.write(writer, .{
                .allocator = options.allocator,
                .use_fact = options.use_fact,
                .use_peak = options.use_peak,
                .peak_timestamp = options.peak_timestamp,
            });
        }

        /// Options for writing wave data to a file.
        pub const WriteOptions = struct {
            allocator: std.mem.Allocator,
            use_fact: bool = false,
            use_peak: bool = false,
            peak_timestamp: u32 = 0,

            bits: u16,
            format_code: zigggwavvv.FormatCode,
        };

        /// Applies a filter function with custom arguments to the wave.
        ///
        /// The original wave is automatically freed after the filter is applied.
        /// This enables chaining multiple filters together efficiently.
        ///
        /// ## Parameters
        /// - `self`: The wave to filter (will be freed after filtering)
        /// - `args_type`: The type of the arguments to pass to the filter function
        /// - `filter_fn`: The filter function to apply
        /// - `args`: Arguments to pass to the filter function
        ///
        /// ## Returns
        /// A new Wave containing the filtered result
        ///
        /// ## Panics
        /// Panics if the filter function returns an error
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

        /// Applies a filter function to the wave.
        ///
        /// The original wave is automatically freed after the filter is applied.
        /// This enables chaining multiple filters together efficiently.
        ///
        /// ## Parameters
        /// - `self`: The wave to filter (will be freed after filtering)
        /// - `filter_fn`: The filter function to apply
        ///
        /// ## Returns
        /// A new Wave containing the filtered result
        ///
        /// ## Panics
        /// Panics if the filter function returns an error
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

            try testing.expectApproxEqAbs(wave.samples[0], 0.0, 0.00001);
            try testing.expectApproxEqAbs(wave.samples[1], 0.05011139255958739, 0.00001);
            try testing.expectApproxEqAbs(wave.samples[2], 0.1000396740623188, 0.00001);

            try testing.expectEqual(wave.sample_rate, 44100);
            try testing.expectEqual(wave.channels, 1);
        }

        test "init & deinit" {
            const allocator = testing.allocator;

            const generator = struct {
                fn sinewave() [44100]T {
                    const sample_rate: T = 44100.0;
                    const radins_per_sec: T = 440.0 * 2.0 * std.math.pi;

                    var result: [44100]T = undefined;
                    var i: usize = 0;

                    while (i < result.len) : (i += 1) {
                        result[i] = 0.5 * std.math.sin(@as(T, @floatFromInt(i)) * radins_per_sec / sample_rate);
                    }

                    return result;
                }
            };

            const samples: [44100]T = generator.sinewave();
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
                fn sinewave() [44100]T {
                    const sample_rate: T = 44100.0;
                    const radins_per_sec: T = 440.0 * 2.0 * std.math.pi;

                    var result: [44100]T = undefined;
                    var i: usize = 0;

                    while (i < result.len) : (i += 1) {
                        result[i] = 0.5 * std.math.sin(@as(T, @floatFromInt(i)) * radins_per_sec / sample_rate);
                    }

                    return result;
                }
            };

            const samples: [44100]T = generator.sinewave();
            const wave = Self.init(samples[0..], allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            const result: Self = wave.mix(wave, .{});
            defer result.deinit();

            try testing.expectEqual(wave.sample_rate, 44100);
            try testing.expectEqual(wave.channels, 1);

            try testing.expectApproxEqAbs(result.samples[0], 0.0, 0.00001);
            try testing.expectApproxEqAbs(result.samples[1], 0.06264832417874369, 0.00001);
            try testing.expectApproxEqAbs(result.samples[2], 0.1250505236945281, 0.00001);
        }

        test "fill_zero_to_end" {
            const allocator = testing.allocator;
            const generator = struct {
                fn sinewave() [44100]T {
                    const sample_rate: T = 44100.0;
                    const radins_per_sec: T = 440.0 * 2.0 * std.math.pi;

                    var result: [44100]T = undefined;
                    var i: usize = 0;

                    while (i < result.len) : (i += 1) {
                        result[i] = 0.5 * std.math.sin(@as(T, @floatFromInt(i)) * radins_per_sec / sample_rate);
                    }

                    return result;
                }
            };

            const samples: [44100]T = generator.sinewave();
            const wave = Self.init(samples[0..], allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            const filled_wave: Self = try wave.fill_zero_to_end(22050, 44100);
            defer filled_wave.deinit();

            try testing.expectEqual(filled_wave.sample_rate, 44100);
            try testing.expectEqual(filled_wave.channels, 1);

            try testing.expectApproxEqAbs(filled_wave.samples[0], 0.0, 0.00001);
            try testing.expectApproxEqAbs(filled_wave.samples[1], 0.031324162089371846, 0.00001);
            try testing.expectApproxEqAbs(filled_wave.samples[2], 0.06252526184726405, 0.00001);

            try testing.expectApproxEqAbs(filled_wave.samples[22049], -0.03132416208941618, 0.00001);
            try testing.expectApproxEqAbs(filled_wave.samples[22050], 0.0, 0.00001);
            try testing.expectApproxEqAbs(filled_wave.samples[22051], 0.0, 0.00001);
            try testing.expectApproxEqAbs(filled_wave.samples[44099], 0.0, 0.00001);
        }

        test "filter_with" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{};
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
            var result: std.array_list.Aligned(T, null) = .empty;

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
            const samples: []const T = &[_]T{};
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
            var result: std.array_list.Aligned(T, null) = .empty;

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
            const samples: []const T = &[_]T{};
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
            const samples: []const T = &[_]T{};
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
            var original_samples = [_]T{ 1.0, 2.0, 3.0 };
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
            const samples: []const T = &[_]T{ 1.0, 2.0, 3.0, 4.0 };

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
            const samples1: []const T = &[_]T{ 1.0, 2.0, 3.0 };
            const samples2: []const T = &[_]T{ 0.5, 1.0, 1.5 };

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
    };
}

test "Run tests for each samples' type" {
    _ = inner(f128);
    _ = inner(f80);
    _ = inner(f64);
    // _ = inner(f32); zigggwavvv 0.2.1 cannot use f32 as samples' type
}
