local ADDON_NAME = "KhajiitFengShui"
local ADDON_VERSION = "1.0.6"

--- @class KhajiitFengShui
local KhajiitFengShui =
{
    name = ADDON_NAME,
    displayName = GetString(KFS_NAME),
    version = ADDON_VERSION,
    savedVars = nil,
    panels = {},
    panelLookup = {},
    activePanelId = nil,
    compassHookRegistered = false,
    buffAnimationHookRegistered = false,
    globalCooldownActive = false,
}

KhajiitFengShui.defaults =
{
    grid =
    {
        enabled = false,
        size = 15,
    },
    positions = {},
    buffAnimationsEnabled = false,
    globalCooldownEnabled = false,
}

local LCA  --- @type LibCombatAlerts
local LHAS --- @type LibHarvensAddonSettings

local wm = GetWindowManager()
local em = GetEventManager()
local sceneManager = SCENE_MANAGER
local SecurePostHook = SecurePostHook

local PanelUtils = KFS_PanelUtils
local PanelDefinitions = KFS_PanelDefinitions

local function BuildOverlayMessage(panel, left, top)
    return PanelUtils.formatPositionMessage(left, top, PanelDefinitions.getLabel(panel.definition))
end

--- @class KhajiitFengShuiPanel
--- @field definition KhajiitFengShuiPanelDefinition
--- @field control Control
--- @field overlay TopLevelWindow
--- @field handler MoveableControl
--- @field label LabelControl

local function UpdateOverlayLabel(panel, message)
    PanelUtils.updateOverlayLabel(panel.label, message)
end

--- @param panel KhajiitFengShuiPanel
--- @return string
local function BuildPositionText(panel)
    if not (panel and panel.handler) then
        return "N/A"
    end
    local left, top = PanelUtils.getAnchorPosition(panel.handler, true)
    return string.format("%d, %d", left, top)
end

--- @param panel KhajiitFengShuiPanel
local function SyncOverlaySize(panel)
    PanelUtils.syncOverlaySize(panel)
end

function KhajiitFengShui:AddPanelSetting(panel)
    if not self.settingsPanel or panel.settingAdded then
        return
    end

    self.settingsPanel:AddSetting(
        {
            type = LHAS.ST_BUTTON,
            label = PanelDefinitions.getLabel(panel.definition),
            tooltip = function ()
                return string.format("%s\n%s", GetString(KFS_MOVE_BUTTON_DESC), BuildPositionText(panel))
            end,
            buttonText = GetString(KFS_MOVE_BUTTON),
            disable = function ()
                return panel.handler == nil
            end,
            clickHandler = function ()
                if self.activePanelId == panel.definition.id then
                    self:StopControlMove()
                else
                    self:StartControlMove(panel.definition.id)
                end
            end,
        })
    panel.settingAdded = true
end

function KhajiitFengShui:TryCreatePanel(definition)
    if not definition then
        return nil
    end

    local control = PanelDefinitions.resolveControl(definition)
    if not control then
        return nil
    end

    local existing = self.panelLookup[definition.id]
    if existing then
        existing.control = control
        return existing
    end

    local left = control:GetLeft() or 0
    local top = control:GetTop() or 0
    local panel =
    {
        definition = definition,
        control = control,
        defaultPosition =
        {
            left = left,
            top = top,
        },
    }

    table.insert(self.panels, panel)
    self.panelLookup[definition.id] = panel

    self:CreateMover(panel)
    self:AddPanelSetting(panel)
    return panel
end

--- @param panel KhajiitFengShuiPanel
--- @return boolean
function KhajiitFengShui:IsPanelVisible(panel)
    return self.activePanelId == panel.definition.id
end

--- @param panel KhajiitFengShuiPanel
--- @return boolean
function KhajiitFengShui:IsPanelUnlocked(panel)
    return self.activePanelId == panel.definition.id
