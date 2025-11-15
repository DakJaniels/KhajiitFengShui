---@class KFS_UnitFrameAnchors
local UnitFrameAnchors = {};

local PanelUtils = KhajiitFengShui.PanelUtils;
local em = GetEventManager();
local wm = GetWindowManager();

---Group panel IDs that are managed by this module
---Note: These anchor frames are used by:
---  - Regular group member unit frames (GROUP_UNIT_FRAME)
---  - Companion group unit frames (COMPANION_GROUP_UNIT_FRAME) - companions in small groups
---  - Raid unit frames (RAID_UNIT_FRAME)
---  - Companion raid unit frames (COMPANION_RAID_UNIT_FRAME) - companions in large groups
---  - Local companion frames (COMPANION_UNIT_FRAME) - use ZO_SmallGroupAnchorFrame
local GROUP_PANEL_IDS =
{
    "groupAnchorSmall";
    "groupAnchorLarge1";
    "groupAnchorLarge2";
    "groupAnchorLarge3";
};

---Sets up custom control wrapper for a unitframe anchor
---@param customControlName string Name for the custom control
---@param gameControlName string Name of the game control to wrap
---@param width number Width of the custom control
---@param height number Height of the custom control
---@param defaultAnchor fun(customControl: userdata)? Function to set default anchor for new controls
local function setupUnitFrameAnchorWrapper(customControlName, gameControlName, width, height, defaultAnchor)
    local customControl = _G[customControlName];
    local isNewControl = false;
    if not customControl then
        customControl = wm:CreateControl(customControlName, GuiRoot, CT_CONTROL);
        isNewControl = true;
    end;

    local gameControl = GetControl(gameControlName);
    if gameControl then
        -- Use actual game control dimensions for unitframe anchors
        local gameWidth = gameControl:GetWidth() or width;
        local gameHeight = gameControl:GetHeight() or height;
        customControl:SetDimensions(gameWidth, gameHeight);

        -- Only set initial anchor if this is a new control
        if isNewControl and defaultAnchor then
            defaultAnchor(customControl);
        else
            -- If not new, sync position from game control's current screen position
            local gameLeft = gameControl:GetLeft() or 0;
            local gameTop = gameControl:GetTop() or 0;
            -- Anchor our custom control to GuiRoot at the game control's position
            customControl:ClearAnchors();
            customControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, gameLeft, gameTop);
        end;

        -- Always ensure the game control is anchored to our custom control at TOPLEFT
        -- This preserves the anchor frame structure where unit frames anchor relative to these frames
        gameControl:ClearAnchors();
        gameControl:SetAnchor(TOPLEFT, customControl, TOPLEFT, 0, 0);
        -- Ensure game control inherits scale from custom control
        gameControl:SetInheritScale(true);
    else
        customControl:SetDimensions(width, height);
        if isNewControl and defaultAnchor then
            defaultAnchor(customControl);
        end;
    end;

    customControl:SetDrawLayer(DL_CONTROLS);
end;

---Sets up all unitframe anchor control wrappers
function UnitFrameAnchors.SetupAnchors()
    -- Create a custom control for small group frame
    setupUnitFrameAnchorWrapper(
        "KhajiitFengShui_GroupSmall",
        "ZO_SmallGroupAnchorFrame",
        260,
        200,
        function (customControl)
            -- Default position if game control doesn't exist yet
            customControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 28, 100);
        end
    );

    -- Create custom controls for large group frames (raid)
    setupUnitFrameAnchorWrapper(
        "KhajiitFengShui_GroupLarge1",
        "ZO_LargeGroupAnchorFrame1",
        260,
        200,
        function (customControl)
            -- Default position if game control doesn't exist yet
            customControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 28, 100);
        end
    );

    setupUnitFrameAnchorWrapper(
        "KhajiitFengShui_GroupLarge2",
        "ZO_LargeGroupAnchorFrame2",
        260,
        200,
        function (customControl)
            -- Default position if game control doesn't exist yet
            customControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 28, 100);
        end
    );

    setupUnitFrameAnchorWrapper(
        "KhajiitFengShui_GroupLarge3",
        "ZO_LargeGroupAnchorFrame3",
        260,
        200,
        function (customControl)
            -- Default position if game control doesn't exist yet
            customControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 28, 100);
        end
    );
end;

---Applies scale to a group frame panel (custom control + game control)
---@param panel KhajiitFengShuiPanel
---@param scale number
---@param gameControlName string Name of the original game control
local function applyGroupFrameScale(panel, scale, gameControlName)
    local control = panel and panel.control;
    if not control then
        return;
    end;
    -- Apply scale to custom control
    PanelUtils.enableInheritScaleRecursive(control);
    control:SetScale(scale);
    -- Ensure original game control inherits scale
    local gameControl = GetControl(gameControlName);
    if gameControl then
        gameControl:SetInheritScale(true);
        PanelUtils.enableInheritScaleRecursive(gameControl);
    end;
    -- Trigger group frame hooks reapply
    if KhajiitFengShui and KhajiitFengShui.panelLookup then
        local self = KhajiitFengShui;
        UnitFrameAnchors.ReapplyScales(self);
    end;
