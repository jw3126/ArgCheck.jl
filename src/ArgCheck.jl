__precompile__()
module ArgCheck

export @argcheck

macro argcheck(code)
    msg = "$code must hold."
    :($(esc(code)) ? nothing : throw(ArgumentError($msg)))
end


end
