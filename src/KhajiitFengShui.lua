local ADDON_NAME = "KhajiitFengShui"
local ADDON_VERSION = "1.0.8"

--- @class KhajiitFengShui
local KhajiitFengShui =
{
    name = ADDON_NAME,
    displayName = GetString(KFS_NAME),
    version = ADDON_VERSION,
    savedVars = nil,
    accountSavedVars = nil,
    characterSavedVars = nil,
    panels = {},
    panelLookup = {},
    activePanelId = nil,
    editModeFocusId = nil,
    profileMode = nil,
    editModeActive = false,
    editModeController = nil,
    gridOverlay = nil,
    keybindStripDescriptor = nil,
    keybindStripActive = false,
    keybindSceneCallbacks = {},
    keybindSceneGroups = {},
    keybindStripReduced = false,
    keybindStripOriginalHeight = nil,
    keybindStripBackgroundOriginalHeight = nil,
    keybindStripBackgroundTextureOriginalHeight = nil,
    keybindStripCenterAdjusted = false,
    keybindStripBackgroundWasHidden = nil,
    keybindFragmentSceneName = nil,
    keybindScenes = nil,
    actionLayerName = nil,
    actionLayerActive = false,
    editModeHintShown = false,
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
    profileMode = "account",
}

local LCA  --- @type LibCombatAlerts
local LHAS --- @type LibHarvensAddonSettings

local wm = GetWindowManager()
local em = GetEventManager()
local sceneManager = SCENE_MANAGER
local SecurePostHook = SecurePostHook

local PanelUtils = KFS_PanelUtils
local PanelDefinitions = KFS_PanelDefinitions
local GridOverlay = KFS_GridOverlay
local EditModeController = KFS_EditModeController

local function IsConsoleInterface()
    return IsConsoleUI()
end

local function BuildOverlayMessage(panel, left, top)
    return PanelUtils.formatPositionMessage(left, top, PanelDefinitions.getLabel(panel.definition))
end

local function GetProfileModeLabel(mode)
    if mode == "character" then
        return GetString(KFS_PROFILE_CHARACTER)
    end
    return GetString(KFS_PROFILE_ACCOUNT)
end

local function EnsureSavedVarStructure(savedVars, defaults)
    if not savedVars then
        return
    end

    defaults = defaults or {}

    savedVars.grid = savedVars.grid or PanelUtils.copyPosition(defaults.grid)
    if savedVars.grid then
        if savedVars.grid.enabled == nil and defaults.grid then
            savedVars.grid.enabled = defaults.grid.enabled
        end
        if not savedVars.grid.size and defaults.grid then
            savedVars.grid.size = defaults.grid.size
        end
    end

    savedVars.positions = savedVars.positions or {}

    if savedVars.buffAnimationsEnabled == nil then
        savedVars.buffAnimationsEnabled = defaults.buffAnimationsEnabled or false
    end
    if savedVars.globalCooldownEnabled == nil then
        savedVars.globalCooldownEnabled = defaults.globalCooldownEnabled or false
    end
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
    if self.editModeActive then
        return true
    end

    return self.activePanelId == panel.definition.id
end

--- @param panel KhajiitFengShuiPanel
--- @return boolean
function KhajiitFengShui:IsPanelUnlocked(panel)
    if self.editModeActive then
        return true
    end

    return self.activePanelId == panel.definition.id
end

--- @param panel KhajiitFengShuiPanel
function KhajiitFengShui:RefreshPanelState(panel)
    local unlocked = self:IsPanelUnlocked(panel)
    local shouldGamepadMove = false
    if self.editModeActive then
        shouldGamepadMove = self.editModeFocusId ~= nil and panel.definition.id == self.editModeFocusId
    else
        shouldGamepadMove = self.activePanelId ~= nil and panel.definition.id == self.activePanelId
    end
    if panel.handler then
        panel.handler:ToggleLock(not unlocked)
        if panel.gamepadActive ~= shouldGamepadMove then
            panel.handler:ToggleGamepadMove(shouldGamepadMove, 10000)
            panel.gamepadActive = shouldGamepadMove
        end
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
    panel.gamepadActive = true
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
    panel.gamepadActive = false
    self.activePanelId = nil
    self:RefreshAllPanels()

    if self.editModeFocusId then
        local focusedPanel = self.panelLookup[self.editModeFocusId]
        if focusedPanel and focusedPanel.handler then
            focusedPanel.handler:ToggleLock(false)
            focusedPanel.handler:ToggleGamepadMove(true, 10000)
            focusedPanel.gamepadActive = true
        end
    end
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
    if panel.handler.SetCenterHighlightControl and panel.overlay then
        panel.handler:SetCenterHighlightControl(panel.overlay)
    end
    panel.handler:RegisterCallback(string.format("%s_MoveStart_%s", self.name, panel.definition.id), LCA.EVENT_CONTROL_MOVE_START, function ()
        self:OnMoveStart(panel, panel.handler)
    end)
    panel.handler:RegisterCallback(string.format("%s_MoveStop_%s", self.name, panel.definition.id), LCA.EVENT_CONTROL_MOVE_STOP, function (newPos)
        self:OnMoveStop(panel, panel.handler, newPos)
    end)
    panel.gamepadActive = false

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

    self:RefreshGridOverlay()
