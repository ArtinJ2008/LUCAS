function _json_escape(value::AbstractString)
    io = IOBuffer()
    write(io, '"')
    for character in value
        if character == '"'
            write(io, "\\\"")
        elseif character == '\\'
            write(io, "\\\\")
        elseif character == '\b'
            write(io, "\\b")
        elseif character == '\f'
            write(io, "\\f")
        elseif character == '\n'
            write(io, "\\n")
        elseif character == '\r'
            write(io, "\\r")
        elseif character == '\t'
            write(io, "\\t")
        elseif Int(character) < 0x20
            write(io, "\\u", lowercase(string(Int(character); base=16, pad=4)))
        else
            write(io, character)
        end
    end
    write(io, '"')
    return String(take!(io))
end

function _write_json(io::IO, value)
    if value === nothing || ismissing(value)
        write(io, "null")
    elseif value isa Bool
        write(io, value ? "true" : "false")
    elseif value isa Integer
        write(io, string(value))
    elseif value isa AbstractFloat
        isfinite(value) || throw(ArgumentError("JSON output rejects non-finite floating-point values"))
        write(io, repr(Float64(value)))
    elseif value isa AbstractString || value isa Symbol
        write(io, _json_escape(string(value)))
    elseif value isa NamedTuple
        _write_json(io, Dict(string(key) => item for (key, item) in pairs(value)))
    elseif value isa AbstractDict
        write(io, '{')
        keys_sorted = sort!(collect(keys(value)); by=key -> string(key))
        for (index, key) in enumerate(keys_sorted)
            index > 1 && write(io, ',')
            write(io, _json_escape(string(key)), ':')
            _write_json(io, value[key])
        end
        write(io, '}')
    elseif value isa AbstractVector || value isa Tuple
        write(io, '[')
        for (index, item) in enumerate(value)
            index > 1 && write(io, ',')
            _write_json(io, item)
        end
        write(io, ']')
    else
        throw(ArgumentError("unsupported JSON value of type $(typeof(value))"))
    end
end

function _write_json_file(path::AbstractString, value)
    open(path, "w") do io
        _write_json(io, value)
        write(io, '\n')
    end
    return path
end
