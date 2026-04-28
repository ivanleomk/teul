---
name: teul
description: Learn how to build and scaffold Zig CLIs using the Teul framework.
---

# Teul CLI Framework Skill

Teul is a modern, comptime-powered CLI framework for Zig (built for 0.16+). It provides a clean, type-safe, and boilerplate-free way to build robust command-line applications through struct-based argument parsing and tree-based command routing.

When building a CLI tool with Teul, adhere to the following principles and syntax.

## 1. Defining Commands as Structs

In Teul, each command is a Zig struct where the fields represent the command-line arguments.

- **Positional Arguments:** Fields without default values are required positional arguments.
- **Flags/Options:** Fields with default values are optional flags (e.g., `--key=value`).
- **Boolean Flags:** `bool` fields are automatically treated as flags (e.g., `--verbose`).

```zig
const std = @import("std");

pub const MyCmd = struct {
    // Required positional argument
    target: []const u8,       
    
    // Optional boolean flag (can be used as --verbose)
    verbose: bool = false,    
    
    // Optional integer flag (can be used as --retries=5)
    retries: u32 = 3,         

    // The run function executes the command
    pub fn run(self: @This(), init: std.process.Init) !void {
        std.debug.print("Target: {s}\n", .{self.target});
        if (self.verbose) {
            std.debug.print("Verbose mode enabled!\n", .{});
        }
    }
};
```

## 2. Context Injection (Dependency Injection)

Teul allows passing a shared context to your commands, preventing the need to initialize things like database connections or HTTP clients repeatedly.

The context pointer must be consistent across all commands. Your `run` function should take it as the second parameter instead of `std.process.Init`.

```zig
pub const AppContext = struct {
    init: std.process.Init,
    // Add your shared state here (e.g., db: DbConnection)
};

pub const DeployCmd = struct {
    target: []const u8,

    pub fn run(self: @This(), ctx: *AppContext) !void {
        // Access allocator through ctx.init.gpa
        const allocator = ctx.init.gpa;
        std.debug.print("Deploying {s}\n", .{self.target});
    }
};
```

## 3. Creating the Application and Routing

In `main.zig`, assemble your commands into a tree and initialize the application.

```zig
const std = @import("std");
const teul = @import("teul");
const DeployCmd = @import("commands/deploy.zig").DeployCmd;
const AppContext = @import("commands/deploy.zig").AppContext; // From previous example

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    
    // Collect arguments
    var args_iter = try init.minimal.args.iterateAllocator(allocator);
    defer args_iter.deinit();

    var args_list: std.ArrayList([]const u8) = .empty;
    defer args_list.deinit(allocator);

    while (args_iter.next()) |arg| {
        try args_list.append(allocator, arg);
    }

    // Initialize shared context
    var ctx = AppContext{
        .init = init,
    };

    // Define the command tree
    const Cmd = teul.Command(*AppContext);
    const root_cmd = Cmd{
        .name = "my_app",
        .description = "My CLI Tool",
        .subcommands = &[_]Cmd{
            .{
                .name = "deploy",
                .description = "Deploy the target",
                .run_fn = Cmd.wrap(DeployCmd),
            },
        },
    };

    // Run the app
    const app = teul.App(*AppContext).init(root_cmd);
    try app.run(allocator, args_list.items, init, &ctx);
}
```

## Scaffolding New Projects

Teul includes an `init` binary for easy setup. It vendors the framework directly into `src/teul/`, eliminating external dependencies.

```bash
teul init ./my-new-cli
cd my-new-cli
zig build run -- --help
```