end

function KhajiitFengShui:RefreshGridOverlay()
    if not self.gridOverlay then
        return
    end

    local gridEnabled = self.savedVars and self.savedVars.grid and self.savedVars.grid.enabled
    local snapSize = self:GetSnapSize()
    self.gridOverlay:Refresh(self.editModeActive and gridEnabled, snapSize)
end

local function EnumerateFocusablePanelIds(self)
    local ids = {}
    for _, panel in ipairs(self.panels) do
        if panel.handler then
            table.insert(ids, panel.definition.id)
        end
    end
    return ids
end

function KhajiitFengShui:ClearEditModeFocus()
    self.editModeFocusId = nil
    for _, panel in ipairs(self.panels) do
        if panel.gamepadActive and panel.handler then
            panel.handler:ToggleGamepadMove(false)
            panel.gamepadActive = false
        end
    end
end

function KhajiitFengShui:SetEditModeFocus(panelId)
    if not self.editModeActive then
        return
    end

    if panelId and self.panelLookup[panelId] and self.panelLookup[panelId].handler then
        self.editModeFocusId = panelId
    else
        self.editModeFocusId = nil
    end

    self:RefreshAllPanels()
    self:RefreshKeybindStrip()
end

function KhajiitFengShui:SelectFirstFocusablePanel()
    local ids = EnumerateFocusablePanelIds(self)
    if #ids == 0 then
        self.editModeFocusId = nil
        return
    end

    local target = self.editModeFocusId
    if not target or not (self.panelLookup[target] and self.panelLookup[target].handler) then
        target = ids[1]
    end
    self:SetEditModeFocus(target)
end

function KhajiitFengShui:CycleFocusedPanel(direction)
    if not (self.editModeActive and direction and direction ~= 0) then
        return
    end

    local ids = EnumerateFocusablePanelIds(self)
    local count = #ids
    if count == 0 then
        return
    end

    local currentIndex = 1
    for index, id in ipairs(ids) do
        if id == self.editModeFocusId then
            currentIndex = index
            break
        end
    end

    local nextIndex = ((currentIndex - 1 + direction) % count) + 1
    self:SetEditModeFocus(ids[nextIndex])
end

function KhajiitFengShui:ShowEditModeHint()
    if self.editModeHintShown then
        return
    end

    if IsInGamepadPreferredMode() then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(KFS_EDIT_MODE_HINT))
        self.editModeHintShown = true
    end
end

function KhajiitFengShui:ActivateActionLayer()
    if not self.actionLayerName or self.actionLayerActive then
        return
    end
    PushActionLayerByName(self.actionLayerName)
    self.actionLayerActive = true
end

function KhajiitFengShui:DeactivateActionLayer()
    if not self.actionLayerName or not self.actionLayerActive then
        return
    end
    RemoveActionLayerByName(self.actionLayerName)
    self.actionLayerActive = false
end

function KhajiitFengShui:EnsureKeybindDescriptor()
    if self.keybindStripDescriptor then
        return
    end

    self.actionLayerName = GetString(SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS)

    local addon = self
    self.keybindStripDescriptor =
    {
        {
            ethereal = true,
            name = function ()
                return GetString(KFS_KEYBIND_ENTER_EDIT_MODE)
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function ()
                return IsInGamepadPreferredMode() and not addon:IsEditModeActive()
            end,
            callback = function ()
                addon:SetEditModeActive(true)
            end,
        },
        {
            name = function ()
                return GetString(KFS_KEYBIND_EXIT_EDIT_MODE)
            end,
            keybind = "UI_SHORTCUT_NEGATIVE",
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive()
            end,
            callback = function ()
                addon:SetEditModeActive(false)
            end,
        },
        {
            name = function ()
                return GetString(KFS_KEYBIND_PREVIOUS_PANEL)
            end,
            keybind = "UI_SHORTCUT_INPUT_LEFT",
            gamepadPreferredKeybind = "UI_SHORTCUT_LEFT_SHOULDER",
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive()
            end,
            callback = function ()
                addon:CycleFocusedPanel(-1)
            end,
        },
        {
            name = function ()
                return GetString(KFS_KEYBIND_NEXT_PANEL)
            end,
            keybind = "UI_SHORTCUT_INPUT_RIGHT",
            gamepadPreferredKeybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            visible = function ()
                return IsInGamepadPreferredMode() and addon:IsEditModeActive()
            end,
            callback = function ()
                addon:CycleFocusedPanel(1)
            end,
        },
    }
