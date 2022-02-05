module ArgCheck

using Base.Meta
using MacroTools: @q

export @argcheck, @check, CheckError

include("checks.jl")
end
