local originalCreateControlFromVirtual = CreateControlFromVirtual
CreateControlFromVirtual = function(controlName, parent, templateName, optionalSuffix)
    if optionalSuffix and controlName and controlName:sub(1, 25) == "ZO_IncreasedPowerTexture" then
        local suffixStr = tostring(optionalSuffix)
        if not controlName:sub(-#suffixStr) == suffixStr then
            controlName = controlName .. optionalSuffix
        end
    end
    return originalCreateControlFromVirtual(controlName, parent, templateName, optionalSuffix)
end
