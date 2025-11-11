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

local function snapAnchorOffset(offset, gridSize)
    if not gridSize or gridSize <= 0 then
        return offset;
    end;
    return zo_roundToNearest(offset, gridSize);
end;

function PanelUtils.snapPositionToGrid(position, gridSize)
    if not position or not gridSize or gridSize <= 0 then
        return nil;
    end;

    local snapped = {};
    for key, value in pairs(position) do
        snapped[key] = snapAnchorOffset(value, gridSize);
    end;

    return snapped;
end;

local function getAnchorPointX(point, left, width, rootWidth)
    if point == LEFT or point == TOPLEFT or point == BOTTOMLEFT then
        return left;
    elseif point == RIGHT or point == TOPRIGHT or point == BOTTOMRIGHT then
        return (left + width) - rootWidth;
    elseif point == CENTER or point == TOP or point == BOTTOM then
        return (left + (width * 0.5)) - (rootWidth * 0.5);
    end;
    return left;
end;

local function getAnchorPointY(point, top, height, rootHeight)
    if point == TOP or point == TOPLEFT or point == TOPRIGHT then
        return top;
    elseif point == BOTTOM or point == BOTTOMLEFT or point == BOTTOMRIGHT then
        return (top + height) - rootHeight;
    elseif point == CENTER or point == LEFT or point == RIGHT then
        return (top + (height * 0.5)) - (rootHeight * 0.5);
    end;
    return top;
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

    local controlAnchorX = getAnchorPointX(point, left, controlWidth, rootWidth);
    local controlAnchorY = getAnchorPointY(point, top, controlHeight, rootHeight);
    local targetAnchorX = getAnchorPointX(relativePoint, 0, rootWidth, rootWidth);
    local targetAnchorY = getAnchorPointY(relativePoint, 0, rootHeight, rootHeight);

    return controlAnchorX - targetAnchorX, controlAnchorY - targetAnchorY;
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

    if type(applyAnchor) == "function" then
        control:ClearAnchors();
        applyAnchor(panel, left, top);
        return;
    end;

    local offsetX, offsetY;
    if point == TOPLEFT and relativePoint == TOPLEFT then
        offsetX = left;
        offsetY = top;
    else
        offsetX, offsetY = computeRelativeOffsets(control, point, relativePoint, left, top, definition);
    end;

    local anchor = ZO_Anchor:New(point, GuiRoot, relativePoint, offsetX, offsetY);
    anchor:Set(control);
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
    local scale = control:GetTransformScale() or control:GetScale() or 1;
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

local function convertMoveablePositionToAnchor(position, gridSize)
    if not position then
        return TOPLEFT, TOPLEFT, 0, 0;
    end;

    local horizontalAnchor = nil;
    local verticalAnchor = nil;
    local offsetX = 0;
    local offsetY = 0;

    if position.left ~= nil then
        horizontalAnchor = LEFT;
        offsetX = snapAnchorOffset(position.left, gridSize);
    elseif position.center ~= nil then
        horizontalAnchor = CENTER;
        offsetX = snapAnchorOffset(position.center, gridSize);
    elseif position.right ~= nil then
        horizontalAnchor = RIGHT;
        offsetX = snapAnchorOffset(position.right, gridSize);
    end;

    if position.top ~= nil then
        verticalAnchor = TOP;
        offsetY = snapAnchorOffset(position.top, gridSize);
    elseif position.mid ~= nil then
        verticalAnchor = CENTER;
        offsetY = snapAnchorOffset(position.mid, gridSize);
    elseif position.bottom ~= nil then
        verticalAnchor = BOTTOM;
        offsetY = snapAnchorOffset(position.bottom, gridSize);
    end;

    local point = TOPLEFT;
    if horizontalAnchor == LEFT and verticalAnchor == TOP then
        point = TOPLEFT;
    elseif horizontalAnchor == LEFT and verticalAnchor == CENTER then
        point = LEFT;
    elseif horizontalAnchor == LEFT and verticalAnchor == BOTTOM then
        point = BOTTOMLEFT;
    elseif horizontalAnchor == CENTER and verticalAnchor == TOP then
        point = TOP;
    elseif horizontalAnchor == CENTER and verticalAnchor == CENTER then
        point = CENTER;
    elseif horizontalAnchor == CENTER and verticalAnchor == BOTTOM then
        point = BOTTOM;
    elseif horizontalAnchor == RIGHT and verticalAnchor == TOP then
        point = TOPRIGHT;
    elseif horizontalAnchor == RIGHT and verticalAnchor == CENTER then
        point = RIGHT;
    elseif horizontalAnchor == RIGHT and verticalAnchor == BOTTOM then
        point = BOTTOMRIGHT;
    end;

    return point, point, offsetX, offsetY;
end;

function PanelUtils.applyControlAnchorFromPosition(panel, position, gridSize)
    if not panel or not position then
        return;
    end;

    local control = panel.control;
    if not (control and control.SetAnchor) then
        return;
    end;

    local definition = panel.definition or {};
    local applyAnchor = definition.anchorApply;

    if type(applyAnchor) == "function" then
        control:ClearAnchors();
        local left, top = PanelUtils.getAnchorPosition(panel.handler);
        applyAnchor(panel, left, top);
        return;
    end;

    local point, relativePoint, offsetX, offsetY = convertMoveablePositionToAnchor(position, gridSize);

    local definitionPoint = definition.anchorPoint;
    local definitionRelativePoint = definition.anchorRelativePoint or definitionPoint;

    if definitionPoint then
        point = definitionPoint;
        relativePoint = definitionRelativePoint;
        local left, top = PanelUtils.getAnchorPosition(panel.handler);
        offsetX, offsetY = computeRelativeOffsets(control, point, relativePoint, left, top, definition);
    end;

    local anchor = ZO_Anchor:New(point, GuiRoot, relativePoint, offsetX, offsetY);
    anchor:Set(control);
end;

KFS_PanelUtils = PanelUtils;
