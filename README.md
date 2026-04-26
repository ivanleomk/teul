# Teul

Teul is a modern, comptime-powered CLI framework for Zig (built for 0.16+). 
It provides a clean, type-safe, and boilerplate-free way to build robust command-line applications through struct-based argument parsing and tree-based command routing.

## Features

- **Comptime Wrapper Generation**: Define your commands as simple structs. Teul automatically generates the underlying parsing and execution logic at compile time.
- **Strict, Type-Safe Argument Parsing**: Define positional arguments and flags directly via struct fields. Supports strings, integers, and booleans natively.
- **Tree-Based Routing**: Easily structure complex CLIs with hierarchical subcommands and command groups.
- **Clean Error Handling**: User-friendly validation errors. No messy stack traces when a user provides an unknown flag or misses a required argument.
- **Standard Flag Syntax**: Supports `--flag`, `--key=value`, and `--key value` syntax out of the box.
- **Built-in `init` Command**: Includes a scaffolding executable to bootstrap your new CLI project instantly.

## Getting Started

### Using the Scaffolding Tool

Teul provides its own CLI tool to instantly scaffold a new project with the framework pre-configured.

**Option 1: Download Release Binary**
1. Download the latest binary for your platform from the [Releases page](https://github.com/ivanleomk/teul/releases).
2. Make it executable (`chmod +x teul`) and run it:
```bash
./teul init ./my-new-cli
cd ./my-new-cli
zig build run -- --help
```

**Option 2: Build from Source**
```bash
# Clone the repository and build the teul binary
git clone https://github.com/ivanleomk/teul.git
cd teul
zig build -Doptimize=ReleaseSafe

# Initialize a new project in your target directory
./zig-out/bin/teul init ../my-new-cli
cd ../my-new-cli
zig build run -- --help
```

The `init` tool vendors the framework files directly into your project's `src/teul/` directory, meaning the generated project has zero external dependencies! You can just build and run immediately.

### Manual Installation (As a Dependency)

If you prefer to install Teul as a traditional Zig package instead of scaffolding:

1. Add Teul to your `build.zig.zon`:
```bash
zig fetch --save git+https://github.com/ivanleomk/teul.git
```

2. Add the dependency to your `build.zig`:
```zig
const teul = b.dependency("teul", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("teul", teul.module("teul"));
```

## Quick Example

Teul makes it easy to map command line arguments directly to Zig structs:

```zig
const std = @import("std");
const App = @import("teul").App;
const Command = @import("teul").Command;
const generateWrapper = @import("teul").generateWrapper;

// 1. Define your command struct
const MyCmd = struct {
    // Fields without defaults are required positional arguments
    target: []const u8,       
    
    // Bools are parsed as optional flags (--verbose, --verbose=true, --verbose=false)
    verbose: bool = false,    
    
    // Fields with defaults are parsed as optional flags (--retries=5 or --retries 5)
    retries: u32 = 3,         

    // 2. Define your run function
    pub fn run(self: @This(), init: std.process.Init) !void {
        std.debug.print("Target: {s}\n", .{self.target});
        if (self.verbose) {
            std.debug.print("Verbose mode enabled!\n", .{});
        }
        std.debug.print("Retries configured: {d}\n", .{self.retries});
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

    // 3. Define the CLI Routing Tree
    const root_cmd = Command{
        .name = "my_app",
        .description = "An awesome CLI built with Teul",
        .subcommands = &[_]Command{
            .{
                .name = "do-thing",
                .description = "Does a very important thing",
                .run_fn = generateWrapper(MyCmd),
            },
        },
    };

    // 4. Initialize and Run
    const app = App.init(root_cmd);
    try app.run(allocator, args_list.items, init);
}
```

When you run this application:

```bash
$ my_app do-thing my-target --verbose --retries 10
Target: my-target
Verbose mode enabled!
Retries configured: 10

$ my_app do-thing
Error: missing required argument(s).
  Usage: <target> [--verbose] [--retries]
```

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request or open an issue for bug fixes or features.
