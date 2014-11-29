local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")

local ipairs = ipairs
local tinsert = table.insert

local knXCursorOffset = 10
local knYCursorOffset = 25

local ContextMenu = {}
ContextMenu.__index = ContextMenu
function ContextMenu:new(xmlDoc, config)
	local o = setmetatable({
		xmlDoc = xmlDoc,
		config = config,
		value = nil
	}, self)

	o.wndMain = Apollo.LoadForm(xmlDoc, "ContextMenu", "TooltipStratum", ContextMenu)
	o.entryList = o.wndMain:FindChild("EntryList")
	o.wndMain:SetData(o)
	o.entryList:SetData(o)

	if config.attachTo then
		config.attachTo:AttachWindow(o.wndMain)
	end

	return o
end

function ContextMenu:Init(parent)
	Apollo.LinkAddon(parent, self)
end

function ContextMenu:Show(value)
	self.value = value
	if not self.wndMain:IsShown() then
		self.wndMain:Show(true, true)
	end
end

function ContextMenu:OnMainWindowShow(wndHandler)
	self = wndHandler:GetData()
	self:Refresh()

	local tCursor = Apollo.GetMouse()
	self.wndMain:Move(tCursor.x - knXCursorOffset, tCursor.y - knYCursorOffset, self.config.width or self.wndMain:GetWidth(), self.wndMain:GetHeight())
end

function ContextMenu:Refresh()
	self.entryList:DestroyChildren()

	if self.config.type == "CRUD" then
		for i, model in ipairs(self.config.model) do
			local btn = Apollo.LoadForm(self.xmlDoc, "BtnCRUD", self.entryList, ContextMenu)
			btn:FindChild("BtnText"):SetText(tostring(self.config.GetName(model)))
			btn:SetData({i, model})

			btn:FindChild("MoveUp"):Enable(i > 1)
			btn:FindChild("MoveDown"):Enable(i < #self.config.model)
		end

		local editBox = Apollo.LoadForm(self.xmlDoc, "EditBoxCRUD", self.entryList, ContextMenu)
		editBox:SetText(self.config.defaultName or "")
	elseif self.config.type == "dynamic" then
		local buttons = self.config.ShowCallback(self.value)
		for i, button in ipairs(buttons) do
			local btn = Apollo.LoadForm(self.xmlDoc, "BtnRegular", self.entryList, ContextMenu)
			btn:FindChild("BtnText"):SetText(tostring(button.label))
			btn:SetData(button)
		end

		if not self.wndMain:IsShown() and #buttons > 0 then
			self.wndMain:Show(true, true)
		end
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.entryList:ArrangeChildrenVert(0) + 62)
end


function ContextMenu:OnMainWindowClosed(wndHandler, wndControl)
	self = wndHandler:GetData()
	if self.config.attachTo then
		self.config.attachTo:SetCheck(false)
	end
	if self.config.HideCallback then
		self.config.HideCallback(self.value)
	end
	wndHandler:Show(false, true)
end


function ContextMenu:OnRegularBtn(wndHandler, wndControl, eMouseButton)
	self = wndHandler:GetParent():GetData()
	local data = wndHandler:GetData()

	data.OnClick(self.value)

	self.wndMain:Close()
end

function ContextMenu:OnBtnCRUDMouseButtonDown(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick)
	self = wndHandler:GetParent():GetData()

	if bDoubleClick then
		self = wndHandler:GetParent():GetData()
		local data = wndHandler:GetData()
		self.config.OnSelect(data[2])

		self.wndMain:Close()
	end
end

function ContextMenu:OnBtnCRUD(wndHandler, wndControl, eMouseButton)

end

function ContextMenu:OnEditBoxReturn(wndHandler, wndControl, text)
	self = wndHandler:GetParent():GetData()
	tinsert(self.config.model, self.config.OnCreate(text))
	self:Refresh()
end

function ContextMenu:OnBtnCRUDMoveUp(wndHandler, wndControl)
	self = wndHandler:GetParent():GetParent():GetData()
	local data = wndHandler:GetParent():GetData()
	if data[1] > 1 then
		self.config.model[data[1]] = self.config.model[data[1] - 1]
		self.config.model[data[1] - 1] = data[2]

		self:Refresh()
	end
end

function ContextMenu:OnBtnCRUDMoveDown(wndHandler, wndControl)
	self = wndHandler:GetParent():GetParent():GetData()
	local data = wndHandler:GetParent():GetData()
	if data[1] < #self.config.model then
		self.config.model[data[1]] = self.config.model[data[1] + 1]
		self.config.model[data[1] + 1] = data[2]

		self:Refresh()
	end
end

function ContextMenu:OnBtnCRUDOverwrite(wndHandler, wndControl)
	self = wndHandler:GetParent():GetParent():GetData()
	local data = wndHandler:GetParent():GetData()
	self.config.model[data[1]] = self.config.OnCreate(self.config.GetName(data[2]))
	self:Refresh()
end

function ContextMenu:OnBtnCRUDDelete(wndHandler, wndControl)
	self = wndHandler:GetParent():GetParent():GetData()
	local data = wndHandler:GetParent():GetData()
	table.remove(self.config.model, data[1])
	self:Refresh()
end

function ContextMenu:OnBtnRegularMouseEnter(wndHandler, wndControl)
	wndHandler:GetParent():FindChild("BtnText"):SetTextColor("UI_BtnTextBlueFlyBy")
end

function ContextMenu:OnBtnRegularMouseExit(wndHandler, wndControl)
	wndHandler:GetParent():FindChild("BtnText"):SetTextColor("UI_BtnTextBlueNormal")
end

VinceRaidFrames.ContextMenu = ContextMenu
