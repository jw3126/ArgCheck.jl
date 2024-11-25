module TestChecks
using Test
using ArgCheck
using ArgCheck: pretty_string
using Random: randstring

macro catch_exception_object(code)
    quote
        err = try
            $(esc(code))
            nothing
        catch e
            e
        end
        if err == nothing
            error("Expected exception, got $err.")
        end
        err
    end
end

@testset "Chained comparisons" begin
    #6
    x=y=z = 1
    @test x == y == z
    @argcheck x == y == z
    z = 2
    @test_throws ArgumentError @argcheck x == y == z

    @test_throws ArgumentError @argcheck 1 ≈ 2 == 2
    @argcheck 1 == 1 ≈ 1 < 2 > 1.2
    @test_throws DimensionMismatch @argcheck 1 < 2 ==3 DimensionMismatch
end

@testset "@argcheck" begin
    @test_throws ArgumentError @argcheck false
    @argcheck true

    x = 1
    @test_throws ArgumentError (@argcheck x > 1)
    @argcheck x>0 # does not throw

    n =2; m=3
    @test_throws DimensionMismatch (@argcheck n==m DimensionMismatch)
    @argcheck n==n DimensionMismatch

    denominator = 0
    @test_throws DivideError (@argcheck denominator != 0 DivideError())
    @argcheck 1 !=0 DivideError()
end

# exotic cases
struct MyError <: Exception
    msg::String
end
struct MyExoticError <: Exception
    a::Int
    b::Int
end

falsy(args...;kw...) = false
truthy(args...;kw...) = true

@testset "exotic cases" begin
    @argcheck truthy()
    @test_throws ArgumentError @argcheck falsy()

    @argcheck begin
        multi_line_true_is_no_problem = true
        multi_line_true_is_no_problem
    end
    @test_throws DimensionMismatch @argcheck let
        falsy(1,2)
    end DimensionMismatch

    op() = (x,y) -> x < y
    x = 1; y = 2
    @argcheck op()(x,y)
    @test_throws ArgumentError @argcheck op()(y,x)
    @test_throws ArgumentError @argcheck begin false end
    @test_throws DivideError @argcheck falsy() DivideError()
    err = @catch_exception_object @argcheck false MyExoticError(1,2)
    @test err === MyExoticError(1,2)
end

@testset "error messages" begin
    x = 1.23455475675
    y = 2.345345345
    # comparison
    err = @catch_exception_object @argcheck x == y MyError
    @test err isa MyError
    msg = err.msg
    @test occursin(string(x), msg)
    @test occursin(string(y), msg)
    @test occursin("x", msg)
    @test occursin("y", msg)
    @test occursin("==", msg)

    x = 1.2
    y = 1.34
    z = -345.234
    err = @catch_exception_object @argcheck x < y < z
    msg = err.msg
    @test occursin(string(z), msg)
    @test occursin(string(y), msg)
    @test occursin("y", msg)
    @test occursin("z", msg)
    @test occursin("<", msg)
    @test !occursin(string(x), msg)

    ≦(a,b) = false
    err = @catch_exception_object @argcheck x ≦ y ≦ z
    msg = err.msg
    @test occursin("x", msg)
    @test occursin("y", msg)
    @test occursin(string(x), msg)
    @test occursin(string(y), msg)
    @test occursin("≦", msg)

    s = randstring()
    arr = rand(1000:9999, 1000)
    x = randn()
    err = @catch_exception_object @check falsy(x, arr, s)
    @test typeof(err) == CheckError
    msg = err.msg
    @test length(msg) < 2000
    @test occursin(pretty_string(x), msg)
    @test occursin(pretty_string(arr), msg)
    @test occursin(pretty_string(s), msg)

    x = 1.2
    y = 1.34
    z = -345.234
    err = @catch_exception_object @argcheck falsy([x y; z z])
    msg = err.msg
    @test occursin(string(x), msg)
    @test occursin(string(z), msg)
    @test occursin(string(y), msg)
    @test occursin("y", msg)
    @test occursin("z", msg)
    @test occursin("x", msg)
    @test occursin("f", msg)

    fail_function(args...) = false
    err = @catch_exception_object @argcheck fail_function(x,y,z) DimensionMismatch
    msg = err.msg

    @test err isa DimensionMismatch
    @test occursin(string(x), msg)
    @test occursin(string(z), msg)
    @test occursin(string(y), msg)
    @test occursin("y", msg)
    @test occursin("z", msg)
    @test occursin("x", msg)
    @test occursin("Got", msg)
    @test occursin("fail_function", msg)

    err = @catch_exception_object @argcheck issorted([2,1])
    @test !occursin("Got", err.msg)

    z = "some_keyword_arg"
    err = @catch_exception_object @argcheck falsy(x=z)
    @test occursin("z", err.msg)
    @test occursin(z, err.msg)

    args = ["these", "are", "splatargs"]
    err = @catch_exception_object @argcheck falsy(args...)
    @test occursin("args", err.msg)
    @test occursin(args[1], err.msg)

    myatol = 0.1
    err = @catch_exception_object @argcheck isapprox(1,2,atol=myatol)
    @test occursin("atol", err.msg)
    @test occursin("0.1", err.msg)

    kw = (atol=1.34, rtol=0.02)
    err = @catch_exception_object @argcheck isapprox(10, 20; kw...)
    @test occursin("atol", err.msg)
    @test occursin("1.34", err.msg)
    @test occursin("rtol", err.msg)
    @test occursin("0.02", err.msg)

    args = (10, 20)
    kw = (atol=1.34, rtol=0.02)
    err = @catch_exception_object @argcheck isapprox(args...; kw...)
    @test occursin("atol", err.msg)
    @test occursin("1.34", err.msg)
    @test occursin("rtol", err.msg)
    @test occursin("0.02", err.msg)
    @test occursin("10", err.msg)
    @test occursin("20", err.msg)

    # check argument orders
    err = @catch_exception_object @argcheck let 
        a = 1.0; b = 1.2; atol = 0.1; nvalue = false; rtol = 0.05;
        @check isapprox(a, b, atol=atol, nans=nvalue; rtol)
    end
    locations = map(["a =>", "b =>", "atol =>", "nvalue =>", "rtol =>"]) do name
        findfirst(name, err.msg)
    end
    @test all(x -> x isa UnitRange, locations)
    @test issorted(getindex.(locations, 1))

    x = 1.234
    err = @catch_exception_object @argcheck (!isfinite)(x)
    @test occursin(string(x), err.msg)
    err = @catch_exception_object @argcheck !isfinite(x)
    @test_broken occursin(string(x), err.msg)


    t1 = Int32
    t2 = Integer
    err = @catch_exception_object @argcheck t2 <: t1
    @test occursin(string(t1), err.msg)
    @test occursin(string(t2), err.msg)
    @test occursin("t1 =>", err.msg)
    @test occursin("t2 =>", err.msg)

    # Symbols
    x = :x
    err = @catch_exception_object @argcheck x == :X
    @test occursin(":x", err.msg)
    x = :y
    err = @catch_exception_object @argcheck x == :Y
    @test occursin(":y", err.msg)
    @test !occursin(":x", err.msg)
