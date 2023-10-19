const std = @import("std");
const print = @import("std").debug.print;
const panic = @import("std").debug.panic;
const path = @import("std").fs.path;

pub fn build(b: *std.Build) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    _ = alloc;

    var args = b.args orelse {
        print("build with \"zig build -- <path-to-dora>\"\r\n", .{});
        return;
    };

    var dora_root = args[0];
    const cargo_path = b.pathJoin(&[_][]const u8{ dora_root, "Cargo.toml" });

    const c_api_path = b.pathJoin(&[_][]const u8{ dora_root, "target", "debug" });

    const c_api_header_path = b.pathJoin(&[_][]const u8{ dora_root, "apis", "c" });

    const build_dora_cmd = b.addSystemCommand(&[_][]const u8{ "cargo", "build", "--package", "dora-node-api-c", "--manifest-path", cargo_path });

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig_node",
        .root_source_file = .{ .path = "node.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    exe.linkLibC();
    exe.linkSystemLibrary("dora_node_api_c");
    exe.linkSystemLibrary("gcc_s");
    exe.addLibraryPath(.{ .path = c_api_path });
    exe.addIncludePath(.{ .path = c_api_header_path });

    b.getInstallStep().dependOn(&build_dora_cmd.step);
}
