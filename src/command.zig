const std = @import("std");
const parser = @import("parser.zig");

/// A node in the CLI routing tree, generic over the Context type.
pub fn Command(comptime CtxType: type) type {
    return struct {
        name: []const u8,
        description: []const u8 = "",

        /// A list of subcommands. If this is not empty, this command acts as a group (e.g. `gcp`).
        subcommands: []const Command(CtxType) = &[_]Command(CtxType){},

        /// The type-erased wrapper function.
        /// It takes an allocator, the remaining raw string arguments, the Init struct, and the typed context.
        /// If this is null, the command is just a routing group and cannot be executed directly.
        run_fn: ?*const fn(allocator: std.mem.Allocator, args: []const []const u8, init: std.process.Init, ctx: CtxType) anyerror!void = null,

        /// A comptime helper to generate the `run_fn` wrapper for a given user struct.
        /// The `CmdStruct` must have fields defining its arguments and a `pub fn run(...) !void` method.
        pub fn wrap(comptime CmdStruct: type) *const fn(std.mem.Allocator, []const []const u8, std.process.Init, CtxType) anyerror!void {
            return struct {
                fn wrapper(allocator: std.mem.Allocator, args: []const []const u8, init: std.process.Init, ctx: CtxType) anyerror!void {
                    // We use the SliceIterator so we can parse a simple array of strings!
                    var iter = parser.SliceIterator{ .args = args };
                    
                    // 1. Parse the remaining strings into the user's struct
                    const parsed_args = try parser.parseArgs(CmdStruct, allocator, &iter);
                    
                    // 2. Execute the user's logic!
                    // We use comptime reflection to check the arguments of the user's run() function.
                    const RunFn = @TypeOf(CmdStruct.run);
                    const run_info = @typeInfo(RunFn).@"fn";
                    
                    if (run_info.params.len == 1) {
                        try parsed_args.run();
                    } else if (run_info.params.len == 2) {
                        const ArgType = run_info.params[1].type orelse @compileError("Missing parameter type for context");
                        
                        if (ArgType == std.process.Init) {
                            try parsed_args.run(init);
                        } else if (ArgType == CtxType) {
                            try parsed_args.run(ctx);
                        } else {
                            @compileError("run() second argument must be std.process.Init or the shared CtxType");
                        }
                    } else {
                        @compileError("run() must take either 1 argument (self) or 2 arguments (self, ctx).");
                    }
                }
            }.wrapper;
        }
    };
}
