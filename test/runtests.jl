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

        if Sys.iswindows()
            expected_value = P.setdrive(joinpath("foo", "bar"), "D:")
            @test path"foo/bar|drive:D:" == expected_value
        else
            @test_throws ArgumentError path"foo/bar|drive:D:"
        end
    end

    @testset "initial path commands" begin
        @test path"|curdir" == pwd()
        @test path"|curdir/foo" == joinpath(pwd(), "foo")
        @test path"|srcfile" == @__FILE__
        @test path"|homedir" == homedir()

        if isempty(@__FILE__)
            @test_throws ErrorException path"|srcdir"
        else
            @test path"|srcdir" == dirname(@__FILE__)
        end

        if isempty(Base.PROGRAM_FILE)
            @test_throws ErrorException path"|progfile"
        else
            @test path"|progfile" == Base.PROGRAM_FILE
        end

        @test path"|pathof:PathMacro" == pathof(PathMacro)

        if pathof(Main) === nothing
            @test_throws ErrorException path"|pathof:Main"
        else
            @test path"|pathof:Main" == pathof(Main)
        end

        @test_throws LoadError eval(:(path"|pathof:1"))

        @test_throws LoadError eval(:(path"foo|curdir"))
        @test_throws LoadError eval(:(path"foo|srcfile"))
        @test_throws LoadError eval(:(path"foo|srcdir"))
        @test_throws LoadError eval(:(path"foo|homedir"))
        @test_throws LoadError eval(:(path"foo|progfile"))
        @test_throws LoadError eval(:(path"foo|pathof:PathMacro"))
    end

    @testset "initial segment sugar" begin
        @test path"." == pwd()
        @test path".." == dirname(pwd())
        @test path"../foo" == joinpath(dirname(pwd()), "foo")
        @test path"@" == @__FILE__
        @test path"~/foo" == joinpath(homedir(), "foo")
    end

    @testset "setext helper" begin
        @test P.setext("/tmp/foo.jl", ".txt") == "/tmp/foo.txt"
        @test P.setext("/tmp/foo", ".md") == "/tmp/foo.md"
    end

    @testset "setdrive helper" begin
        original = Sys.iswindows() ? "C:/path/file" : "/tmp/file"

        if Sys.iswindows()
            _, tail = splitdrive(original)
            expected_drive = string("D:", tail)
            @test P.setdrive(original, "D:") == expected_drive
            @test P.setdrive(original, "") == string("", tail)
        else
            @test P.setdrive(original, "") == original
            @test_throws ArgumentError P.setdrive(original, "D:")
        end
    end
end
