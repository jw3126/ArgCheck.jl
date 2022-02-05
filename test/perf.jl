module Perf
# compare performance with plain assertion
using BenchmarkTools
using ArgCheck

@noinline truthy(x) = x == x

@noinline function fallback_argcheck(x)
    @argcheck x
end
@noinline function comparison_argcheck(x)
    @argcheck x == x
end
@noinline function call_argcheck(x)
    @argcheck truthy(x)
end
@noinline function fallback_assert(x)
    @assert x
end
@noinline function comparison_assert(x)
    @assert x == x
end
@noinline function call_assert(x)
    @assert truthy(x)
end

benchmarks =[
    (fallback_assert, fallback_argcheck, true),
    (call_assert, call_argcheck, 42),
    (comparison_assert, comparison_argcheck, 42),
    ]

for (f_assert, f_argcheck, arg) in benchmarks
    println(f_assert)
    @btime ($f_assert)($arg)
    println(f_argcheck)
    @btime ($f_argcheck)($arg)
end

end#module
