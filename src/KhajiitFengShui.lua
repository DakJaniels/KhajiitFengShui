local ADDON_NAME = "KhajiitFengShui";
local ADDON_VERSION = "1.0.9";

--- @class KhajiitFengShui
local KhajiitFengShui =
{
    name = ADDON_NAME;
    displayName = GetString(KFS_NAME);
    version = ADDON_VERSION;
    savedVars = nil;
    accountSavedVars = nil;
    characterSavedVars = nil;
    panels = {};
    panelLookup = {};
    activePanelId = nil;
    editModeFocusId = nil;
    profileMode = nil;
    editModeActive = false;
    editModeController = nil;
    gridOverlay = nil;
    keybindStripDescriptor = nil;
    keybindStripActive = false;
    keybindSceneCallbacks = {};
    keybindSceneGroups = {};
    keybindStripReduced = false;
    keybindStripOriginalHeight = nil;
    keybindStripBackgroundOriginalHeight = nil;
    keybindStripBackgroundTextureOriginalHeight = nil;
    keybindStripCenterAdjusted = false;
    keybindStripBackgroundWasHidden = nil;
    keybindFragmentSceneName = nil;
    keybindScenes = nil;
    actionLayerName = nil;
    actionLayerActive = false;
    editModeHintShown = false;
    compassHookRegistered = false;
    buffAnimationHookRegistered = false;
    globalCooldownActive = false;
    groupFrameHooksRegistered = false;
};

KhajiitFengShui.defaults =
{
    grid =
    {
        enabled = false;
        size = 15;
    };
    positions = {};
    scales = {};
    buffAnimationsEnabled = false;
    globalCooldownEnabled = false;
    profileMode = "account";
    pyramidLayoutEnabled = false;
    pyramidOffset = { left = 0; top = 0 };
    alwaysExpandedBars = false;
};

local SCALE_MIN_PERCENT = 50;
local SCALE_MAX_PERCENT = 150;
local SCALE_STEP_PERCENT = 5;
local DEFAULT_SCALE = 1;

local LCA;  --- @type LibCombatAlerts
local LHAS; --- @type LibHarvensAddonSettings

local wm = GetWindowManager();
local em = GetEventManager();
local sceneManager = SCENE_MANAGER;
local SecurePostHook = SecurePostHook;

local PanelUtils = KFS_PanelUtils;
local PanelDefinitions = KFS_PanelDefinitions;
local GridOverlay = KFS_GridOverlay;
local EditModeController = KFS_EditModeController;
local SettingsController = KFS_SettingsController;

function KhajiitFengShui:BuildOverlayMessage(panel, left, top)
    local labelText = PanelDefinitions.getLabel(panel.definition);
    local message = PanelUtils.formatPositionMessage(left, top, labelText);
    local scalePercent = zo_roundToNearest(self:GetPanelScale(panel.definition.id) * 100, SCALE_STEP_PERCENT);
    return string.format("%s | %d%%", message, scalePercent);
end;


local function EnsureSavedVarStructure(savedVars, defaults)
    if not savedVars then
        return;
    end;

    defaults = defaults or {};

    savedVars.grid = savedVars.grid or PanelUtils.copyPosition(defaults.grid);
    if savedVars.grid then
        if savedVars.grid.enabled == nil and defaults.grid then
            savedVars.grid.enabled = defaults.grid.enabled;
        end;
        if not savedVars.grid.size and defaults.grid then
            savedVars.grid.size = defaults.grid.size;
        end;
    end;

    savedVars.positions = savedVars.positions or {};
    savedVars.scales = savedVars.scales or {};

    if savedVars.buffAnimationsEnabled == nil then
        savedVars.buffAnimationsEnabled = defaults.buffAnimationsEnabled or false;
    end;
    if savedVars.globalCooldownEnabled == nil then
        savedVars.globalCooldownEnabled = defaults.globalCooldownEnabled or false;
    end;
    if savedVars.pyramidLayoutEnabled == nil then
        savedVars.pyramidLayoutEnabled = defaults.pyramidLayoutEnabled or false;
    end;
    if savedVars.alwaysExpandedBars == nil then
        savedVars.alwaysExpandedBars = defaults.alwaysExpandedBars or false;
    end;
    if savedVars.pyramidOffset == nil then
        savedVars.pyramidOffset = PanelUtils.copyPosition(defaults.pyramidOffset);
    end;
end;

--- @class KhajiitFengShuiPanel
--- @field definition KhajiitFengShuiPanelDefinition
--- @field control Control
--- @field overlay TopLevelWindow
--- @field handler MoveableControl
--- @field label LabelControl

local function UpdateOverlayLabel(panel, message)
    PanelUtils.updateOverlayLabel(panel.label, message);
end;


--- @param panel KhajiitFengShuiPanel
local function SyncOverlaySize(panel)
    PanelUtils.syncOverlaySize(panel);
end;

--- @param panelId string
--- @return number
function KhajiitFengShui:GetPanelScale(panelId)
    if not (panelId and self.savedVars) then
        return DEFAULT_SCALE;
    end;
    local panel = self.panelLookup and self.panelLookup[panelId];
    local defaultScale = (panel and panel.defaultScale) or DEFAULT_SCALE;
    local scales = self.savedVars.scales;
    if scales and scales[panelId] and scales[panelId] > 0 then
        return scales[panelId];
    end;
    return defaultScale;
end;

--- @param panelId string
--- @return number
function KhajiitFengShui:GetPanelScalePercent(panelId)
    return zo_roundToNearest(self:GetPanelScale(panelId) * 100, SCALE_STEP_PERCENT);
end;

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:ApplyPanelScale(panel)
    if not panel then
        return;
    end;
    PanelUtils.applyScale(panel, self:GetPanelScale(panel.definition.id));
end;

--- @param panelId string
--- @param scale number
function KhajiitFengShui:SetPanelScale(panelId, scale)
    if not (panelId and self.savedVars) then
        return;
    end;

    self.savedVars.scales = self.savedVars.scales or {};

    local panel = self.panelLookup and self.panelLookup[panelId];
    local defaultScale = (panel and panel.defaultScale) or DEFAULT_SCALE;
    local normalized = zo_clamp(scale or defaultScale, SCALE_MIN_PERCENT / 100, SCALE_MAX_PERCENT / 100);
    local rounded = zo_roundToNearest(normalized, SCALE_STEP_PERCENT / 100);

    if zo_floatsAreEqual(rounded, defaultScale) then
        self.savedVars.scales[panelId] = nil;
    else
        self.savedVars.scales[panelId] = rounded;
    end;

    if not panel then
        return;
    end;

    self:ApplyPanelScale(panel);
    if panel.definition and panel.definition.postApply then
        local hasCustomPosition = self.savedVars.positions and self.savedVars.positions[panelId] ~= nil;
        panel.definition.postApply(panel.control, hasCustomPosition);
    end;
    SyncOverlaySize(panel);

    if self.savedVars.pyramidLayoutEnabled and (panelId == "playerHealth" or panelId == "playerMagicka" or panelId == "playerStamina") then
        self:ApplyPyramidLayout();
    end;

    if panel.handler then
        local left, top = PanelUtils.getAnchorPosition(panel.handler, true);
        UpdateOverlayLabel(panel, self:BuildOverlayMessage(panel, left, top));
    end;
