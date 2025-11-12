local ADDON_NAME = "KhajiitFengShui";
local ADDON_VERSION = "1.1.5";

---@class KFS_SavedVars
---@field grid { enabled: boolean, size: number }
---@field positions table<string, KFS_Position>
---@field scales table<string, number>
---@field buffAnimationsEnabled boolean
---@field globalCooldownEnabled boolean
---@field pyramidLayoutEnabled boolean
---@field alwaysExpandedBars boolean
---@field pyramidOffset { left: number, top: number }
---@field profileMode string
---@field showAllLabels boolean

---@class KFS_Defaults
---@field grid { enabled: boolean, size: number }
---@field positions table
---@field scales table
---@field buffAnimationsEnabled boolean
---@field globalCooldownEnabled boolean
---@field profileMode string
---@field pyramidLayoutEnabled boolean
---@field pyramidOffset { left: number, top: number }
---@field alwaysExpandedBars boolean
---@field showAllLabels boolean

---@class KhajiitFengShui
---@field name string Addon name
---@field displayName string Localized display name
---@field version string Version string
---@field savedVars KFS_SavedVars|nil Active saved variables (account or character)
---@field accountSavedVars KFS_SavedVars|nil Account-wide saved variables
---@field characterSavedVars KFS_SavedVars|nil Per-character saved variables
---@field panels KhajiitFengShuiPanel[] All created panel instances
---@field panelLookup table<string, KhajiitFengShuiPanel> Panel ID to panel instance map
---@field definitionLookup table<string, KhajiitFengShuiPanelDefinition>|nil Definition ID to definition map
---@field activePanelId string|nil Currently moving panel ID
---@field editModeFocusId string|nil Panel focused in edit mode
---@field profileMode string|nil "account" or "character"
---@field editModeActive boolean Whether edit mode is active
---@field editModeController KFS_EditModeController|nil Edit mode controller instance
---@field settingsController KFS_SettingsController|nil Settings controller instance
---@field gridOverlay KFS_GridOverlay|nil Grid overlay instance
---@field keybindStripDescriptor table?
---@field keybindStripActive boolean
---@field keybindSceneCallbacks table
---@field keybindSceneGroups table
---@field keybindStripReduced boolean
---@field keybindStripOriginalHeight number?
---@field keybindStripBackgroundOriginalHeight number?
---@field keybindStripBackgroundTextureOriginalHeight number?
---@field keybindStripCenterAdjusted boolean
---@field keybindStripBackgroundWasHidden boolean?
---@field keybindFragmentSceneName string?
---@field keybindScenes table?
---@field actionLayerName string?
---@field actionLayerActive boolean
---@field editModeHintShown boolean
---@field compassHookRegistered boolean
---@field buffAnimationHookRegistered boolean
---@field globalCooldownActive boolean
---@field groupFrameHooksRegistered boolean
---@field LHAS LibHarvensAddonSettings LibHarvensAddonSettings instance
---@field settingsPanel table|nil Settings panel instance
---@field defaults KFS_Defaults Default configuration values
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
    showAllLabels = false;
};

local SCALE_MIN_PERCENT = 50;
local SCALE_MAX_PERCENT = 150;
local SCALE_STEP_PERCENT = 5;
local DEFAULT_SCALE = 1;

---@class LibCombatAlerts
---@field MoveableControl table
---@field EVENT_CONTROL_MOVE_START string
---@field EVENT_CONTROL_MOVE_STOP string

---@class LibCombatAlerts_MoveableControl
---@field New fun(control: userdata, options: { color: integer, size: number }): LibCombatAlerts_MoveableControl
---@field ToggleLock fun(self: LibCombatAlerts_MoveableControl, locked: boolean)
---@field ToggleGamepadMove fun(self: LibCombatAlerts_MoveableControl, enabled: boolean, speed: number?)
---@field SetSnap fun(self: LibCombatAlerts_MoveableControl, snapSize: number?)
---@field GetPosition fun(self: LibCombatAlerts_MoveableControl, snapToGrid: boolean?): KFS_Position
---@field GetLeftTopPosition fun(self: LibCombatAlerts_MoveableControl, snapToGrid: boolean?): { left: number, top: number }
---@field UpdatePosition fun(self: LibCombatAlerts_MoveableControl, position: KFS_Position)
---@field RegisterCallback fun(self: LibCombatAlerts_MoveableControl, id: string, event: string, callback: function)
---@field SetCenterHighlightControl fun(self: LibCombatAlerts_MoveableControl, control: userdata)

