# ArgCheck

```
julia> using ArgCheck

julia> function f(x)
           x == 0 && throw(ArgumentError("x != 0 must hold"))
           1/x
       end
f (generic function with 1 method)

julia> f(0)
ERROR: ArgumentError: x != 0 must hold
 in f(::Int64) at ./REPL[10]:2

julia> function f2(x)
           @argcheck x != 0
           1/x
       end
f2 (generic function with 1 method)

julia> f2(0)
ERROR: ArgumentError: x != 0 must hold.
 in f2(::Int64) at ./REPL[12]:2
```
