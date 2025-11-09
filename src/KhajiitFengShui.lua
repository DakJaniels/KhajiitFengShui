local ADDON_NAME = "KhajiitFengShui"
local ADDON_VERSION = "1.0.2"

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
}

KhajiitFengShui.defaults =
{
    grid =
    {
        enabled = false,
        size = 16,
    },
    positions = {},
}

local LCA  --- @type LibCombatAlerts
local LHAS --- @type LibHarvensAddonSettings

local wm = GetWindowManager()
local em = GetEventManager()
local sceneManager = SCENE_MANAGER

--- @param pos table<string, any>
--- @return table<string, any>
local function CopyPosition(pos)
    if not pos then
        return nil
    end
    local copy = {}
    for key, value in pairs(pos) do
        copy[key] = value
    end
    return copy
end

local function GetPanelLabel(controlData)
    return GetString(controlData.label)
end

--- @return boolean
local function IsConsole()
    return IsConsoleUI()
end

--- @alias KhajiitFengShuiPanelDefinition { id: string, controlName: string, label: integer, width?: number, height?: number, condition?: fun(): boolean, postApply:( fun(control: Control, hasCustomPosition: boolean)?) }

--- @type KhajiitFengShuiPanelDefinition[]
local DEFAULT_PANEL_DEFINITIONS =
{
    { id = "infamy",       controlName = "ZO_HUDInfamyMeter",                  label = KFS_LABEL_INFAMY                                 },
    { id = "telvar",       controlName = "ZO_HUDTelvarMeter",                  label = KFS_LABEL_TELVAR                                 },
    { id = "volendrung",   controlName = "ZO_HUDDaedricEnergyMeter",           label = KFS_LABEL_VOLENDRUNG                             },
    { id = "equipment",    controlName = "ZO_HUDEquipmentStatus",              label = KFS_LABEL_EQUIPMENT,    width = 64,  height = 64 },
    { id = "quest",        controlName = "ZO_FocusedQuestTrackerPanel",        label = KFS_LABEL_QUEST,        height = 200             },
    { id = "battleground", controlName = "ZO_BattlegroundHUDFragmentTopLevel", label = KFS_LABEL_BATTLEGROUND, height = 200             },
    { id = "actionbar",    controlName = "ZO_ActionBar1",                      label = KFS_LABEL_ACTIONBAR                              },
    { id = "subtitles",    controlName = "ZO_Subtitles",                       label = KFS_LABEL_SUBTITLES,    width = 256, height = 80 },
    {
        id = "objective",
        controlName = "ZO_ObjectiveCaptureMeter",
        label = KFS_LABEL_OBJECTIVE,
        width = 128,
        height = 128,
        postApply = function (control)
            if ZO_ObjectiveCaptureMeterFrame then
                ZO_ObjectiveCaptureMeterFrame:SetAnchor(BOTTOM, control, BOTTOM, 0, 0)
            end
        end,
    },
    { id = "playerInteract", controlName = "ZO_PlayerToPlayerAreaPromptContainer", label = KFS_LABEL_PLAYER_INTERACT, height = 30 },
    { id = "synergy",        controlName = "ZO_SynergyTopLevelContainer",          label = KFS_LABEL_SYNERGY                      },
    {
        id = "compass",
        controlName = "ZO_CompassFrame",
        label = KFS_LABEL_COMPASS,
        preApply = function ()
            if COMPASS_FRAME and COMPASS_FRAME.ApplyStyle then
                COMPASS_FRAME:ApplyStyle()
            end
        end,
    },
    {
        id = "playerProgress",
        controlName = "ZO_PlayerProgress",
        label = KFS_LABEL_PLAYER_PROGRESS,
        postApply = function ()
            if PLAYER_PROGRESS_BAR then
                PLAYER_PROGRESS_BAR:RefreshTemplate()
            end
        end,
    },
    {
        id = "endlessDungeon",
        controlName = "ZO_EndDunHUDTrackerContainer",
        label = KFS_LABEL_ENDLESS_DUNGEON,
        width = 230,
        height = 100,
    },
    { id = "reticle", controlName = "ZO_ReticleContainerInteract", label = KFS_LABEL_RETICLE },
    {
        id = "lootHistory",
        controlName = "ZO_LootHistoryControl_Gamepad",
        label = KFS_LABEL_LOOT_HISTORY,
        width = 280,
        height = 400,
        condition = function ()
            return IsConsole()
        end,
    },
    {
        id = "tutorials",
        controlName = "ZO_TutorialHudInfoTipGamepad",
        label = KFS_LABEL_TUTORIALS,
        condition = function ()
            return IsConsole()
        end,
    },
    {
        id = "alerts",
        controlName = "ZO_AlertTextNotification",
        label = KFS_LABEL_ALERTS,
        width = 600,
        height = 56,
        postApply = function (control, hasCustomPosition)
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NONE, " ")
            local alertText = control:GetChild(1)
            if IsInGamepadPreferredMode() and ZO_AlertTextNotificationGamepad then
                alertText = ZO_AlertTextNotificationGamepad:GetChild(1)
            end
            if alertText and hasCustomPosition then
                alertText.fadingControlBuffer.anchor = ZO_Anchor:New(TOPRIGHT, control, TOPRIGHT)
            end
        end,
    },
    {
        id = "activeCombatTips",
        controlName = "ZO_ActiveCombatTipsTip",
        label = KFS_LABEL_COMBAT_TIPS,
        width = 250,
        height = 20,
        postApply = function ()
            if ACTIVE_COMBAT_TIP_SYSTEM and ACTIVE_COMBAT_TIP_SYSTEM.ApplyStyle then
                ACTIVE_COMBAT_TIP_SYSTEM:ApplyStyle()
            end
        end,
    },
    {
        id = "groupAnchorSmall",
        controlName = "ZO_SmallGroupAnchorFrame",
        label = KFS_LABEL_GROUP_SMALL,
        width = 260,
        height = 200,
    },
    {
        id = "groupAnchorLarge1",
        controlName = "ZO_LargeGroupAnchorFrame1",
        label = KFS_LABEL_GROUP_LARGE_1,
        width = 260,
        height = 200,
    },
    {
        id = "groupAnchorLarge2",
        controlName = "ZO_LargeGroupAnchorFrame2",
        label = KFS_LABEL_GROUP_LARGE_2,
        width = 260,
        height = 200,
    },
    {
        id = "groupAnchorLarge3",
        controlName = "ZO_LargeGroupAnchorFrame3",
        label = KFS_LABEL_GROUP_LARGE_3,
        width = 260,
        height = 200,
    },
    {
        id = "groupAnchorLarge4",
        controlName = "ZO_LargeGroupAnchorFrame4",
        label = KFS_LABEL_GROUP_LARGE_4,
        width = 260,
        height = 200,
    },
    {
        id = "playerHealth",
        controlName = "ZO_PlayerAttributeHealth",
        label = KFS_LABEL_PLAYER_HEALTH,
        width = 300,
        height = 60,
    },
    {
        id = "playerMagicka",
        controlName = "ZO_PlayerAttributeMagicka",
        label = KFS_LABEL_PLAYER_MAGICKA,
        width = 300,
        height = 60,
    },
    {
        id = "playerStamina",
        controlName = "ZO_PlayerAttributeStamina",
        label = KFS_LABEL_PLAYER_STAMINA,
        width = 300,
        height = 60,
    },
    {
        id = "playerWerewolf",
        controlName = "ZO_PlayerAttributeWerewolf",
        label = KFS_LABEL_PLAYER_WEREWOLF,
        width = 300,
        height = 60,
        condition = function ()
            return GetControl("ZO_PlayerAttributeWerewolf") ~= nil
        end,
    },
    {
        id = "playerMount",
        controlName = "ZO_PlayerAttributeMountStamina",
        label = KFS_LABEL_PLAYER_MOUNT,
        width = 300,
        height = 60,
        condition = function ()
            return GetControl("ZO_PlayerAttributeMountStamina") ~= nil
        end,
    },
    {
        id = "playerSiege",
        controlName = "ZO_PlayerAttributeSiegeHealth",
        label = KFS_LABEL_PLAYER_SIEGE,
        width = 300,
        height = 60,
        condition = function ()
            return GetControl("ZO_PlayerAttributeSiegeHealth") ~= nil
        end,
    },
    {
        id = "buffSelf",
        controlName = "ZO_BuffDebuffTopLevelSelfContainer",
        label = KFS_LABEL_BUFF_SELF,
        width = 420,
        height = 220,
        condition = function ()
            return GetControl("ZO_BuffDebuffTopLevelSelfContainer") ~= nil
        end,
    },
    {
        id = "buffTarget",
        controlName = "ZO_BuffDebuffTopLevelTargetContainer",
        label = KFS_LABEL_BUFF_TARGET,
        width = 420,
        height = 220,
        condition = function ()
            return GetControl("ZO_BuffDebuffTopLevelTargetContainer") ~= nil
        end,
    },
    {
        id = "miniChat",
        controlName = "ZO_ChatWindow",
        label = KFS_LABEL_CHAT_MINI,
        width = 400,
        height = 200,
    },
    {
        id = "gamepadChat",
        controlName = "ZO_GamepadTextChat",
        label = KFS_LABEL_CHAT_GAMEPAD,
        width = 400,
        height = 200,
        condition = function ()
            return GetControl("ZO_GamepadTextChat") ~= nil
        end,
    },
}

