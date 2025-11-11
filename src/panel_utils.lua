local PanelUtils = {};

function PanelUtils.copyPosition(position)
    if not position then
        return nil;
    end;

    local clone = {};
    for key, value in pairs(position) do
        clone[key] = value;
    end;

    return clone;
end;

local function computeRelativeOffsets(control, point, relativePoint, left, top, definition)
    local rootWidth = GuiRoot:GetWidth() or 0;
    local rootHeight = GuiRoot:GetHeight() or 0;
    local owner = ZO_GetControlOwnerObject(control);

    local function resolveDimension(currentSize, fallbackValue)
        local size = currentSize;
        if size and size ~= 0 then
            return size;
        end;
        if definition then
            local evaluated = ZO_Eval(fallbackValue, control, owner);
            if evaluated then
                return evaluated;
            end;
        end;
        return 0;
    end;

    local controlWidth = resolveDimension(control.GetWidth and control:GetWidth(), definition and definition.width);
    local controlHeight = resolveDimension(control.GetHeight and control:GetHeight(), definition and definition.height);

    if point == BOTTOMLEFT and relativePoint == BOTTOMLEFT then
        return left, (top + controlHeight) - rootHeight;
    elseif point == TOPRIGHT and relativePoint == TOPRIGHT then
        return (left + controlWidth) - rootWidth, top;
    elseif point == BOTTOMRIGHT and relativePoint == BOTTOMRIGHT then
        return (left + controlWidth) - rootWidth, (top + controlHeight) - rootHeight;
    elseif point == TOP and relativePoint == TOP then
        return (left + (controlWidth * 0.5)) - (rootWidth * 0.5), top;
    elseif point == BOTTOM and relativePoint == BOTTOM then
        return (left + (controlWidth * 0.5)) - (rootWidth * 0.5),
            (top + controlHeight) - rootHeight;
    elseif point == LEFT and relativePoint == LEFT then
        return left, (top + (controlHeight * 0.5)) - (rootHeight * 0.5);
    elseif point == RIGHT and relativePoint == RIGHT then
        return (left + controlWidth) - rootWidth,
            (top + (controlHeight * 0.5)) - (rootHeight * 0.5);
    elseif point == CENTER and relativePoint == CENTER then
        return (left + (controlWidth * 0.5)) - (rootWidth * 0.5),
            (top + (controlHeight * 0.5)) - (rootHeight * 0.5);
    end;

    return left, top;
end;

function PanelUtils.applyControlAnchor(panel, left, top)
    if not panel then
        return;
    end;

    local control = panel.control;
    if not (control and control.SetAnchor) then
        return;
    end;

    local definition = panel.definition or {};
    local point = definition.anchorPoint or TOPLEFT;
    local relativePoint = definition.anchorRelativePoint or point;
    local applyAnchor = definition.anchorApply;

    control:ClearAnchors();

    if type(applyAnchor) == "function" then
        applyAnchor(panel, left, top);
        return;
    end;

    if point == TOPLEFT and relativePoint == TOPLEFT then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top);
        return;
    end;

    local offsetX, offsetY = computeRelativeOffsets(control, point, relativePoint, left, top, definition);
    control:SetAnchor(point, GuiRoot, relativePoint, offsetX, offsetY);
end;

function PanelUtils.applySizing(control, width, height)
    if not control then
        return;
    end;

    local owner = ZO_GetControlOwnerObject(control);

    if width ~= nil then
        local resolvedWidth = ZO_Eval(width, control, owner);
        if resolvedWidth then
            control:SetWidth(resolvedWidth);
        end;
    end;

    if height ~= nil then
        local resolvedHeight = ZO_Eval(height, control, owner);
        if resolvedHeight then
            control:SetHeight(resolvedHeight);
        end;
    end;
end;

function PanelUtils.enableInheritScaleRecursive(control)
    if not control then
        return;
    end;

    if not control:GetInheritsScale() then
        control:SetInheritScale(true);
    end;

    local numChildren = control:GetNumChildren();
    for i = 1, numChildren do
        local child = control:GetChild(i);
        if child then
            PanelUtils.enableInheritScaleRecursive(child);
        end;
    end;
end;

function PanelUtils.applyScale(panel, scale)
    if not panel then
        return;
    end;

    local control = panel.control;
    local definition = panel.definition or {};
    local appliedScale = scale or 1;

    if type(definition.scaleApply) == "function" then
        definition.scaleApply(panel, appliedScale);
        return;
    end;

    if control then
        PanelUtils.enableInheritScaleRecursive(control);
        control:SetTransformScale(appliedScale);
    end;
end;

function PanelUtils.formatPositionMessage(left, top, labelText)
    return string.format("%d, %d | %s", left or 0, top or 0, labelText);
end;

function PanelUtils.createOverlay(panelId, control)
    local windowManager = GetWindowManager();
    local overlay = windowManager:CreateTopLevelWindow(string.format("KhajiitFengShuiMover_%s", panelId));
    overlay:SetMouseEnabled(true);
    overlay:SetMovable(true);
    overlay:SetClampedToScreen(true);
    overlay:SetHidden(true);
    overlay:SetDrawLayer(DL_OVERLAY);
    overlay:SetDrawTier(DT_HIGH);
    overlay:SetDrawLevel(5);
    overlay:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, control:GetLeft(), control:GetTop());

    local backdrop = windowManager:CreateControl(nil, overlay, CT_BACKDROP);
    backdrop:SetAnchorFill();
    backdrop:SetCenterColor(0.05, 0.6, 0.9, 0.25);
    backdrop:SetEdgeColor(0.05, 0.6, 0.9, 0.9);
    backdrop:SetEdgeTexture("", 2, 1, 1, 1);
    backdrop:SetDrawLayer(DL_OVERLAY);
    backdrop:SetDrawLevel(2);
    backdrop:SetDrawTier(DT_LOW);

    local label = windowManager:CreateControl(nil, overlay, CT_LABEL);
    label:SetFont("ZoFontGamepadHeaderDataValue");
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT);
    label:SetVerticalAlignment(TEXT_ALIGN_TOP);
    label:SetAnchor(TOPLEFT, overlay, TOPLEFT, 4, 4);
    label:SetColor(1, 1, 0, 1);
    label:SetDrawLayer(DL_OVERLAY);
    label:SetDrawLevel(5);
    label:SetDrawTier(DT_MEDIUM);
    label:SetText("0, 0");

    local labelBackground = windowManager:CreateControl(nil, label, CT_BACKDROP);
    labelBackground:SetAnchorFill();
    labelBackground:SetCenterColor(0, 0, 0, 0.75);
    labelBackground:SetEdgeColor(0, 0, 0, 0);
    labelBackground:SetDrawLayer(DL_BACKGROUND);
    labelBackground:SetDrawLevel(4);
    labelBackground:SetDrawTier(DT_LOW);

    return overlay, label;
end;

function PanelUtils.syncOverlaySize(panel)
    local control = panel.control;
    local overlay = panel.overlay;
    if not (control and overlay) then
        return;
    end;

    local width = control.GetWidth and control:GetWidth() or 0;
    local height = control.GetHeight and control:GetHeight() or 0;
    local scale = control:GetTransformScale() or 1;
    overlay:SetDimensions(width * scale, height * scale);
end;

function PanelUtils.updateOverlayLabel(labelControl, message)
    if labelControl then
        labelControl:SetText(message);
    end;
end;

function PanelUtils.getAnchorPosition(handler, snapToGrid)
    local position = handler:GetLeftTopPosition(snapToGrid);
    return position.left or 0, position.top or 0;
end;

KFS_PanelUtils = PanelUtils;