end

function KhajiitFengShui:RemoveKeybindStrip()
    if not (self.keybindStripActive and self.keybindStripDescriptor) then
        return
    end

    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    self.keybindStripActive = false

    self:ApplyKeybindStripSizing()

    if self.keybindFragmentSceneName then
        local scene = sceneManager:GetScene(self.keybindFragmentSceneName)
        if scene and scene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
            scene:RemoveFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
        end
        self.keybindFragmentSceneName = nil
    end
end

local REDUCED_KEYBIND_STRIP_HEIGHT = 48

function KhajiitFengShui:ApplyKeybindStripSizing()
    local shouldReduce = self.editModeActive and IsInGamepadPreferredMode()
    if shouldReduce then
        if not self.keybindStripReduced then
            if KEYBIND_STRIP and KEYBIND_STRIP.control then
                self.keybindStripOriginalHeight = self.keybindStripOriginalHeight or KEYBIND_STRIP.control:GetHeight()
                KEYBIND_STRIP.control:SetHeight(REDUCED_KEYBIND_STRIP_HEIGHT)
            end
            if ZO_KeybindStripGamepadBackground then
                self.keybindStripBackgroundOriginalHeight = self.keybindStripBackgroundOriginalHeight or ZO_KeybindStripGamepadBackground:GetHeight()
                ZO_KeybindStripGamepadBackground:SetHeight(REDUCED_KEYBIND_STRIP_HEIGHT)
                if self.keybindStripBackgroundWasHidden == nil then
                    self.keybindStripBackgroundWasHidden = ZO_KeybindStripGamepadBackground:IsHidden()
                end
                ZO_KeybindStripGamepadBackground:SetHidden(true)
            end
            if ZO_KeybindStripGamepadBackgroundTexture then
                self.keybindStripBackgroundTextureOriginalHeight = self.keybindStripBackgroundTextureOriginalHeight or ZO_KeybindStripGamepadBackgroundTexture:GetHeight()
                ZO_KeybindStripGamepadBackgroundTexture:SetHeight(REDUCED_KEYBIND_STRIP_HEIGHT)
                ZO_KeybindStripGamepadBackgroundTexture:SetHidden(true)
            end
            if KEYBIND_STRIP and KEYBIND_STRIP.centerParent and not self.keybindStripCenterAdjusted then
                KEYBIND_STRIP.centerParent:ClearAnchors()
                KEYBIND_STRIP.centerParent:SetAnchor(BOTTOM, KEYBIND_STRIP.control, BOTTOM, 0, -6)
                self.keybindStripCenterAdjusted = true
            end
            self.keybindStripReduced = true
        end
    elseif self.keybindStripReduced then
        if KEYBIND_STRIP and KEYBIND_STRIP.control and self.keybindStripOriginalHeight then
            KEYBIND_STRIP.control:SetHeight(self.keybindStripOriginalHeight)
        end
        if ZO_KeybindStripGamepadBackground and self.keybindStripBackgroundOriginalHeight then
            ZO_KeybindStripGamepadBackground:SetHeight(self.keybindStripBackgroundOriginalHeight)
        end
        if ZO_KeybindStripGamepadBackgroundTexture and self.keybindStripBackgroundTextureOriginalHeight then
            ZO_KeybindStripGamepadBackgroundTexture:SetHeight(self.keybindStripBackgroundTextureOriginalHeight)
            ZO_KeybindStripGamepadBackgroundTexture:SetHidden(false)
        end
        if KEYBIND_STRIP and KEYBIND_STRIP.centerParent and self.keybindStripCenterAdjusted then
            KEYBIND_STRIP.centerParent:ClearAnchors()
            KEYBIND_STRIP.centerParent:SetAnchor(CENTER, KEYBIND_STRIP.control, CENTER, 0, 0)
            self.keybindStripCenterAdjusted = false
        end
        if ZO_KeybindStripGamepadBackground then
            if self.keybindStripBackgroundWasHidden ~= nil then
                ZO_KeybindStripGamepadBackground:SetHidden(self.keybindStripBackgroundWasHidden)
            end
        end
        self.keybindStripBackgroundWasHidden = nil
        self.keybindStripReduced = false
    end
