# compare performance with plain assertion
using BenchmarkTools
using ArgCheck

truthy(x) = true

function fallback_argcheck(x)
    @argcheck x
end
function comparison_argcheck(x)
    @argcheck x == x
end
function call_argcheck(x)
    @argcheck truthy(x)
end
function fallback_assert(x)
    @assert x
end
function comparison_assert(x)
    @assert x == x
end
function call_assert(x)
    @assert truthy(x)
end

benchmarks =[
    (fallback_assert, fallback_argcheck, true),
    (call_assert, call_argcheck, 42),
    (comparison_assert, comparison_argcheck, 42),
    ]

for (f_argcheck, f_assert, arg) in benchmarks
    println(f_argcheck)
    @btime ($f_argcheck)($arg)
    println(f_assert)
    @btime ($f_assert)($arg)
end