end;


function KhajiitFengShui:TryCreatePanel(definition)
    if not definition then
        return nil;
    end;

    local control = PanelDefinitions.resolveControl(definition);
    if not control then
        return nil;
    end;

    local existing = self.panelLookup[definition.id];
    if existing then
        existing.control = control;
        existing.defaultScale = control:GetTransformScale() or existing.defaultScale or DEFAULT_SCALE;
        return existing;
    end;

    local left = control:GetLeft() or 0;
    local top = control:GetTop() or 0;
    local panel =
    {
        definition = definition;
        control = control;
        defaultPosition =
        {
            left = left;
            top = top;
        };
        defaultScale = control:GetTransformScale() or DEFAULT_SCALE;
    };

    table.insert(self.panels, panel);
    self.panelLookup[definition.id] = panel;

    self:CreateMover(panel);
    if self.settingsController then
        self.settingsController:AddPanelSetting(panel);
    end;
    return panel;
end;

--- @param panel KhajiitFengShuiPanel
--- @return boolean
function KhajiitFengShui:IsPanelVisible(panel)
    if self.editModeActive then
        return true;
    end;

    return self.activePanelId == panel.definition.id;
end;

--- @param panel KhajiitFengShuiPanel
--- @return boolean
function KhajiitFengShui:IsPanelUnlocked(panel)
    if self.editModeActive then
        return true;
    end;

    return self.activePanelId == panel.definition.id;
end;

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:RefreshPanelState(panel)
    local unlocked = self:IsPanelUnlocked(panel);
    local shouldGamepadMove = false;
    if self.editModeActive then
        shouldGamepadMove = self.editModeFocusId ~= nil and panel.definition.id == self.editModeFocusId;
    else
        shouldGamepadMove = self.activePanelId ~= nil and panel.definition.id == self.activePanelId;
    end;
    if panel.handler then
        panel.handler:ToggleLock(not unlocked);
        if panel.gamepadActive ~= shouldGamepadMove then
            panel.handler:ToggleGamepadMove(shouldGamepadMove, 10000);
            panel.gamepadActive = shouldGamepadMove;
        end;
    end;
    if panel.overlay then
        panel.overlay:SetHidden(not self:IsPanelVisible(panel));
    end;
end;

function KhajiitFengShui:RefreshAllPanels()
    for _, panel in ipairs(self.panels) do
        self:RefreshPanelState(panel);
    end;
end;

function KhajiitFengShui:EnsureCompassHook()
    if self.compassHookRegistered then
        return;
    end;

    if not (COMPASS_FRAME and COMPASS_FRAME.ApplyStyle and ZO_PostHook) then
        return;
    end;

    ZO_PostHook(COMPASS_FRAME, "ApplyStyle", function ()
        local compassPanel = self.panelLookup and self.panelLookup.compass;
        if not (compassPanel and compassPanel.handler and compassPanel.control and compassPanel.control.SetAnchor) then
            return;
        end;
        local position = compassPanel.handler:GetPosition(true);
        if position then
            local gridSize = self:GetSnapSize();
            PanelUtils.applyControlAnchorFromPosition(compassPanel, position, gridSize);
        end;
    end);

    self.compassHookRegistered = true;
end;

function KhajiitFengShui:EnsureGroupFrameHooks()
    if self.groupFrameHooksRegistered then
        return;
    end;

    local function reapplyGroupFrameScales()
        local groupPanelIds =
        {
            "groupAnchorSmall";
            "groupAnchorLarge1";
            "groupAnchorLarge2";
            "groupAnchorLarge3";
            "groupAnchorLarge4";
        };

        for _, panelId in ipairs(groupPanelIds) do
            local panel = self.panelLookup and self.panelLookup[panelId];
            if panel and panel.control then
                local scale = self:GetPanelScale(panelId);
                panel.control:SetTransformScale(scale);
                PanelUtils.enableInheritScaleRecursive(panel.control);
            end;
        end;

        local unitFramesGroups = GetControl("ZO_UnitFramesGroups");
        if unitFramesGroups then
            local maxScale = 1;
            for _, panelId in ipairs(groupPanelIds) do
                local panel = self.panelLookup and self.panelLookup[panelId];
                if panel then
                    local scale = self:GetPanelScale(panelId);
                    if scale > maxScale then
                        maxScale = scale;
                    end;
                end;
            end;
            if maxScale ~= 1 then
                PanelUtils.enableInheritScaleRecursive(unitFramesGroups);
                unitFramesGroups:SetTransformScale(maxScale);
            end;
        end;
    end;

    if SecurePostHook and ZO_UnitFrames_Manager then
        SecurePostHook(ZO_UnitFrames_Manager, "UpdateGroupAnchorFrames", function ()
            zo_callLater(function ()
                             reapplyGroupFrameScales();
                         end, 200);
        end);
    end;

    em:RegisterForEvent(self.name .. "_GROUP_UPDATE", EVENT_GROUP_UPDATE, function ()
        zo_callLater(reapplyGroupFrameScales, 50);
    end);

    em:RegisterForEvent(self.name .. "_GROUP_MEMBER_JOINED", EVENT_GROUP_MEMBER_JOINED, function ()
        zo_callLater(reapplyGroupFrameScales, 50);
    end);

    self.groupFrameHooksRegistered = true;
end;

function KhajiitFengShui:RegisterBuffAnimationHook()
    if self.buffAnimationHookRegistered then
        return;
    end;
    if not SecurePostHook then
        return;
    end;
    local addon = self;
    SecurePostHook("ZO_BuffDebuffIcon_OnInitialized", function (control)
        if addon.savedVars and addon.savedVars.buffAnimationsEnabled then
            control.showCooldown = true;
        end;
    end);
    self.buffAnimationHookRegistered = true;
end;

function KhajiitFengShui:UpdateBuffAnimationHook()
    if self.savedVars and self.savedVars.buffAnimationsEnabled then
        self:RegisterBuffAnimationHook();
    end;
end;

function KhajiitFengShui:ApplyGlobalCooldownSetting()
    local enabled = self.savedVars and self.savedVars.globalCooldownEnabled;
    local desired = enabled == true;
    if self.globalCooldownActive ~= desired then
        ZO_ActionButtons_ToggleShowGlobalCooldown();
        self.globalCooldownActive = desired;
    end;
