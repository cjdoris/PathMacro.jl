module PathMacro

export @path_str

"""
    path"..."

A string macro for chaining filesystem path transformations with a pipeline-like syntax.
"""
macro path_str(input)
    raw = String(input)
    parsed = Meta.parse("\"$(escape_string(raw))\"")
    parts = parsed isa Expr && parsed.head == :string ? parsed.args : [parsed]

    items = Any[]
    for part in parts
        if part isa String
            for ch in part
                push!(items, ch)
            end
        else
            push!(items, part)
        end
    end

    function push_char!(segments, ch)
        if !isempty(segments) && isa(segments[end], String)
            segments[end] *= string(ch)
        else
            push!(segments, string(ch))
        end
    end

    function push_expr!(segments, expr)
        push!(segments, expr)
    end

    function segments_expr(segments)
        isempty(segments) && return ""
        return :(string($(segments...)))
    end

    function apply_command(current, cmd, arg_segments)
        arg_expr = segments_expr(arg_segments)
        if cmd == "join"
            isempty(arg_segments) && error("join requires an argument")
            return :(Base.joinpath($current, $arg_expr))
        elseif cmd == "dir"
            !isempty(arg_segments) && error("dir does not take an argument")
            return :(Base.dirname($current))
        elseif cmd == "abs"
            !isempty(arg_segments) && error("abs does not take an argument")
            return :(Base.abspath($current))
        elseif cmd == "rel"
            isempty(arg_segments) && error("rel requires an argument")
            return :(Base.relpath($current, $arg_expr))
        else
            error("unknown command: $cmd")
        end
    end

    idx = 1
    n = length(items)
    segments = Any[]
    current = nothing

    while idx <= n
        item = items[idx]
        if item isa Char
            if item == '|'
                current === nothing && (current = segments_expr(segments); segments = Any[])
                idx += 1
                cmdname = ""
                while idx <= n
                    next = items[idx]
                    if !(next isa Char)
                        error("command name must be literal text")
                    end
                    if next == ':' || next == '|' || next == '/'
                        break
                    end
                    cmdname *= string(next)
                    idx += 1
                end
                isempty(cmdname) && error("expected command name after '|'")
                arg_segments = Any[]
                if idx <= n && items[idx] == ':'
                    idx += 1
                    while idx <= n
                        next = items[idx]
                        if next isa Char && (next == '|' || next == '/')
                            break
                        end
                        if next isa Char
                            push_char!(arg_segments, next)
                        else
                            push_expr!(arg_segments, next)
                        end
                        idx += 1
                    end
                end
                current = apply_command(current, cmdname, arg_segments)
                continue
            elseif item == '/'
                current === nothing && (current = segments_expr(segments); segments = Any[])
                idx += 1
                arg_segments = Any[]
                while idx <= n
                    next = items[idx]
                    if next isa Char && (next == '|' || next == '/')
                        break
                    end
                    if next isa Char
                        push_char!(arg_segments, next)
                    else
                        push_expr!(arg_segments, next)
                    end
                    idx += 1
                end
                if length(arg_segments) == 1 && arg_segments[1] == ".."
                    current = apply_command(current, "dir", Any[])
                else
                    current = apply_command(current, "join", arg_segments)
                end
                continue
            else
                push_char!(segments, item)
            end
        else
            push_expr!(segments, item)
        end
        idx += 1
    end

    current === nothing && (current = segments_expr(segments))
    return esc(current)
end

end # module
