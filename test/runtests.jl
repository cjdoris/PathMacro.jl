using Test
using PathMacro

const P = PathMacro

@testset "PathMacro" begin
    @testset "literal" begin
        parsed = P.parse_path("foo")
        @test parsed == P.ParsedPath(["foo"], P.ParsedCommand[])

        lowered = P.lower_parsed(parsed)
        @test lowered == "foo"

        @test path"foo" == "foo"
    end

    @testset "join with slash" begin
        parsed = P.parse_path("foo/bar")
        expected_cmds = [P.ParsedCommand("join", ["bar"])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(joinpath)("foo", "bar"))

        @test path"foo/bar" == joinpath("foo", "bar")
    end

    @testset "dir command" begin
        parsed = P.parse_path("foo|dir")
        expected_cmds = [P.ParsedCommand("dir", Any[])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(dirname)("foo"))

        @test path"foo|dir" == dirname("foo")
    end

    @testset "abs command" begin
        parsed = P.parse_path("foo|abs")
        expected_cmds = [P.ParsedCommand("abs", Any[])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(abspath)("foo"))

        @test path"foo|abs" == abspath("foo")
    end

    @testset "join command" begin
        parsed = P.parse_path("foo|join:bar")
        expected_cmds = [P.ParsedCommand("join", ["bar"])]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(joinpath)("foo", "bar"))

        @test path"foo|join:bar" == joinpath("foo", "bar")
    end

    @testset "nested dir after slash" begin
        parsed = P.parse_path("foo/bar|dir")
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("dir", Any[]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(dirname)($(joinpath)("foo", "bar")))

        @test path"foo/bar|dir" == dirname(joinpath("foo", "bar"))
    end

    @testset "interpolation dir sugar" begin
        foo = "/tmp/mydir"
        parsed = P.parse_path("\$foo/..")
        expected_cmds = [P.ParsedCommand("dir", Any[])]
        @test parsed == P.ParsedPath([:(foo)], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(dirname)(string(foo)))

        @test path"$foo/.." == dirname(foo)
    end

    @testset "interpolation rel" begin
        foo = "/tmp/mydir"
        baz = "/tmp"
        parsed = P.parse_path("\$foo/bar|rel:\$baz")
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("rel", [:baz]),
        ]
        @test parsed == P.ParsedPath([:(foo)], expected_cmds)

        lowered = P.lower_parsed(parsed)
        @test lowered == :($(relpath)($(joinpath)(string(foo), "bar"), string(baz)))

        @test path"$foo/bar|rel:$baz" == relpath(joinpath(foo, "bar"), baz)
    end

    @testset "complex chain" begin
        foo2 = "/tmp/qux"
        baz2 = "/tmp/base"
        parsed = P.parse_path("\$foo2.d/../bar|rel:\$baz2")
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("rel", [:baz2]),
        ]
        @test parsed == P.ParsedPath([:(foo2), ".d"], [P.ParsedCommand("dir", Any[]); expected_cmds])

        lowered = P.lower_parsed(parsed)
        expected_lowered = :($(relpath)($(joinpath)($(dirname)(string(foo2, ".d")), "bar"), string(baz2)))
        @test lowered == expected_lowered

        expected_value = relpath(joinpath(dirname(string(foo2, ".d")), "bar"), baz2)
        @test path"$foo2.d/../bar|rel:$baz2" == expected_value
    end

    @testset "subdir interpolation then join" begin
        sub = "subdir"
        parsed = P.parse_path("foo/\$sub|join:baz")
        expected_cmds = [
            P.ParsedCommand("join", [:sub]),
            P.ParsedCommand("join", ["baz"]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        expected_lowered = :($(joinpath)($(joinpath)("foo", string(sub)), "baz"))
        @test lowered == expected_lowered

        @test path"foo/$sub|join:baz" == joinpath(joinpath("foo", sub), "baz")
    end

    @testset "norm command" begin
        parsed = P.parse_path("foo/./bar|norm")
        expected_cmds = [
            P.ParsedCommand("join", ["."]),
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("norm", Any[]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        expected_lowered = :($(normpath)($(joinpath)($(joinpath)("foo", "."), "bar")))
        @test lowered == expected_lowered

        @test path"foo/./bar|norm" == normpath(joinpath(joinpath("foo", "."), "bar"))
    end

    @testset "ext command" begin
        parsed = P.parse_path("foo/bar.jl|ext:.txt")
        expected_cmds = [
            P.ParsedCommand("join", ["bar.jl"]),
            P.ParsedCommand("ext", [".txt"]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        expected_lowered = :($(P.setext)($(joinpath)("foo", "bar.jl"), ".txt"))
        @test Base.remove_linenums!(copy(lowered)) == Base.remove_linenums!(copy(expected_lowered))

        expected_value = P.setext(joinpath("foo", "bar.jl"), ".txt")
        @test path"foo/bar.jl|ext:.txt" == expected_value
    end

    @testset "drive command" begin
        parsed = P.parse_path("foo/bar|drive:D:")
        expected_cmds = [
            P.ParsedCommand("join", ["bar"]),
            P.ParsedCommand("drive", ["D:"]),
        ]
        @test parsed == P.ParsedPath(["foo"], expected_cmds)

        lowered = P.lower_parsed(parsed)
        expected_lowered = :($(P.setdrive)($(joinpath)("foo", "bar"), "D:"))
        @test Base.remove_linenums!(copy(lowered)) == Base.remove_linenums!(copy(expected_lowered))

        expected_value = P.setdrive(joinpath("foo", "bar"), "D:")
        @test path"foo/bar|drive:D:" == expected_value
    end

    @testset "setext and setdrive helpers" begin
        @test P.setext("/tmp/foo.jl", ".txt") == "/tmp/foo.txt"
        @test P.setext("/tmp/foo", ".md") == "/tmp/foo.md"

        original = Sys.iswindows() ? "C:/path/file" : "/tmp/file"
        expected_drive = begin
            _, tail = splitdrive(original)
            string("D:", tail)
        end
        @test P.setdrive(original, "D:") == expected_drive
    end
end