end;

---Gets the game control name for a group panel ID
---@param panelId string
---@return string?
local function getGameControlName(panelId)
    if panelId == "groupAnchorSmall" then
        return "ZO_SmallGroupAnchorFrame";
    elseif panelId == "groupAnchorLarge1" then
        return "ZO_LargeGroupAnchorFrame1";
    elseif panelId == "groupAnchorLarge2" then
        return "ZO_LargeGroupAnchorFrame2";
    elseif panelId == "groupAnchorLarge3" then
        return "ZO_LargeGroupAnchorFrame3";
    end;
    return nil;
end;

---Applies scale to a unitframe panel
---@param panel KhajiitFengShuiPanel
---@param scale number
function UnitFrameAnchors.ApplyScale(panel, scale)
    if not panel then
        return;
    end;

    local panelId = panel.definition and panel.definition.id;
    if not panelId then
        return;
    end;

    -- Check if this is a group frame
    local gameControlName = getGameControlName(panelId);
    if gameControlName then
        applyGroupFrameScale(panel, scale, gameControlName);
        return;
    end;

    -- For other unitframes, use default scale application
    PanelUtils.applyScale(panel, scale);
end;

---Debounce timer for reapplying positions to prevent jumpiness
local reapplyTimer = nil;

---Reapplies scales and positions for all group frames
---This is called when ZOS updates anchor frames (e.g., when companions are created/destroyed)
---to ensure our custom positions are maintained
---@param self KhajiitFengShui
function UnitFrameAnchors.ReapplyScales(self)
    if not self or not self.panelLookup then
        return;
    end;

    for _, panelId in ipairs(GROUP_PANEL_IDS) do
        local panel = self.panelLookup[panelId];
        if panel and panel.control then
            -- Don't reapply if mover is disabled
            if not self:IsMoverEnabled(panelId) then
                -- If disabled, ensure game control is not anchored to our custom control
                -- Let ZOS manage it directly
                local gameControlName = getGameControlName(panelId);
                if gameControlName then
                    local gameControl = GetControl(gameControlName);
                    if gameControl then
                        -- Reset to default scale
                        local defaultScale = panel.defaultScale or 1;
                        PanelUtils.enableInheritScaleRecursive(gameControl);
                        gameControl:SetInheritScale(false);
                        if panel.control then
                            panel.control:SetTransformScale(defaultScale);
                        end;
                    end;
                end;
                -- Skip this panel - continue to next iteration
            else
                local scale = self:GetPanelScale(panelId);
                panel.control:SetTransformScale(scale);
                PanelUtils.enableInheritScaleRecursive(panel.control);

                -- Always reapply saved position if we have one
                -- ZOS's UpdateGroupAnchorFrames may have moved the game control, breaking our setup
                if self.savedVars and self.savedVars.positions and self.savedVars.positions[panelId] then
                    local savedPosition = self.savedVars.positions[panelId];
                    -- Reapply saved position to restore our custom control position
                    UnitFrameAnchors.ApplyAnchor(panel, savedPosition);
                end;

                -- Always ensure game control is anchored to our custom control
                -- ZOS re-anchors it to GuiRoot during UpdateGroupAnchorFrames, breaking our setup
                local gameControlName = getGameControlName(panelId);
                if gameControlName then
                    local gameControl = GetControl(gameControlName);
                    if gameControl then
                        gameControl:ClearAnchors();
                        gameControl:SetAnchor(TOPLEFT, panel.control, TOPLEFT, 0, 0);
                        gameControl:SetInheritScale(true);
                    end;
                end;

                -- Sync overlay size and position to match actual frame dimensions after scale update
                PanelUtils.syncOverlaySize(panel);
            end;
        end;
    end;

    local unitFramesGroups = GetControl("ZO_UnitFramesGroups");
    if unitFramesGroups then
        local maxScale = 1;
        for _, panelId in ipairs(GROUP_PANEL_IDS) do
            local panel = self.panelLookup[panelId];
            -- Only include enabled movers in scale calculation
            if panel and self:IsMoverEnabled(panelId) then
                local scale = self:GetPanelScale(panelId);
                if scale > maxScale then
                    maxScale = scale;
                end;
            end;
        end;
        if maxScale ~= 1 then
            PanelUtils.enableInheritScaleRecursive(unitFramesGroups);
            unitFramesGroups:SetTransformScale(maxScale);
        else
            -- Reset to default scale if no enabled movers
            unitFramesGroups:SetTransformScale(1);
        end;
    end;
end;

---Checks if a panel ID is a unitframe anchor panel
---@param panelId string
---@return boolean
function UnitFrameAnchors.IsUnitFrameAnchor(panelId)
    for _, id in ipairs(GROUP_PANEL_IDS) do
        if id == panelId then
            return true;
        end;
    end;
    return false;
end;

