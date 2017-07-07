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

iscomparison_symbol(op) = false
function iscomparison_symbol(op::Symbol)
    precedence = 6 # does this catch all comparisons?
    Base.operator_precedence(op) == precedence
end

iscomparison(ex) = false
function iscomparison(ex::Expr) 
    # TODO
    # support chains like 1 == 2 < 3
    # ex.head == :comparison && return true
    # Expr(:call, ≈, 1, 2) should also be a comparison.
    if ex.head == :call && length(ex.args) == 3
        op = ex.args[1]
        iscomparison_symbol(op) && return true
    end
    return false
end

function argcheck(code, args...)
    if iscomparison(code)
        op, lhs, rhs = code.args
        vlhs = gensym("vlhs")
        vrhs = gensym("vrhs")
        preamble = :($vlhs = $lhs; $vrhs = $rhs)
        condition = Expr(:call, op, vlhs, vrhs)
        err = Expr(:call, :(ArgCheck.build_error_comparison), 
            QuoteNode(code), QuoteNode(lhs), QuoteNode(rhs), vlhs, vrhs, args...)
    else
        preamble = :()
        condition = code
        err = Expr(:call, :(ArgCheck.build_error), QuoteNode(code), args...)
    end
    quote
        $preamble
        if !($condition)
            throw($err)
        end
    end
end

macro argcheck(code,args...)
    esc(argcheck(code, args...))
end
end
