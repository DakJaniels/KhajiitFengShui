-- Luacheck configuration for WoW addons
std = "lua51"

-- Maximum line length
max_line_length = 99999

-- WoW globals that are allowed to be read
read_globals =
{
    -- Standard ESO API
    "ZO_CreateStringId",
    "GetControl",
    "GetWindowManager",
    "GetString",
    "ReloadUI",
    "zo_callLater",
    "zo_round",
    "zo_roundToNearest",
    "zo_clamp",
    "zo_max",
    "zo_floatsAreEqual",
    "zo_floor",
    "IsInGamepadPreferredMode",
    "GetEventManager",
    "SecurePostHook",
    "PushActionLayerByName",
    "RemoveActionLayerByName",
    "SafeAddVersion",

    -- Standard Lua globals
    "_G",

    -- ESO API namespaces
    "EVENT_MANAGER",
    "PLAYER_ATTRIBUTE_BARS",
    "CHAT_ROUTER",
    "GuiRoot",
    "SCENE_MANAGER",
    "KEYBIND_STRIP",
    "CALLBACK_MANAGER",
    "WINDOW_MANAGER",
    "BOSS_BAR",
    "RETICLE",
    "CENTER_SCREEN_ANNOUNCE",

    -- ESO API constants - Combat mechanics
    "COMBAT_MECHANIC_FLAGS_HEALTH",
    "COMBAT_MECHANIC_FLAGS_MAGICKA",
    "COMBAT_MECHANIC_FLAGS_STAMINA",
    "COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA",
    "COMBAT_MECHANIC_FLAGS_WEREWOLF",

    -- ESO API constants - Player attributes
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
    "ZO_PlayerAttributeMountStamina",
    "ZO_PlayerAttributeWerewolf",

    -- ESO API constants - Stats
    "STAT_HEALTH_MAX",
    "STAT_MAGICKA_MAX",
    "STAT_STAMINA_MAX",
    "STAT_MOUNT_STAMINA_MAX",

    -- ESO API constants - Attributes
    "ATTRIBUTE_HEALTH",
    "ATTRIBUTE_MAGICKA",
    "ATTRIBUTE_STAMINA",
    "ATTRIBUTE_VISUAL_INCREASED_MAX_POWER",
    "ATTRIBUTE_BAR_STATE_EXPANDED",

    -- ESO API constants - Events
    "EVENT_PLAYER_ACTIVATED",
    "EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED",
    "EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED",
    "EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED",
    "EVENT_MOUNTED_STATE_CHANGED",
    "EVENT_POWER_UPDATE",
    "EVENT_INTERFACE_SETTING_CHANGED",
    "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED",
    "EVENT_ADD_ON_LOADED",
    "EVENT_GROUP_UPDATE",
    "EVENT_GROUP_MEMBER_JOINED",

    -- ESO API constants - Event filters
    "REGISTER_FILTER_UNIT_TAG",
    "REGISTER_FILTER_POWER_TYPE",
    "REGISTER_FILTER_SETTING_SYSTEM_TYPE",

    -- ESO API constants - Settings
    "SETTING_TYPE_UI",
    "UI_SETTING_SHOW_RESOURCE_BARS",
    "UI_ALERT_CATEGORY_ALERT",

    -- ESO API constants - Keybind strip
    "KEYBIND_STRIP_ALIGN_RIGHT",
    "KEYBIND_STRIP_GAMEPAD_FRAGMENT",

    -- ESO API constants - Scene states
    "SCENE_SHOWING",
    "SCENE_SHOWN",
    "SCENE_HIDDEN",
    "SCENE_HIDING",

    -- ESO API constants - String IDs
    "SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS",

    -- ESO API constants - Compass
    "ZO_COMPASS_FRAME_HEIGHT_GAMEPAD",
    "ZO_COMPASS_FRAME_HEIGHT_KEYBOARD",
    "COMPASS_FRAME",

    -- ESO API namespaces - Game systems
    "PLAYER_PROGRESS_BAR",
    "LOOT_HISTORY_GAMEPAD",
    "ACTIVE_COMBAT_TIP_SYSTEM",
    "SOUNDS",

    -- ESO API constants - Text alignment
    "TEXT_ALIGN_CENTER",
    "TEXT_ALIGN_BOTTOM",

    -- ESO API constants - Control types
    "CT_LINE",
    "CT_BACKDROP",
    "CT_LABEL",
    "CT_CONTROL",

    -- ESO API constants - Draw layers
    "DL_OVERLAY",
    "DL_CONTROLS",

    -- ESO API constants - Draw tiers
    "DT_LOW",
    "DT_MEDIUM",
    "DT_HIGH",

    -- ESO API constants - Anchor points
    "TOPLEFT",
    "BOTTOMLEFT",
    "TOPRIGHT",
    "LEFT",
    "RIGHT",
    "BOTTOMRIGHT",
    "CENTER",
    "TOP",
    "BOTTOM",

    -- ZO library classes and functions
    "ZO_ObjectPool",
    "ZO_ClearTable",
    "ZO_Anchor",
    "ZO_IsConsoleUI",
    "ZO_GetControlOwnerObject",
    "ZO_Eval",
    "ZO_Alert",
    "ZO_AlertNoSuppression",
    "ZO_PreHook",
    "ZO_PostHook",
    "ZO_ObjectiveCaptureMeterFrame",
    "ZO_CompassFrameLeft",
    "ZO_CompassFrameRight",
    "ZO_CompassFrameCenter",
    "ZO_CompassCenterOverPinLabel",
    "ZO_Compass",
    "ZO_TargetUnitFrame",
    "ZO_AlertTextNotificationGamepad",
    "ZO_UnitFrames_Manager",
    "ZO_UnitVisualizer_ShrinkExpandModule",
    "ZO_ActionButtons_ToggleShowGlobalCooldown",
    "ZO_KeybindStripGamepadBackground",
    "ZO_KeybindStripGamepadBackgroundTexture",
    "ZO_SavedVars",
    "ZO_StatusBar_SmoothTransition",
    "ZO_FormatResourceBarCurrentAndMax",

    -- String ID constants (created via ZO_CreateStringId)
    "KFS_SETTINGS",
    "KFS_SETTINGS_DESC",
    "KFS_ENABLE_SNAP",
    "KFS_ENABLE_SNAP_DESC",
    "KFS_SNAP_SIZE",
    "KFS_SNAP_SIZE_DESC",
    "KFS_RESET_ALL",
    "KFS_RESET_ALL_DESC",
    "KFS_ENABLE_BUFF_ANIMATIONS",
    "KFS_ENABLE_BUFF_ANIMATIONS_DESC_RELOAD",
    "KFS_ENABLE_GCD",
    "KFS_ENABLE_GCD_DESC",
    "KFS_PYRAMID_LAYOUT",
    "KFS_PYRAMID_LAYOUT_DESC",
    "KFS_ALWAYS_EXPANDED_BARS",
    "KFS_ALWAYS_EXPANDED_BARS_DESC_RELOAD",
    "KFS_SCALE_SLIDER_LABEL",
    "KFS_SCALE_SLIDER_DESC",
    "KFS_PROFILE_MODE",
    "KFS_PROFILE_MODE_DESC_RELOAD",
    "KFS_PROFILE_MODE_TOGGLE",
    "KFS_PROFILE_ACCOUNT",
    "KFS_PROFILE_CHARACTER",
    "KFS_MOVE_BUTTON",
    "KFS_MOVE_BUTTON_DESC",
    "KFS_MOVE_BUTTON_PYRAMID_DESC",
    "KFS_SECTION_CONTROLS",
    "KFS_LABEL_INFAMY",
    "KFS_LABEL_TELVAR",
    "KFS_LABEL_VOLENDRUNG",
    "KFS_LABEL_EQUIPMENT",
    "KFS_LABEL_QUEST",
    "KFS_LABEL_QUEST_TRACKER",
    "KFS_LABEL_BATTLEGROUND",
    "KFS_LABEL_ACTIONBAR",
    "KFS_LABEL_SUBTITLES",
    "KFS_LABEL_OBJECTIVE",
    "KFS_LABEL_PLAYER_INTERACT",
    "KFS_LABEL_SYNERGY",
    "KFS_LABEL_COMPASS",
    "KFS_LABEL_PLAYER_PROGRESS",
    "KFS_LABEL_ENDLESS_DUNGEON",
    "KFS_LABEL_RETICLE",
    "KFS_LABEL_TARGET_FRAME",
    "KFS_LABEL_LOOT_HISTORY",
    "KFS_LABEL_TUTORIALS",
    "KFS_LABEL_ALERTS",
    "KFS_LABEL_COMBAT_TIPS",
    "KFS_LABEL_GROUP_SMALL",
    "KFS_LABEL_GROUP_LARGE_1",
    "KFS_LABEL_GROUP_LARGE_2",
    "KFS_LABEL_GROUP_LARGE_3",
    "KFS_LABEL_GROUP_LARGE_4",
    "KFS_LABEL_PLAYER_HEALTH",
    "KFS_LABEL_PLAYER_MAGICKA",
    "KFS_LABEL_PLAYER_STAMINA",
    "KFS_LABEL_PLAYER_WEREWOLF",
    "KFS_LABEL_PLAYER_MOUNT",
    "KFS_LABEL_PLAYER_SIEGE",
    "KFS_LABEL_BUFF_SELF",
    "KFS_LABEL_BUFF_TARGET",
    "KFS_LABEL_CHAT_MINI",
    "KFS_LABEL_CHAT_GAMEPAD",
    "KFS_NAME",
    "KFS_EDIT_MODE_HINT",
    "KFS_EDIT_MODE_ENABLED",
    "KFS_EDIT_MODE_DISABLED",
    "KFS_KEYBIND_ENTER_EDIT_MODE",
    "KFS_KEYBIND_EXIT_EDIT_MODE",
    "KFS_KEYBIND_PREVIOUS_PANEL",
    "KFS_KEYBIND_NEXT_PANEL",
    "KFS_KEYBIND_TOGGLE_LABELS",
    "KFS_ENABLE_PANEL",
    "KFS_ENABLE_PANEL_DESC",
    "KFS_ENABLE_BOSS_BAR",
    "KFS_ENABLE_BOSS_BAR_DESC_RELOAD",
    "KFS_ENABLE_RETICLE",
    "KFS_ENABLE_RETICLE_DESC_RELOAD",
    "KFS_LABEL_PET_GROUP",
    "KFS_LABEL_CENTER_ANNOUNCE",
    "KFS_LABEL_STEALTH_ICON",
    "KFS_LABEL_RETICLE_ICON",
    "KFS_LABEL_DIALOGUE_WINDOW",
    "KFS_LABEL_RAM_SIEGE",
    "KFS_LABEL_QUEST_TIMER",

    -- addons
    "LibCombatAlerts",
    "LibHarvensAddonSettings",

}

-- Globals that are allowed to be set
globals =
{
    -- Slash command globals
    "SLASH_COMMANDS",

    -- Saved variables


    -- ESO globals that can be modified

    -- Addon globals
    "KFS_AttributeScaler",
    "KFS_EditModeController",
    "KFS_GridOverlay",
    "KFS_SettingsController",
    "KFS_PanelUtils",
    "KFS_PanelDefinitions",
    "KhajiitFengShui",

    -- Utility functions from functionUtility.lua (defined as globals)
    "GenerateClosure",
    "GenerateFlatClosure",
    "IterateTables",
    "IteratePools",

}

-- Ignore specific warnings
ignore =
{
    "212", -- unused argument
    "542", -- value assigned to variable is overwritten before use (intentional in panel_utils.lua)

}
