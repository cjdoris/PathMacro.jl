module PathMacro

export @path_str

struct ParsedCommand
    name::String
    args::Vector{Any}
end

struct ParsedPath
    initial::Vector{Any}
    commands::Vector{ParsedCommand}
end

Base.:(==)(a::ParsedCommand, b::ParsedCommand) = a.name == b.name && a.args == b.args
Base.:(==)(a::ParsedPath, b::ParsedPath) = a.initial == b.initial && a.commands == b.commands

function push_segment!(segments::Vector{Any}, piece)
    if piece === ""
        return segments
    elseif piece isa String && !isempty(segments) && segments[end] isa String
        segments[end] *= piece
    else
        push!(segments, piece)
    end
    return segments
end

function parse_path(input)
    raw = String(input)

    function parse_interpolation(start::Int)
        expr, newidx = Meta.parse(raw, nextind(raw, start); greedy = false)
        return expr, newidx
    end

    function parse_segments(start::Int)
        segments = Any[]
        i = start
        last = lastindex(raw)

        while i <= last
            idx = findnext(c -> c == '$' || c == '|' || c == '/', raw, i)

            if idx === nothing
                push_segment!(segments, raw[i:last])
                return segments, last + 1
            end

            if idx > i
                push_segment!(segments, raw[i:prevind(raw, idx)])
            end

            ch = raw[idx]
            if ch == '$'
                expr, newidx = parse_interpolation(idx)
                push!(segments, expr)
                i = newidx
            else
                return segments, idx
            end
        end

        return segments, last + 1
    end

    function parse_command_name(start::Int)
        i = start
        last = lastindex(raw)
        while i <= last
            ch = raw[i]
            if ch == ':' || ch == '|' || ch == '/'
                break
            elseif ch == '$'
                error("command names cannot include interpolation")
            end
            i = nextind(raw, i)
        end
        name = raw[start:prevind(raw, i)]
        isempty(name) && error("expected command name after '|'")
        return name, i
    end

    initial_segments, i = parse_segments(firstindex(raw))
    commands = ParsedCommand[]
    last = lastindex(raw)

    while i <= last
        ch = raw[i]
        if ch == '/'
            arg_segments, next_i = parse_segments(nextind(raw, i))
            if length(arg_segments) == 1 && arg_segments[1] == ".."
                push!(commands, ParsedCommand("dir", Any[]))
            else
                push!(commands, ParsedCommand("join", arg_segments))
            end
            i = next_i
        elseif ch == '|'
            name, pos_after_name = parse_command_name(nextind(raw, i))
            args = Any[]
            i = pos_after_name
            if i <= last && raw[i] == ':'
                args, i = parse_segments(nextind(raw, i))
            end
            push!(commands, ParsedCommand(name, args))
        else
            error("unexpected parser state at index $(i)")
        end
    end

    return ParsedPath(initial_segments, commands)
end

function segments_expr(segments::Vector{Any})
    isempty(segments) && return ""
    if all(segment -> segment isa String, segments)
        return *(segments...)
    else
        return length(segments) == 1 ? :(string($(segments[1]))) : :(string($(segments...)))
    end
end

function setext(path, newext)
    stem, _ = splitext(path)
    return string(stem, newext)
end

function setdrive(path, newdrive)
    if Sys.iswindows()
        _, tail = splitdrive(path)
        return string(newdrive, tail)
    else
        if !isempty(newdrive)
            throw(ArgumentError("drive changes are only supported on Windows; use an empty drive elsewhere"))
        end
        return path
    end
end

function ensure_nonempty(value, label)
    if value === nothing || value == ""
        error("$(label) is empty")
    end
    return value
end

curdir_path() = pwd()
srcfile_path(file) = file === nothing ? "" : string(file)
srcdir_path(file) = ensure_nonempty(dirname(ensure_nonempty(srcfile_path(file), "source file")), "source dir")
homedir_path() = homedir()
progfile_path() = ensure_nonempty(Base.PROGRAM_FILE, "program file")
pathof_path(mod) = ensure_nonempty(pathof(mod), "pathof")

function lower_parsed(parsed::ParsedPath; source = LineNumberNode(0, Symbol("")))
    current = segments_expr(parsed.initial)
    source_file = QuoteNode(source.file)

    if length(parsed.initial) == 1 && parsed.initial[1] isa String
        segment = parsed.initial[1]
        if segment == "."
            current = :($(curdir_path)())
        elseif segment == ".."
            current = :($(dirname)($(curdir_path)()))
        elseif segment == "@"
            current = :($(srcfile_path)($source_file))
        elseif segment == "~"
            current = :($(homedir_path)())
        end
    end

    for cmd in parsed.commands
        args = cmd.args
        if cmd.name == "join"
            isempty(args) && error("join requires an argument")
            current = :($(joinpath)($current, $(segments_expr(args))))
        elseif cmd.name == "dir"
            !isempty(args) && error("dir does not take an argument")
            current = :($(dirname)($current))
        elseif cmd.name == "abs"
            !isempty(args) && error("abs does not take an argument")
            current = :($(abspath)($current))
        elseif cmd.name == "rel"
            isempty(args) && error("rel requires an argument")
            current = :($(relpath)($current, $(segments_expr(args))))
        elseif cmd.name == "norm"
            !isempty(args) && error("norm does not take an argument")
            current = :($(normpath)($current))
        elseif cmd.name == "ext"
            isempty(args) && error("ext requires an argument")
            arg_expr = segments_expr(args)
            current = :($(setext)($current, $arg_expr))
        elseif cmd.name == "drive"
            isempty(args) && error("drive requires an argument")
            arg_expr = segments_expr(args)
            current = :($(setdrive)($current, $arg_expr))
        elseif cmd.name == "curdir"
            !isempty(args) && error("curdir does not take an argument")
            current == "" || error("curdir must appear at the start of a path macro")
            current = :($(curdir_path)())
        elseif cmd.name == "srcfile"
            !isempty(args) && error("srcfile does not take an argument")
            current == "" || error("srcfile must appear at the start of a path macro")
            current = :($(srcfile_path)($source_file))
        elseif cmd.name == "srcdir"
            !isempty(args) && error("srcdir does not take an argument")
            current == "" || error("srcdir must appear at the start of a path macro")
            current = :($(srcdir_path)($source_file))
        elseif cmd.name == "homedir"
            !isempty(args) && error("homedir does not take an argument")
            current == "" || error("homedir must appear at the start of a path macro")
            current = :($(homedir_path)())
        elseif cmd.name == "progfile"
            !isempty(args) && error("progfile does not take an argument")
            current == "" || error("progfile must appear at the start of a path macro")
            current = :($(progfile_path)())
        elseif cmd.name == "pathof"
            length(args) == 1 || error("pathof requires a single argument")
            current == "" || error("pathof must appear at the start of a path macro")
            arg_expr = args[1]
            if arg_expr isa String
                arg_expr = Meta.parse(arg_expr)
            end
            if !(arg_expr isa Expr || arg_expr isa Symbol)
                error("pathof requires a module name")
            end
            current = :($(pathof_path)($arg_expr))
        else
            error("unknown command: $(cmd.name)")
        end
    end

    return current
end

"""
    path"..."

A string macro for chaining filesystem path transformations with a pipeline-like syntax.
"""
macro path_str(input)
    parsed = parse_path(input)
    lowered = lower_parsed(parsed; source = __source__)
    return esc(lowered)
end

end # module
