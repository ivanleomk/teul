const std = @import("std");
const App = @import("app.zig").App;
const Command = @import("command.zig").Command;
const generateWrapper = @import("command.zig").generateWrapper;

// 1. Define our strongly-typed Command object
const AddCmd = struct {
    target: []const u8, // Positional argument
    verbose: bool = false, // Flag

    pub fn run(self: @This()) !void {
        std.debug.print("🚀 Executing AddCmd!\n", .{});
        std.debug.print("Target: {s}\n", .{self.target});
        std.debug.print("Verbose Mode: {}\n", .{self.verbose});
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
    const root_cmd = Command{
        .name = "teul",
        .description = "The ultimate comptime CLI framework",
        .subcommands = &[_]Command{
            .{
                .name = "add",
                .description = "Add a new secret",
                .run_fn = generateWrapper(AddCmd),
            },
        },
    };

    // 3. Initialize the Router and Run!
    const app = App.init(root_cmd);
    try app.run(allocator, args_list.items);
}
