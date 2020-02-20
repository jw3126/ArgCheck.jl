# ArgCheck

[![Build Status](https://travis-ci.org/jw3126/ArgCheck.jl.svg?branch=master)](https://travis-ci.org/jw3126/ArgCheck.jl)
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
```

### Performance
`@argcheck code` is as fast as `@assert` or a hand written `if`. That being said it is possible to erase argchecks, much like one can erase bounds checking using `@inbounds`. This is implemented in [OptionalArgChecks.jl](https://github.com/simeonschaub/OptionalArgChecks.jl):

```julia
using OptionalArgChecks # this also reexports ArgCheck.jl for convenience

f(x) = @argcheck x > 0

@unsafe_skipargcheck f(-1) # see OptionalArgChecks docs for why this is called unsafe
```
