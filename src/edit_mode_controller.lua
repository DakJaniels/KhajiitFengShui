local EditModeController = {};
EditModeController.__index = EditModeController;

function EditModeController:New(addon)
    local controller =
    {
        addon = addon;
    };

    return setmetatable(controller, self);
end;

function EditModeController:Initialize()
    SLASH_COMMANDS["/kfsedit"] = function ()
        self:ToggleEditMode();
    end;
end;

function EditModeController:IsEditModeActive()
    return self.addon and self.addon:IsEditModeActive();
end;

function EditModeController:SetEditModeActive(active)
    if not self.addon then
        return;
    end;

    self.addon:SetEditModeActive(active);
end;

function EditModeController:ToggleEditMode()
    if not self.addon then
        return;
    end;

    self.addon:ToggleEditMode();
end;

KFS_EditModeController = EditModeController;
