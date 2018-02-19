using ArgCheck
if VERSION < v"0.7.0-"
    using Base.Test
else
    using Test
end

include("checks.jl")