---@class LibHarvensAddonSettings
---@field AddAddon fun(name: string, options: table): table
---@field ST_SECTION integer
---@field ST_SLIDER integer
---@field ST_CHECKBOX integer
---@field ST_BUTTON integer
---@field ST_DROPDOWN integer
---@field ST_LABEL integer

---@type LibCombatAlerts?
local LCA;
---@type LibHarvensAddonSettings?
local LHAS;

local em = GetEventManager();
local sceneManager = SCENE_MANAGER;
local SecurePostHook = SecurePostHook;

local PanelUtils = KFS_PanelUtils;
local PanelDefinitions = KFS_PanelDefinitions;
local GridOverlay = KFS_GridOverlay;
local EditModeController = KFS_EditModeController;
local SettingsController = KFS_SettingsController;


---Builds overlay message with position and scale
---@param panel KhajiitFengShuiPanel
---@param left number
---@param top number
---@return string
function KhajiitFengShui:BuildOverlayMessage(panel, left, top)
    local labelText = PanelDefinitions.getLabel(panel.definition);
    local message = PanelUtils.formatPositionMessage(left, top, labelText);
    local scalePercent = zo_roundToNearest(self:GetPanelScale(panel.definition.id) * 100, SCALE_STEP_PERCENT);
    return string.format("%s | %d%%", message, scalePercent);
end;

---Ensures saved vars has all required fields
---@param savedVars KFS_SavedVars?
---@param defaults KFS_Defaults?
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
    if savedVars.showAllLabels == nil then
        savedVars.showAllLabels = defaults.showAllLabels or false;
    end;
end;

---@class KhajiitFengShuiPanel
---@field definition KhajiitFengShuiPanelDefinition Panel definition
---@field control userdata Game UI control being tracked
---@field overlay userdata|nil Movable overlay window
---@field handler LibCombatAlerts_MoveableControl|nil LibCombatAlerts MoveableControl handler
---@field label userdata|nil Overlay label control
---@field defaultPosition { left: number, top: number }|nil Original position before any moves
---@field defaultScale number Original scale before any changes
---@field gamepadActive boolean|nil Whether gamepad movement is active
---@field sectionAdded boolean|nil Settings section created flag
---@field scaleSettingAdded boolean|nil Scale slider created flag
---@field moveSettingAdded boolean|nil Move button created flag
---@field compassDefaults { baseWidth: number?, baseHeight: number?, leftWidth: number?, rightWidth: number?, labelScale: number?, labelAnchorPoint: integer?, labelAnchorTarget: userdata?, labelAnchorRelativePoint: integer?, labelOffsetX: number?, labelOffsetY: number? }|nil Compass-specific defaults

---Updates overlay label text
---@param panel KhajiitFengShuiPanel
---@param message string
local function UpdateOverlayLabel(panel, message)
    PanelUtils.updateOverlayLabel(panel.label, message);
end;


---Syncs overlay size to control
---@param panel KhajiitFengShuiPanel
local function SyncOverlaySize(panel)
    PanelUtils.syncOverlaySize(panel);
end;

---Gets scale for a panel
---@param panelId string
---@return number
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

---Gets scale as percentage for a panel
---@param panelId string
---@return number
function KhajiitFengShui:GetPanelScalePercent(panelId)
    return zo_roundToNearest(self:GetPanelScale(panelId) * 100, SCALE_STEP_PERCENT);
end;

---Applies scale to a panel
---@param panel KhajiitFengShuiPanel?
function KhajiitFengShui:ApplyPanelScale(panel)
    if not panel then
        return;
    end;
    PanelUtils.applyScale(panel, self:GetPanelScale(panel.definition.id));
end;

---Sets scale for a panel
---@param panelId string
---@param scale number
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

---Attempts to create a panel from definition
---@param definition KhajiitFengShuiPanelDefinition?
---@return KhajiitFengShuiPanel?
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

---Checks if panel overlay should be visible
---@param panel KhajiitFengShuiPanel
---@return boolean
function KhajiitFengShui:IsPanelVisible(panel)
    if self.editModeActive then
        return true;
    end;

    return self.activePanelId == panel.definition.id;
end;