end

function KhajiitFengShui:OnKeybindSceneStateChange(sceneName, newState)
    if not IsInGamepadPreferredMode() then
        return
    end

    if not self.editModeActive then
        return
    end

    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        local scene = sceneManager:GetScene(sceneName)
        if scene and not scene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
            scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
            self.keybindFragmentSceneName = sceneName
        end
        if not self.keybindStripActive then
            self:RefreshKeybindStrip()
        end
    elseif newState == SCENE_HIDDEN or newState == SCENE_HIDING then
        local scene = sceneManager:GetScene(sceneName)
        if scene and scene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
            scene:RemoveFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
        end
        if self.keybindFragmentSceneName == sceneName then
            self.keybindFragmentSceneName = nil
        end
        self:RemoveKeybindStrip()
    end
end

function KhajiitFengShui:RefreshKeybindStrip()
    self:EnsureKeybindDescriptor()
    if not self.keybindStripDescriptor then
        return
    end

    self:UpdateKeybindFragments()

    self:ApplyKeybindStripSizing()

    if not (self.editModeActive and IsInGamepadPreferredMode()) then
        self:RemoveKeybindStrip()
        return
    end

    local currentScene = sceneManager:GetCurrentScene()
    local currentName = currentScene and currentScene:GetName()
    local allowed = false
    if currentName and self.keybindScenes then
        for _, name in ipairs(self.keybindScenes) do
            if name == currentName then
                allowed = true
                break
            end
        end
    end

    if not allowed then
        self:RemoveKeybindStrip()
        return
    end

    currentScene = sceneManager:GetCurrentScene()
    if KEYBIND_STRIP_GAMEPAD_FRAGMENT and currentScene and not currentScene:HasFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) then
        currentScene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
        self.keybindFragmentSceneName = currentName
    end

    if self.keybindStripActive then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    else
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
        self.keybindStripActive = true
    end
end

function KhajiitFengShui:RegisterKeybindScene(sceneName)
    if self.keybindSceneCallbacks[sceneName] then
        return
    end

    local scene = sceneManager:GetScene(sceneName)
    if not scene then
        return
    end

    scene:RegisterCallback("StateChange", function (_, newState)
        self:OnKeybindSceneStateChange(sceneName, newState)
    end)

    self.keybindSceneCallbacks[sceneName] = true
end

function KhajiitFengShui:UpdateKeybindFragments()
    if not self.keybindScenes then
        return
    end

    -- Scene fragments manage the keybind strip visibility. No-op here.
end

function KhajiitFengShui:InitializeKeybindStrip()
    if not KEYBIND_STRIP then
        return
    end

    self:EnsureKeybindDescriptor()
    self.keybindScenes = { "hud", "hudui", "gamepadInteract"}
    for _, sceneName in ipairs(self.keybindScenes) do
        self:RegisterKeybindScene(sceneName)
    end
    if self.editModeActive then
        self:RefreshKeybindStrip()
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
        panel.gamepadActive = false
        self:OnMoveStop(panel, panel.handler, panel.handler:GetPosition(true))
    end
end

function KhajiitFengShui:IsEditModeActive()
    return self.editModeActive == true
end

function KhajiitFengShui:GetProfileMode()
    return self.profileMode or self.defaults.profileMode
end

local function ResolveSavedVarsForMode(self, mode)
    if mode == "character" then
        return self.characterSavedVars
    end
    return self.accountSavedVars
end

--- @param mode string
--- @param suppressRefresh boolean?
function KhajiitFengShui:SetProfileMode(mode, suppressRefresh)
    if not mode or mode ~= "character" then
        mode = "account"
    end

    local target = ResolveSavedVarsForMode(self, mode)
    if not target then
        return
    end

    EnsureSavedVarStructure(target, self.defaults)

    self.profileMode = mode
    if self.accountSavedVars then
        self.accountSavedVars.profileMode = mode
    end

    self.savedVars = target

    if suppressRefresh then
        return
    end

    self:UpdateBuffAnimationHook()
    self:ApplyGlobalCooldownSetting()
    self:ApplyAllPositions()
    self:ApplySnapSettings()
    self:RefreshAllPanels()
    self:RefreshGridOverlay()
end

