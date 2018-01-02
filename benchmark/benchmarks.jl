@benchgroup "trivial pass" begin
    f_argcheck(x) = @argcheck x
    f_assert(x)   = @assert x
    f_argcheck() = f_argcheck(true)
    f_assert() = f_assert(true)
    @bench "x -> @argcheck x" f_argcheck(x)
    @bench "x -> @assert x" f_assert(x)
    @bench "@argcheck true" f_argcheck()
    @bench "@assert true" f_assert()
end
