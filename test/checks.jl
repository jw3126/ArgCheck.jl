using ArgCheck: pretty_string
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
    @test contains(msg, string(x))
    @test contains(msg, string(y))
    @test contains(msg, "x")
    @test contains(msg, "y")
    @test contains(msg, "==")

    x = 1.2
    y = 1.34
    z = -345.234
    err = @catch_exception_object @argcheck x < y < z
    msg = err.msg
    @test contains(msg, string(z))
    @test contains(msg, string(y))
    @test contains(msg, "y")
    @test contains(msg, "z")
    @test contains(msg, "<")
    @test !contains(msg, string(x))

    ≦(a,b) = false
    err = @catch_exception_object @argcheck x ≦ y ≦ z
    msg = err.msg
    @test contains(msg, "x")
    @test contains(msg, "y")
    @test contains(msg, string(x))
    @test contains(msg, string(y))
    @test contains(msg, "≦")

    s = randstring()
    arr = rand(1000:9999, 1000)
    x = randn()
    err = @catch_exception_object @check falsy(x, arr, s)
    @test typeof(err) == CheckError
    msg = err.msg
    @test length(msg) < 2000
    @test contains(msg, pretty_string(x))
    @test contains(msg, pretty_string(arr))
    @test contains(msg, pretty_string(s))
end

# In 
# We can't wrap this in @testset on julia v0.6
# because of https://github.com/JuliaLang/julia/issues/24316
# @testset "error message call" begin
let
    x = 1.2
    y = 1.34
    z = -345.234
    err = @catch_exception_object @argcheck falsy([x y; z z])
    msg = err.msg
    @test contains(msg, string(x))
    @test contains(msg, string(z))
    @test contains(msg, string(y))
    @test contains(msg, "y")
    @test contains(msg, "z")
    @test contains(msg, "x")
    @test contains(msg, "f")

    fail_function(args...) = false
    err = @catch_exception_object @argcheck fail_function(x,y,z) DimensionMismatch
    msg = err.msg

    @test err isa DimensionMismatch
    @test contains(msg, string(x))
    @test contains(msg, string(z))
    @test contains(msg, string(y))
    @test contains(msg, "y")
    @test contains(msg, "z")
    @test contains(msg, "x")
    @test contains(msg, "Got")
    @test contains(msg, "fail_function")

    err = @catch_exception_object @argcheck issorted([2,1])
    @test !contains(err.msg, "Got")
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
end

@testset "custom message" begin
    x = 0
    @test_throws ArgumentError @argcheck x > 1 "this should not happen"
    @argcheck true "this should not happen"
end

@testset "@check" begin
    @check true
    E = CheckError
    @test_throws E @check false
    @test_throws E @check false "oh no"
    @test_throws DimensionMismatch @check false DimensionMismatch
end

@testset "pretty_string" begin
    @test pretty_string("asd") == "\"asd\""
    
    data = rand(10000:99999, 1000)
    str = pretty_string(data)
    @test length(str) < 1000
    @test contains(str, string(last(data)))
    @test contains(str, string(first(data)))
    @test !contains(str, "\n")
    
    data = randn()
    @test parse(Float64,pretty_string(data)) === data
end
