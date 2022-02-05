# ArgCheck

![CI](https://github.com/jw3126/ArgCheck.jl/workflows/CI/badge.svg)
[![codecov.io](https://codecov.io/github/jw3126/ArgCheck.jl/coverage.svg?branch=master)](http://codecov.io/github/jw3126/ArgCheck.jl?branch=master)
## Installation
```Julia
Pkg.add("ArgCheck")
```

## Usage
```Julia
using ArgCheck

function f(x,y)
    @argcheck cos(x) < sin(y)
    # doit
end

f(0,0)
ERROR: ArgumentError: cos(x) < sin(y) must hold. Got
cos(x) => 1.0
sin(y) => 0.0
```
You can also customize the error:

```Julia
@argcheck k > n
@argcheck size(A) == size(B) DimensionMismatch
@argcheck det(A) < 0 DomainError
@argcheck false MyCustomError(my, args...)
@argcheck isfinite(x) "custom error message"
```

### Performance
`@argcheck code` is as fast as `@assert` or a hand written `if`. That being said it is possible to erase argchecks, much like one can erase bounds checking using `@inbounds`. This is implemented in [OptionalArgChecks.jl](https://github.com/simeonschaub/OptionalArgChecks.jl):

```julia
using OptionalArgChecks # this also reexports ArgCheck.jl for convenience

f(x) = @argcheck x > 0

@unsafe_skipargcheck f(-1)
```
This feature is currently experimental. It may be silently changed or removed without increasing the major ArgCheck version number.
See the OptionalArgChecks documentation for some of the caveats.