end

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:RefreshPanelState(panel)
    local unlocked = self:IsPanelUnlocked(panel)
    if panel.handler then
        panel.handler:ToggleLock(not unlocked)
    end
    if panel.overlay then
        panel.overlay:SetHidden(not self:IsPanelVisible(panel))
    end
end

function KhajiitFengShui:RefreshAllPanels()
    for _, panel in ipairs(self.panels) do
        self:RefreshPanelState(panel)
    end
end

function KhajiitFengShui:EnsureCompassHook()
    if self.compassHookRegistered then
        return
    end

    if not (COMPASS_FRAME and COMPASS_FRAME.ApplyStyle and ZO_PostHook) then
        return
    end

    ZO_PostHook(COMPASS_FRAME, "ApplyStyle", function ()
        local compassPanel = self.panelLookup and self.panelLookup.compass
        if not (compassPanel and compassPanel.handler and compassPanel.control and compassPanel.control.SetAnchor) then
            return
        end
        local left, top = PanelUtils.getAnchorPosition(compassPanel.handler, true)
        PanelUtils.applyControlAnchor(compassPanel, left, top)
    end)

    self.compassHookRegistered = true
end

function KhajiitFengShui:RegisterBuffAnimationHook()
    if self.buffAnimationHookRegistered then
        return
    end
    if not SecurePostHook then
        return
    end
    local addon = self
    SecurePostHook("ZO_BuffDebuffIcon_OnInitialized", function (control)
        if addon.savedVars and addon.savedVars.buffAnimationsEnabled then
            control.showCooldown = true
        end
    end)
    self.buffAnimationHookRegistered = true
end

function KhajiitFengShui:UpdateBuffAnimationHook()
    if self.savedVars and self.savedVars.buffAnimationsEnabled then
        self:RegisterBuffAnimationHook()
    end
end

function KhajiitFengShui:ApplyGlobalCooldownSetting()
    local enabled = self.savedVars and self.savedVars.globalCooldownEnabled
    local desired = enabled == true
    if self.globalCooldownActive ~= desired then
        ZO_ActionButtons_ToggleShowGlobalCooldown()
        self.globalCooldownActive = desired
    end
end

function KhajiitFengShui:GetSnapSize()
    if not self.savedVars.grid.enabled then
        return 0
    end
    return self.savedVars.grid.size or self.defaults.grid.size
end

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:ApplySavedPosition(panel)
    if not panel.handler then
        return
    end
    local hasCustom = self.savedVars.positions[panel.definition.id] ~= nil
    local handler = panel.handler
    local savedPosition = self.savedVars.positions[panel.definition.id]

    if savedPosition then
        handler:UpdatePosition(savedPosition)
    else
        local left = panel.control:GetLeft()
        local top = panel.control:GetTop()
        handler:UpdatePosition({ left = left, top = top })
    end

    if panel.definition.preApply then
        panel.definition.preApply(panel.control, hasCustom)
    end

    local left, top = PanelUtils.getAnchorPosition(handler)
    PanelUtils.applyControlAnchor(panel, left, top)

    if panel.definition.postApply then
        panel.definition.postApply(panel.control, hasCustom)
    end

    SyncOverlaySize(panel)

    local message = BuildOverlayMessage(panel, left, top)
    UpdateOverlayLabel(panel, message)
    self:RefreshPanelState(panel)
end

--- @param panelId string
function KhajiitFengShui:StartControlMove(panelId)
    if self.activePanelId and self.activePanelId ~= panelId then
        local previous = self.panelLookup[self.activePanelId]
        if previous and previous.handler then
            previous.handler:ToggleGamepadMove(false)
            previous.handler:ToggleLock(true)
        end
    end

    local panel = self.panelLookup[panelId]
    if not panel or not panel.handler then
        return
    end

    self.activePanelId = panelId
    self:RefreshAllPanels()
    panel.handler:ToggleLock(false)
    panel.handler:ToggleGamepadMove(true, 10000)
end

