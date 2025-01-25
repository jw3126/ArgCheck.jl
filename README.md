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
`@argcheck code` is as fast as `@assert` or a hand written `if`.
