const std = @import("std");

// xbps-remove -Ro gtk+3-devel libwebkit2gtk41-devel
pub fn stepWebview(b: *std.build.Builder) *std.build.LibExeObjStep {
    const w = b.addSharedLibrary("webview", null, .unversioned);
    w.linkLibCpp();
    w.addCSourceFile("vendor/webview/webview.cc", &[_][]const u8{});
    w.linkSystemLibrary("gtk+-3.0");
    w.linkSystemLibrary("webkit2gtk-4.1");
    w.addIncludePath("vendor/");
    return w;
}

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("marz", "src/main.zig");
    exe.setTarget(target);

    // --- Webview deps
    exe.addIncludePath("vendor/");
    const webview = stepWebview(b);
    exe.linkLibrary(webview);
    // --- End of build confusion.

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
