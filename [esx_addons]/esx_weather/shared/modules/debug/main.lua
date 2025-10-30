Shared = Shared or {}
Shared.Modules = Shared.Modules or {}
Shared.Modules.Debug = Shared.Modules.Debug or {}

Shared.Modules.Debug.print = function(...)
    if Config.debug then
        print("^5[DEBUG]^7", ...)
    end
end
