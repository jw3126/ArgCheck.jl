using ArgCheck
using Base.Test
import ArgCheck: build_error
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
