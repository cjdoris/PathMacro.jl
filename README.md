# PathMacro.jl

PathMacro provides the `path"..."` string macro for building and transforming filesystem paths with a concise pipeline syntax. Each segment before a `|` or `/` is treated as literal text (with normal Julia `$` interpolation), and commands are applied from left to right to produce the final path string.

## Commands

- `join:arg` → `joinpath(value, arg)`
- `dir` → `dirname(value)`
- `abs` → `abspath(value)`
- `rel:arg` → `relpath(value, arg)`
- `norm` → `normpath(value)`
- `ext:arg` → replace the file extension with `arg` via `splitext`
- `drive:arg` → replace the drive prefix with `arg` via `splitdrive`

Shorthand:
- `/arg` is equivalent to `|join:arg`
- `/..` is equivalent to `|dir`

Arguments and the initial value can include standard `$` interpolation.

## Examples

```julia
using PathMacro

julia> foo = "/tmp/mydir";
julia> path"$foo/.."
"/tmp"

julia> baz = "/tmp"
julia> path"$foo/bar|rel:$baz"
"mydir/bar"

julia> path"/etc/passwd|dir"
"/etc"
```

## Development

Run the tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