--- @param definition KhajiitFengShuiPanelDefinition
--- @return Control|nil
local function ResolveControl(definition)
    if definition.condition and not definition.condition() then
        return nil
    end
    local control = _G[definition.controlName]
    if not control and GetControl then
        control = GetControl(definition.controlName)
    end
    if not control or not control.SetAnchor then
        return nil
    end
    return control
end

--- @class KhajiitFengShuiPanel
--- @field definition KhajiitFengShuiPanelDefinition
--- @field control Control
--- @field overlay TopLevelWindow
--- @field handler MoveableControl
--- @field label LabelControl

--- @param parent Control
--- @param text string
--- @return LabelControl
local function CreateOverlayLabel(parent, text)
    local label = wm:CreateControl(nil, parent, CT_LABEL)
    label:SetFont("ZoFontGamepadHeaderDataValue")
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 4, 4)
    label:SetColor(1, 1, 0, 1)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(5)
    label:SetDrawTier(DT_MEDIUM)
    label:SetText(text)
    local bg = wm:CreateControl(nil, label, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.75)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(4)
    bg:SetDrawTier(DT_LOW)
    return label
end

--- @param parent Control
--- @return BackdropControl
local function CreateOverlayBackdrop(parent)
    local backdrop = wm:CreateControl(nil, parent, CT_BACKDROP)
    backdrop:SetAnchorFill()
    backdrop:SetCenterColor(0.05, 0.6, 0.9, 0.25)
    backdrop:SetEdgeColor(0.05, 0.6, 0.9, 0.9)
    backdrop:SetEdgeTexture("", 2, 1, 1, 1)
    backdrop:SetDrawLayer(DL_OVERLAY)
    backdrop:SetDrawLevel(2)
    backdrop:SetDrawTier(DT_LOW)
    return backdrop