end;

function KhajiitFengShui:GetSnapSize()
    if not self.savedVars.grid.enabled then
        return 0;
    end;
    return self.savedVars.grid.size or self.defaults.grid.size;
end;

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:ApplySavedPosition(panel)
    if not panel.handler then
        return;
    end;
    
    if self.savedVars.pyramidLayoutEnabled and (panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina") then
        self:ApplyPyramidLayout();
        return;
    end;
    
    local hasCustom = self.savedVars.positions[panel.definition.id] ~= nil;
    local handler = panel.handler;
    local savedPosition = self.savedVars.positions[panel.definition.id];

    if savedPosition then
        handler:UpdatePosition(savedPosition);
        local gridSize = self:GetSnapSize();
        PanelUtils.applyControlAnchorFromPosition(panel, savedPosition, gridSize);
    else
        local left = panel.control:GetLeft();
        local top = panel.control:GetTop();
        local defaultPosition = { left = left; top = top };
        handler:UpdatePosition(defaultPosition);
        local gridSize = self:GetSnapSize();
        PanelUtils.applyControlAnchorFromPosition(panel, defaultPosition, gridSize);
    end;

    if panel.definition.preApply then
        panel.definition.preApply(panel.control, hasCustom);
    end;
    self:ApplyPanelScale(panel);

    if panel.definition.postApply then
        panel.definition.postApply(panel.control, hasCustom);
    end;

    SyncOverlaySize(panel);

    local message = self:BuildOverlayMessage(panel, left, top);
    UpdateOverlayLabel(panel, message);
    self:RefreshPanelState(panel);
end;

--- @param panelId string
function KhajiitFengShui:StartControlMove(panelId)
    if self.activePanelId and self.activePanelId ~= panelId then
        local previous = self.panelLookup[self.activePanelId];
        if previous and previous.handler then
            previous.handler:ToggleGamepadMove(false);
            previous.handler:ToggleLock(true);
        end;
    end;

    local panel = self.panelLookup[panelId];
    if not panel or not panel.handler then
        return;
    end;

    self.activePanelId = panelId;
    self:RefreshAllPanels();
    self:RefreshGridOverlay();
    
    if self.savedVars.pyramidLayoutEnabled and (panelId == "playerHealth" or panelId == "playerMagicka" or panelId == "playerStamina") then
        local healthPanel = self.panelLookup["playerHealth"];
        local magickaPanel = self.panelLookup["playerMagicka"];
        local staminaPanel = self.panelLookup["playerStamina"];
        
        if healthPanel and healthPanel.handler then
            healthPanel.handler:ToggleLock(false);
            if IsInGamepadPreferredMode() then
                pcall(function () healthPanel.handler:ToggleGamepadMove(true, 10000); end);
                healthPanel.gamepadActive = true;
            else
                healthPanel.gamepadActive = false;
            end;
        end;
        if magickaPanel and magickaPanel.handler then
            magickaPanel.handler:ToggleLock(false);
            if IsInGamepadPreferredMode() then
                pcall(function () magickaPanel.handler:ToggleGamepadMove(true, 10000); end);
                magickaPanel.gamepadActive = true;
            else
                magickaPanel.gamepadActive = false;
            end;
        end;
        if staminaPanel and staminaPanel.handler then
            staminaPanel.handler:ToggleLock(false);
            if IsInGamepadPreferredMode() then
                pcall(function () staminaPanel.handler:ToggleGamepadMove(true, 10000); end);
                staminaPanel.gamepadActive = true;
            else
                staminaPanel.gamepadActive = false;
            end;
        end;
    else
        panel.handler:ToggleLock(false);
        if IsInGamepadPreferredMode() then
            panel.handler:ToggleGamepadMove(true, 10000);
            panel.gamepadActive = true;
        else
            panel.gamepadActive = false;
        end;
    end;
end;

--- @param panel KhajiitFengShuiPanel
--- @param handler MoveableControl
function KhajiitFengShui:OnMoveStart(panel, handler)
    local updateName = string.format("%s_MoveUpdate_%s", self.name, panel.definition.id);
    
    if self.savedVars.pyramidLayoutEnabled and (panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina") then
        local healthPanel = self.panelLookup["playerHealth"];
        local magickaPanel = self.panelLookup["playerMagicka"];
        local staminaPanel = self.panelLookup["playerStamina"];
        
        if healthPanel and healthPanel.handler and magickaPanel and magickaPanel.handler and staminaPanel and staminaPanel.handler then
            em:RegisterForUpdate(updateName, 200, function ()
                local left, top = PanelUtils.getAnchorPosition(handler);
                self:UpdatePyramidLayoutFromPosition(panel.definition.id, left, top);
            end);
        end;
    else
        em:RegisterForUpdate(updateName, 200, function ()
            local left, top = PanelUtils.getAnchorPosition(handler);
            local message = self:BuildOverlayMessage(panel, left, top);
            UpdateOverlayLabel(panel, message);
        end);
    end;
end;

function KhajiitFengShui:UpdatePyramidLayoutFromPosition(movedPanelId, left, top)
    local healthPanel = self.panelLookup["playerHealth"];
    local magickaPanel = self.panelLookup["playerMagicka"];
    local staminaPanel = self.panelLookup["playerStamina"];
    
    if not (healthPanel and healthPanel.handler and magickaPanel and magickaPanel.handler and staminaPanel and staminaPanel.handler) then
        return;
    end;
    
    local healthScale = self:GetPanelScale("playerHealth");
    local magickaScale = self:GetPanelScale("playerMagicka");
    local staminaScale = self:GetPanelScale("playerStamina");
    
    local healthWidth = getExpectedBarWidth(healthPanel, healthScale);
    local magickaWidth = getExpectedBarWidth(magickaPanel, magickaScale);
    local staminaWidth = getExpectedBarWidth(staminaPanel, staminaScale);
    
    local healthHeight = getExpectedBarHeight(healthPanel, healthScale);
    
    local screenWidth = GuiRoot:GetWidth();
    local screenHeight = GuiRoot:GetHeight();
    
    local alwaysExpanded = KFS_AttributeScaler and KFS_AttributeScaler.alwaysExpandedEnabled or false;
    local baseVerticalSpacing = alwaysExpanded and 15 or 5;
    local scaleAdjustment = zo_max(healthScale, magickaScale, staminaScale);
    local verticalSpacing = baseVerticalSpacing + (scaleAdjustment > 1 and (scaleAdjustment - 1) * 8 or 0);
    local horizontalSpacing = 0;
    local baseHealthTop = screenHeight - 100;
    local baseHealthLeft = (screenWidth - healthWidth) / 2;
    
    local offsetLeft, offsetTop;
    if movedPanelId == "playerHealth" then
        offsetLeft = left - baseHealthLeft;
        offsetTop = top - baseHealthTop;
    elseif movedPanelId == "playerMagicka" then
        local baseMagickaLeft = (screenWidth - magickaWidth - staminaWidth - horizontalSpacing) / 2;
        local baseMagickaTop = baseHealthTop + healthHeight + verticalSpacing;
        offsetLeft = left - baseMagickaLeft;
        offsetTop = top - baseMagickaTop;
    elseif movedPanelId == "playerStamina" then
        local baseMagickaLeft = (screenWidth - magickaWidth - staminaWidth - horizontalSpacing) / 2;
        local baseStaminaLeft = baseMagickaLeft + magickaWidth + horizontalSpacing;
        local baseStaminaTop = baseHealthTop + healthHeight + verticalSpacing;
        offsetLeft = left - baseStaminaLeft;
        offsetTop = top - baseStaminaTop;
    else
        return;
    end;
    
    self.savedVars.pyramidOffset = { left = offsetLeft; top = offsetTop };
    self:ApplyPyramidLayout();
end;

--- @param panel KhajiitFengShuiPanel
--- @param handler MoveableControl
--- @param newPos table<string, any>?
--- @param isExplicitStop boolean? Whether this is an explicit stop (via StopControlMove) vs just movement ending
function KhajiitFengShui:OnMoveStop(panel, handler, newPos, isExplicitStop)
    local updateName = string.format("%s_MoveUpdate_%s", self.name, panel.definition.id);
    em:UnregisterForUpdate(updateName);

    if self.savedVars.pyramidLayoutEnabled and (panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina") then
        local position = newPos or handler:GetPosition(true);
        local left, top = PanelUtils.getAnchorPosition(handler, true);
        self:UpdatePyramidLayoutFromPosition(panel.definition.id, left, top);
        
        local healthPanel = self.panelLookup["playerHealth"];
        local magickaPanel = self.panelLookup["playerMagicka"];
        local staminaPanel = self.panelLookup["playerStamina"];
        
        if IsInGamepadPreferredMode() then
            if healthPanel and healthPanel.handler and healthPanel.gamepadActive then
                pcall(function () healthPanel.handler:ToggleGamepadMove(false); end);
                healthPanel.gamepadActive = false;
            end;
            if magickaPanel and magickaPanel.handler and magickaPanel.gamepadActive then
                pcall(function () magickaPanel.handler:ToggleGamepadMove(false); end);
                magickaPanel.gamepadActive = false;
            end;
            if staminaPanel and staminaPanel.handler and staminaPanel.gamepadActive then
                pcall(function () staminaPanel.handler:ToggleGamepadMove(false); end);
                staminaPanel.gamepadActive = false;
            end;
        end;
        
        if isExplicitStop or IsInGamepadPreferredMode() then
            self.activePanelId = nil;
            if not IsInGamepadPreferredMode() then
                if healthPanel and healthPanel.handler then
                    healthPanel.handler:ToggleLock(true);
                end;
                if magickaPanel and magickaPanel.handler then
                    magickaPanel.handler:ToggleLock(true);
                end;
                if staminaPanel and staminaPanel.handler then
                    staminaPanel.handler:ToggleLock(true);
                end;
            end;
            self:RefreshAllPanels();
            self:RefreshGridOverlay();
            
            if self.editModeFocusId then
                local focusedPanel = self.panelLookup[self.editModeFocusId];
                if focusedPanel and focusedPanel.handler then
                    focusedPanel.handler:ToggleLock(false);
                    if IsInGamepadPreferredMode() then
                        focusedPanel.handler:ToggleGamepadMove(true, 10000);
                        focusedPanel.gamepadActive = true;
                    else
                        focusedPanel.gamepadActive = false;
                    end;
                end;
            end;
        else
            self:RefreshAllPanels();
        end;
        return;
    end;
    
    local position = newPos or handler:GetPosition(true);
    self.savedVars.positions[panel.definition.id] = PanelUtils.copyPosition(position);

    local gridSize = self:GetSnapSize();
    PanelUtils.applyControlAnchorFromPosition(panel, position, gridSize);

    if panel.definition.postApply then
        panel.definition.postApply(panel.control, true);
    end;

    local left, top = PanelUtils.getAnchorPosition(handler, true);
    local message = self:BuildOverlayMessage(panel, left, top);
    UpdateOverlayLabel(panel, message);

    handler:ToggleGamepadMove(false);
    panel.gamepadActive = false;

    if isExplicitStop or IsInGamepadPreferredMode() then
        self.activePanelId = nil;
        if not IsInGamepadPreferredMode() then
            handler:ToggleLock(true);
        end;
        self:RefreshAllPanels();
        self:RefreshGridOverlay();

        if self.editModeFocusId then
            local focusedPanel = self.panelLookup[self.editModeFocusId];
            if focusedPanel and focusedPanel.handler then
                focusedPanel.handler:ToggleLock(false);
                if IsInGamepadPreferredMode() then
                    focusedPanel.handler:ToggleGamepadMove(true, 10000);
                    focusedPanel.gamepadActive = true;
                else
                    focusedPanel.gamepadActive = false;
                end;
            end;
        end;
    else
        self:RefreshAllPanels();
    end;
end;

--- @param panel KhajiitFengShuiPanel
--- @return TopLevelWindow
local function CreateOverlay(panel)
    local overlay, label = PanelUtils.createOverlay(panel.definition.id, panel.control);
    panel.label = label;
    return overlay;
end;

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:CreateMover(panel)
    panel.overlay = CreateOverlay(panel);

    panel.handler = LCA.MoveableControl:New(panel.overlay, { color = 0x00C0FFFF; size = 2 });
    if panel.handler.SetCenterHighlightControl and panel.overlay then
        panel.handler:SetCenterHighlightControl(panel.overlay);
    end;
    panel.handler:RegisterCallback(string.format("%s_MoveStart_%s", self.name, panel.definition.id), LCA.EVENT_CONTROL_MOVE_START, function ()
        self:OnMoveStart(panel, panel.handler);
    end);
    panel.handler:RegisterCallback(string.format("%s_MoveStop_%s", self.name, panel.definition.id), LCA.EVENT_CONTROL_MOVE_STOP, function (newPos)
        self:OnMoveStop(panel, panel.handler, newPos);
    end);
    panel.gamepadActive = false;

    local snapSize = self:GetSnapSize();
    panel.handler:SetSnap(snapSize > 0 and snapSize or nil);
    panel.handler:ToggleLock(true);

    PanelUtils.applySizing(panel.control, panel.definition.width, panel.definition.height);
    self:ApplySavedPosition(panel);
    if panel.definition.id == "compass" then
        self:EnsureCompassHook();
    end;
    if panel.definition.id == "groupAnchorSmall" or
    panel.definition.id == "groupAnchorLarge1" or
    panel.definition.id == "groupAnchorLarge2" or
    panel.definition.id == "groupAnchorLarge3" or
    panel.definition.id == "groupAnchorLarge4" then
        self:EnsureGroupFrameHooks();
    end;
end;

function KhajiitFengShui:ApplySnapSettings()
    local snapSize = self:GetSnapSize();
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            panel.handler:SetSnap(snapSize > 0 and snapSize or nil);
        end;
    end;

    self:RefreshGridOverlay();
end;

function KhajiitFengShui:RefreshGridOverlay()
    if not self.gridOverlay then
        return;
    end;

    local gridEnabled = self.savedVars and self.savedVars.grid and self.savedVars.grid.enabled;
    local snapSize = self:GetSnapSize();
    local shouldShow = gridEnabled and (self.editModeActive or self.activePanelId ~= nil);
    self.gridOverlay:Refresh(shouldShow, snapSize);
end;

local function EnumerateFocusablePanelIds(self)
    local ids = {};
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            table.insert(ids, panel.definition.id);
        end;
    end;
    return ids;
end;

function KhajiitFengShui:ClearEditModeFocus()
    self.editModeFocusId = nil;
    for _, panel in ipairs(self.panels) do
        if panel.gamepadActive and panel.handler then
            panel.handler:ToggleGamepadMove(false);
            panel.gamepadActive = false;
        end;
    end;
end;

function KhajiitFengShui:SetEditModeFocus(panelId)
    if not self.editModeActive then
        return;
    end;

    if panelId and self.panelLookup[panelId] and self.panelLookup[panelId].handler then
        self.editModeFocusId = panelId;
    else
        self.editModeFocusId = nil;
    end;

    self:RefreshAllPanels();
    self:RefreshKeybindStrip();
end;

function KhajiitFengShui:SelectFirstFocusablePanel()
    local ids = EnumerateFocusablePanelIds(self);
    if #ids == 0 then
        self.editModeFocusId = nil;
        return;
    end;

    local target = self.editModeFocusId;
    if not target or not (self.panelLookup[target] and self.panelLookup[target].handler) then
        target = ids[1];
    end;
    self:SetEditModeFocus(target);
end;

function KhajiitFengShui:CycleFocusedPanel(direction)
    if not (self.editModeActive and direction and direction ~= 0) then
        return;
    end;

    local ids = EnumerateFocusablePanelIds(self);
    local count = #ids;
    if count == 0 then
        return;
    end;

    local currentIndex = 1;
    for index, id in ipairs(ids) do
        if id == self.editModeFocusId then
            currentIndex = index;
            break;
        end;
    end;

    local nextIndex = ((currentIndex - 1 + direction) % count) + 1;
    self:SetEditModeFocus(ids[nextIndex]);
end;

function KhajiitFengShui:ShowEditModeHint()
    if self.editModeHintShown then
        return;
    end;

    if IsInGamepadPreferredMode() then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(KFS_EDIT_MODE_HINT));
        self.editModeHintShown = true;
    end;
end;

function KhajiitFengShui:ActivateActionLayer()
    if not self.actionLayerName or self.actionLayerActive then
        return;
    end;
    PushActionLayerByName(self.actionLayerName);
    self.actionLayerActive = true;
end;

function KhajiitFengShui:DeactivateActionLayer()
    if not self.actionLayerName or not self.actionLayerActive then
        return;
    end;
    RemoveActionLayerByName(self.actionLayerName);
    self.actionLayerActive = false;
end;

function KhajiitFengShui:EnsureKeybindDescriptor()
    if self.keybindStripDescriptor then
        return;
    end;

    self.actionLayerName = GetString(SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS);

    local addon = self;
    self.keybindStripDescriptor =
    {
        {
            ethereal = true;
            name = function ()
                return GetString(KFS_KEYBIND_ENTER_EDIT_MODE);
            end;
            keybind = "UI_SHORTCUT_TERTIARY";
            visible = function ()
                return IsInGamepadPreferredMode() and not addon:IsEditModeActive();
            end;
            callback = function ()
                addon:SetEditModeActive(true);
            end;
        };
        {
            name = function ()
                return GetString(KFS_KEYBIND_EXIT_EDIT_MODE);
            end;
            keybind = "UI_SHORTCUT_NEGATIVE";
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive();
            end;
            callback = function ()
                addon:SetEditModeActive(false);
            end;
        };
        {
            name = function ()
                return GetString(KFS_KEYBIND_PREVIOUS_PANEL);
            end;
            keybind = "UI_SHORTCUT_INPUT_LEFT";
            gamepadPreferredKeybind = "UI_SHORTCUT_LEFT_SHOULDER";
            alignment = KEYBIND_STRIP_ALIGN_RIGHT;
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive();
            end;
            callback = function ()
                addon:CycleFocusedPanel(-1);
            end;
        };
        {
            name = function ()
                return GetString(KFS_KEYBIND_NEXT_PANEL);
            end;
            keybind = "UI_SHORTCUT_INPUT_RIGHT";
            gamepadPreferredKeybind = "UI_SHORTCUT_RIGHT_SHOULDER";
            alignment = KEYBIND_STRIP_ALIGN_RIGHT;
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive();
            end;
            callback = function ()
                addon:CycleFocusedPanel(1);
            end;
        };
    };
end;

function KhajiitFengShui:RemoveKeybindStrip()
    if not (self.keybindStripActive and self.keybindStripDescriptor) then
        return;
    end;

    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor);
    self.keybindStripActive = false;

    self:ApplyKeybindStripSizing();

    if self.keybindFragmentSceneName then
        local scene = sceneManager:GetScene(self.keybindFragmentSceneName);
        if scene and scene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
            scene:RemoveFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT);
        end;
        self.keybindFragmentSceneName = nil;
    end;
