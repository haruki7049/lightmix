const std = @import("std");
const ziex = @import("ziex");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const app_exe = b.addExecutable(.{
        .name = "lightmix_website",
        .root_module = b.createModule(.{
            .root_source_file = b.path("app/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Adds the `dev`, `serve` and `export` steps. `zig build export` writes the static site to `dist/`.
    _ = try ziex.init(b, app_exe, .{
        // GitHub Pages serves the site under `/lightmix`.
        .app = .{ .base_path = "/lightmix" },
        .cli = .{
            .steps = .{
                .dev = "dev",
                .serve = "serve",
                .@"export" = "export",
            },
        },
    });
}
