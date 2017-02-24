# ArgCheck

## Usage

Often you have a function like this

```Julia
function f(x)
    # does something awesome
    # but works only if x > 0
end
```
So you need to enforce `x > 0`. The correct way would be:

```Julia
function f(x)
    x > 0 || throw(ArgumentError("x > 0 must hold."))
    # does something awesome
    # but works only if x > 0
end
```
This is quite a mouthful. Especially if your function has more then one argument
that needs checking this becomes quite verbose. See real world examples below.

Often people are too lazy to type the above and replace the above by
```Julia
x > 0 || error("x > 0 must hold.")
```
This is not perfect, because it throws and `ErrorException`, which is less precise then `ArgumentError`. Sometimes

```Julia
@assert x > 0
```
is used, which is very concise, but a misuse `@assert`.

The `@argcheck` macro allows you to be consise and have an appropriate error:

```Julia
julia> using ArgCheck

julia> function f(x)
           @argcheck x > 0
       end
f (generic function with 1 method)

julia> f(1)

julia> f(-1)
ERROR: ArgumentError: x > 0 must hold.
 in f(::Int64) at ./REPL[2]:2
```

You can also customize the error:

```Julia
@argcheck size(A) == size(B) DimensionMismatch
```
```Julia 
@argcheck x > 0 SomeErrorType(my, custom, args)
```


## Examples from the wild

### [Dierckx](https://github.com/kbarbary/Dierckx.jl)

```Julia
function Spline1D(x::AbstractVector, y::AbstractVector,
                  xknots::AbstractVector;
                  w::AbstractVector=ones(length(x)),
                  k::Int=3, bc::AbstractString="nearest")
    m = length(x)
    length(y) == m || error("length of x and y must match")
    length(w) == m || error("length of x and w must match")
    m > k || error("k must be less than length(x)")
    length(xknots) <= m + k + 1 || error("length(xknots) <= length(x) + k + 1 must hold")
    first(x) < first(xknots) || error("first(x) < first(xknots) must hold")
    last(x) > last(xknots) || error("last(x) > last(xknots) must hold")
end
```

```Julia
    @argcheck length(x) == length(y)
    @argcheck length(x) == length(w)
    @argcheck length(x) > k
    @argcheck length(xknots) <= length(x) + k + 1
    @argcheck first(x) < first(xknots)
    @argcheck last(x) > last(xknots)
```

### [LsqFit](https://github.com/JuliaNLSolvers/LsqFit.jl)

```Julia
function levenberg_marquardt{T}(f::Function, g::Function, initial_x::AbstractVector{T};
    tolX::Real = 1e-8, tolG::Real = 1e-12, maxIter::Integer = 100,
    lambda::Real = 10.0, lambda_increase::Real = 10., lambda_decrease::Real = 0.1,
    min_step_quality::Real = 1e-3, good_step_quality::Real = 0.75,
    show_trace::Bool = false, lower::Vector{T} = Array{T}(0), upper::Vector{T} = Array{T}(0)
    )


    # check parameters
    ((isempty(lower) || length(lower)==length(initial_x)) && (isempty(upper) || length(upper)==length(initial_x))) ||
            throw(ArgumentError("Bounds must either be empty or of the same length as the number of parameters."))
    ((isempty(lower) || all(initial_x .>= lower)) && (isempty(upper) || all(initial_x .<= upper))) ||
            throw(ArgumentError("Initial guess must be within bounds."))
    (0 <= min_step_quality < 1) || throw(ArgumentError(" 0 <= min_step_quality < 1 must hold."))
    (0 < good_step_quality <= 1) || throw(ArgumentError(" 0 < good_step_quality <= 1 must hold."))
(min_step_quality < good_step_quality) || throw(ArgumentError("min_step_quality < good_step_quality must hold."))
```

```Julia
    @argcheck isempty(lower) || length(lower) == length(initial_x)
    @argcheck isempty(upper) || length(upper) == length(initial_x)
    @argcheck (isempty(lower) || all(initial_x .>= lower)) && (isempty(upper) || all(initial_x .<= upper)) "Initial guess must be within bounds."
    @argcheck 0 <= min_step_quality < 1
    @argcheck 0 < good_step_quality <= 1
    @argcheck min_step_quality < good_step_quality
```
