---@class KFS_EditModeController
---@field addon KhajiitFengShui Reference to main addon instance
local EditModeController = {};
EditModeController.__index = EditModeController;

---Creates new EditModeController
---@param addon KhajiitFengShui
---@return KFS_EditModeController
function EditModeController:New(addon)
    local controller =
    {
        addon = addon;
    };

    return setmetatable(controller, self);
end;

---Initializes slash commands
function EditModeController:Initialize()
    SLASH_COMMANDS["/kfsedit"] = function ()
        self:ToggleEditMode();
    end;
end;

---Checks if edit mode is active
---@return boolean
function EditModeController:IsEditModeActive()
    return self.addon and self.addon:IsEditModeActive();
end;

---Sets edit mode active state
---@param active boolean
function EditModeController:SetEditModeActive(active)
    if not self.addon then
        return;
    end;

    self.addon:SetEditModeActive(active);
end;

---Toggles edit mode on/off
function EditModeController:ToggleEditMode()
    if not self.addon then
        return;
    end;

    self.addon:ToggleEditMode();
end;

KFS_EditModeController = EditModeController;
