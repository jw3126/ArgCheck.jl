# ArgCheck

[![Build Status](https://travis-ci.org/jw3126/ArgCheck.jl.svg?branch=master)](https://travis-ci.org/jw3126/ArgCheck.jl)
[![Coverage Status](https://coveralls.io/repos/github/jw3126/ArgCheck.jl/badge.svg?branch=master)](https://coveralls.io/github/jw3126/ArgCheck.jl?branch=master)
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
@argcheck det(A) < 0 DomainError()
@argcheck false MyCustomError(my, args...)
```