---Checks if panel should be unlocked for movement
---@param panel KhajiitFengShuiPanel
---@return boolean
function KhajiitFengShui:IsPanelUnlocked(panel)
    if self.editModeActive then
        return true;
    end;

    if not self.activePanelId then
        return false;
    end;

    if self.activePanelId == panel.definition.id then
        return true;
    end;

    if self.savedVars.pyramidLayoutEnabled then
        local isPyramidBar = panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina";
        local isActivePyramidBar = self.activePanelId == "playerHealth" or self.activePanelId == "playerMagicka" or self.activePanelId == "playerStamina";
        if isPyramidBar and isActivePyramidBar then
            return true;
        end;
    end;

    return false;
end;

---Refreshes panel state (locked, visible, etc)
---@param panel KhajiitFengShuiPanel
function KhajiitFengShui:RefreshPanelState(panel)
    if not (panel and panel.handler) then
        return;
    end;

    -- Determine active panel ID based on current mode
    local activePanelId = self.editModeActive and self.editModeFocusId or self.activePanelId;
    local isActive = panel.definition.id == activePanelId;
    local shouldGamepadMove = activePanelId ~= nil and isActive;

    -- Update lock state
    local unlocked = self:IsPanelUnlocked(panel);
    panel.handler:ToggleLock(not unlocked);

    -- Update gamepad move state if changed
    if panel.gamepadActive ~= shouldGamepadMove then
        panel.handler:ToggleGamepadMove(shouldGamepadMove, 10000);
        panel.gamepadActive = shouldGamepadMove;
    end;

    -- Update overlay visibility and highlight
    if panel.overlay then
        panel.overlay:SetHidden(not self:IsPanelVisible(panel));
        PanelUtils.setOverlayHighlight(panel, isActive);
    end;

    -- Update label visibility
    if panel.label then
        local isPanelVisible = self:IsPanelVisible(panel);
        local showLabel = isPanelVisible and (self.savedVars.showAllLabels or isActive);
        panel.label:SetHidden(not showLabel);
    end;
end;

---Refreshes state for all panels
function KhajiitFengShui:RefreshAllPanels()
    for _, panel in ipairs(self.panels) do
        self:RefreshPanelState(panel);
    end;
end;

---Ensures compass hook is registered
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

---Ensures group frame hooks are registered
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

---Registers buff animation hook
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

---Updates buff animation hook based on settings
function KhajiitFengShui:UpdateBuffAnimationHook()
    if self.savedVars and self.savedVars.buffAnimationsEnabled then
        self:RegisterBuffAnimationHook();
    end;
end;

---Applies global cooldown setting
function KhajiitFengShui:ApplyGlobalCooldownSetting()
    local enabled = self.savedVars and self.savedVars.globalCooldownEnabled;
    local desired = enabled == true;
    if self.globalCooldownActive ~= desired then
        ZO_ActionButtons_ToggleShowGlobalCooldown();
        self.globalCooldownActive = desired;
    end;
end;

---Gets current snap grid size
---@return number
function KhajiitFengShui:GetSnapSize()
    if not self.savedVars.grid.enabled then
        return 0;
    end;
    return self.savedVars.grid.size or self.defaults.grid.size;
end;

---Applies saved position to panel
---@param panel KhajiitFengShuiPanel
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

    local message = self:BuildOverlayMessage(panel, panel.control:GetLeft(), panel.control:GetTop());
    UpdateOverlayLabel(panel, message);
    self:RefreshPanelState(panel);
end;

---Gets expected bar width with scale applied
---@param panel KhajiitFengShuiPanel
---@param scale number
---@return number
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

---Gets expected bar height with scale applied
---@param panel KhajiitFengShuiPanel
---@param scale number
---@return number
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

---Starts moving a control
---@param panelId string
function KhajiitFengShui:StartControlMove(panelId)
    local panel = self.panelLookup[panelId];
    if not (panel and panel.handler) then
        return;
    end;

    self.activePanelId = panelId;
    self:RefreshAllPanels();
    self:RefreshGridOverlay();
end;

