const std = @import("std");
const parser = @import("parser.zig");

/// A node in the CLI routing tree.
pub const Command = struct {
    name: []const u8,
    description: []const u8 = "",

    /// A list of subcommands. If this is not empty, this command acts as a group (e.g. `gcp`).
    subcommands: []const Command = &[_]Command{},

    /// The type-erased wrapper function.
    /// It takes an allocator and the remaining raw string arguments.
    /// If this is null, the command is just a routing group and cannot be executed directly.
    run_fn: ?*const fn(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void = null,
};

/// A comptime helper to generate the `run_fn` wrapper for a given user struct.
/// The `CmdStruct` must have fields defining its arguments and a `pub fn run(self: CmdStruct) !void` method.
pub fn generateWrapper(comptime CmdStruct: type) *const fn(std.mem.Allocator, []const []const u8) anyerror!void {
    return struct {
        fn wrapper(allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
            // We use the SliceIterator so we can parse a simple array of strings!
            var iter = parser.SliceIterator{ .args = args };
            
            // 1. Parse the remaining strings into the user's struct
            const parsed_args = try parser.parseArgs(CmdStruct, allocator, &iter);
            
            // 2. Execute the user's logic!
            try parsed_args.run();
        }
    }.wrapper;
}
