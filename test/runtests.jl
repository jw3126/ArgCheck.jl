using ArgCheck
if VERSION < v"0.7.0-"
    using Base.Test
else
    using Test
    using Random
    contains(haystick, needle) = occursin(needle, haystick)
end

include("checks.jl")
include("perf.jl")
