local PanelUtils = {}

function PanelUtils.copyPosition(position)
    if not position then
        return nil
    end

    local clone = {}
    for key, value in pairs(position) do
        clone[key] = value
    end

    return clone
end

function PanelUtils.applyControlAnchor(control, left, top)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

function PanelUtils.applySizing(control, width, height)
    if width then
        control:SetWidth(width)
    end
    if height then
        control:SetHeight(height)
    end
end

function PanelUtils.formatPositionMessage(left, top, labelText)
    return string.format("%d, %d | %s", left or 0, top or 0, labelText)
end

function PanelUtils.createOverlay(windowManager, panelId, control)
    local overlay = windowManager:CreateTopLevelWindow(string.format("KhajiitFengShuiMover_%s", panelId))
    overlay:SetMouseEnabled(true)
    overlay:SetMovable(true)
    overlay:SetClampedToScreen(true)
    overlay:SetHidden(true)
    overlay:SetDrawLayer(DL_OVERLAY)
    overlay:SetDrawTier(DT_HIGH)
    overlay:SetDrawLevel(5)
    overlay:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, control:GetLeft(), control:GetTop())

    local backdrop = windowManager:CreateControl(nil, overlay, CT_BACKDROP)
    backdrop:SetAnchorFill()
    backdrop:SetCenterColor(0.05, 0.6, 0.9, 0.25)
    backdrop:SetEdgeColor(0.05, 0.6, 0.9, 0.9)
    backdrop:SetEdgeTexture("", 2, 1, 1, 1)
    backdrop:SetDrawLayer(DL_OVERLAY)
    backdrop:SetDrawLevel(2)
    backdrop:SetDrawTier(DT_LOW)

    local label = windowManager:CreateControl(nil, overlay, CT_LABEL)
    label:SetFont("ZoFontGamepadHeaderDataValue")
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetAnchor(TOPLEFT, overlay, TOPLEFT, 4, 4)
    label:SetColor(1, 1, 0, 1)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(5)
    label:SetDrawTier(DT_MEDIUM)
    label:SetText("0, 0")

    local labelBackground = windowManager:CreateControl(nil, label, CT_BACKDROP)
    labelBackground:SetAnchorFill()
    labelBackground:SetCenterColor(0, 0, 0, 0.75)
    labelBackground:SetEdgeColor(0, 0, 0, 0)
    labelBackground:SetDrawLayer(DL_BACKGROUND)
    labelBackground:SetDrawLevel(4)
    labelBackground:SetDrawTier(DT_LOW)

    return overlay, label
end

function PanelUtils.syncOverlaySize(panel)
    local control = panel.control
    local overlay = panel.overlay
    if not (control and overlay) then
        return
    end

    overlay:SetDimensions(control:GetWidth(), control:GetHeight())
end

function PanelUtils.updateOverlayLabel(labelControl, message)
    if labelControl then
        labelControl:SetText(message)
    end
end

function PanelUtils.getAnchorPosition(handler, snapToGrid)
    local position = handler:GetLeftTopPosition(snapToGrid)
    return position.left or 0, position.top or 0
end

KFS_PanelUtils = PanelUtils