end

--- @param panel KhajiitFengShuiPanel
--- @param message string
local function UpdateOverlayLabel(panel, message)
    if panel.label then
        panel.label:SetText(message)
    end
end

--- @param panel KhajiitFengShuiPanel
--- @return string
local function BuildPositionText(panel)
    if not panel or not panel.handler then
        return "N/A"
    end
    local position = panel.handler:GetLeftTopPosition(true)
    local left = position.left or 0
    local top = position.top or 0
    return string.format("%d, %d", left, top)
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

--- @param control Control
--- @param width number?
--- @param height number?
local function ApplySizing(control, width, height)
    if width then
        control:SetWidth(width)
    end
    if height then
        control:SetHeight(height)
    end
end

function KhajiitFengShui:GetSnapSize()
    if not self.savedVars.grid.enabled then
        return 0
    end
    return self.savedVars.grid.size or self.defaults.grid.size
end

--- @param panel KhajiitFengShuiPanel
--- @param left number
--- @param top number
local function ApplyControlAnchor(panel, left, top)
    local control = panel.control
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

--- @param panel KhajiitFengShuiPanel
local function SyncOverlaySize(panel)
    local width = panel.control:GetWidth()
    local height = panel.control:GetHeight()
    panel.overlay:SetDimensions(width, height)
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

    local leftTop = handler:GetLeftTopPosition()
    ApplyControlAnchor(panel, leftTop.left or 0, leftTop.top or 0)

    if panel.definition.postApply then
        panel.definition.postApply(panel.control, hasCustom)
    end

    SyncOverlaySize(panel)

    local labelText = string.format("%d, %d | %s", leftTop.left or 0, leftTop.top or 0, GetPanelLabel(panel.definition))
    UpdateOverlayLabel(panel, labelText)
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
        local leftTop = handler:GetLeftTopPosition()
        local message = string.format("%d, %d | %s", leftTop.left or 0, leftTop.top or 0, GetPanelLabel(panel.definition))
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
    self.savedVars.positions[panel.definition.id] = CopyPosition(position)

    local leftTop = handler:GetLeftTopPosition(true)
    ApplyControlAnchor(panel, leftTop.left or 0, leftTop.top or 0)

    if panel.definition.postApply then
        panel.definition.postApply(panel.control, true)
    end

    local message = string.format("%d, %d | %s", leftTop.left or 0, leftTop.top or 0, GetPanelLabel(panel.definition))
    UpdateOverlayLabel(panel, message)

    handler:ToggleGamepadMove(false)
    self.activePanelId = nil
    self:RefreshAllPanels()
