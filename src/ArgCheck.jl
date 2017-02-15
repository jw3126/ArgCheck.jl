__precompile__()
module ArgCheck

export @argcheck

function argcheck(code, msg="$code must hold.")
    :($code ? nothing : throw(ArgumentError($msg)))
end

macro argcheck(code)
    esc(argcheck(code))
end
macro argcheck(code, msg)
    esc(argcheck(code, msg))
end

end
