using Test
using PathMacro

const P = PathMacro

function parsed_expr(str)
    return Meta.parse(str)
end

@testset "PathMacro" begin
    @testset "literal" begin
        input = parsed_expr("\"foo\"")
        parsed = P.parse_path(input)
        @test parsed == P.ParsedPath(["foo"], P.ParsedCommand[])

        lowered = P.lower_parsed(parsed)
        @test lowered == :("foo")

        @test path"foo" == "foo"
    end

    @testset "join with slash" begin
        input = parsed_expr("\"foo/bar\"")
        parsed = P.parse_path(input)
        expected_cmds = [P.ParsedCommand("join", ["bar"])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.joinpath("foo", "bar"))

        @test path"foo/bar" == joinpath("foo", "bar")
    end

    @testset "dir command" begin
        input = parsed_expr("\"foo|dir\"")
        parsed = P.parse_path(input)
        expected_cmds = [P.ParsedCommand("dir", Any[])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.dirname("foo"))

        @test path"foo|dir" == dirname("foo")
    end

    @testset "abs command" begin
        input = parsed_expr("\"foo|abs\"")
        parsed = P.parse_path(input)
        expected_cmds = [P.ParsedCommand("abs", Any[])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.abspath("foo"))

        @test path"foo|abs" == abspath("foo")
    end

    @testset "join command" begin
        input = parsed_expr("\"foo|join:bar\"")
        parsed = P.parse_path(input)
        expected_cmds = [P.ParsedCommand("join", ["bar"])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.joinpath("foo", "bar"))

        @test path"foo|join:bar" == joinpath("foo", "bar")
    end

    @testset "nested dir after slash" begin
        input = parsed_expr("\"foo/bar|dir\"")
        parsed = P.parse_path(input)
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("dir", Any[]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.dirname(Base.joinpath("foo", "bar")))

        @test path"foo/bar|dir" == dirname(joinpath("foo", "bar"))
    end

    @testset "interpolation dir sugar" begin
        foo = "/tmp/mydir"
        input = parsed_expr("\"$foo/..\"")
        parsed = P.parse_path(input)
        expected_cmds = [P.ParsedCommand("dir", Any[])]
        @test parsed == P.ParsedPath([:(foo)], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.dirname(string(foo)))

        @test path"$foo/.." == dirname(foo)
    end

    @testset "interpolation rel" begin
        foo = "/tmp/mydir"
        baz = "/tmp"
        input = parsed_expr("\"$foo/bar|rel:$baz\"")
        parsed = P.parse_path(input)
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("rel", [:baz]),
        ]
        @test parsed == P.ParsedPath([:(foo)], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :(Base.relpath(Base.joinpath(string(foo), "bar"), string(baz)))

        @test path"$foo/bar|rel:$baz" == relpath(joinpath(foo, "bar"), baz)
    end

    @testset "complex chain" begin
        foo2 = "/tmp/qux"
        baz2 = "/tmp/base"
        input = parsed_expr("\"$foo2.d/../bar|rel:$baz2\"")
        parsed = P.parse_path(input)
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("rel", [:baz2]),
        ]
        @test parsed == P.ParsedPath([:(foo2), ".d"], [P.ParsedCommand("dir", Any[]); expected_cmds])

        lowered = P.lower_parsed(parsed)
        expected_lowered = :(Base.relpath(Base.joinpath(Base.dirname(string(foo2, ".d")), "bar"), string(baz2)))
        @test lowered == expected_lowered

        expected_value = relpath(joinpath(dirname(string(foo2, ".d")), "bar"), baz2)
        @test path"$foo2.d/../bar|rel:$baz2" == expected_value
    end

    @testset "subdir interpolation then join" begin
        sub = "subdir"
        input = parsed_expr("\"foo/$sub|join:baz\"")
        parsed = P.parse_path(input)
        expected_cmds = [
            P.ParsedCommand("join", [:sub]),
            P.ParsedCommand("join", ["baz"]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        expected_lowered = :(Base.joinpath(Base.joinpath("foo", string(sub)), "baz"))
        @test lowered == expected_lowered

        @test path"foo/$sub|join:baz" == joinpath(joinpath("foo", sub), "baz")
    end
end