end;

local REDUCED_KEYBIND_STRIP_HEIGHT = 48;

function KhajiitFengShui:ApplyKeybindStripSizing()
    local shouldReduce = self.editModeActive and IsInGamepadPreferredMode();
    if shouldReduce then
        if not self.keybindStripReduced then
            if KEYBIND_STRIP and KEYBIND_STRIP.control then
                self.keybindStripOriginalHeight = self.keybindStripOriginalHeight or KEYBIND_STRIP.control:GetHeight();
                KEYBIND_STRIP.control:SetHeight(REDUCED_KEYBIND_STRIP_HEIGHT);
            end;
            if ZO_KeybindStripGamepadBackground then
                self.keybindStripBackgroundOriginalHeight = self.keybindStripBackgroundOriginalHeight or ZO_KeybindStripGamepadBackground:GetHeight();
                ZO_KeybindStripGamepadBackground:SetHeight(REDUCED_KEYBIND_STRIP_HEIGHT);
                if self.keybindStripBackgroundWasHidden == nil then
                    self.keybindStripBackgroundWasHidden = ZO_KeybindStripGamepadBackground:IsHidden();
                end;
                ZO_KeybindStripGamepadBackground:SetHidden(true);
            end;
            if ZO_KeybindStripGamepadBackgroundTexture then
                self.keybindStripBackgroundTextureOriginalHeight = self.keybindStripBackgroundTextureOriginalHeight or ZO_KeybindStripGamepadBackgroundTexture:GetHeight();
                ZO_KeybindStripGamepadBackgroundTexture:SetHeight(REDUCED_KEYBIND_STRIP_HEIGHT);
                ZO_KeybindStripGamepadBackgroundTexture:SetHidden(true);
            end;
            if KEYBIND_STRIP and KEYBIND_STRIP.centerParent and not self.keybindStripCenterAdjusted then
                KEYBIND_STRIP.centerParent:ClearAnchors();
                KEYBIND_STRIP.centerParent:SetAnchor(BOTTOM, KEYBIND_STRIP.control, BOTTOM, 0, -6);
                self.keybindStripCenterAdjusted = true;
            end;
            self.keybindStripReduced = true;
        end;
    elseif self.keybindStripReduced then
        if KEYBIND_STRIP and KEYBIND_STRIP.control and self.keybindStripOriginalHeight then
            KEYBIND_STRIP.control:SetHeight(self.keybindStripOriginalHeight);
        end;
        if ZO_KeybindStripGamepadBackground and self.keybindStripBackgroundOriginalHeight then
            ZO_KeybindStripGamepadBackground:SetHeight(self.keybindStripBackgroundOriginalHeight);
        end;
        if ZO_KeybindStripGamepadBackgroundTexture and self.keybindStripBackgroundTextureOriginalHeight then
            ZO_KeybindStripGamepadBackgroundTexture:SetHeight(self.keybindStripBackgroundTextureOriginalHeight);
            ZO_KeybindStripGamepadBackgroundTexture:SetHidden(false);
        end;
        if KEYBIND_STRIP and KEYBIND_STRIP.centerParent and self.keybindStripCenterAdjusted then
            KEYBIND_STRIP.centerParent:ClearAnchors();
            KEYBIND_STRIP.centerParent:SetAnchor(CENTER, KEYBIND_STRIP.control, CENTER, 0, 0);
            self.keybindStripCenterAdjusted = false;
        end;
        if ZO_KeybindStripGamepadBackground then
            if self.keybindStripBackgroundWasHidden ~= nil then
                ZO_KeybindStripGamepadBackground:SetHidden(self.keybindStripBackgroundWasHidden);
            end;
        end;
        self.keybindStripBackgroundWasHidden = nil;
        self.keybindStripReduced = false;
    end;
