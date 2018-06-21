__precompile__()
module ArgCheck

if VERSION < v"0.7-"
    pushfirst!(args...) = unshift!(args...)
end

using Base.Meta
export @argcheck, @check, CheckError

include("checks.jl")
end
