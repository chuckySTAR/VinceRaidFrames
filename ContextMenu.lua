local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")

local ipairs = ipairs
local tinsert = table.insert

local knXCursorOffset = 10
local knYCursorOffset = 25

local ContextMenu = {}
ContextMenu.__index = ContextMenu
function ContextMenu:new(xmlDoc, config)
	local o = {
		xmlDoc = xmlDoc,
		config = config,
		buttons = {},
		value = nil
	}
	setmetatable(o, self)

	return o
end

function ContextMenu:Init(parent)
	Apollo.LinkAddon(parent, self)
end

function ContextMenu:Build()
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ContextMenu", "TooltipStratum", ContextMenu)
	self.wndMain:SetData(self)

	for i, config in ipairs(self.config) do
		local button = Apollo.LoadForm(self.xmlDoc, "BtnRegular", self.wndMain:FindChild("ButtonList"), ContextMenu)
		button:SetData(config)
		tinsert(self.buttons, button)
	end
end

function ContextMenu:Show(value)
	if not self.wndMain then
		self:Build()
	end

	self.wndMain:Show(true, true)

	self.value = value

	for i, button in ipairs(self.buttons) do
		local config = button:GetData()
		if config.IsVisible(value) then
			button:Show(true, true)
			button:FindChild("BtnText"):SetText(tostring(config.GetLabel(value)))
		else
			button:Show(false, true)
		end
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndMain:FindChild("ButtonList"):ArrangeChildrenVert(0) + 62)

	local tCursor = Apollo.GetMouse()
	self.wndMain:Move(tCursor.x - knXCursorOffset, tCursor.y - knYCursorOffset, self.wndMain:GetWidth(), self.wndMain:GetHeight())
end


function ContextMenu:OnMainWindowClosed(wndHandler, wndControl)
	wndHandler:Show(false, true)
end

function ContextMenu:OnRegularBtn(wndHandler, wndControl)
	self = wndHandler:GetParent():GetParent():GetData()
	local status, err = pcall(function() wndHandler:GetData().OnClick(self.value) end)
	if not status then
		Print(err)
	end
	self.wndMain:Close()
end

function ContextMenu:OnBtnRegularMouseEnter(wndHandler, wndControl)
	wndHandler:GetParent():FindChild("BtnText"):SetTextColor("UI_BtnTextBlueFlyBy")
end

function ContextMenu:OnBtnRegularMouseExit(wndHandler, wndControl)
	wndHandler:GetParent():FindChild("BtnText"):SetTextColor("UI_BtnTextBlueNormal")
end

VinceRaidFrames.ContextMenu = ContextMenu
