local AttributeScaler = {};
AttributeScaler.__index = AttributeScaler;

local EVENT_NAMESPACE = "KFS_AttributeScaler";

local POWER_TYPE_TO_CONTROL = {};
if COMBAT_MECHANIC_FLAGS_HEALTH then
    POWER_TYPE_TO_CONTROL[COMBAT_MECHANIC_FLAGS_HEALTH] = ZO_PlayerAttributeHealth;
end;
if COMBAT_MECHANIC_FLAGS_MAGICKA then
    POWER_TYPE_TO_CONTROL[COMBAT_MECHANIC_FLAGS_MAGICKA] = ZO_PlayerAttributeMagicka;
end;
if COMBAT_MECHANIC_FLAGS_STAMINA then
    POWER_TYPE_TO_CONTROL[COMBAT_MECHANIC_FLAGS_STAMINA] = ZO_PlayerAttributeStamina;
end;
if COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA then
    POWER_TYPE_TO_CONTROL[COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA] = ZO_PlayerAttributeMountStamina;
end;
if COMBAT_MECHANIC_FLAGS_WEREWOLF then
    POWER_TYPE_TO_CONTROL[COMBAT_MECHANIC_FLAGS_WEREWOLF] = ZO_PlayerAttributeWerewolf;
end;

local STAT_TO_CONTROL = {};
if STAT_HEALTH_MAX then
    STAT_TO_CONTROL[STAT_HEALTH_MAX] = ZO_PlayerAttributeHealth;
end;
if STAT_MAGICKA_MAX then
    STAT_TO_CONTROL[STAT_MAGICKA_MAX] = ZO_PlayerAttributeMagicka;
end;
if STAT_STAMINA_MAX then
    STAT_TO_CONTROL[STAT_STAMINA_MAX] = ZO_PlayerAttributeStamina;
end;
if STAT_MOUNT_STAMINA_MAX then
    STAT_TO_CONTROL[STAT_MOUNT_STAMINA_MAX] = ZO_PlayerAttributeMountStamina;
end;

local PRIMARY_STATS =
{
    { statType = STAT_HEALTH_MAX;  attributeType = ATTRIBUTE_HEALTH;  powerType = COMBAT_MECHANIC_FLAGS_HEALTH  };
    { statType = STAT_MAGICKA_MAX; attributeType = ATTRIBUTE_MAGICKA; powerType = COMBAT_MECHANIC_FLAGS_MAGICKA };
    { statType = STAT_STAMINA_MAX; attributeType = ATTRIBUTE_STAMINA; powerType = COMBAT_MECHANIC_FLAGS_STAMINA };
};

function AttributeScaler:New()
    local scaler =
    {
        entries = {};
        shrinkExpandModule = nil;
        originalWidths = {};
        statScales = {};
        eventsRegistered = false;
    };
    return setmetatable(scaler, self);
end;

local function findShrinkExpandModule()
    if not PLAYER_ATTRIBUTE_BARS or not PLAYER_ATTRIBUTE_BARS.attributeVisualizer then
        return nil;
    end;

    local visualizer = PLAYER_ATTRIBUTE_BARS.attributeVisualizer;
    for _, module in pairs(visualizer.visualModules) do
        if module and module.IsUnitVisualRelevant then
            if module:IsUnitVisualRelevant(ATTRIBUTE_VISUAL_INCREASED_MAX_POWER, STAT_HEALTH_MAX) then
                return module;
            end;
        end;
    end;

    return nil;
end;

function AttributeScaler:CaptureOriginalWidths()
    local module = findShrinkExpandModule();
    if not module then
        return false;
    end;

    if not self.originalWidths.normalWidth then
        self.originalWidths.normalWidth = module.normalWidth;
        self.originalWidths.expandedWidth = module.expandedWidth;
        self.originalWidths.shrunkWidth = module.shrunkWidth;
    end;

    self.shrinkExpandModule = module;
    return true;
end;

local function getStatTypeForControl(control)
    for _, stat in ipairs(PRIMARY_STATS) do
        local expectedControl = STAT_TO_CONTROL[stat.statType];
        if expectedControl == control then
            return stat.statType;
        end;
    end;
    return nil;
end;

