FiveFY.Bridge.Register({
    name = "standalone",

    GetIdentifier = function(source)
        local license = FiveFY.Bridge.GetLicense(source)
        return license and ("license:" .. license) or nil
    end
})
