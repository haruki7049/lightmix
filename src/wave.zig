const std = @import("std");
const zigggwavvv = @import("zigggwavvv");
const zaudio = @import("zaudio");
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

        /// Supported audio file formats for reading wave data.
        pub const LowLevelInterfaces = enum {
            wav,

            /// Reads wave data using the specified file format.
            ///
            /// ## Parameters
            /// - `self`: The file format to use for decoding
            /// - `allocator`: Memory allocator for sample data
            /// - `reader`: A reader interface providing the raw file bytes
            ///
            /// ## Returns
            /// A `LowLevelWave` containing the decoded samples, sample rate, and channel count
            ///
            /// ## Errors
            /// Returns errors from the underlying format decoder or allocation failures
            pub fn read(self: LowLevelInterfaces, allocator: std.mem.Allocator, reader: anytype) anyerror!LowLevelWave {
                return switch (self) {
                    .wav => {
                        const v = try zigggwavvv.Wave(T).read(allocator, reader);

                        return .{
                            .samples = v.samples,
                            .sample_rate = v.sample_rate,
                            .channels = v.channels,
                        };
                    },
                };
            }

            /// Writes wave data using the specified file format.
            ///
            /// ## Parameters
            /// - `self`: The file format to use for encoding
            /// - `wave`: The wave instance to write
            /// - `writer`: A writer interface for the output bytes
            /// - `options`: Format-specific write options (see `writeOptions`)
            ///
            /// ## Errors
            /// Returns errors from the underlying format encoder or I/O failures
            pub fn write(self: LowLevelInterfaces, wave: Self, writer: anytype, options: writeOptions(self)) anyerror!void {
                switch (self) {
                    .wav => {
                        const zigggwavvv_wave = zigggwavvv.Wave(T).init(.{
                            .format_code = options.format_code,
                            .sample_rate = wave.sample_rate,
                            .channels = wave.channels,
                            .bits = options.bits,
                            .samples = try wave.allocator.dupe(T, wave.samples),
                        });
                        defer zigggwavvv_wave.deinit(wave.allocator);

                        try zigggwavvv_wave.write(writer, .{
                            .allocator = wave.allocator,
                            .use_fact = options.use_fact,
                            .use_peak = options.use_peak,
                            .peak_timestamp = options.peak_timestamp,
                        });
                    },
                }
            }

            /// Returns the format-specific options type for `write`.
            ///
            /// ## Parameters
            /// - `interface`: The file format whose options type to return
            ///
            /// ## Returns
            /// The options struct type corresponding to the given format
            pub fn writeOptions(interface: LowLevelInterfaces) type {
                return switch (interface) {
                    .wav => writeWavOptions,
                };
            }

            /// Options for writing wave data to a WAV file.
            pub const writeWavOptions = struct {
                /// Whether to include a `fact` chunk in the output file
                use_fact: bool = false,
                /// Whether to include a `PEAK` chunk in the output file
                use_peak: bool = false,
                /// Timestamp value written into the `PEAK` chunk (only used when `use_peak` is true)
                peak_timestamp: u32 = 0,

                /// Bits per sample (e.g. 16 or 24)
                bits: u16,
                /// Audio format code (e.g. PCM or IEEE float)
                format_code: zigggwavvv.FormatCode,
            };

            /// Calculates the binary file size (in bytes) when writing wave data using the specified format.
            ///
            /// ## Parameters
            /// - `self`: The file format to use (e.g. `.wav`)
            /// - `wave`: The wave instance to measure
            /// - `options`: Format-specific size options (see `sizeOptions`)
            ///
            /// ## Returns
            /// The total binary file size in bytes
            pub fn size(self: LowLevelInterfaces, wave: Self, options: sizeOptions(self)) usize {
                return switch (self) {
                    .wav => {
                        const bytes_per_sample = (@as(usize, options.bits) + 7) / 8;
                        const header_size: usize = 44;
                        return header_size + (wave.samples.len * bytes_per_sample);
                    },
                };
            }

            /// Returns the format-specific options type for `size`.
            ///
            /// ## Parameters
            /// - `interface`: The file format whose options type to return
            ///
            /// ## Returns
            /// The options struct type corresponding to the given format
            pub fn sizeOptions(interface: LowLevelInterfaces) type {
                return switch (interface) {
                    .wav => sizeWavOptions,
                };
            }

            /// Options for calculating binary file size of WAV wave data.
            pub const sizeWavOptions = struct {
                /// Bits per sample (e.g. 16 or 24)
                bits: u16,
            };

            /// Raw wave data returned by low-level format decoders.
            pub const LowLevelWave = struct {
                samples: []const T,
                sample_rate: u32,
                channels: u16,
            };
        };

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
        ///
        /// ## Errors
        /// - Allocator error (errors.OutOfMemory)
        pub fn init(
            samples: []const T,
            allocator: std.mem.Allocator,
            options: InitOptions,
        ) std.mem.Allocator.Error!Self {
            const owned_samples = try allocator.alloc(T, samples.len);
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

        /// Saturating mixing function that adds two samples and clamps the result to [-1.0, 1.0].
        ///
        /// ## Parameters
        /// - `left`: Sample value from the first wave
        /// - `right`: Sample value from the second wave
        ///
        /// ## Returns
        /// The clamped sum of the sample values in [-1.0, 1.0]
        pub fn saturating_mixing_expression(left: T, right: T) T {
            const sum: T = left + right;
            return std.math.clamp(sum, -1.0, 1.0);
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
        /// ## Errors
        /// - `MismatchedWaveProperties`: If the waves have different lengths, sample rates, or channel counts
        /// - `OutOfMemory`: Allocator error when memory allocation fails
        pub fn mix(self: Self, other: Self, options: mixOptions) (MixErrors || std.mem.Allocator.Error)!Self {
            if (self.samples.len != other.samples.len or
                self.sample_rate != other.sample_rate or
                self.channels != other.channels)
            {
                return error.MismatchedWaveProperties;
            }

            if (self.samples.len == 0)
                return Self{
                    .samples = &[_]T{},
                    .allocator = self.allocator,

                    .sample_rate = self.sample_rate,
                    .channels = self.channels,
                };

            const result_samples = try self.allocator.alloc(T, self.samples.len);
            errdefer self.allocator.free(result_samples);

            for (0..self.samples.len) |i| {
                result_samples[i] = options.mixer(self.samples[i], other.samples[i]);
            }

            return Self{
                .samples = result_samples,
                .allocator = self.allocator,

                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };
        }

        /// Normalizes wave samples so the peak absolute amplitude equals `target_peak`.
        ///
        /// ## Parameters
        /// - `self`: The wave to normalize
        /// - `target_peak`: The desired peak amplitude (typically 1.0)
        ///
        /// ## Returns
        /// A new Wave with normalized samples
        pub fn normalize(self: Self, target_peak: T) std.mem.Allocator.Error!Self {
            var max_amp: T = 0.0;
            for (self.samples) |sample| {
                const abs_s = @abs(sample);
                if (abs_s > max_amp) max_amp = abs_s;
            }

            const new_samples = try self.allocator.alloc(T, self.samples.len);
            errdefer self.allocator.free(new_samples);

            if (max_amp == 0.0) {
                @memset(new_samples, 0.0);
            } else {
                const scale = target_peak / max_amp;
                for (self.samples, 0..) |sample, i| {
                    new_samples[i] = sample * scale;
                }
            }

            return Self{
                .samples = new_samples,
                .allocator = self.allocator,
                .sample_rate = self.sample_rate,
                .channels = self.channels,
            };
        }

        /// Separates a wave into two waves at the specified sample index.
        ///
        /// ## Parameters
        /// - `self`: The wave to separate
        /// - `options`: Separation options (allocator and separation point)
        ///
        /// ## Returns
        /// A SeparateResult containing two Wave instances (initial and terminal)
        ///
        /// ## Errors
        /// - `SeparatingZeroLengthWave`: If the wave has no samples
        /// - `TooBigSeparatePoint`: If the separation point exceeds the wave length
        /// - `UnalignedChannelOffset`: If the separation point is not aligned to channel boundaries
        /// - `OutOfMemory`: Allocator error when memory allocation fails
        pub fn separate(
            self: Self,
            options: SeparateOptions,
        ) (SeparateErrors || std.mem.Allocator.Error)!SeparateResult {
            if (self.samples.len == 0)
                return error.SeparatingZeroLengthWave;

            if (self.samples.len < options.separate_point)
                return error.TooBigSeparatePoint;

            if (options.separate_point % self.channels != 0)
                return error.UnalignedChannelOffset;

            const initial_len = options.separate_point;
            const terminal_len = self.samples.len - options.separate_point;
            const initial: []T = try options.allocator.alloc(T, initial_len);
            errdefer options.allocator.free(initial);
            const terminal: []T = try options.allocator.alloc(T, terminal_len);
            errdefer options.allocator.free(terminal);

            @memcpy(initial, self.samples[0..initial_len]);
            @memcpy(terminal, self.samples[initial_len..]);

            const result = SeparateResult{
                .initial = Self{
                    .allocator = options.allocator,
                    .samples = initial,
                    .sample_rate = self.sample_rate,
                    .channels = self.channels,
                },
                .terminal = Self{
                    .allocator = options.allocator,
                    .samples = terminal,
                    .sample_rate = self.sample_rate,
                    .channels = self.channels,
                },
            };

            return result;
        }

        /// Options for separating a wave into two parts.
        pub const SeparateOptions = struct {
            /// Memory allocator for the new wave instances
            allocator: std.mem.Allocator,
            /// Sample index at which to split the wave (exclusive for initial, inclusive for terminal)
            separate_point: usize,
        };

        /// Result of separating a wave into two parts.
        pub const SeparateResult = struct {
            /// The first part of the wave (from start to separation point)
            initial: Self,
            /// The second part of the wave (from separation point to end)
            terminal: Self,
        };

        /// Errors that can occur when separating a wave.
        pub const SeparateErrors = error{
            /// Attempted to separate a wave with zero samples
            SeparatingZeroLengthWave,
            /// The separation point exceeds the wave's sample length
            TooBigSeparatePoint,
            /// The separation point is not aligned to channel boundaries
            UnalignedChannelOffset,
        };

        /// Errors that can occur when mixing waves.
        pub const MixErrors = error{
            /// The waves being mixed have mismatched sample lengths, sample rates, or channel counts
            MismatchedWaveProperties,
            /// The wave start point is not aligned to channel boundaries
            UnalignedChannelOffset,
        };

        /// Errors that can occur when filling zeros to end.
        pub const FillZeroErrors = error{
            /// The start index exceeds the sample length or the end index
            InvalidTruncationRange,
            /// The start or end index is not aligned to channel boundaries
            UnalignedChannelOffset,
        };

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
        ///
        /// ## Errors
        /// - `InvalidTruncationRange`: If `start > self.samples.len` or `start > end`
        /// - `UnalignedChannelOffset`: If `start` or `end` is not aligned to channel boundaries
        /// - Allocator error (errors.OutOfMemory)
        pub fn fill_zero_to_end(self: Self, start: usize, end: usize) (FillZeroErrors || std.mem.Allocator.Error)!Self {
            if (start > self.samples.len or start > end) {
                return error.InvalidTruncationRange;
            }

            if (start % self.channels != 0 or end % self.channels != 0) {
                return error.UnalignedChannelOffset;
            }

            const result_samples = try self.allocator.alloc(T, end);
            errdefer self.allocator.free(result_samples);

            @memcpy(result_samples[0..start], self.samples[0..start]);
            @memset(result_samples[start..end], 0.0);

            return Self{
                .samples = result_samples,
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

        /// Creates a deep copy of this wave's samples into a newly allocated `Wave(T)`.
        ///
        /// If `allocator` is `null`, the wave's own allocator (`self.allocator`) is reused.
        /// Otherwise, the provided allocator is used for the new samples buffer instead.
        /// The caller owns the returned Wave and is responsible for calling `deinit()` on it.
        ///
        /// ## Parameters
        /// - `self`: The wave to clone
        /// - `allocator`: Optional allocator to use for the clone; defaults to `self.allocator` when `null`
        ///
        /// ## Returns
        /// A new Wave instance with a deep copy of `self.samples`, sharing the same
        /// `sample_rate` and `channels`
        ///
        /// ## Errors
        /// - Allocator error (errors.OutOfMemory)
        ///
        /// ## Example
        /// ```zig
        /// const wave: Wave(f64) = try Wave(f64).init(samples, allocator, .{
        ///     .sample_rate = 44100,
        ///     .channels = 1,
        /// });
        /// defer wave.deinit();
        ///
        /// // Clone using the wave's own allocator
        /// const cloned = try wave.clone(null);
        /// defer cloned.deinit();
        ///
        /// // Clone using a different allocator
        /// const other_alloc_clone = try wave.clone(some_other_allocator);
        /// defer other_alloc_clone.deinit();
        /// ```
        pub fn clone(self: Self, allocator: ?std.mem.Allocator) std.mem.Allocator.Error!Self {
            const gpa = allocator orelse self.allocator;
            const clonedSamples = try gpa.dupe(T, self.samples);

            return Self{
                .samples = clonedSamples,
                .allocator = gpa,
                .channels = self.channels,
                .sample_rate = self.sample_rate,
            };
        }

        /// Options for channel conversion/upmixing/downmixing.
        pub const ChannelConvertOptions = struct {
            /// Pan position for mono-to-stereo conversion: [-1.0 (hard left), 1.0 (hard right)]
            /// Default is 0.0 (center panning).
            pan: f32 = 0.0,
        };

        /// Converts wave sample data to a target channel count (upmixing or downmixing).
        ///
        /// - Mono (1) to Stereo (2): Applies panning `options.pan` to left/right channels.
        /// - Stereo (2) to Mono (1): Averages left and right channel samples `(L + R) / 2.0`.
        /// - Same channel count: Returns a clone of the original wave.
        /// - General N to M: Replicates mono or averages N channels to target M channels.
        ///
        /// ## Parameters
        /// - `self`: The source wave to convert
        /// - `target_channels`: Target channel count (e.g., 1 for mono, 2 for stereo)
        /// - `options`: Conversion options including pan positioning
        ///
        /// ## Returns
        /// A new Wave instance converted to `target_channels`
        pub fn to_channels(
            self: Self,
            target_channels: u16,
            options: ChannelConvertOptions,
        ) std.mem.Allocator.Error!Self {
            if (self.channels == target_channels) {
                return self.clone(null);
            }

            const total_frames = if (self.channels > 0) self.samples.len / self.channels else 0;
            const new_len = total_frames * target_channels;
            const new_samples = try self.allocator.alloc(T, new_len);
            errdefer self.allocator.free(new_samples);

            if (self.channels == 1) {
                const pan_clamped = std.math.clamp(options.pan, -1.0, 1.0);
                const left_gain: T = @floatCast(@min(1.0, 1.0 - pan_clamped));
                const right_gain: T = @floatCast(@min(1.0, 1.0 + pan_clamped));

                for (self.samples, 0..) |m, i| {
                    if (target_channels == 2) {
                        new_samples[i * 2] = m * left_gain;
                        new_samples[i * 2 + 1] = m * right_gain;
                    } else {
                        @memset(new_samples[i * target_channels .. (i + 1) * target_channels], m);
                    }
                }
            } else {
                const src_ch: T = @floatFromInt(self.channels);
                for (0..total_frames) |i| {
                    var sum: T = 0.0;
                    for (self.samples[i * self.channels .. (i + 1) * self.channels]) |s| sum += s;
                    @memset(new_samples[i * target_channels .. (i + 1) * target_channels], sum / src_ch);
                }
            }

            return Self{
                .samples = new_samples,
                .allocator = self.allocator,
                .sample_rate = self.sample_rate,
                .channels = target_channels,
            };
        }

        /// Reads wave data from a file using the specified format.
        ///
        /// ## Parameters
        /// - `file_extension`: The file format to use for decoding (e.g. `.wav`)
        /// - `allocator`: Memory allocator for sample data
        /// - `reader`: A reader interface for reading the audio file data
        ///
        /// ## Returns
        /// A new Wave instance containing the audio data from the file
        ///
        /// ## Errors
        /// Returns errors from the underlying format decoder or allocation failures
        pub fn read(
            file_extension: LowLevelInterfaces,
            allocator: std.mem.Allocator,
            reader: anytype,
        ) anyerror!Self {
            const lowlevel_wave = try file_extension.read(allocator, reader);

            return Self{
                .samples = lowlevel_wave.samples,
                .allocator = allocator,
                .sample_rate = lowlevel_wave.sample_rate,
                .channels = lowlevel_wave.channels,
            };
        }

        /// Writes wave data to a file writer using the specified format.
        ///
        /// ## Parameters
        /// - `self`: The wave to write
        /// - `file_extension`: The file format to use for encoding (e.g. `.wav`)
        /// - `writer`: A writer interface for writing the audio file data
        /// - `options`: Format-specific write options (e.g. bit depth, format code)
        ///
        /// ## Errors
        /// Returns errors from the underlying format encoder or I/O failures
        pub fn write(self: Self, file_extension: LowLevelInterfaces, writer: anytype, options: LowLevelInterfaces.writeOptions(file_extension)) anyerror!void {
            try file_extension.write(self, writer, options);
        }

        /// Calculates the binary file size (in bytes) when saving wave data in the specified format.
        ///
        /// ## Parameters
        /// - `self`: The wave to measure
        /// - `file_extension`: The file format to use (e.g. `.wav`)
        /// - `options`: Format-specific size options (e.g. bit depth)
        ///
        /// ## Returns
        /// The total binary file size in bytes
        pub fn size(
            self: Self,
            file_extension: LowLevelInterfaces,
            options: LowLevelInterfaces.sizeOptions(file_extension),
        ) usize {
            return file_extension.size(self, options);
        }

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
        /// ## Errors
        /// Returns any error produced by `filter_fn` or allocation failures
        ///
        /// ## Example Usage
        /// ```zig
        /// const DecayWithDebugPrintArgs = struct {
        ///     string: []const u8,
        /// };
        ///
        /// /// Decay filter: Creates a linear fade-out effect
        /// /// The volume decreases from 100% to 0% over the duration of the wave
        /// fn decay_with_debug_print(comptime T: type, original_wave: Wave(T), args: DecayWithDebugPrintArgs) !Wave(T) {
        ///     var result_list: std.array_list.Aligned(T, null) = .empty;
        ///     defer result_list.deinit(original_wave.allocator);
        ///
        ///     // Process each sample, applying a decay factor
        ///     for (original_wave.samples, 0..) |sample, n| {
        ///         // Calculate how far from the end we are
        ///         const remaining_samples = original_wave.samples.len - n;
        ///
        ///         // Decay factor: 1.0 at start, 0.0 at end
        ///         const decay_factor = @as(T, @floatFromInt(remaining_samples)) /
        ///             @as(T, @floatFromInt(original_wave.samples.len));
        ///
        ///         // Apply the decay to the sample
        ///         const decayed_sample = sample * decay_factor;
        ///         try result_list.append(original_wave.allocator, decayed_sample);
        ///     }
        ///
        ///     // A example usage of args
        ///     // This means that you can accept any arguments to change this filter's effects
        ///     std.debug.print("A message from args: {s}\n", .{args.string});
        ///
        ///     // Return a new Wave with the filtered samples
        ///     return Wave(T).init(result_list.items, original_wave.allocator, .{
        ///         .sample_rate = original_wave.sample_rate,
        ///         .channels = original_wave.channels,
        ///     });
        /// }
        ///
        /// // Sine wave generation
        /// var samples: [44100]f64 = undefined;
        /// for (0..samples.len) |i| {
        ///     const t = @as(f64, @floatFromInt(i)) / sample_rate;
        ///     samples[i] = 0.5 * @sin(radians_per_sec * t);
        /// }
        ///
        /// const wave: Wave(f64) = Wave(f64).init(samples[0..], allocator, .{
        ///     .sample_rate = 44100,
        ///     .channels = 1,
        /// });
        ///
        /// const decayed_wave: Wave(f64) = wave.filter(decay);
        /// defer decayed_wave.deinit();
        /// ```
        pub fn filter_with(
            self: *Self,
            comptime args_type: type,
            comptime filter_fn: anytype,
            args: args_type,
        ) anyerror!void {
            const result: Self = try filter_fn(T, self.*, args);

            // To destroy original samples array
            // If we don't do this, we may catch some memory leaks by not to free original samples array
            self.deinit();

            // Assign the result into self
            self.* = result;
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
        /// ## Errors
        /// Returns any error produced by `filter_fn` or allocation failures
        ///
        /// ## Example Usage
        /// ```zig
        /// /// Decay filter: Creates a linear fade-out effect
        /// /// The volume decreases from 100% to 0% over the duration of the wave
        /// fn decay(comptime T: type, original_wave: Wave(T)) !Wave(T) {
        ///     var result_list: std.array_list.Aligned(T, null) = .empty;
        ///     defer result_list.deinit(original_wave.allocator);
        ///
        ///     // Process each sample, applying a decay factor
        ///     for (original_wave.samples, 0..) |sample, n| {
        ///         // Calculate how far from the end we are
        ///         const remaining_samples = original_wave.samples.len - n;
        ///
        ///         // Decay factor: 1.0 at start, 0.0 at end
        ///         const decay_factor = @as(T, @floatFromInt(remaining_samples)) /
        ///             @as(T, @floatFromInt(original_wave.samples.len));
        ///
        ///         // Apply the decay to the sample
        ///         const decayed_sample = sample * decay_factor;
        ///         try result_list.append(original_wave.allocator, decayed_sample);
        ///     }
        ///
        ///     // Return a new Wave with the filtered samples
        ///     return Wave(T).init(result_list.items, original_wave.allocator, .{
        ///         .sample_rate = original_wave.sample_rate,
        ///         .channels = original_wave.channels,
        ///     });
        /// }
        ///
        /// // Sine wave generation
        /// var samples: [44100]f64 = undefined;
        /// for (0..samples.len) |i| {
        ///     const t = @as(f64, @floatFromInt(i)) / sample_rate;
        ///     samples[i] = 0.5 * @sin(radians_per_sec * t);
        /// }
        ///
        /// const wave: Wave(f64) = Wave(f64).init(samples[0..], allocator, .{
        ///     .sample_rate = 44100,
        ///     .channels = 1,
        /// });
        ///
        /// const decayed_wave: Wave(f64) = wave.filter(decay);
        /// defer decayed_wave.deinit();
        /// ```
        pub fn filter(
            self: *Self,
            comptime filter_fn: anytype,
        ) anyerror!void {
            const result: Self = try filter_fn(T, self.*);

            // To destroy original samples array
            // If we don't do this, we may catch some memory leaks by not to free original samples array
            self.deinit();

            // Assign the result into self
            self.* = result;
        }

        /// Plays the wave audio through the system audio output.
        ///
        /// Initializes the audio engine, converts samples to f32, and blocks until
        /// playback completes.
        ///
        /// ## Parameters
        /// - `self`: The wave to play
        ///
        /// ## Errors
        /// Returns errors from the audio engine initialization or playback
        pub fn play(self: Self) anyerror!void {
            const allocator = self.allocator;
            var threaded = std.Io.Threaded.init(allocator, .{});
            const io = threaded.io();

            zaudio.init(allocator);
            defer zaudio.deinit();

            var engine: *zaudio.Engine = try zaudio.Engine.create(null);
            defer engine.destroy();

            const samples = try allocator.alloc(f32, self.samples.len);
            defer allocator.free(samples);

            for (self.samples, 0..) |orig_sample, i| {
                samples[i] = @as(f32, @floatCast(orig_sample));
            }

            var buffer_config = zaudio.AudioBuffer.Config.init(.float32, self.channels, samples.len / self.channels, samples.ptr);
            buffer_config.sample_rate = self.sample_rate;
            const buffer = try zaudio.AudioBuffer.create(buffer_config);
            defer buffer.destroy();
            const sound = try engine.createSoundFromDataSource(buffer.asDataSourceMut(), .{}, null);
            defer sound.destroy();

            try sound.start();

            while (!sound.isAtEnd()) {
                try io.sleep(std.Io.Duration.fromNanoseconds(10 * std.time.ns_per_ms), .real);
            }
        }

        fn tmp_file(allocator: std.mem.Allocator) !struct { std.fs.File, std.testing.TmpDir, []const u8 } {
            const timestamp: i64 = std.time.timestamp();
            const timestamp_str: []const u8 = try std.fmt.allocPrint(allocator, "{s}", .{timestamp});

            const tmp = std.testing.tmpDir(.{});
            const file = try tmp.dir.createFile(timestamp_str ++ ".wav", .{});

            return .{ file, tmp, timestamp_str };
        }

        /// Options for the `play` function (reserved for future use).
        pub const PlayOptions = struct {
            do_cleanup: bool,
        };

        test "read & deinit" {
            const allocator = testing.allocator;
            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
            const wave = try Self.read(.wav, allocator, &reader);
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
            const wave = try Self.init(samples[0..], allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            try testing.expectEqual(wave.sample_rate, 44100);
            try testing.expectEqual(wave.channels, 1);
        }

        test "clone creates deep copy of samples" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 2.0, 3.0 };

            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 2,
            });
            defer wave.deinit();

            const cloned = try wave.clone(null);
            defer cloned.deinit();

            // Cloned wave must keep the same sample_rate and channels
            try testing.expectEqual(wave.sample_rate, cloned.sample_rate);
            try testing.expectEqual(wave.channels, cloned.channels);
            try testing.expectEqualSlices(T, wave.samples, cloned.samples);

            // Samples must live in a different allocation, not just an aliased slice
            try testing.expect(wave.samples.ptr != cloned.samples.ptr);
        }

        test "clone with explicit allocator" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 4.0, 5.0, 6.0, 7.0 };

            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 48000,
                .channels = 1,
            });
            defer wave.deinit();

            var arena = std.heap.ArenaAllocator.init(testing.allocator);
            defer arena.deinit();

            // Passing a different allocator should make the clone use it,
            // instead of falling back to wave.allocator
            const cloned = try wave.clone(arena.allocator());

            try testing.expectEqual(wave.sample_rate, cloned.sample_rate);
            try testing.expectEqual(wave.channels, cloned.channels);
            try testing.expectEqualSlices(T, wave.samples, cloned.samples);
        }

        test "clone with empty samples" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{};

            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            const cloned = try wave.clone(null);
            defer cloned.deinit();

            try testing.expectEqual(cloned.samples.len, 0);
            try testing.expectEqual(wave.sample_rate, cloned.sample_rate);
            try testing.expectEqual(wave.channels, cloned.channels);
        }

        test "saturating_mixing_expression clamps values" {
            try testing.expectEqual(Self.saturating_mixing_expression(0.8, 0.5), 1.0);
            try testing.expectEqual(Self.saturating_mixing_expression(-0.8, -0.5), -1.0);
            try testing.expectApproxEqAbs(Self.saturating_mixing_expression(0.2, 0.3), 0.5, 0.00001);
        }

        test "normalize wave samples" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 0.2, -0.5, 0.1 };
            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            const normalized = try wave.normalize(1.0);
            defer normalized.deinit();

            try testing.expectApproxEqAbs(normalized.samples[0], 0.4, 0.00001);
            try testing.expectApproxEqAbs(normalized.samples[1], -1.0, 0.00001);
            try testing.expectApproxEqAbs(normalized.samples[2], 0.2, 0.00001);
        }

        test "normalize with all zero wave" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 0.0, 0.0, 0.0 };
            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            const normalized = try wave.normalize(1.0);
            defer normalized.deinit();

            try testing.expectEqual(normalized.samples[0], 0.0);
            try testing.expectEqual(normalized.samples[1], 0.0);
            try testing.expectEqual(normalized.samples[2], 0.0);
        }

        test "mix with custom multiplication mixer" {
            const allocator = testing.allocator;
            const mult_mixer = struct {
                fn mult(left: T, right: T) T {
                    return left * right;
                }
            }.mult;

            const samples1: []const T = &[_]T{ 0.5, 0.8, -0.4 };
            const samples2: []const T = &[_]T{ 0.2, -0.5, 0.5 };
            const wave1 = try Self.init(samples1, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave1.deinit();
            const wave2 = try Self.init(samples2, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave2.deinit();

            const mixed = try wave1.mix(wave2, .{ .mixer = mult_mixer });
            defer mixed.deinit();

            try testing.expectApproxEqAbs(mixed.samples[0], 0.1, 0.00001);
            try testing.expectApproxEqAbs(mixed.samples[1], -0.4, 0.00001);
            try testing.expectApproxEqAbs(mixed.samples[2], -0.2, 0.00001);
        }

        test "separate error paths and boundaries" {
            const allocator = testing.allocator;

            // Separating zero length wave
            const empty_wave = try Self.init(&.{}, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer empty_wave.deinit();
            try testing.expectError(error.SeparatingZeroLengthWave, empty_wave.separate(.{ .allocator = allocator, .separate_point = 0 }));

            // Too big separate point
            const samples: []const T = &[_]T{ 0.1, 0.2, 0.3 };
            const wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();
            try testing.expectError(error.TooBigSeparatePoint, wave.separate(.{ .allocator = allocator, .separate_point = 5 }));

            // Boundary separate point 0
            const sep0 = try wave.separate(.{ .allocator = allocator, .separate_point = 0 });
            defer sep0.initial.deinit();
            defer sep0.terminal.deinit();
            try testing.expectEqual(sep0.initial.samples.len, 0);
            try testing.expectEqual(sep0.terminal.samples.len, 3);

            // Boundary separate point len
            const sep_len = try wave.separate(.{ .allocator = allocator, .separate_point = 3 });
            defer sep_len.initial.deinit();
            defer sep_len.terminal.deinit();
            try testing.expectEqual(sep_len.initial.samples.len, 3);
            try testing.expectEqual(sep_len.terminal.samples.len, 0);

            // Unaligned channel separate point
            const stereo_samples: []const T = &[_]T{ 0.1, 0.2, 0.3, 0.4 };
            const stereo_wave = try Self.init(stereo_samples, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer stereo_wave.deinit();
            try testing.expectError(error.UnalignedChannelOffset, stereo_wave.separate(.{ .allocator = allocator, .separate_point = 1 }));
        }

        test "write with ieee float format and chunk options" {
            const allocator = testing.allocator;
            const io = testing.io;
            const samples: []const T = &[_]T{ 0.1, -0.2, 0.3, -0.4 };
            const wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            var tmpDir = testing.tmpDir(.{});
            defer tmpDir.cleanup();

            var file = try tmpDir.dir.createFile(io, "float.wav", .{});
            defer file.close(io);
            const buf = try allocator.alloc(u8, 64 * 1024);
            defer allocator.free(buf);
            var writer = file.writer(io, buf);

            try wave.write(.wav, &writer.interface, .{
                .bits = 32,
                .format_code = .ieee_float,
                .use_fact = true,
                .use_peak = true,
                .peak_timestamp = 12345,
            });
            try writer.interface.flush();

            const file_bytes = try tmpDir.dir.readFileAlloc(io, "float.wav", allocator, .limited(64 * 1024));
            defer allocator.free(file_bytes);

            try testing.expect(file_bytes.len > 44);
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
            const wave = try Self.init(samples[0..], allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            const result: Self = try wave.mix(wave, .{});
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
            const wave = try Self.init(samples[0..], allocator, .{
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

        test "fill_zero_to_end out of bounds returns error" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 2.0, 3.0 };
            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            try testing.expectError(error.InvalidTruncationRange, wave.fill_zero_to_end(5, 10));
            try testing.expectError(error.InvalidTruncationRange, wave.fill_zero_to_end(2, 1));

            // Unaligned channel offset test for multi-channel wave
            const stereo_samples: []const T = &[_]T{ 1.0, 2.0, 3.0, 4.0 };
            const stereo_wave = try Self.init(stereo_samples, allocator, .{
                .sample_rate = 44100,
                .channels = 2,
            });
            defer stereo_wave.deinit();

            try testing.expectError(error.UnalignedChannelOffset, stereo_wave.fill_zero_to_end(1, 4));
            try testing.expectError(error.UnalignedChannelOffset, stereo_wave.fill_zero_to_end(0, 3));
        }

        test "filter_with" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{};

            var wave = try Self.init(samples[0..], allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            try wave.filter_with(ArgsForTesting, test_filter_with_args, .{ .samples = 3 });
            defer wave.deinit();

            try testing.expectEqual(wave.sample_rate, 44100);
            try testing.expectEqual(wave.channels, 1);

            try testing.expectEqual(wave.samples.len, 3);
            try testing.expectEqual(wave.samples[0], 0.0);
            try testing.expectEqual(wave.samples[1], 0.0);
            try testing.expectEqual(wave.samples[2], 0.0);
        }

        test "filter" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{};

            var wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            try wave.filter(test_filter_without_args);
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

        test "filter memory leaks' check" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{};

            var wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            try wave.filter(test_filter_without_args);
            try wave.filter(test_filter_without_args);
            try wave.filter(test_filter_without_args);
            try wave.filter(test_filter_without_args);
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

            const wave = try Self.init(samples, allocator, .{
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
            const wave = try Self.init(&original_samples, allocator, .{
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
            const wave_mono = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave_mono.deinit();
            try testing.expectEqual(wave_mono.channels, 1);

            // Stereo
            const wave_stereo = try Self.init(samples, allocator, .{
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

            const wave1 = try Self.init(samples1, allocator, .{
                .sample_rate = 48000,
                .channels = 2,
            });
            defer wave1.deinit();

            const wave2 = try Self.init(samples2, allocator, .{
                .sample_rate = 48000,
                .channels = 2,
            });
            defer wave2.deinit();

            const result: Self = try wave1.mix(wave2, .{});
            defer result.deinit();

            try testing.expectEqual(result.sample_rate, 48000);
            try testing.expectEqual(result.channels, 2);
            try testing.expectEqual(result.samples.len, 3);
            try testing.expectEqual(result.samples[0], 1.5);
            try testing.expectEqual(result.samples[1], 3.0);
            try testing.expectEqual(result.samples[2], 4.5);
        }

        test "mix with mismatched properties returns error" {
            const allocator = testing.allocator;
            const samples1: []const T = &[_]T{ 1.0, 2.0 };
            const samples2: []const T = &[_]T{ 1.0, 2.0, 3.0 };

            const wave1 = try Self.init(samples1, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer wave1.deinit();
            const wave2 = try Self.init(samples2, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer wave2.deinit();
            const wave3 = try Self.init(samples1, allocator, .{ .sample_rate = 48000, .channels = 2 });
            defer wave3.deinit();
            const wave4 = try Self.init(samples1, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave4.deinit();

            // Mismatched length
            try testing.expectError(error.MismatchedWaveProperties, wave1.mix(wave2, .{}));
            // Mismatched sample rate
            try testing.expectError(error.MismatchedWaveProperties, wave1.mix(wave3, .{}));
            // Mismatched channels
            try testing.expectError(error.MismatchedWaveProperties, wave1.mix(wave4, .{}));
        }

        test "to_channels upmixing mono to stereo with panning" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 0.5 };
            const wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            const stereo_center = try wave.to_channels(2, .{ .pan = 0.0 });
            defer stereo_center.deinit();

            try testing.expectEqual(stereo_center.channels, 2);
            try testing.expectEqual(stereo_center.samples.len, 4);
            try testing.expectApproxEqAbs(stereo_center.samples[0], 1.0, 0.00001);
            try testing.expectApproxEqAbs(stereo_center.samples[1], 1.0, 0.00001);
            try testing.expectApproxEqAbs(stereo_center.samples[2], 0.5, 0.00001);
            try testing.expectApproxEqAbs(stereo_center.samples[3], 0.5, 0.00001);

            const stereo_left = try wave.to_channels(2, .{ .pan = -1.0 });
            defer stereo_left.deinit();

            try testing.expectApproxEqAbs(stereo_left.samples[0], 1.0, 0.00001);
            try testing.expectApproxEqAbs(stereo_left.samples[1], 0.0, 0.00001);
        }

        test "to_channels downmixing stereo to mono" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 0.6, 0.4, 0.2 };
            const wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 2 });
            defer wave.deinit();

            const mono = try wave.to_channels(1, .{});
            defer mono.deinit();

            try testing.expectEqual(mono.channels, 1);
            try testing.expectEqual(mono.samples.len, 2);
            try testing.expectApproxEqAbs(mono.samples[0], 0.8, 0.00001);
            try testing.expectApproxEqAbs(mono.samples[1], 0.3, 0.00001);
        }

        test "read with different sample rates" {
            const allocator = testing.allocator;
            var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
            const wave = try Self.read(.wav, allocator, &reader);
            defer wave.deinit();

            // Verify the wave has valid properties
            try testing.expect(wave.sample_rate > 0);
            try testing.expect(wave.channels > 0);
            try testing.expect(wave.samples.len > 0);
        }

        test "separate func separates a Wave" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 2.0, 3.0, 4.0, 5.0 };
            const original = try Self.init(samples, allocator, .{
                .sample_rate = 41000,
                .channels = 1,
            });
            defer original.deinit();

            const result = try original.separate(.{
                .allocator = allocator,
                .separate_point = 3,
            });
            defer result.initial.deinit();
            defer result.terminal.deinit();

            try testing.expectEqualSlices(T, result.initial.samples, &.{ 1.0, 2.0, 3.0 });
            try testing.expectEqualSlices(T, result.terminal.samples, &.{ 4.0, 5.0 });
        }

        test "size method calculates correct WAV binary size" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 0.1, 0.2, 0.3, 0.4 };
            const wave = try Self.init(samples, allocator, .{
                .sample_rate = 44100,
                .channels = 1,
            });
            defer wave.deinit();

            // 16-bit: 44 header bytes + 4 samples * 2 bytes = 52 bytes
            try testing.expectEqual(wave.size(.wav, .{ .bits = 16 }), 52);
            // 24-bit: 44 header bytes + 4 samples * 3 bytes = 56 bytes
            try testing.expectEqual(wave.size(.wav, .{ .bits = 24 }), 56);
            // 32-bit: 44 header bytes + 4 samples * 4 bytes = 60 bytes
            try testing.expectEqual(wave.size(.wav, .{ .bits = 32 }), 60);
        }

        test "fill_zero_to_end error when start is greater than end" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 0.1, 0.2, 0.3, 0.4 };
            const wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            try testing.expectError(error.InvalidTruncationRange, wave.fill_zero_to_end(3, 1));
        }

        test "filter chaining applies multiple filters sequentially" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{ 1.0, 2.0, 3.0 };
            var wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            const gain_filter = struct {
                fn apply(comptime SampleType: type, orig: Self) !Self {
                    var new_samples = try orig.allocator.alloc(SampleType, orig.samples.len);
                    for (orig.samples, 0..) |v, i| {
                        new_samples[i] = v * 2.0;
                    }
                    return Self{
                        .samples = new_samples,
                        .allocator = orig.allocator,
                        .sample_rate = orig.sample_rate,
                        .channels = orig.channels,
                    };
                }
            }.apply;

            const offset_filter = struct {
                fn apply(comptime SampleType: type, orig: Self) !Self {
                    var new_samples = try orig.allocator.alloc(SampleType, orig.samples.len);
                    for (orig.samples, 0..) |v, i| {
                        new_samples[i] = v + 0.5;
                    }
                    return Self{
                        .samples = new_samples,
                        .allocator = orig.allocator,
                        .sample_rate = orig.sample_rate,
                        .channels = orig.channels,
                    };
                }
            }.apply;

            try wave.filter(gain_filter);
            try wave.filter(offset_filter);

            try testing.expectEqual(wave.samples.len, 3);
            try testing.expectApproxEqAbs(wave.samples[0], 2.5, 0.00001);
            try testing.expectApproxEqAbs(wave.samples[1], 4.5, 0.00001);
            try testing.expectApproxEqAbs(wave.samples[2], 6.5, 0.00001);
        }

        test "filter on zero-length wave" {
            const allocator = testing.allocator;
            const samples: []const T = &[_]T{};
            var wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            const identity_filter = struct {
                fn apply(comptime SampleType: type, orig: Self) !Self {
                    const new_samples = try orig.allocator.alloc(SampleType, orig.samples.len);
                    @memcpy(new_samples, orig.samples);
                    return Self{
                        .samples = new_samples,
                        .allocator = orig.allocator,
                        .sample_rate = orig.sample_rate,
                        .channels = orig.channels,
                    };
                }
            }.apply;

            try wave.filter(identity_filter);
            try testing.expectEqual(wave.samples.len, 0);
        }

        test "write and read 24-bit pcm wav roundtrip" {
            const allocator = testing.allocator;
            const io = testing.io;
            const samples: []const T = &[_]T{ 0.1, -0.2, 0.5, -0.8 };
            const wave = try Self.init(samples, allocator, .{ .sample_rate = 44100, .channels = 1 });
            defer wave.deinit();

            var tmpDir = testing.tmpDir(.{});
            defer tmpDir.cleanup();

            {
                var file = try tmpDir.dir.createFile(io, "pcm24.wav", .{});
                defer file.close(io);
                const buf = try allocator.alloc(u8, 64 * 1024);
                defer allocator.free(buf);
                var writer = file.writer(io, buf);

                try wave.write(.wav, &writer.interface, .{
                    .bits = 24,
                    .format_code = .pcm,
                });
                try writer.interface.flush();
            }

            const file_bytes = try tmpDir.dir.readFileAlloc(io, "pcm24.wav", allocator, .limited(64 * 1024));
            defer allocator.free(file_bytes);
            var reader = std.Io.Reader.fixed(file_bytes);

            const read_wave = try Self.read(.wav, allocator, &reader);
            defer read_wave.deinit();

            try testing.expectEqual(read_wave.sample_rate, 44100);
            try testing.expectEqual(read_wave.channels, 1);
            try testing.expectEqual(read_wave.samples.len, samples.len);
            for (samples, read_wave.samples) |expected, actual| {
                try testing.expectApproxEqAbs(expected, actual, 0.001);
            }
        }
    };
}

test "Run tests for each samples' type" {
    _ = inner(f128);
    _ = inner(f80);
    _ = inner(f64);
    // _ = inner(f32); zigggwavvv 0.2.1 cannot use f32 as samples' type
}

fn test_filter_without_args(comptime SampleType: type, original: inner(SampleType)) !inner(SampleType) {
    var result: std.array_list.Aligned(SampleType, null) = .empty;
    defer result.deinit(original.allocator);

    for (0..5) |_|
        try result.append(original.allocator, 0.0);

    return inner(SampleType).init(result.items, original.allocator, .{
        .sample_rate = original.sample_rate,
        .channels = original.channels,
    });
}

fn test_filter_with_args(
    comptime SampleType: type,
    original: inner(SampleType),
    args: ArgsForTesting,
) !inner(SampleType) {
    var result: std.array_list.Aligned(SampleType, null) = .empty;
    defer result.deinit(original.allocator);

    for (0..args.samples) |_|
        try result.append(original.allocator, 0.0);

    return try inner(SampleType).init(result.items, original.allocator, .{
        .sample_rate = original.sample_rate,
        .channels = original.channels,
    });
}

const ArgsForTesting = struct {
    samples: usize,
};
