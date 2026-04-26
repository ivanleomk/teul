const std = @import("std");

/// A simple iterator for testing purposes. It mimics `std.process.ArgIterator`.
pub const SliceIterator = struct {
    args: []const []const u8,
    index: usize = 0,

    pub fn next(self: *@This()) ?[]const u8 {
        if (self.index >= self.args.len) return null;
        const arg = self.args[self.index];
        self.index += 1;
        return arg;
    }
};

/// The core comptime parser.
/// Takes a target type `T` and an iterator that has a `next() ?[]const u8` method.
pub fn parseArgs(comptime T: type, allocator: std.mem.Allocator, iter: anytype) !T {
    _ = allocator;

    var result: T = undefined;

    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                if (field.default_value_ptr) |def_ptr| {
                    const default_val = @as(*align(1) const field.type, @ptrCast(def_ptr)).*;
                    @field(result, field.name) = default_val;
                } else if (field.type == bool) {
                    @field(result, field.name) = false;
                }
            }
        },
        else => @compileError("parseArgs target must be a struct"),
    }

    // 1. Parse all positional arguments first
    var next_arg: ?[]const u8 = iter.next();
    var positional_index: usize = 0;

    while (next_arg) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            // We hit a flag, transition to flag parsing
            break; 
        }

        var assigned = false;
        comptime var current_pos = 0;
        
        inline for (info.@"struct".fields) |field| {
            // Fields without defaults and not bools are positional
            if (field.type != bool and field.default_value_ptr == null) {
                if (current_pos == positional_index) {
                    if (field.type == []const u8) {
                        @field(result, field.name) = arg;
                    } else if (@typeInfo(field.type) == .int) {
                        @field(result, field.name) = try std.fmt.parseInt(field.type, arg, 10);
                    } else {
                        @compileError("Unsupported type for positional: " ++ @typeName(field.type));
                    }
                    assigned = true;
                }
                current_pos += 1;
            }
        }

        if (!assigned) return error.TooManyPositionalArguments;
        positional_index += 1;
        
        next_arg = iter.next();
    }

    // 2. Parse all flags afterwards
    while (next_arg) |arg| {
        if (!std.mem.startsWith(u8, arg, "--")) {
            return error.PositionalAfterFlagNotAllowed;
        }
        
        const flag_name = arg[2..];
        var found = false;

        inline for (info.@"struct".fields) |field| {
            // We consider it a flag if it's a bool OR if it has a default value
            if (field.type == bool or field.default_value_ptr != null) {
                if (std.mem.eql(u8, field.name, flag_name)) {
                    found = true;
                    if (field.type == bool) {
                        // Booleans don't take a value, they are just true if present
                        @field(result, field.name) = true;
                    } else {
                        // Other types require a value like `--retries 5`
                        const val_str = iter.next() orelse return error.MissingFlagValue;
                        
                        if (field.type == []const u8) {
                            @field(result, field.name) = val_str;
                        } else if (@typeInfo(field.type) == .int) {
                            @field(result, field.name) = try std.fmt.parseInt(field.type, val_str, 10);
                        } else {
                            @compileError("Unsupported type for flag: " ++ @typeName(field.type));
                        }
                    }
                }
            }
        }

        if (!found) return error.UnknownFlag;
        
        next_arg = iter.next();
    }

    return result;
}

test "parseArgs - initializes default values" {
    const TestArgs = struct {
        verbose: bool, // Should default to false
        retries: u32 = 3, // Should default to 3
    };

    var iter = SliceIterator{ .args = &[_][]const u8{} };
    const args = try parseArgs(TestArgs, std.testing.allocator, &iter);

    try std.testing.expectEqual(false, args.verbose);
    try std.testing.expectEqual(@as(u32, 3), args.retries);
}

test "parseArgs - strict ordering (positionals then flags)" {
    const TestArgs = struct {
        target: []const u8,        // Positional 0
        verbose: bool = false,     // Flag
        retries: u32 = 3,          // Flag
    };

    // Test case 1: Valid strict ordering
    var iter1 = SliceIterator{ .args = &[_][]const u8{
        "my_target", "--verbose", "--retries", "5"
    } };
    const args1 = try parseArgs(TestArgs, std.testing.allocator, &iter1);
    try std.testing.expectEqualStrings("my_target", args1.target);
    try std.testing.expectEqual(true, args1.verbose);
    try std.testing.expectEqual(@as(u32, 5), args1.retries);

    // Test case 2: Invalid interleaved ordering throws error
    var iter2 = SliceIterator{ .args = &[_][]const u8{
        "--verbose", "another_target"
    } };
    const err = parseArgs(TestArgs, std.testing.allocator, &iter2);
    try std.testing.expectError(error.PositionalAfterFlagNotAllowed, err);
}
