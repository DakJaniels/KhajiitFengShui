local GridOverlay = {};
GridOverlay.__index = GridOverlay;

local wm = GetWindowManager();

local GRID_COLOR =
{
    r = 0.1;
    g = 0.7;
    b = 0.9;
    a = 0.35;
};

function GridOverlay:New()
    local overlay =
    {
        control = nil;
        verticalLines = {};
        horizontalLines = {};
        size = 0;
    };

    return setmetatable(overlay, self);
end;

function GridOverlay:EnsureControl()
    if self.control then
        return;
    end;

    local control = wm:CreateTopLevelWindow("KhajiitFengShuiGridOverlay");
    control:SetAnchorFill(GuiRoot);
    control:SetDrawLayer(DL_OVERLAY);
    control:SetDrawTier(DT_LOW);
    control:SetDrawLevel(1);
    control:SetAlpha(1);
    control:SetMouseEnabled(false);
    control:SetMovable(false);
    control:SetHidden(true);
    control:SetClampedToScreen(false);

    self.control = control;
end;

function GridOverlay:AcquireLine(pool, index)
    local line = pool[index];
    if not line then
        line = wm:CreateControl(nil, self.control, CT_LINE);
        line:SetDrawLayer(DL_OVERLAY);
        line:SetDrawTier(DT_LOW);
        line:SetDrawLevel(2);
        line:SetColor(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, GRID_COLOR.a);
        line:SetThickness(1);
        pool[index] = line;
    end;

    line:SetHidden(false);
    return line;
end;

function GridOverlay:HideUnused(pool, startIndex)
    for index = startIndex, #pool do
        local line = pool[index];
        if line then
            line:SetHidden(true);
        end;
    end;
end;

function GridOverlay:UpdateLines(size)
    if not self.control then
        return;
    end;

    local rootWidth = GuiRoot:GetWidth() or 0;
    local rootHeight = GuiRoot:GetHeight() or 0;

    local verticalCount = math.floor(rootWidth / size);
    for i = 0, verticalCount do
        local offsetX = zo_round(i * size);
        local line = self:AcquireLine(self.verticalLines, i + 1);
        line:SetAnchor(TOPLEFT, self.control, TOPLEFT, offsetX, 0);
        line:SetAnchor(BOTTOMLEFT, self.control, BOTTOMLEFT, offsetX, 0);
    end;
    self:HideUnused(self.verticalLines, verticalCount + 2);

    local horizontalCount = math.floor(rootHeight / size);
    for i = 0, horizontalCount do
        local offsetY = zo_round(i * size);
        local line = self:AcquireLine(self.horizontalLines, i + 1);
        line:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, offsetY);
        line:SetAnchor(TOPRIGHT, self.control, TOPRIGHT, 0, offsetY);
    end;
    self:HideUnused(self.horizontalLines, horizontalCount + 2);
end;

function GridOverlay:Hide()
    if not self.control then
        return;
    end;

    self.control:SetHidden(true);
    self:HideUnused(self.verticalLines, 1);
    self:HideUnused(self.horizontalLines, 1);
end;

function GridOverlay:Refresh(visible, size)
    self.size = size or self.size;
    if not visible or not size or size <= 0 then
        self:Hide();
        return;
    end;

    self:EnsureControl();
    self.control:SetHidden(false);
    self:UpdateLines(size);
end;

KFS_GridOverlay = GridOverlay;
