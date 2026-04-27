const std = @import("std");
const App = @import("app.zig").App;
const Command = @import("command.zig").Command;

const InitCmd = struct {
    target: []const u8, // Target directory

    pub fn run(self: @This(), init: std.process.Init) !void {
        std.debug.print("Initializing teul project in '{s}'...\n", .{self.target});
        const io = init.io; // The IO backend from program initialization

        var dir = try std.Io.Dir.cwd().createDirPathOpen(io, self.target, .{});
        defer dir.close(io);

        try dir.writeFile(io, .{ .sub_path = "build.zig", .data = @embedFile("template_build_zig") });
        try dir.writeFile(io, .{ .sub_path = "build.zig.zon", .data = @embedFile("template_build_zig_zon") });

        try dir.createDirPath(io, "src");
        try dir.writeFile(io, .{ .sub_path = "src/main.zig", .data = @embedFile("template_main_zig") });

        try dir.createDirPath(io, "src/teul");
        try dir.writeFile(io, .{ .sub_path = "src/teul/teul.zig", .data = @embedFile("teul_zig") });
        try dir.writeFile(io, .{ .sub_path = "src/teul/app.zig", .data = @embedFile("app_zig") });
        try dir.writeFile(io, .{ .sub_path = "src/teul/command.zig", .data = @embedFile("command_zig") });
        try dir.writeFile(io, .{ .sub_path = "src/teul/parser.zig", .data = @embedFile("parser_zig") });

        std.debug.print("teul project created in '{s}'!\n", .{self.target});
    }
};

pub fn main(init: std.process.Init) !void {
    // 1. Juicy Main provides the allocator and arguments natively!
    const allocator = init.gpa;

    var args_iter = try init.minimal.args.iterateAllocator(allocator);
    defer args_iter.deinit();

    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(allocator);

    while (args_iter.next()) |arg| {
        try args_list.append(allocator, arg);
    }

    // 2. Define the CLI Routing Tree
    const Cmd = Command(void);
    const root_cmd = Cmd{
        .name = "teul",
        .description = "The ultimate comptime CLI framework",
        .subcommands = &[_]Cmd{
            .{
                .name = "init",
                .description = "Initialize a teul starter project",
                .run_fn = Cmd.wrap(InitCmd),
            },
        },
    };

    // 3. Initialize the Router and Run!
    const app = App(void).init(root_cmd);
    try app.run(allocator, args_list.items, init, {});
}
