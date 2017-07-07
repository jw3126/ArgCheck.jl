__precompile__()
module ArgCheck

export @argcheck

build_error{T <: Exception}(code, ::Type{T}, args...) = T(args...)
build_error{T <: Exception}(code, ::Type{T}=ArgumentError) = T("$code must hold.")
build_error(code, msg::AbstractString) = ArgumentError(msg)
build_error(code, err::Exception) = err

build_error_comparison(code, lhs, rhs, vlhs, vrhs, args...) = build_error(code, args...)
build_error_comparison{T <: Exception}(code, lhs, rhs, vlhs, vrhs, ::Type{T}=ArgumentError) =
    T("""$code must hold. Got
    $lhs => $vlhs
    $rhs => $vrhs""")

function is_comparison_call(ex::Expr)
    ex.head == :call &&
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

function argcheck_fallback(ex, args...)
    quote
        if !($ex)
            err = ArgCheck.build_error($(QuoteNode(ex)), $(args...))
            throw(err)
        end
    end
end

function argcheck_comparison(ex, args...)
    exprs = ex.args[1:2:end]
    ops = ex.args[2:2:end]
    variables = map(gensym, [string("v$i") for i in 1:length(exprs)])
    ret = quote end
    rhs = exprs[1]
    vrhs = variables[1]
    assignment = Expr(:(=), vrhs, rhs)
    push!(ret.args, assignment)
    for i in eachindex(ops)   
        op = ops[i]
        lhs = rhs
        vlhs = vrhs
        rhs = exprs[i+1]
        vrhs = variables[i+1]
        assignment = Expr(:(=), vrhs, rhs)
        condition = Expr(:call, op, vlhs, vrhs)
        code = Expr(:call, op, lhs, rhs)
        err = Expr(:call, :(ArgCheck.build_error_comparison), 
            QuoteNode(code), QuoteNode(lhs), QuoteNode(rhs), 
            vlhs, vrhs, args...)
        reti = quote
            $assignment
            if !($condition)
                throw($err)
            end
        end
        append!(ret.args, reti.args)
    end
    ret
end

function argcheck(ex, args...)
    ex = canonicalize(ex)
    if !isa(ex, Expr) 
        argcheck_fallback(ex, args...)
    elseif ex.head == :comparison
        argcheck_comparison(ex, args...)
    else
        argcheck_fallback(ex, args...)
    end
end

macro argcheck(code,args...)
    esc(argcheck(code, args...))
end
end