end

--- @param panel KhajiitFengShuiPanel
--- @return TopLevelWindow
local function CreateOverlay(panel)
    local overlay = wm:CreateTopLevelWindow(string.format("KhajiitFengShuiMover_%s", panel.definition.id))
    overlay:SetMouseEnabled(true)
    overlay:SetMovable(true)
    overlay:SetClampedToScreen(true)
    overlay:SetHidden(true)
    overlay:SetDrawLayer(DL_OVERLAY)
    overlay:SetDrawTier(DT_HIGH)
    overlay:SetDrawLevel(5)
    overlay:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, panel.control:GetLeft(), panel.control:GetTop())

    CreateOverlayBackdrop(overlay)
    panel.label = CreateOverlayLabel(overlay, "0, 0")

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

    ApplySizing(panel.control, panel.definition.width, panel.definition.height)
    self:ApplySavedPosition(panel)
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
                panel.handler:UpdatePosition(CopyPosition(panel.defaultPosition))
                if panel.definition.preApply then
                    panel.definition.preApply(panel.control, false)
                end
                ApplyControlAnchor(panel, panel.defaultPosition.left or 0, panel.defaultPosition.top or 0)
                if panel.definition.postApply then
                    panel.definition.postApply(panel.control, false)
                end
                local message = string.format("%d, %d | %s", panel.defaultPosition.left or 0, panel.defaultPosition.top or 0, GetPanelLabel(panel.definition))
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

    for _, panel in ipairs(self.panels) do
        settings:AddSetting(
            {
                type = LHAS.ST_BUTTON,
                label = GetPanelLabel(panel.definition),
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
    end

end

function KhajiitFengShui:InitializePanels()
    for _, definition in ipairs(DEFAULT_PANEL_DEFINITIONS) do
        local control = ResolveControl(definition)
        if control then
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
        end
    end

    for _, panel in ipairs(self.panels) do
        self:CreateMover(panel)
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

    self.savedVars.grid = self.savedVars.grid or CopyPosition(self.defaults.grid)
    if self.savedVars.grid.enabled == nil then
        self.savedVars.grid.enabled = self.defaults.grid.enabled
    end
    if not self.savedVars.grid.size then
        self.savedVars.grid.size = self.defaults.grid.size
    end
    self.savedVars.positions = self.savedVars.positions or {}

    self:InitializePanels()
    self:CreateSettingsMenu()
    self:ApplyAllPositions()
    self:ApplySnapSettings()
    self:RefreshAllPanels()

    em:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function ()
        self:ApplyAllPositions()
    end)
end

em:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function (event, addonName)
    KhajiitFengShui:OnAddOnLoaded(event, addonName)
end)
