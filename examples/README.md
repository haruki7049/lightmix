# Examples

- Composer
- Wave
- drum
- guitar

## How to run examples

### Run all examples at once

From the root of the repository, you can build and run all examples automatically:

```bash
zig build examples
```

This will compile and execute all example programs. The output `.wav` files will be generated in `zig-out/examples/<example_name>/` directories.

### Run a specific example

Go to the example's directory you want to check. Then, run this command, `zig build run`. You will see the `result.wav` file in current directory.

**Please check the volume!! The wave files' volume are not checked!!**
