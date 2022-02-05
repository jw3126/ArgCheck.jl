struct LabelArgCheck end
const LABEL_ARGCHECK = LabelArgCheck()

const LABEL_BEGIN_CHECK = Expr(:meta, :begin_optional, LABEL_ARGCHECK)
const LABEL_END_CHECK = Expr(:meta, :end_optional, LABEL_ARGCHECK)

function mark_check(code)
    # Mark a code block as check, for usage with OptionalArgChecks.jl
    Expr(:block,
        LABEL_BEGIN_CHECK,
        code,
        LABEL_END_CHECK,
     )
end

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
struct SubtypeFlavor    <: AbstractCodeFlavor end
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
struct SubtypeErrorInfo <: AbstractErrorInfo
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
    elseif isexpr(ex, :call)
        CallFlavor()
    elseif isexpr(ex, :(<:))
        SubtypeFlavor()
    else
        FallbackFlavor()
    end
    checker = Checker(ex, checkflavor, codeflavor, options)
    inner = check(checker, codeflavor)
    mark_check(inner)
end

function check(c, ::FallbackFlavor)
    info = Expr(:call, :FallbackErrorInfo,
                QuoteNode(c.code),
                c.checkflavor,
                Expr(:tuple, esc.(c.options)...))

    condition = esc(c.code)
    expr_error_block(info, condition)
end

const SPLAT = Symbol("...")

function analyze_call_arg(expr, isparameter)
    if isexpr(expr, :kw)
        (kind=:kw, expr=expr.args[2], key=expr.args[1], symbol=gensym("kw"), isparameter=isparameter)
    elseif isexpr(expr, SPLAT)
        (kind=:splat, expr=expr.args[1], symbol=gensym("splat"), isparameter=isparameter)
    elseif isparameter
        if expr isa Symbol
            # e.g. ;foo
            (kind=:kw, expr=expr, key=expr, symbol=gensym("arg"), isparameter=isparameter)
        else
            # e.g. ;foo => bar
            (kind=:ghost, expr=expr, isparameter=isparameter)
        end
    else
        (kind=:arg, expr=expr, symbol=gensym("arg"), isparameter=isparameter)
    end
end

function analyze_call(expr)
    @assert Meta.isexpr(expr, :call)
    args = []
    kw_args = []
    for item in expr.args[2:end]
        if Meta.isexpr(item, :parameters)
            append!(kw_args, analyze_call_arg.(item.args, true))
        else
            push!(args, analyze_call_arg(item, false))
        end
    end
    pushfirst!(args, (kind=:calle, expr=expr.args[1], symbol=gensym("calle")))
    append!(args, kw_args)
    return (args=args, expr=expr)
end

function build_call(ana)
    @assert :args in propertynames(ana)
    @assert :expr in propertynames(ana)
    arglist = []
    parameterlist = []
    for item in ana.args[2:end]
        list =  item.isparameter ? parameterlist : arglist
        if item.kind == :arg
            push!(list, item.symbol)
        elseif item.kind == :kw
            push!(list, Expr(:kw, item.key, item.symbol))
        elseif item.kind == :splat
            push!(list, Expr(SPLAT, item.symbol))
        elseif item.kind == :ghost
            push!(list, esc(item.expr))
        else
            error("Unreachable $item $ana")
        end
    end
    callargs = copy(arglist)
    if !isempty(parameterlist)
        pushfirst!(callargs, Expr(:parameters, parameterlist...))
    end
    item = ana.args[1]
    @assert item.kind == :calle
    f = item.symbol
    return Expr(:call, f, callargs...)
end

function check(c::Checker, ::CallFlavor)
    ana = analyze_call(c.code)
    variables = []
    argument_expressions = []
    assignments = []
    for item in ana.args
        if item.kind == :ghost
            nothing
        else
            push!(variables, item.symbol)
            push!(argument_expressions, item.expr)
            push!(assignments, :($(item.symbol) = $(esc(item.expr))))
        end
    end
    condition = build_call(ana)
    info = Expr(:call, :CallErrorInfo,
                QuoteNode(c.code),
                c.checkflavor,
                QuoteNode(argument_expressions),
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

function check(c::Checker, ::SubtypeFlavor)
    lhs, rhs = c.code.args
    vlhs, vrhs = gensym(:lhs), gensym(:rhs)

    condition = Expr(:(<:), vlhs, vrhs)
    assignments = (Expr(:(=), vlhs, esc(lhs)), Expr(:(=), vrhs, esc(rhs)))
    info = Expr(:call, :SubtypeErrorInfo,
                QuoteNode(c.code),
                c.checkflavor,
                QuoteNode([lhs, rhs]),
                Expr(:vect, vlhs, vrhs),
                Expr(:tuple, esc.(c.options)...))

    expr_error_block(info, condition, assignments...)
end

function expr_error_block(info, condition, preamble...)
    quote
        $(preamble...)
        if $condition
            nothing
        else
            throw_check_error($info)
        end
    end |> Base.remove_linenums!
end

@noinline function throw_check_error(info...)::Union{}
    # the compiler sometimes deoptimizes functions with inline errors
    @nospecialize
    err = build_error(info...)
    throw(err)
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
error_message(info::SubtypeErrorInfo) = fancy_error_message(info)

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
