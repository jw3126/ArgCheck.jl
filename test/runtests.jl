using ArgCheck
using Base.Test

import ArgCheck: iscomparison
@testset "iscomparison" begin
    @test iscomparison(:(1==2))
    @test iscomparison(:(f(2x) + 1 ≈ f(x)))
    @test iscomparison(:(<(2,3)))
    @test !iscomparison(:(f(1,1)))

    @test_broken iscomparison_symbol(:(1 == 2 == 3))
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
    @test_throws ArgumentError @argcheck x > 1 "this should not happen"
    @argcheck x>0 # does not throw
    
    n =2; m=3
    @test_throws DimensionMismatch (@argcheck n==m DimensionMismatch)
    @argcheck n==n DimensionMismatch
    
    denominator = 0
    @test_throws DivideError (@argcheck denominator != 0 DivideError())
    @argcheck 1 !=0 DivideError()
end

immutable MyError <: Exception
    msg::String
end

@testset "error message" begin
    x = 1.23455475675
    y = 2.345345345
    # comparison
    try
        @argcheck x == y MyError
        error("@argcheck should throw before this is reached!")
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
