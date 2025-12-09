using Test
using PathMacro

@testset "PathMacro" begin
    @test path"foo" == "foo"
    @test path"foo/bar" == joinpath("foo", "bar")
    @test path"foo|dir" == dirname("foo")
    @test path"foo|abs" == abspath("foo")
    @test path"foo|join:bar" == joinpath("foo", "bar")
    @test path"foo/bar|dir" == dirname(joinpath("foo", "bar"))

    foo = "/tmp/mydir"
    baz = "/tmp"
    @test path"$foo/.." == dirname(foo)
    @test path"$foo/bar|rel:$baz" == relpath(joinpath(foo, "bar"), baz)

    foo2 = "/tmp/qux"
    baz2 = "/tmp/base"
    expected = relpath(joinpath(dirname(string(foo2, ".d")), "bar"), baz2)
    @test path"$foo2.d/../bar|rel:$baz2" == expected

    sub = "subdir"
    @test path"foo/$sub|join:baz" == joinpath(joinpath("foo", sub), "baz")
end
