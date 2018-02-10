__precompile__()
module ArgCheck
using Base.Meta
export @argcheck, @check

include("checks.jl")
end