---Handles move start event
---@param panel KhajiitFengShuiPanel
---@param handler LibCombatAlerts_MoveableControl
function KhajiitFengShui:OnMoveStart(panel, handler)
    local updateName = string.format("%s_MoveUpdate_%s", self.name, panel.definition.id);

    -- Only apply pyramid layout updates when in edit mode and actively dragging
    -- When using settings move button, treat as individual bar movement
    if self.editModeActive and self.savedVars.pyramidLayoutEnabled and (panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina") then
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

---Updates pyramid layout from a moved panel position
---@param movedPanelId string
---@param left number
---@param top number
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

---Handles move stop event
---@param panel KhajiitFengShuiPanel
---@param handler LibCombatAlerts_MoveableControl
---@param newPos KFS_Position?
---@param isExplicitStop boolean?
function KhajiitFengShui:OnMoveStop(panel, handler, newPos, isExplicitStop)
    local updateName = string.format("%s_MoveUpdate_%s", self.name, panel.definition.id);
    em:UnregisterForUpdate(updateName);

    -- Only apply pyramid layout updates when in edit mode
    -- When using settings move button, treat as individual bar movement
    if self.editModeActive and self.savedVars.pyramidLayoutEnabled and (panel.definition.id == "playerHealth" or panel.definition.id == "playerMagicka" or panel.definition.id == "playerStamina") then
        local left, top = PanelUtils.getAnchorPosition(handler, true);
        self:UpdatePyramidLayoutFromPosition(panel.definition.id, left, top);
    else
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
    end;

    if isExplicitStop or IsInGamepadPreferredMode() then
        self.activePanelId = nil;
        self:RefreshAllPanels();
        self:RefreshGridOverlay();
    else
        self:RefreshAllPanels();
    end;
end;

---Creates overlay for panel
---@param panel KhajiitFengShuiPanel
---@return userdata
local function CreateOverlay(panel)
    local overlay, label = PanelUtils.createOverlay(panel.definition.id, panel.control);
    panel.label = label;
    return overlay;
end;

---Creates mover handler for panel
---@param panel KhajiitFengShuiPanel
function KhajiitFengShui:CreateMover(panel)
    if not panel then
        return;
    end;

    panel.overlay = CreateOverlay(panel);
    if not panel.overlay then
        return;
    end;

    panel.handler = LCA.MoveableControl:New(panel.overlay, { color = 0x33DD33FF; size = 2 });
    if not panel.handler then
        return;
    end;

    if panel.handler.SetCenterHighlightControl then
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

---Applies snap settings to all panels
function KhajiitFengShui:ApplySnapSettings()
    local snapSize = self:GetSnapSize();
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            panel.handler:SetSnap(snapSize > 0 and snapSize or nil);
        end;
    end;

    self:RefreshGridOverlay();
end;

---Refreshes grid overlay visibility and size
function KhajiitFengShui:RefreshGridOverlay()
    if not self.gridOverlay then
        return;
    end;

    local gridEnabled = self.savedVars and self.savedVars.grid and self.savedVars.grid.enabled;
    local snapSize = self:GetSnapSize();
    local shouldShow = gridEnabled and (self.editModeActive or self.activePanelId ~= nil);
    self.gridOverlay:Refresh(shouldShow, snapSize);
end;

---Enumerates all focusable panel IDs
---@param self KhajiitFengShui
---@return string[]
local function EnumerateFocusablePanelIds(self)
    local ids = {};
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            table.insert(ids, panel.definition.id);
        end;
    end;
    return ids;
end;

---Clears edit mode focus
function KhajiitFengShui:ClearEditModeFocus()
    self.editModeFocusId = nil;
    self:RefreshAllPanels();
end;

---Sets edit mode focus to a panel
---@param panelId string?
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

---Selects first focusable panel
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

---Cycles focused panel in direction
---@param direction integer
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

---Shows edit mode hint
function KhajiitFengShui:ShowEditModeHint()
    if self.editModeHintShown then
        return;
    end;

    if IsInGamepadPreferredMode() then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(KFS_EDIT_MODE_HINT));
        self.editModeHintShown = true;
    end;
end;

---Activates action layer
function KhajiitFengShui:ActivateActionLayer()
    if not self.actionLayerName or self.actionLayerActive then
        return;
    end;
    PushActionLayerByName(self.actionLayerName);
    self.actionLayerActive = true;
end;

---Deactivates action layer
function KhajiitFengShui:DeactivateActionLayer()
    if not self.actionLayerName or not self.actionLayerActive then
        return;
    end;
    RemoveActionLayerByName(self.actionLayerName);
    self.actionLayerActive = false;
end;

---Ensures keybind descriptor is created
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
        {
            name = function ()
                return GetString(KFS_KEYBIND_TOGGLE_LABELS);
            end;
            keybind = "UI_SHORTCUT_QUATERNARY";
            alignment = KEYBIND_STRIP_ALIGN_RIGHT;
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive();
            end;
            callback = function ()
                addon:ToggleLabels();
            end;
        };
    };
end;

---Removes keybind strip
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

---Applies keybind strip sizing based on edit mode
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

---Handles keybind scene state change
---@param sceneName string
---@param newState integer
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

