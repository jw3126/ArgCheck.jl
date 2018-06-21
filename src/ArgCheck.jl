__precompile__()
module ArgCheck

using Base.Meta
export @argcheck, @check, CheckError

include("checks.jl")
end