end;

function KhajiitFengShui:OnKeybindSceneStateChange(sceneName, newState)
    if not IsInGamepadPreferredMode() then
        return;
    end;

    if not self.editModeActive then
        return;
    end;

    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        local scene = sceneManager:GetScene(sceneName);
        if scene and not scene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
            scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT);
            self.keybindFragmentSceneName = sceneName;
        end;
        if not self.keybindStripActive then
            self:RefreshKeybindStrip();
        end;
    elseif newState == SCENE_HIDDEN or newState == SCENE_HIDING then
        local scene = sceneManager:GetScene(sceneName);
        if scene and scene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
            scene:RemoveFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT);
        end;
        if self.keybindFragmentSceneName == sceneName then
            self.keybindFragmentSceneName = nil;
        end;
        self:RemoveKeybindStrip();
    end;
end;

function KhajiitFengShui:RefreshKeybindStrip()
    self:EnsureKeybindDescriptor();
    if not self.keybindStripDescriptor then
        return;
    end;

    self:UpdateKeybindFragments();

    self:ApplyKeybindStripSizing();

    if not (self.editModeActive and IsInGamepadPreferredMode()) then
        self:RemoveKeybindStrip();
        return;
    end;

    local currentScene = sceneManager:GetCurrentScene();
    local currentName = currentScene and currentScene:GetName();
    local allowed = false;
    if currentName and self.keybindScenes then
        for _, name in ipairs(self.keybindScenes) do
            if name == currentName then
                allowed = true;
                break;
            end;
        end;
    end;

    if not allowed then
        self:RemoveKeybindStrip();
        return;
    end;

    currentScene = sceneManager:GetCurrentScene();
    if KEYBIND_STRIP_GAMEPAD_FRAGMENT and currentScene and not currentScene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
        currentScene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT);
        self.keybindFragmentSceneName = currentName;
    end;

    if self.keybindStripActive then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor);
    else
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor);
        self.keybindStripActive = true;
    end;
