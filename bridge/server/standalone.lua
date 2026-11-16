FiveFly.Bridge.Register({
    name = "standalone",

    GetIdentifier = function(source)
        local license = FiveFly.Bridge.GetLicense(source)
        return license and ("license:" .. license) or nil
    end
})
