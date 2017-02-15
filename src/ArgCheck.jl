__precompile__()
module ArgCheck

export @argcheck

build_error{T <: Exception}(code, ::Type{T}, args...) = T(args...)
build_error{T <: Exception}(code, ::Type{T}=ArgumentError) = T("$code must hold.")
build_error(code, msg::AbstractString) = ArgumentError(msg)
build_error(code, err::Exception) = err

function argcheck(code, args...)
	err = Expr(:call, :(ArgCheck.build_error), QuoteNode(code), args...)
	:($code ? nothing : throw($err))
end

macro argcheck(code,args...)
    esc(argcheck(code, args...))
end
end