--- @param panel KhajiitFengShuiPanel
--- @param handler MoveableControl
function KhajiitFengShui:OnMoveStart(panel, handler)
    local updateName = string.format("%s_MoveUpdate_%s", self.name, panel.definition.id)
    em:RegisterForUpdate(updateName, 200, function ()
        local left, top = PanelUtils.getAnchorPosition(handler)
        local message = BuildOverlayMessage(panel, left, top)
        UpdateOverlayLabel(panel, message)
    end)
end

--- @param panel KhajiitFengShuiPanel
--- @param handler MoveableControl
--- @param newPos table<string, any>?
function KhajiitFengShui:OnMoveStop(panel, handler, newPos)
    local updateName = string.format("%s_MoveUpdate_%s", self.name, panel.definition.id)
    em:UnregisterForUpdate(updateName)

    local position = newPos or handler:GetPosition(true)
    self.savedVars.positions[panel.definition.id] = PanelUtils.copyPosition(position)

    local left, top = PanelUtils.getAnchorPosition(handler, true)
    PanelUtils.applyControlAnchor(panel, left, top)

    if panel.definition.postApply then
        panel.definition.postApply(panel.control, true)
    end

    local message = BuildOverlayMessage(panel, left, top)
    UpdateOverlayLabel(panel, message)

    handler:ToggleGamepadMove(false)
    self.activePanelId = nil
    self:RefreshAllPanels()
end

--- @param panel KhajiitFengShuiPanel
--- @return TopLevelWindow
local function CreateOverlay(panel)
    local overlay, label = PanelUtils.createOverlay(panel.definition.id, panel.control)
    panel.label = label
    return overlay
end

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:CreateMover(panel)
    panel.overlay = CreateOverlay(panel)

    panel.handler = LCA.MoveableControl:New(panel.overlay, { color = 0x00C0FFFF, size = 2 })
    panel.handler:RegisterCallback(string.format("%s_MoveStart_%s", self.name, panel.definition.id), LCA.EVENT_CONTROL_MOVE_START, function ()
        self:OnMoveStart(panel, panel.handler)
    end)
    panel.handler:RegisterCallback(string.format("%s_MoveStop_%s", self.name, panel.definition.id), LCA.EVENT_CONTROL_MOVE_STOP, function (newPos)
        self:OnMoveStop(panel, panel.handler, newPos)
    end)

    local snapSize = self:GetSnapSize()
    panel.handler:SetSnap(snapSize > 0 and snapSize or nil)
    panel.handler:ToggleLock(true)

    PanelUtils.applySizing(panel.control, panel.definition.width, panel.definition.height)
    self:ApplySavedPosition(panel)
    if panel.definition.id == "compass" then
        self:EnsureCompassHook()
    end
end

function KhajiitFengShui:ApplySnapSettings()
    local snapSize = self:GetSnapSize()
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            panel.handler:SetSnap(snapSize > 0 and snapSize or nil)
        end
    end
end

function KhajiitFengShui:StopControlMove()
    if not self.activePanelId then
        return
    end
    local panel = self.panelLookup[self.activePanelId]
    if panel and panel.handler then
        panel.handler:ToggleGamepadMove(false)
        panel.handler:ToggleLock(true)
        self:OnMoveStop(panel, panel.handler, panel.handler:GetPosition(true))
    end
end

function KhajiitFengShui:ResetPositions()
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            self.savedVars.positions[panel.definition.id] = nil
            if panel.defaultPosition then
                panel.handler:UpdatePosition(PanelUtils.copyPosition(panel.defaultPosition))
                if panel.definition.preApply then
                    panel.definition.preApply(panel.control, false)
                end
                PanelUtils.applyControlAnchor(panel, panel.defaultPosition.left or 0, panel.defaultPosition.top or 0)
                if panel.definition.postApply then
                    panel.definition.postApply(panel.control, false)
                end
                local message = BuildOverlayMessage(panel, panel.defaultPosition.left or 0, panel.defaultPosition.top or 0)
                UpdateOverlayLabel(panel, message)
            end
        end
    end
    for _, panel in ipairs(self.panels) do
        self:ApplySavedPosition(panel)
    end
    self:ApplySnapSettings()
    self:RefreshAllPanels()
