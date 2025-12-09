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
    str_expr = Meta.parse("\"$(escape_string(raw))\"")
    parts = str_expr isa Expr && str_expr.head == :string ? str_expr.args : Any[str_expr]
    interpolations = [part for part in parts if part isa Expr]

    idx_interp = 1
    function next_interpolation()
        idx_interp > length(interpolations) && error("interpolation marker found without matching expression")
        expr = interpolations[idx_interp]
        idx_interp += 1
        return expr
    end

    function parse_interpolation(raw::String, start::Int)
        expr = next_interpolation()
        _, newidx = Meta.parse(raw, start + 1; greedy = false)
        return expr, newidx
    end

    initial_segments = Any[]
    commands = ParsedCommand[]

    i = firstindex(raw)
    last = lastindex(raw)

    while i <= last
        ch = raw[i]
        if ch == '|'
            i = nextind(raw, i)

            cmdname = String()
            while i <= last
                ch_cmd = raw[i]
                if ch_cmd == ':' || ch_cmd == '|' || ch_cmd == '/'
                    break
                elseif ch_cmd == '$'
                    error("command names cannot include interpolation")
                else
                    cmdname *= ch_cmd
                    i = nextind(raw, i)
                end
            end

            isempty(cmdname) && error("expected command name after '|'")

            arg_segments = Any[]
            if i <= last && raw[i] == ':'
                i = nextind(raw, i)
                while i <= last
                    ch_arg = raw[i]
                    if ch_arg == '|' || ch_arg == '/'
                        break
                    elseif ch_arg == '$'
                        expr, newidx = parse_interpolation(raw, i)
                        push!(arg_segments, expr)
                        i = newidx
                    else
                        push_segment!(arg_segments, string(ch_arg))
                        i = nextind(raw, i)
                    end
                end
            end

            push!(commands, ParsedCommand(cmdname, arg_segments))
            continue
        elseif ch == '/'
            i = nextind(raw, i)
            arg_segments = Any[]
            while i <= last
                ch_arg = raw[i]
                if ch_arg == '|' || ch_arg == '/'
                    break
                elseif ch_arg == '$'
                    expr, newidx = parse_interpolation(raw, i)
                    push!(arg_segments, expr)
                    i = newidx
                else
                    push_segment!(arg_segments, string(ch_arg))
                    i = nextind(raw, i)
                end
            end

            if length(arg_segments) == 1 && arg_segments[1] == ".."
                push!(commands, ParsedCommand("dir", Any[]))
            else
                push!(commands, ParsedCommand("join", arg_segments))
            end
            continue
        elseif ch == '$'
            expr, newidx = parse_interpolation(raw, i)
            push!(initial_segments, expr)
            i = newidx
        else
            push_segment!(initial_segments, string(ch))
            i = nextind(raw, i)
        end
    end

    if idx_interp <= length(interpolations)
        error("unused interpolations detected in input")
    end

    return ParsedPath(initial_segments, commands)
end

function segments_expr(segments::Vector{Any})
    isempty(segments) && return ""
    return :(string($(segments...)))
end

function lower_parsed(parsed::ParsedPath)
    current = segments_expr(parsed.initial)

    for cmd in parsed.commands
        args = cmd.args
        if cmd.name == "join"
            isempty(args) && error("join requires an argument")
            current = :(Base.joinpath($current, $(segments_expr(args))))
        elseif cmd.name == "dir"
            !isempty(args) && error("dir does not take an argument")
            current = :(Base.dirname($current))
        elseif cmd.name == "abs"
            !isempty(args) && error("abs does not take an argument")
            current = :(Base.abspath($current))
        elseif cmd.name == "rel"
            isempty(args) && error("rel requires an argument")
            current = :(Base.relpath($current, $(segments_expr(args))))
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
    lowered = lower_parsed(parsed)
    return esc(lowered)
end

end # module
