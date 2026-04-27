const std = @import("std");
const teul = @import("teul");

const AppContext = struct {
    init: std.process.Init,
    app_version: []const u8,
};

const EchoCmd = struct {
    message: []const u8,

    pub fn run(self: @This(), ctx: *AppContext) !void {
        std.debug.print("v{s}: {s}\n", .{ctx.app_version, self.message});
        
        // accessing gpa to prove init is available
        _ = ctx.init.gpa;
        std.debug.print("Successfully accessed std.process.Init.gpa!\n", .{});
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args_iter = try init.minimal.args.iterateAllocator(allocator);
    defer args_iter.deinit();

    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(allocator);

    while (args_iter.next()) |arg| {
        try args_list.append(allocator, arg);
    }

    var ctx = AppContext{
        .init = init,
        .app_version = "1.2.3",
    };

    const root_cmd = teul.Command{
        .name = "app",
        .description = "A teul starter project",
        .subcommands = &[_]teul.Command{
            .{
                .name = "echo",
                .description = "Echo a message",
                .run_fn = teul.generateWrapper(EchoCmd),
            },
        },
    };

    const app = teul.App.init(root_cmd);
    try app.runWithContext(allocator, args_list.items, init, &ctx);
}