end;

function KhajiitFengShui:RegisterKeybindScene(sceneName)
    if self.keybindSceneCallbacks[sceneName] then
        return;
    end;

    local scene = sceneManager:GetScene(sceneName);
    if not scene then
        return;
    end;

    scene:RegisterCallback("StateChange", function (_, newState)
        self:OnKeybindSceneStateChange(sceneName, newState);
    end);

    self.keybindSceneCallbacks[sceneName] = true;
end;

function KhajiitFengShui:UpdateKeybindFragments()
    if not self.keybindScenes then
        return;
    end;

    -- Scene fragments manage the keybind strip visibility. No-op here.
end;

function KhajiitFengShui:InitializeKeybindStrip()
    if not KEYBIND_STRIP then
        return;
    end;

    self:EnsureKeybindDescriptor();
    self.keybindScenes = { "hud"; "hudui"; "gamepadInteract" };
    for _, sceneName in ipairs(self.keybindScenes) do
        self:RegisterKeybindScene(sceneName);
    end;
    if self.editModeActive then
        self:RefreshKeybindStrip();
    end;
end;

function KhajiitFengShui:StopControlMove()
    if not self.activePanelId then
        return;
    end;
    local panel = self.panelLookup[self.activePanelId];
    if panel and panel.handler then
        panel.handler:ToggleGamepadMove(false);
        panel.handler:ToggleLock(true);
        panel.gamepadActive = false;
        self:OnMoveStop(panel, panel.handler, panel.handler:GetPosition(true), true);
    end;
end;

function KhajiitFengShui:IsEditModeActive()
    return self.editModeActive == true;
end;

function KhajiitFengShui:GetProfileMode()
    return self.profileMode or self.defaults.profileMode;
end;

local function ResolveSavedVarsForMode(self, mode)
    if mode == "character" then
        return self.characterSavedVars;
    end;
    return self.accountSavedVars;
end;

