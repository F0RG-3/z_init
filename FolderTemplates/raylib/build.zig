const std = @import("std");
const Import = std.Build.Module.Import;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const common_imports = [_] Import {
        .{ .name = "raylib", .module = raylib_dep.module("raylib") },
        .{ .name = "raygui", .module = raylib_dep.module("raygui") },
    };


    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
            .imports = &common_imports,
        }),
    });

    exe.linkLibrary(raylib_dep.artifact("raylib"));
    b.installArtifact(exe);

    const run_step = b.step("run", "run the program");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
}