end

function KhajiitFengShui:OnTargetFrameCreated(targetFrame)
    local definition = self.definitionLookup and self.definitionLookup.targetFrame
    if not definition then
        return
    end

    local control = targetFrame and targetFrame.GetPrimaryControl and targetFrame:GetPrimaryControl()
    if control then
        definition.controlName = control:GetName()
    end

    local panel = self:TryCreatePanel(definition)
    if not panel then
        return
    end

    if control then
        panel.control = control
    end

    if panel.control and not panel.defaultPosition then
        panel.defaultPosition =
        {
            left = panel.control:GetLeft() or 0,
            top = panel.control:GetTop() or 0,
        }
    end

    if panel.control then
        self:ApplySavedPosition(panel)
    end

    if panel.definition.id == "compass" then
        self:EnsureCompassHook()
    end

    self:AddPanelSetting(panel)
end

--- @param oldState number
--- @param newState number
function KhajiitFengShui:OnSceneChange(oldState, newState)
    if not self.activePanelId then
        return
    end

    if newState == SCENE_SHOWN then
        for _, panel in ipairs(self.panels) do
            if panel.overlay then
                panel.overlay:SetHidden(true)
            end
        end
    elseif newState == SCENE_HIDDEN then
        self:RefreshAllPanels()
    end
end

function KhajiitFengShui:CreateSettingsMenu()
    if not LHAS then
        return
    end

    local settings = LHAS:AddAddon(GetString(KFS_SETTINGS),
                                   {
                                       allowDefaults = true,
                                       defaultsFunction = function ()
                                           self.savedVars.grid.enabled = self.defaults.grid.enabled
                                           self.savedVars.grid.size = self.defaults.grid.size
                                           self:ResetPositions()
                                           self:ApplySnapSettings()
                                           self.savedVars.buffAnimationsEnabled = self.defaults.buffAnimationsEnabled
                                           self:UpdateBuffAnimationHook()
                                           self.savedVars.globalCooldownEnabled = self.defaults.globalCooldownEnabled
                                           self:ApplyGlobalCooldownSetting()
                                           self.activePanelId = nil
                                           self:RefreshAllPanels()
                                       end,
                                   })

    settings:AddSettings(
        {
            {
                type = LHAS.ST_LABEL,
                label = GetString(KFS_SETTINGS_DESC),
            },
            {
                type = LHAS.ST_CHECKBOX,
                label = GetString(KFS_ENABLE_SNAP),
                tooltip = GetString(KFS_ENABLE_SNAP_DESC),
                default = self.defaults.grid.enabled,
                getFunction = function ()
                    return self.savedVars.grid.enabled
                end,
                setFunction = function (value)
                    self.savedVars.grid.enabled = value
                    self:ApplySnapSettings()
                end,
            },
            {
                type = LHAS.ST_SLIDER,
                label = GetString(KFS_SNAP_SIZE),
                tooltip = GetString(KFS_SNAP_SIZE_DESC),
                min = 2,
                max = 128,
                step = 1,
                default = self.defaults.grid.size,
                getFunction = function ()
                    return self.savedVars.grid.size
                end,
                setFunction = function (value)
                    self.savedVars.grid.size = value
                    self:ApplySnapSettings()
                end,
            },
            {
                type = LHAS.ST_CHECKBOX,
                label = GetString(KFS_ENABLE_BUFF_ANIMATIONS),
                tooltip = GetString(KFS_ENABLE_BUFF_ANIMATIONS_DESC),
                default = self.defaults.buffAnimationsEnabled,
                getFunction = function ()
                    return self.savedVars.buffAnimationsEnabled
                end,
                setFunction = function (value)
                    self.savedVars.buffAnimationsEnabled = value
                    self:UpdateBuffAnimationHook()
                    ReloadUI("ingame")
                end,
            },
            {
                type = LHAS.ST_CHECKBOX,
                label = GetString(KFS_ENABLE_GCD),
                tooltip = GetString(KFS_ENABLE_GCD_DESC),
                default = self.defaults.globalCooldownEnabled,
                getFunction = function ()
                    return self.savedVars.globalCooldownEnabled
                end,
                setFunction = function (value)
                    self.savedVars.globalCooldownEnabled = value
                    self:ApplyGlobalCooldownSetting()
                end,
            },
            {
                type = LHAS.ST_BUTTON,
                label = GetString(KFS_RESET_ALL_DESC),
                tooltip = GetString(KFS_RESET_ALL_DESC),
                buttonText = GetString(KFS_RESET_ALL),
                clickHandler = function ()
                    self:ResetPositions()
                end,
            },
        })

    settings:AddSetting(
        {
            type = LHAS.ST_SECTION,
            label = GetString(KFS_SECTION_CONTROLS),
        })
    self.settingsPanel = settings
    for _, panel in ipairs(self.panels) do
        self:AddPanelSetting(panel)
    end