--- @param mode string
--- @param suppressRefresh boolean?
function KhajiitFengShui:SetProfileMode(mode, suppressRefresh)
    if not mode or mode ~= "character" then
        mode = "account";
    end;

    local target = ResolveSavedVarsForMode(self, mode);
    if not target then
        return;
    end;

    EnsureSavedVarStructure(target, self.defaults);

    self.profileMode = mode;
    if self.accountSavedVars then
        self.accountSavedVars.profileMode = mode;
    end;

    self.savedVars = target;

    if suppressRefresh then
        return;
    end;

    self:UpdateBuffAnimationHook();
    self:ApplyGlobalCooldownSetting();
    self:ApplyAllPositions();
    self:ApplySnapSettings();
    self:RefreshAllPanels();
    self:RefreshGridOverlay();
end;

function KhajiitFengShui:SetEditModeActive(active)
    local shouldEnable = active == true;
    if self.editModeActive == shouldEnable then
        return;
    end;

    self.editModeActive = shouldEnable;

    if shouldEnable then
        self:SelectFirstFocusablePanel();
        self:ActivateActionLayer();
    else
        self:ClearEditModeFocus();
        self:DeactivateActionLayer();
    end;

    self.activePanelId = nil;

    self:RefreshAllPanels();
    self:RefreshGridOverlay();
    self:RefreshKeybindStrip();

    local message = shouldEnable and GetString(KFS_EDIT_MODE_ENABLED) or GetString(KFS_EDIT_MODE_DISABLED);

    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(message);
    else
        d(message);
    end;

    if shouldEnable then
        self:ShowEditModeHint();
    end;
end;

function KhajiitFengShui:ToggleEditMode()
    self:SetEditModeActive(not self.editModeActive);
end;

function KhajiitFengShui:ResetPositions()
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            self.savedVars.positions[panel.definition.id] = nil;
            self.savedVars.scales[panel.definition.id] = nil;
            if panel.defaultPosition then
                local defaultPos = PanelUtils.copyPosition(panel.defaultPosition);
                panel.handler:UpdatePosition(defaultPos);
                if panel.definition.preApply then
                    panel.definition.preApply(panel.control, false);
                end;
                local gridSize = self:GetSnapSize();
                PanelUtils.applyControlAnchorFromPosition(panel, defaultPos, gridSize);
                self:ApplyPanelScale(panel);
                if panel.definition.postApply then
                    panel.definition.postApply(panel.control, false);
                end;
                SyncOverlaySize(panel);
                local message = self:BuildOverlayMessage(panel, panel.defaultPosition.left or 0, panel.defaultPosition.top or 0);
                UpdateOverlayLabel(panel, message);
            end;
        end;
    end;
    for _, panel in ipairs(self.panels) do
        self:ApplySavedPosition(panel);
    end;
    self:ApplySnapSettings();
    self:RefreshAllPanels();
end;

function KhajiitFengShui:OnTargetFrameCreated(targetFrame)
    local definition = self.definitionLookup and self.definitionLookup.targetFrame;
    if not definition then
        return;
    end;

    local control = targetFrame and targetFrame.GetPrimaryControl and targetFrame:GetPrimaryControl();
    if control then
        definition.controlName = control:GetName();
    end;

    local panel = self:TryCreatePanel(definition);
    if not panel then
        return;
    end;

    if control then
        panel.control = control;
    end;

    if panel.control and not panel.defaultPosition then
        panel.defaultPosition =
        {
            left = panel.control:GetLeft() or 0;
            top = panel.control:GetTop() or 0;
        };
    end;

    if panel.control then
        self:ApplySavedPosition(panel);
    end;

    if panel.definition.id == "compass" then
        self:EnsureCompassHook();
    end;

    if self.settingsController then
        self.settingsController:AddPanelSetting(panel);
    end;
end;

--- @param oldState number
--- @param newState number
function KhajiitFengShui:OnSceneChange(oldState, newState)
    if not self.activePanelId then
        return;
    end;

    if newState == SCENE_SHOWN then
        for _, panel in ipairs(self.panels) do
            if panel.overlay then
                panel.overlay:SetHidden(true);
            end;
        end;
        self:RefreshKeybindStrip();
    elseif newState == SCENE_HIDDEN then
        self:RefreshAllPanels();
        self:RefreshKeybindStrip();
    end;
end;


function KhajiitFengShui:InitializePanels()
    self.definitionLookup = {};
    self.panels = {};
    self.panelLookup = {};

    for _, definition in ipairs(PanelDefinitions.getAll()) do
        self.definitionLookup[definition.id] = definition;
        self:TryCreatePanel(definition);
    end;

    self:RefreshAllPanels();

    local scene = sceneManager:GetScene("gameMenuInGame");
    if scene then
        scene:RegisterCallback("StateChange", function (oldState, newState)
            self:OnSceneChange(oldState, newState);
        end);
    end;
end;

