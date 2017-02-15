using ArgCheck
using Base.Test

x = 1
@test_throws ArgumentError (@argcheck x > 1) 
@argcheck x>0 # does not throw