end

function KhajiitFengShui:InitializePanels()
    self.definitionLookup = {}
    self.panels = {}
    self.panelLookup = {}

    for _, definition in ipairs(PanelDefinitions.getAll()) do
        self.definitionLookup[definition.id] = definition
        self:TryCreatePanel(definition)
    end

    self:RefreshAllPanels()

    local scene = sceneManager:GetScene("gameMenuInGame")
    if scene then
        scene:RegisterCallback("StateChange", function (oldState, newState)
            self:OnSceneChange(oldState, newState)
        end)
    end
end

function KhajiitFengShui:ApplyAllPositions()
    for _, panel in ipairs(self.panels) do
        self:ApplySavedPosition(panel)
    end
end

--- @param eventId integer
--- @param initial boolean
function KhajiitFengShui:EVENT_PLAYER_ACTIVATED(eventId, initial)
    zo_callLater(function ()
                     self:ApplyAllPositions()
                 end, 200)
end

--- @param event number
--- @param addonName string
function KhajiitFengShui:OnAddOnLoaded(event, addonName)
    if addonName ~= self.name then
        return
    end

    em:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)

    LCA = LibCombatAlerts
    LHAS = LibHarvensAddonSettings

    self.savedVars = ZO_SavedVars:NewAccountWide("KhajiitFengShui_SavedVariables", 1, nil, self.defaults)

    self.savedVars.grid = self.savedVars.grid or PanelUtils.copyPosition(self.defaults.grid)
    if self.savedVars.grid.enabled == nil then
        self.savedVars.grid.enabled = self.defaults.grid.enabled
    end
    if not self.savedVars.grid.size then
        self.savedVars.grid.size = self.defaults.grid.size
    end
    self.savedVars.positions = self.savedVars.positions or {}
    if self.savedVars.buffAnimationsEnabled == nil then
        self.savedVars.buffAnimationsEnabled = self.defaults.buffAnimationsEnabled
    end
    if self.savedVars.globalCooldownEnabled == nil then
        self.savedVars.globalCooldownEnabled = self.defaults.globalCooldownEnabled
    end

    self:UpdateBuffAnimationHook()
    self:ApplyGlobalCooldownSetting()

    self:InitializePanels()
    self:CreateSettingsMenu()
    self:ApplyAllPositions()
    self:ApplySnapSettings()
    self:RefreshAllPanels()

    CALLBACK_MANAGER:RegisterCallback("TargetFrameCreated", function (targetFrame)
        self:OnTargetFrameCreated(targetFrame)
    end)

    em:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function (eventId, initial)
        self:EVENT_PLAYER_ACTIVATED(eventId, initial)
    end)
end

em:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function (event, addonName)
    KhajiitFengShui:OnAddOnLoaded(event, addonName)
end)
