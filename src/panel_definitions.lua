local function isConsole()
    return IsConsoleUI()
end

local definitions =
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
        width = function ()
            local rootWidth = GuiRoot:GetWidth() or 0
            return zo_clamp(rootWidth * 0.35, 400, 800)
        end,
        height = function ()
            if IsInGamepadPreferredMode() then
                return ZO_COMPASS_FRAME_HEIGHT_GAMEPAD or 0
            end
            return ZO_COMPASS_FRAME_HEIGHT_KEYBOARD or 0
        end,
        anchorPoint = TOP,
        anchorRelativePoint = TOP,
        preApply = function ()
            if COMPASS_FRAME and COMPASS_FRAME.ApplyStyle then
                COMPASS_FRAME:ApplyStyle()
            end
        end,
        postApply = function (control)
            if COMPASS_FRAME and COMPASS_FRAME.ApplyStyle then
                zo_callLater(function ()
                                 if control and control.SetAnchor then
                                     COMPASS_FRAME:ApplyStyle()
                                 end
                             end, 0)
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
        id = "targetFrame",
        controlName = "ZO_TargetUnitFramereticleover",
        label = KFS_LABEL_TARGET_FRAME,
        condition = function ()
            return GetControl("ZO_TargetUnitFramereticleover") ~= nil
        end,
        postApply = function (control, hasCustomPosition)
            local frame = ZO_TargetUnitFrame
            if not frame then
                return
            end

            if frame.ApplyPlatformStyle then
                frame:ApplyPlatformStyle()
            end

            if hasCustomPosition then
                frame:SetMovingTargetFrame(true)
            end
        end,
    },
    {
        id = "lootHistory",
        controlName = "ZO_LootHistoryControl_Gamepad",
        label = KFS_LABEL_LOOT_HISTORY,
        width = 280,
        height = 400,
        condition = isConsole,
        anchorPoint = BOTTOMLEFT,
        anchorRelativePoint = BOTTOMLEFT,
        postApply = function (control)
            if not LOOT_HISTORY_GAMEPAD then
                return
            end

            local function refreshBuffer(buffer)
                if not buffer then
                    return
                end

                buffer.anchor = ZO_Anchor:New(BOTTOMLEFT, control, BOTTOMLEFT)
            end

            refreshBuffer(LOOT_HISTORY_GAMEPAD.lootStream)
            refreshBuffer(LOOT_HISTORY_GAMEPAD.lootStreamPersistent)
        end,
    },
    {
        id = "tutorials",
        controlName = "ZO_TutorialHudInfoTipGamepad",
        label = KFS_LABEL_TUTORIALS,
        condition = isConsole,
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
        height = 100,
        anchorPoint = CENTER,
        anchorRelativePoint = CENTER,
        condition = function ()
            return GetControl("ZO_BuffDebuffTopLevelSelfContainer") ~= nil
        end,
    },
    {
        id = "buffTarget",
        controlName = "ZO_BuffDebuffTopLevelTargetContainer",
        label = KFS_LABEL_BUFF_TARGET,
        width = 420,
        height = 100,
        anchorPoint = CENTER,
        anchorRelativePoint = CENTER,
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

local PanelDefinitions = {}

PanelDefinitions.list = definitions

function PanelDefinitions.getAll()
    return definitions
end

function PanelDefinitions.getLabel(definition)
    return GetString(definition.label)
end

function PanelDefinitions.resolveControl(definition)
    if definition.condition and not definition.condition() then
        return nil
    end

    local control = _G[definition.controlName]
    if not control and GetControl then
        control = GetControl(definition.controlName)
    end

    if not (control and control.SetAnchor) then
        return nil
    end

    return control
end

KFS_PanelDefinitions = PanelDefinitions
