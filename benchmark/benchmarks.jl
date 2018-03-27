using ArgCheck

@benchgroup "literal true" begin
    f_argcheck() = @argcheck true
    f_assert() = @assert true
    @bench "@argcheck" f_argcheck()
    @bench "@assert" f_assert()
end

@benchgroup "variable true" begin
    f_argcheck(x) = @argcheck x
    f_assert(x)   = @assert x
    x = true
    @bench "@argcheck" f_argcheck($x)
    @bench "@assert" f_assert($x)
end

@benchgroup "computed true" begin
    uvw_argcheck(u,v,w) = @argcheck (u^2 + v^2 + w^2) ≈ 1
    uvw_assert(u,v,w) = @assert (u^2 + v^2 + w^2) ≈ 1
    u = 1f0; v=w=0f0
    @bench "@argcheck" uvw_argcheck($u,$v,$w)
    @bench "@assert" uvw_assert($u,$v,$w)
end
