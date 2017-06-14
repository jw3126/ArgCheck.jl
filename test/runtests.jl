using ArgCheck
using Base.Test
using Compat
import ArgCheck: build_error

import ArgCheck: iscomparison
@testset "iscomparison" begin
    @test iscomparison(:(1==2))
    @test iscomparison(:(f(2x) + 1 ≈ f(x)))
    @test iscomparison(:(<(2,3)))
    @test !iscomparison(:(f(1,1)))
end

@testset "@argcheck" begin
    @test_throws ArgumentError @argcheck false
    @argcheck true
    
    x = 1
    @test_throws ArgumentError (@argcheck x > 1)
    @test_throws ArgumentError @argcheck x > 1 "this should not happen"
    @argcheck x>0 # does not throw
    
    n =2; m=3
    @test_throws DimensionMismatch (@argcheck n==m DimensionMismatch)
    @argcheck n==n DimensionMismatch
    
    denominator = 0
    @test_throws DivideError (@argcheck denominator != 0 DivideError())
    @argcheck 1 !=0 DivideError()
end

@compat struct MyError <: Exception
    msg::String
end

@testset "error message" begin
    x = 1.23455475675
    y = 2.345345345
    # comparison
    try
        @argcheck x == y MyError
        @test false # argcheck shout throw before this is reached
    catch err
        @test isa(err, MyError)
        msg = err.msg
        @test contains(msg, string(x))
        @test contains(msg, string(y))
        @test contains(msg, "x")
        @test contains(msg, "y")
        @test contains(msg, "==")
    end
end