function KhajiitFengShui:ApplyAllPositions()
    if self.savedVars.pyramidLayoutEnabled then
        self:ApplyPyramidLayout();
    end;
    for _, panel in ipairs(self.panels) do
        if not (self.savedVars.pyramidLayoutEnabled and (panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina")) then
            self:ApplySavedPosition(panel);
        end;
    end;
end;

--- @param panel KhajiitFengShuiPanel
--- @param scale number
--- @return number width
local function getExpectedBarWidth(panel, scale)
    if not panel or not panel.control then
        return (panel and panel.definition and panel.definition.width or 237) * (scale or 1);
    end;
    
    local alwaysExpanded = KFS_AttributeScaler and KFS_AttributeScaler.alwaysExpandedEnabled or false;
    
    if alwaysExpanded and KFS_AttributeScaler and KFS_AttributeScaler.shrinkExpandModule then
        local module = KFS_AttributeScaler.shrinkExpandModule;
        local originalWidths = KFS_AttributeScaler.originalWidths;
        
        if originalWidths and originalWidths.expandedWidth then
            return zo_round(originalWidths.expandedWidth * scale);
        elseif module and module.expandedWidth then
            return zo_round(module.expandedWidth * scale);
        end;
    end;
    
    local actualWidth = panel.control:GetWidth();
    if actualWidth and actualWidth > 0 then
        return actualWidth;
    end;
    
    return (panel.definition.width or 237) * scale;
end;

--- @param panel KhajiitFengShuiPanel
--- @param scale number
--- @return number height
local function getExpectedBarHeight(panel, scale)
    if not panel or not panel.control then
        return (panel and panel.definition and panel.definition.height or 23) * (scale or 1);
    end;
    
    local actualHeight = panel.control:GetHeight();
    if actualHeight and actualHeight > 0 then
        return actualHeight;
    end;
    
    return (panel.definition.height or 23) * scale;
end;

function KhajiitFengShui:ApplyPyramidLayout()
    local healthPanel = self.panelLookup["playerHealth"];
    local magickaPanel = self.panelLookup["playerMagicka"];
    local staminaPanel = self.panelLookup["playerStamina"];
    
    if not (healthPanel and healthPanel.handler and magickaPanel and magickaPanel.handler and staminaPanel and staminaPanel.handler) then
        return;
    end;
    
    local healthScale = self:GetPanelScale("playerHealth");
    local magickaScale = self:GetPanelScale("playerMagicka");
    local staminaScale = self:GetPanelScale("playerStamina");
    
    self:ApplyPanelScale(healthPanel);
    self:ApplyPanelScale(magickaPanel);
    self:ApplyPanelScale(staminaPanel);
    
    zo_callLater(function()
        if not (healthPanel and healthPanel.handler and magickaPanel and magickaPanel.handler and staminaPanel and staminaPanel.handler) then
            return;
        end;
        
        local healthWidth = getExpectedBarWidth(healthPanel, healthScale);
        local magickaWidth = getExpectedBarWidth(magickaPanel, magickaScale);
        local staminaWidth = getExpectedBarWidth(staminaPanel, staminaScale);
        
        local healthHeight = getExpectedBarHeight(healthPanel, healthScale);
        local magickaHeight = getExpectedBarHeight(magickaPanel, magickaScale);
        local staminaHeight = getExpectedBarHeight(staminaPanel, staminaScale);
        
        local screenWidth = GuiRoot:GetWidth();
        local screenHeight = GuiRoot:GetHeight();
        
        local alwaysExpanded = KFS_AttributeScaler and KFS_AttributeScaler.alwaysExpandedEnabled or false;
        local baseVerticalSpacing = alwaysExpanded and 15 or 5;
        local scaleAdjustment = zo_max(healthScale, magickaScale, staminaScale);
        local verticalSpacing = baseVerticalSpacing + (scaleAdjustment > 1 and (scaleAdjustment - 1) * 8 or 0);
        local horizontalSpacing = 0;
        local baseHealthTop = screenHeight - 100;
        local baseHealthLeft = (screenWidth - healthWidth) / 2;
        
        local offset = self.savedVars.pyramidOffset or { left = 0; top = 0 };
        local healthTop = baseHealthTop + (offset.top or 0);
        local healthLeft = baseHealthLeft + (offset.left or 0);
        
        local magickaTop = healthTop + healthHeight + verticalSpacing;
        local magickaLeft = (screenWidth - magickaWidth - staminaWidth - horizontalSpacing) / 2 + (offset.left or 0);
        
        local staminaTop = magickaTop;
        local staminaLeft = magickaLeft + magickaWidth + horizontalSpacing;
        
        local gridSize = self:GetSnapSize();
        
        local healthPos = { left = healthLeft; top = healthTop };
        healthPanel.handler:UpdatePosition(healthPos);
        PanelUtils.applyControlAnchorFromPosition(healthPanel, healthPos, gridSize);
        SyncOverlaySize(healthPanel);
        local message = self:BuildOverlayMessage(healthPanel, healthLeft, healthTop);
        UpdateOverlayLabel(healthPanel, message);
        
        local magickaPos = { left = magickaLeft; top = magickaTop };
        magickaPanel.handler:UpdatePosition(magickaPos);
        PanelUtils.applyControlAnchorFromPosition(magickaPanel, magickaPos, gridSize);
        SyncOverlaySize(magickaPanel);
        message = self:BuildOverlayMessage(magickaPanel, magickaLeft, magickaTop);
        UpdateOverlayLabel(magickaPanel, message);
        
        local staminaPos = { left = staminaLeft; top = staminaTop };
        staminaPanel.handler:UpdatePosition(staminaPos);
        PanelUtils.applyControlAnchorFromPosition(staminaPanel, staminaPos, gridSize);
        SyncOverlaySize(staminaPanel);
        message = self:BuildOverlayMessage(staminaPanel, staminaLeft, staminaTop);
        UpdateOverlayLabel(staminaPanel, message);
        
        self:RefreshPanelState(healthPanel);
        self:RefreshPanelState(magickaPanel);
        self:RefreshPanelState(staminaPanel);
    end, 100);
end;

--- @param eventId integer
--- @param initial boolean
function KhajiitFengShui:EVENT_PLAYER_ACTIVATED(eventId, initial)
    zo_callLater(function ()
                     self:ApplyAllPositions();
                 end, 200);
end;

--- @param event number
--- @param addonName string
function KhajiitFengShui:OnAddOnLoaded(event, addonName)
    if addonName ~= self.name then
        return;
    end;

    em:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED);

    LCA = LibCombatAlerts;
    LHAS = LibHarvensAddonSettings;
    self.LHAS = LHAS;

    self.accountSavedVars = ZO_SavedVars:NewAccountWide("KhajiitFengShui_SavedVariables", 1, nil, self.defaults);
    self.characterSavedVars = ZO_SavedVars:NewCharacterIdSettings("KhajiitFengShui_SavedVariables", 1, nil, self.defaults);

    EnsureSavedVarStructure(self.accountSavedVars, self.defaults);
    EnsureSavedVarStructure(self.characterSavedVars, self.defaults);

    self.accountSavedVars.profileMode = self.accountSavedVars.profileMode or self.defaults.profileMode;
    self:SetProfileMode(self.accountSavedVars.profileMode, true);

    self:UpdateBuffAnimationHook();
    self:ApplyGlobalCooldownSetting();
    
    if KFS_AttributeScaler then
        KFS_AttributeScaler:SetAlwaysExpanded(self.savedVars.alwaysExpandedBars);
    end;

    self:InitializePanels();
    if SettingsController then
        self.settingsController = SettingsController:New(self);
        self.settingsController:CreateSettingsMenu();
    end;
    self:ApplyAllPositions();
    self:ApplySnapSettings();
    self:RefreshAllPanels();

    if EditModeController then
        self.editModeController = EditModeController:New(self);
        self.editModeController:Initialize();
    end;

    if GridOverlay then
        self.gridOverlay = GridOverlay:New();
        self:RefreshGridOverlay();
    end;

    self:InitializeKeybindStrip();

    CALLBACK_MANAGER:RegisterCallback("TargetFrameCreated", function (targetFrame)
        self:OnTargetFrameCreated(targetFrame);
    end);

    em:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function (eventId, initial)
        self:EVENT_PLAYER_ACTIVATED(eventId, initial);
    end);

    em:RegisterForEvent(self.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function ()
        self:UpdateKeybindFragments();
        self:RefreshKeybindStrip();
    end);
end;

em:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function (event, addonName)
    KhajiitFengShui:OnAddOnLoaded(event, addonName);
end);