---Refreshes keybind strip
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

---Registers a scene for keybind callbacks
---@param sceneName string
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

---Updates keybind fragments
function KhajiitFengShui:UpdateKeybindFragments()
    if not self.keybindScenes then
        return;
    end;

    -- Scene fragments manage the keybind strip visibility. No-op here.
end;

---Initializes keybind strip
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

---Stops control movement
function KhajiitFengShui:StopControlMove()
    if not self.activePanelId then
        return;
    end;
    local panel = self.panelLookup[self.activePanelId];
    if panel and panel.handler then
        local position = panel.handler:GetPosition(true);
        self:OnMoveStop(panel, panel.handler, position, true);
    end;
end;

---Checks if edit mode is active
---@return boolean
function KhajiitFengShui:IsEditModeActive()
    return self.editModeActive == true;
end;

---Gets current profile mode
---@return string
function KhajiitFengShui:GetProfileMode()
    return self.profileMode or self.defaults.profileMode;
end;

---Resolves saved vars for a mode
---@param self KhajiitFengShui
---@param mode string
---@return KFS_SavedVars?
local function ResolveSavedVarsForMode(self, mode)
    if mode == "character" then
        return self.characterSavedVars;
    end;
    return self.accountSavedVars;
end;

---Sets profile mode
---@param mode string
---@param suppressRefresh boolean?
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

---Sets edit mode active state
---@param active boolean
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

    CHAT_ROUTER:AddSystemMessage(message);

    if shouldEnable then
        self:ShowEditModeHint();
    end;
end;

---Toggles edit mode
function KhajiitFengShui:ToggleEditMode()
    self:SetEditModeActive(not self.editModeActive);
end;

---Toggles label visibility
function KhajiitFengShui:ToggleLabels()
    if not self.savedVars then
        return;
    end;

    if not self:IsEditModeActive() then
        return;
    end;

    self.savedVars.showAllLabels = not self.savedVars.showAllLabels;
    local status = self.savedVars.showAllLabels and "all labels visible" or "only active label visible";
    CHAT_ROUTER:AddSystemMessage(string.format("[KhajiitFengShui] Labels: %s", status));

    self:RefreshAllPanels();
end;

---Resets all positions and scales
function KhajiitFengShui:ResetPositions()
    local preservePyramid = self.savedVars.pyramidLayoutEnabled;
    local preservePyramidOffset = preservePyramid and PanelUtils.copyPosition(self.savedVars.pyramidOffset);

    self.savedVars.positions = {};
    self.savedVars.scales = {};

    if preservePyramid and preservePyramidOffset then
        self.savedVars.pyramidOffset = preservePyramidOffset;
    else
        self.savedVars.pyramidOffset = PanelUtils.copyPosition(self.defaults.pyramidOffset);
    end;

    ReloadUI("ingame");
end;

---Handles target frame creation
---@param targetFrame { GetPrimaryControl: fun(): userdata }
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

---Handles scene state change
---@param oldState integer
---@param newState integer
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

---Initializes all panels
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

---Applies all saved positions
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

---Applies pyramid layout to attribute bars
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

    zo_callLater(function ()
                     if not (healthPanel and healthPanel.handler and magickaPanel and magickaPanel.handler and staminaPanel and staminaPanel.handler) then
                         return;
                     end;

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

---Handles player activated event
---@param eventId integer
---@param initial boolean
function KhajiitFengShui:EVENT_PLAYER_ACTIVATED(eventId, initial)
    zo_callLater(function ()
                     self:ApplyAllPositions();
                 end, 200);
end;

---Handles addon loaded event
---@param event integer
---@param addonName string
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

    if self.savedVars.alwaysExpandedBars then
        -- Hook OnValueChanged to force expanded state when enabled
        ZO_PreHook(ZO_UnitVisualizer_ShrinkExpandModule, "OnValueChanged", function (moduleself, bar, info, stat, instant)
            -- Force expanded state and width
            info.state = ATTRIBUTE_BAR_STATE_EXPANDED;
            bar:SetWidth(moduleself.expandedWidth);
            bar.bgContainer:SetWidth(moduleself.expandedWidth);
            -- Prevent original method from running
            return true;
        end);

        -- Force re-initialization if bars were already created before the hook
        local module = PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.attributeVisualizer;
        if module then
            for _, visualModule in pairs(module.visualModules) do
                if visualModule.InitializeBarValues then
                    visualModule:InitializeBarValues();
                end;
            end;
        end;
    end;

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
