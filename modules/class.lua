-- Class Constructor --

return function(base, init)
    local c = {}
    if base then
        for i, v in pairs(base) do
            c[i] = v
        end
        c._base = base
    end
    c.__index = c
    local mt = {}
    mt.__call = function(class_tbl, ...)
        local obj = {}
        setmetatable(obj, c)
        local ctor = class_tbl.init or init or (base and base.init)
        if ctor then ctor(obj, ...) end
        return obj
    end
    c.init = init
    setmetatable(c, mt)
    return c
end