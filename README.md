# PathMacro.jl

PathMacro provides the `path"..."` string macro for building and transforming filesystem paths with a concise pipeline syntax. Each segment before a `|` or `/` is treated as literal text (with normal Julia `$` interpolation), and commands are applied from left to right to produce the final path string.

## Commands

- `join:arg` → `joinpath(value, arg)`
- `dir` → `dirname(value)`
- `abs` → `abspath(value)`
- `rel:arg` → `relpath(value, arg)`
- `norm` → `normpath(value)`
- `ext:arg` → replace the file extension with `arg` via `splitext`
- `drive:arg` → replace the drive prefix with `arg` via `splitdrive` (non-empty `arg` is only supported on Windows)
- `curdir` → set the initial value to `pwd()` (must be the first command)
- `srcfile` → set the initial value to the macro call-site file (must be the first command)
- `srcdir` → set the initial value to the call-site directory (errors if empty; must be the first command)
- `homedir` → set the initial value to `homedir()` (must be the first command)
- `progfile` → set the initial value to `Base.PROGRAM_FILE` (errors if empty; must be the first command)
- `pathof:Foo` → set the initial value to `pathof(Foo)` (errors if `nothing`; must be the first command)

Shorthand:
- `/arg` is equivalent to `|join:arg`
- `/..` is equivalent to `|dir`
- `.` as the initial segment is equivalent to `|curdir`
- `..` as the initial segment is equivalent to `|dir` applied to `|curdir`
- `@` as the initial segment is equivalent to `|srcfile`
- `~` as the initial segment is equivalent to `|homedir`

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

julia> path"|curdir/src"
"/current/working/dir/src"

julia> path"@|dir"
"/path/to/calling/dir"
```

## Development

Run the tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