function KhajiitFengShui:SetEditModeActive(active)
    local shouldEnable = active == true
    if self.editModeActive == shouldEnable then
        return
    end

    self.editModeActive = shouldEnable

    if shouldEnable then
        self:SelectFirstFocusablePanel()
        self:ActivateActionLayer()
    else
        self:ClearEditModeFocus()
        self:DeactivateActionLayer()
    end

    self.activePanelId = nil

    self:RefreshAllPanels()
    self:RefreshGridOverlay()
    self:RefreshKeybindStrip()

    local message = shouldEnable and GetString(KFS_EDIT_MODE_ENABLED) or GetString(KFS_EDIT_MODE_DISABLED)

    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(message)
    else
        d(message)
    end

    if shouldEnable then
        self:ShowEditModeHint()
    end
end

function KhajiitFengShui:ToggleEditMode()
    self:SetEditModeActive(not self.editModeActive)
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
        self:RefreshKeybindStrip()
    elseif newState == SCENE_HIDDEN then
        self:RefreshAllPanels()
        self:RefreshKeybindStrip()
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
                                           self:SetProfileMode(self.defaults.profileMode, true)
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
                                           self:RefreshGridOverlay()
                                       end,
                                   })

    local controls =
    {
        {
            type = LHAS.ST_LABEL,
            label = GetString(KFS_SETTINGS_DESC),
        },
    }

    if IsConsoleInterface() then
        table.insert(controls,
                     {
                         type = LHAS.ST_BUTTON,
                         label = GetString(KFS_PROFILE_MODE),
                         tooltip = GetString(KFS_PROFILE_MODE_DESC),
                         buttonText = function ()
                             return GetProfileModeLabel(self:GetProfileMode())
                         end,
                         clickHandler = function ()
                             local nextMode = self:GetProfileMode() == "account" and "character" or "account"
                             self:SetProfileMode(nextMode)
                         end,
                     })
    else
        table.insert(controls,
                     {
                         type = LHAS.ST_DROPDOWN,
                         label = GetString(KFS_PROFILE_MODE),
                         tooltip = GetString(KFS_PROFILE_MODE_DESC),
                         choices = { GetString(KFS_PROFILE_ACCOUNT), GetString(KFS_PROFILE_CHARACTER) },
                         choicesValues = { "account", "character" },
                         getFunction = function ()
                             return self:GetProfileMode()
                         end,
                         setFunction = function (value)
                             self:SetProfileMode(value)
                         end,
                     })
    end

    table.insert(controls,
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
                 })

    table.insert(controls,
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
                 })

    table.insert(controls,
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
                 })

    table.insert(controls,
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
                 })

    table.insert(controls,
                 {
                     type = LHAS.ST_BUTTON,
                     label = GetString(KFS_RESET_ALL_DESC),
                     tooltip = GetString(KFS_RESET_ALL_DESC),
                     buttonText = GetString(KFS_RESET_ALL),
                     clickHandler = function ()
                         self:ResetPositions()
                     end,
                 })
    settings:AddSettings(controls)

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

    self.accountSavedVars = ZO_SavedVars:NewAccountWide("KhajiitFengShui_SavedVariables", 1, nil, self.defaults)
    self.characterSavedVars = ZO_SavedVars:NewCharacterIdSettings("KhajiitFengShui_SavedVariables", 1, nil, self.defaults)

    EnsureSavedVarStructure(self.accountSavedVars, self.defaults)
    EnsureSavedVarStructure(self.characterSavedVars, self.defaults)

    self.accountSavedVars.profileMode = self.accountSavedVars.profileMode or self.defaults.profileMode
    self:SetProfileMode(self.accountSavedVars.profileMode, true)

    self:UpdateBuffAnimationHook()
    self:ApplyGlobalCooldownSetting()

    self:InitializePanels()
    self:CreateSettingsMenu()
    self:ApplyAllPositions()
    self:ApplySnapSettings()
    self:RefreshAllPanels()

    if EditModeController then
        self.editModeController = EditModeController:New(self)
        self.editModeController:Initialize()
    end

    if GridOverlay then
        self.gridOverlay = GridOverlay:New()
        self:RefreshGridOverlay()
    end

    self:InitializeKeybindStrip()

    CALLBACK_MANAGER:RegisterCallback("TargetFrameCreated", function (targetFrame)
        self:OnTargetFrameCreated(targetFrame)
    end)

    em:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function (eventId, initial)
        self:EVENT_PLAYER_ACTIVATED(eventId, initial)
    end)

    em:RegisterForEvent(self.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function ()
        self:UpdateKeybindFragments()
        self:RefreshKeybindStrip()
    end)
end

em:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function (event, addonName)
    KhajiitFengShui:OnAddOnLoaded(event, addonName)
end)
