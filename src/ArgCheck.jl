__precompile__()
module ArgCheck
using Base.Meta
export @argcheck

"""
    @argcheck

Macro for checking invariants on function arguments.
It can be used as follows:
```Julia
function myfunction(k,n,A,B)
    @argcheck k > n
    @argcheck size(A) == size(B) DimensionMismatch
    @argcheck det(A) < 0 DomainError()
    # doit
end
```
"""
macro argcheck(ex, options...)
    ex = canonicalize(ex)
    if isexpr(ex, :comparison)
        argcheck_comparison(ex, options...)
    elseif is_simple_call(ex)
        argcheck_call(ex, options...)
    else
        argcheck_fallback(ex, options...)
    end
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

function argcheck_fallback(ex, options...)
    quote
        if $(esc(ex))
            nothing
        else
            err = ArgCheck.build_error($(QuoteNode(ex)), $(esc.(options)...))
            throw(err)
        end
    end
end

function argcheck_call(ex, options...)
    variables = [gensym() for _ in 1:length(ex.args)]
    assignments = map(variables, ex.args) do vi, exi
        Expr(:(=), vi, esc(exi))
    end
    condition = Expr(:call, variables...)
    values = :([$(variables...)])
    err = Expr(:call, 
        :(ArgCheck.build_error_with_fancy_message), 
        QuoteNode(ex),
        QuoteNode(ex.args),
        values,
        esc.(options)...
    )
    quote
        $(assignments...)
        if $condition
            nothing
        else
            throw($err)
        end
    end
end

function argcheck_comparison(ex, options...)
    exprs = ex.args[1:2:end]
    ops = ex.args[2:2:end]
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
        err = Expr(:call, :(ArgCheck.build_error_comparison), 
            QuoteNode(code), QuoteNode(lhs), QuoteNode(rhs), 
            vlhs, vrhs, esc.(options)...)
        reti = quote
            $assignment
            if $condition
                nothing
            else
                throw($err)
            end
        end
        append!(ret, reti.args)
    end
    Expr(:block, ret...)
end

function build_error(code, T::Type{<:Exception}, options...) 
    ret = T(options...)
    warn("`@argcheck condition $T $(join(options, ' ')...)` is deprecated. Use `@argcheck condition $ret` instead")
    ret 
end
function build_error(code, msg::AbstractString)
    ArgumentError(msg)
end
build_error(code, T::Type{<:Exception}=ArgumentError) = T("$code must hold.")
build_error(code, err::Exception) = err

build_error_comparison(code, lhs, rhs, vlhs, vrhs, options...) = build_error(code, options...)
@noinline function build_error_comparison(code, lhs, rhs, vlhs, vrhs, T::Type{<:Exception}=ArgumentError)
    build_error_with_fancy_message(code, [lhs, rhs], [vlhs, vrhs], T)
end

build_error_with_fancy_message(code, variables, values, options...) = build_error(code, options...)
@noinline function build_error_with_fancy_message(code, variables, values,
                                        T::Type{<:Exception}=ArgumentError)
    msg = fancy_error_message(code, variables, values)
    T(msg)
end

function fancy_error_message(code, exprs, values)
    lines = String[]
    foreach(exprs, values) do ex, val
        sex = string(ex)
        sval = string(val)
        if sex != sval
            push!(lines, "$sex => $sval")
        end
    end
    firstline = if isempty(lines)
        "$code must hold."
    else
        "$code must hold. Got"
    end
    unshift!(lines, firstline)
    join(lines, '\n')
end

function is_comparison_call(ex)
    isexpr(ex, :call) &&
    length(ex.args) == 3 &&
    is_comparison_op(ex.args[1])
end
is_comparison_op(op) = false
function is_comparison_op(op::Symbol)
    precedence = 6 # does this catch all comparisons?
    Base.operator_precedence(op) == precedence
end

canonicalize(x) = x
function canonicalize(ex::Expr)
    if is_comparison_call(ex)
        op, lhs, rhs = ex.args
        Expr(:comparison, lhs, op, rhs)
    else
        ex
    end
end
end