---Schedules a debounced reapplication of positions and scales
---@param self KhajiitFengShui
---@param delay number?
local function scheduleReapply(self, delay)
    delay = delay or 250;

    -- Clear existing timer if any
    if reapplyTimer then
        zo_removeCallLater(reapplyTimer);
    end;

    -- Set new timer
    reapplyTimer = zo_callLater(function ()
                                    if self then
                                        UnitFrameAnchors.ReapplyScales(self);
                                    end;
                                    reapplyTimer = nil;
                                end, delay);
end;

---Ensures group frame hooks are registered
---@param self KhajiitFengShui
function UnitFrameAnchors.EnsureHooks(self)
    if self.groupFrameHooksRegistered then
        return;
    end;

    -- Hook into ZOS unitframe manager to reapply positions AFTER ZOS updates anchor frames
    -- This is the main hook - ZOS calls this when anchor frames need repositioning
    -- (e.g., when companions are created/destroyed, group size changes, etc.)
    SecurePostHook(
        ZO_UnitFrames_Manager,
        "UpdateGroupAnchorFrames",
        function ()
            -- Check if any group frame movers are enabled before reapplying
            local hasEnabledMovers = false;
            for _, panelId in ipairs(GROUP_PANEL_IDS) do
                if self:IsMoverEnabled(panelId) then
                    hasEnabledMovers = true;
                    break;
                end;
            end;
            if hasEnabledMovers then
                -- Use a delay to let ZOS finish its updates, then restore our positions
                scheduleReapply(self, 100);
            end;
        end
    );

    -- Hook into group updates - but only reapply if we have custom positions and enabled movers
    -- This prevents unnecessary repositioning when user hasn't moved frames or movers are disabled
    em:RegisterForEvent(
        self.name .. "_GROUP_UPDATE",
        EVENT_GROUP_UPDATE,
        function ()
            -- Check if we have any custom positions and enabled movers before reapplying
            if self.savedVars and self.savedVars.positions then
                local hasCustomPositions = false;
                local hasEnabledMovers = false;
                for _, panelId in ipairs(GROUP_PANEL_IDS) do
                    if self.savedVars.positions[panelId] then
                        hasCustomPositions = true;
                    end;
                    if self:IsMoverEnabled(panelId) then
                        hasEnabledMovers = true;
                    end;
                end;
                if hasCustomPositions and hasEnabledMovers then
                    scheduleReapply(self, 150);
                end;
            end;
        end
    );

    -- Hook companion state changes - only reapply if we have custom positions and enabled movers
    -- Companions (local, group, and raid) all use the same anchor frames as group members
    em:RegisterForEvent(
        self.name .. "_COMPANION_STATE_CHANGED",
        EVENT_ACTIVE_COMPANION_STATE_CHANGED,
        function ()
            if self.savedVars and self.savedVars.positions then
                local hasCustomPositions = false;
                local hasEnabledMovers = false;
                for _, panelId in ipairs(GROUP_PANEL_IDS) do
                    if self.savedVars.positions[panelId] then
                        hasCustomPositions = true;
                    end;
                    if self:IsMoverEnabled(panelId) then
                        hasEnabledMovers = true;
                    end;
                end;
                if hasCustomPositions and hasEnabledMovers then
                    -- Delay to let ZOS finish companion frame creation/destruction
                    scheduleReapply(self, 200);
                end;
            end;
        end
    );

    self.groupFrameHooksRegistered = true;
end;

---Syncs overlay size for unitframe anchors
---@param panel KhajiitFengShuiPanel
function UnitFrameAnchors.SyncOverlaySize(panel)
    if not panel then
        return;
    end;

    local panelId = panel.definition and panel.definition.id;
    if not panelId or not UnitFrameAnchors.IsUnitFrameAnchor(panelId) then
        return;
    end;

    PanelUtils.syncOverlaySize(panel);
end;

---Applies anchor from saved position to unitframe anchor control
---Note: Position is already snapped by LCA MoveableControl if snapping is enabled
---@param panel KhajiitFengShuiPanel
---@param position KFS_Position Position to apply (already snapped by LCA)
function UnitFrameAnchors.ApplyAnchor(panel, position)
    if not panel or not position then
        return;
    end;

    local control = panel.control;
    if not (control and control.SetAnchor) then
        return;
    end;

    -- Unitframe anchors are always anchored to GuiRoot TOPLEFT
    -- Position is already snapped by LCA MoveableControl, so just apply it directly
    local left = position.left or 0;
    local top = position.top or 0;

    -- Anchor the custom wrapper control to GuiRoot (matching ZOS anchor frame structure)
    control:ClearAnchors();
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top);

    -- The game control should already be anchored to our custom control via SetupAnchors
    -- but ensure it stays anchored correctly
    local gameControlName = getGameControlName(panel.definition.id);
    if gameControlName then
        local gameControl = GetControl(gameControlName);
        if gameControl then
            gameControl:ClearAnchors();
            gameControl:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0);
        end;
    end;
end;

KhajiitFengShui.UnitFrameAnchors = UnitFrameAnchors;
