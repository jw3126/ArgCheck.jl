struct CheckError <: Exception
    msg::String
end

Base.showerror(io::IO, err::CheckError) = print(io, "CheckError: $(err.msg)")

abstract type AbstractCheckFlavor end
struct ArgCheckFlavor <: AbstractCheckFlavor end
struct CheckFlavor    <: AbstractCheckFlavor end

abstract type AbstractCodeFlavor end
struct CallFlavor       <: AbstractCodeFlavor end
struct ComparisonFlavor <: AbstractCodeFlavor end
struct FallbackFlavor   <: AbstractCodeFlavor end

struct Checker
    code
    checkflavor::AbstractCheckFlavor
    codeflavor::AbstractCodeFlavor
    options
end

abstract type AbstractErrorInfo end
struct CallErrorInfo <: AbstractErrorInfo
    code
    checkflavor::AbstractCheckFlavor
    argument_expressions::Vector
    argument_values::Vector
    options::Tuple
end
struct ComparisonErrorInfo <: AbstractErrorInfo
    code
    checkflavor::AbstractCheckFlavor
    argument_expressions::Vector
    argument_values::Vector
    options::Tuple
end
struct FallbackErrorInfo <: AbstractErrorInfo
    code
    checkflavor::AbstractCheckFlavor
    options::Tuple
end

"""
    @argcheck

Check invariants on function arguments and produce
a nice exception message if they are violated.
Usage is as follows:
```Julia
function myfunction(k,n,A,B)
    @argcheck k > n
    @argcheck size(A) == size(B) DimensionMismatch
    @argcheck det(A) < 0 DomainError()
    # doit
end
```
See also [`@check`](@ref).
"""
macro argcheck(ex, options...)
    check(ex, ArgCheckFlavor(), options...)
end

"""
    @check

Check that a condition holds
and produce a nice exception message, if it does not.
Usage is as follows:
```Julia
@check k > n
@check size(A) == size(B) DimensionMismatch
@check det(A) < 0 DomainError()
```
See also [`@argcheck`](@ref).
"""
macro check(ex, options...)
    check(ex, CheckFlavor(), options...)
end

function check(ex, checkflavor, options...)
    codeflavor = if isexpr(ex, :comparison)
        ComparisonFlavor()
    elseif is_simple_call(ex)
        CallFlavor()
    else
        FallbackFlavor()
    end
    checker = Checker(ex, checkflavor, codeflavor, options)
    check(checker, codeflavor)
end

function is_simple_call(ex)
    isexpr(ex, :call) || return false
    for arg in ex.args
        isexpr(arg, :parameters) && return false
        isexpr(arg, :kw) && return false
        isexpr(arg, Symbol("...")) && return false
    end
    true
end

function check(c, ::FallbackFlavor)
    info = Expr(:call, :FallbackErrorInfo,
                QuoteNode(c.code),
                c.checkflavor,
                Expr(:tuple, esc.(c.options)...))

    condition = esc(c.code)
    expr_error_block(info, condition)
end

function check(c, ::CallFlavor)
    variables = [gensym() for _ in 1:length(c.code.args)]
    assignments = map(variables, c.code.args) do vi, exi
        Expr(:(=), vi, esc(exi))
    end
    condition = Expr(:call, variables...)
    info = Expr(:call, :CallErrorInfo,
                QuoteNode(c.code),
                c.checkflavor,
                QuoteNode(c.code.args),
                Expr(:vect, variables...),
                Expr(:tuple, esc.(c.options)...))
    expr_error_block(info, condition, assignments...)
end

function check(c::Checker, ::ComparisonFlavor)
    exprs = c.code.args[1:2:end]
    ops = c.code.args[2:2:end]
    variables = [gensym() for _ in 1:length(exprs)]
    ret = []
    rhs = exprs[1]
    vrhs = variables[1]
    assignment = Expr(:(=), vrhs, esc(rhs))
    push!(ret, assignment)
    for i in eachindex(ops)
        op = ops[i]
        lhs = rhs
        vlhs = vrhs
        rhs = exprs[i+1]
        vrhs = variables[i+1]
        assignment = Expr(:(=), vrhs, esc(rhs))
        condition = Expr(:call, esc(op), vlhs, vrhs)
        code = Expr(:call, op, lhs, rhs)
        info = Expr(:call, :ComparisonErrorInfo,
                    QuoteNode(code),
                    c.checkflavor,
                    QuoteNode([lhs, rhs]),
                    Expr(:vect, vlhs, vrhs),
                    Expr(:tuple, esc.(c.options)...))

        reti = expr_error_block(info, condition, assignment)
        append!(ret, reti.args)
    end
    Expr(:block, ret...)
end

function expr_error_block(info, condition, preamble...)
    reti = quote
        $(preamble...)
        if $condition
            nothing
        else
            throw(build_error($info))
        end
    end
end

default_exception_type(::ArgCheckFlavor) = ArgumentError
default_exception_type(::CheckFlavor) = CheckError

function build_error(info)
    build_error(info, info.checkflavor, info.options...)
end
function build_error(info, checkflavor, msg::AbstractString)
    E = default_exception_type(checkflavor)
    E(msg)
end

function build_error(info, checkflavor,
                     T::Type{<:Exception}=default_exception_type(checkflavor))
    msg = error_message(info)
    T(msg)
end
function build_error(info, checkflavor, err::Exception)
    err
end

error_message(info::FallbackErrorInfo) = "$(info.code) must hold."
error_message(info::CallErrorInfo) = fancy_error_message(info)
error_message(info::ComparisonErrorInfo) = fancy_error_message(info)

function pretty_string(data)
    io = IOBuffer()
    ioc = IOContext(io, :limit=>true, :compact=>true)
    show(ioc, data)
    seekstart(io)
    String(take!(io))
end
pretty_string(x::Number) = string(x)
pretty_string(s::Symbol) = string(s)
pretty_string(ex::Expr) = string(ex)

function fancy_error_message(info)
    code = info.code
    exprs = info.argument_expressions
    values = info.argument_values
    lines = String[]
    foreach(exprs, values) do ex, val
        pex = pretty_string(ex)
        pval = pretty_string(val)
        if pex != pval
            push!(lines, "$pex => $pval")
        end
    end
    firstline = if isempty(lines)
        "$code must hold."
    else
        "$code must hold. Got"
    end
    pushfirst!(lines, firstline)
    join(lines, '\n')
end