local function getPowerTypeForControl(control)
    for powerType, expectedControl in pairs(POWER_TYPE_TO_CONTROL) do
        if expectedControl == control then
            return powerType;
        end;
    end;
    return nil;
end;

local function usesShrinkExpandModule(control)
    local statType = getStatTypeForControl(control);
    return statType ~= nil;
end;

function AttributeScaler:ApplyScaleToControl(control, scale)
    if not control then
        return;
    end;

    control:SetTransformScale(scale);

    local entry = self.entries[control];
    if entry and entry.overlay then
        entry.overlay:SetTransformScale(scale);
    end;

    if not usesShrinkExpandModule(control) then
        return;
    end;

    if not self.shrinkExpandModule then
        if not self:CaptureOriginalWidths() then
            zo_callLater(function ()
                             self:ApplyScaleToControl(control, scale);
                         end, 50);
            return;
        end;
    end;

    local module = self.shrinkExpandModule;
    if not module then
        return;
    end;

    if not self.originalWidths.normalWidth then
        self:CaptureOriginalWidths();
    end;

    local statType = getStatTypeForControl(control);
    if not statType then
        return;
    end;

    self.statScales[statType] = scale;

    local origNormal = self.originalWidths.normalWidth or module.normalWidth;
    local origExpanded = self.originalWidths.expandedWidth or module.expandedWidth;
    local origShrunk = self.originalWidths.shrunkWidth or module.shrunkWidth;

    if module.barInfo and module.barInfo[statType] and module.barControls and module.barControls[statType] then
        local info = module.barInfo[statType];
        local barControl = module.barControls[statType];

        module.normalWidth = zo_round(origNormal * scale);
        module.expandedWidth = zo_round(origExpanded * scale);
        module.shrunkWidth = zo_round(origShrunk * scale);

        if info.value == nil then
            info.value = 0;
        end;
        if barControl.value == nil then
            barControl.value = 0;
        end;

        zo_callLater(function ()
                         if module.OnValueChanged then
                             module:OnValueChanged(barControl, info, statType, true);
                         end;
                     end, 0);
    end;
end;

function AttributeScaler:ReapplyAll()
    for _, entry in pairs(self.entries) do
        if entry and entry.control and entry.scale then
            self:ApplyScaleToControl(entry.control, entry.scale);
        end;
    end;
end;

function AttributeScaler:OnAttributeVisualChange(unitTag, _, statType, _, powerType)
    if unitTag ~= "player" then
        return;
    end;

    local control = STAT_TO_CONTROL[statType] or POWER_TYPE_TO_CONTROL[powerType];
    if control then
        local entry = self.entries[control];
        if entry and entry.scale then
            self:ApplyScaleToControl(control, entry.scale);
        end;
    end;
end;

function AttributeScaler:EnsureEvents()
    if self.eventsRegistered then
        return;
    end;

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED);
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function ()
        self:ReapplyAll();
    end);

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_VISUAL_ADDED", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED);
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_VISUAL_ADDED", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function (_, unitTag, visual, statType, attributeType, powerType)
        self:OnAttributeVisualChange(unitTag, visual, statType, attributeType, powerType);
    end);
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_VISUAL_ADDED", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player");

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_VISUAL_REMOVED", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED);
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_VISUAL_REMOVED", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function (_, unitTag, visual, statType, attributeType, powerType)
        self:OnAttributeVisualChange(unitTag, visual, statType, attributeType, powerType);
    end);
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_VISUAL_REMOVED", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player");

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_VISUAL_UPDATED", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED);
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_VISUAL_UPDATED", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function (_, unitTag, visual, statType, attributeType, powerType)
        self:OnAttributeVisualChange(unitTag, visual, statType, attributeType, powerType);
    end);
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_VISUAL_UPDATED", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player");

    self.eventsRegistered = true;
end;

function AttributeScaler:Apply(panel, scale)
    if not panel or not panel.control or not scale then
        return;
    end;

    self:EnsureEvents();

    local control = panel.control;
    self.entries[control] =
    {
        control = control;
        overlay = panel.overlay;
        scale = scale;
    };

    self:ApplyScaleToControl(control, scale);
end;

KFS_AttributeScaler = AttributeScaler:New();
