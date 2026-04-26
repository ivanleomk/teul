const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("teul", .{
        .root_source_file = b.path("src/teul.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_module.addAnonymousImport("template_build_zig", .{
        .root_source_file = b.path("templates/build.zig.template"),
    });
    exe_module.addAnonymousImport("template_build_zig_zon", .{
        .root_source_file = b.path("templates/build.zig.zon.template"),
    });
    exe_module.addAnonymousImport("template_main_zig", .{
        .root_source_file = b.path("templates/main.zig.template"),
    });
    exe_module.addAnonymousImport("teul_zig", .{
        .root_source_file = b.path("src/teul.zig"),
    });
    exe_module.addAnonymousImport("app_zig", .{
        .root_source_file = b.path("src/app.zig"),
    });
    exe_module.addAnonymousImport("command_zig", .{
        .root_source_file = b.path("src/command.zig"),
    });
    exe_module.addAnonymousImport("parser_zig", .{
        .root_source_file = b.path("src/parser.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "teul",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