end

@testset "complicated calls" begin
    @argcheck issorted([2,1], rev=true)
    @argcheck issorted([2,1]; rev=true)
    xs = [[1,2]]
    @argcheck issorted(xs...)

    @argcheck truthy(xs...,xs...)
    @test_throws MyError @argcheck falsy(xs...,xs...) MyError

    kw1 = Dict(:x =>1)
    kw2 = Dict(:y =>2)
    @argcheck truthy(;kw1...)
    @argcheck truthy(;kw1..., kw2...)
    @test_throws MyError @argcheck falsy(cos, xs...,xs...;kw1...,kw2...,foo=3) MyError

    if VERSION > v"1.4.0"
        atol = 2
        @argcheck isapprox(1, 2; atol)
        @argcheck isapprox(1, 2; atol, rtol=0.2)
        @argcheck isapprox(1, 2; :atol=>2)
        @argcheck isapprox(1, 2; :atol=>2, rtol=0.1)
        @argcheck isapprox(1, 2; (() -> :atol)()=>2, rtol=0.1)

        foo = 3
        foosym = :foo
        @argcheck truthy(cos, xs...,xs...;kw1...,kw2...,foo) MyError
        @test_throws MyError @argcheck falsy(cos, xs...,xs...;kw1...,kw2...,foo) MyError
        @argcheck truthy(cos, xs...,xs...;kw1...,kw2...,foosym=>1) MyError
        @test_throws MyError @argcheck falsy(cos, xs...,xs...;kw1...,kw2...,foosym=>1) MyError
    end
end

@testset "custom message" begin
    x = 0
    expected = ArgumentError("this should not happen\nx > 1 must hold. Got\nx => 0")
    @test_throws expected @argcheck x > 1 "this should not happen"
    @argcheck true "this should not happen"
end

@testset "@check" begin
    @check true
    E = CheckError
    @test_throws E @check false
    @test_throws E @check false "oh no"
    @test_throws DimensionMismatch @check false DimensionMismatch
    s = randstring()
    msg = sprint(showerror, CheckError(s))
    @test msg == "CheckError: $s"
end

@testset "pretty_string" begin
    @test pretty_string("asd") == "\"asd\""
    @test pretty_string(:asd) == ":asd"

    data = rand(10000:99999, 1000)
    str = pretty_string(data)
    @test length(str) < 1000
    @test occursin(string(last(data)), str)
    @test occursin(string(first(data)),str)
    @test !occursin("\n",str)

    data = randn()
    @test parse(Float64,pretty_string(data)) === data
end

@testset "marker" begin
    for ex in [
            :(@argcheck some_expr),
            :(@check some_expr),
            :(@check A < b),
            :(@check A < b MyError),
        ]
        ex = macroexpand(TestChecks, ex)
        @test Meta.isexpr(ex, :block)
        @test first(ex.args) == ArgCheck.LABEL_BEGIN_CHECK
        @test last(ex.args) == ArgCheck.LABEL_END_CHECK
    end
    @test ArgCheck.LABEL_BEGIN_CHECK != ArgCheck.LABEL_END_CHECK
    @test Meta.isexpr(ArgCheck.LABEL_BEGIN_CHECK, :meta)
    @test Meta.isexpr(ArgCheck.LABEL_END_CHECK, :meta)
end

end#module
