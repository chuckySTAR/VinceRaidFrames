local floor = math.floor

local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local L = GeminiLocale:GetLocale("VinceRaidFrames", true)

local SortIdToName = {
	[1] = "SortByClass",
	[2] = "SortByRole",
	[3] = "SortByName",
	[4] = "SortByOrder"
}

local ColorIdToName = {
	[1] = "ColorByClass",
	[2] = "ColorByHealth"
}

local Options = {}
function Options:OnLoad()
	self.parent = nil
	self.settings = nil
	self.xmlDoc = nil
	self.wndMain = nil
	self.activeCategory = nil
	self.closeBtn = nil

	self.refreshIntervalMin = .04
	self.refreshIntervalMax = 2
	self.refreshIntervalTick = .1

	self.maxRowsMin = 1
	self.maxRowsMax = 40
	self.maxRowsTick = 1

	self.memberHeightMin = 5
	self.memberHeightMax = 100
	self.memberHeightTick = 1

	self.memberWidthMin = 20
	self.memberWidthMax = 200
	self.memberWidthTick = 1
end

function Options:Show(xmlDoc)
	if self.wndMain then
		self.wndMain:Invoke()
	else
		self.activeCategory = nil
		self.xmlDoc = xmlDoc
		self.wndMain = Apollo.LoadForm(xmlDoc, "VinceRaidFramesOptions", nil, self)
		self.categories = self.wndMain:FindChild("Categories")
		self.content = self.wndMain:FindChild("Content")
		self.closeBtn = self.wndMain:FindChild("CloseBtn")
		self.categoryGeneral = self.wndMain:FindChild("General")

		self.categoryGeneral:SetCheck(true)
		self:OnCategorySelect(self.categoryGeneral)
		GeminiLocale:TranslateWindow(L, self.wndMain)

		local title = self.wndMain:FindChild("Title")
		title:SetText(title:GetText() .. " v" .. self:GetAddonVersion())

		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Vince Raid Frames Options"})
	end
end

function Options:OnCategorySelect(wndHandler)
	if self.activeCategory ~= wndHandler:GetName() then
		self.activeCategory = wndHandler:GetName()
		self.content:DestroyChildren()
		local options = Apollo.LoadForm(self.xmlDoc, "Options" .. wndHandler:GetName(), self.content, self)
		if options then
			GeminiLocale:TranslateWindow(L, self.wndMain)

			if wndHandler:GetName() == "General" then
				self.refreshIntervalSliderWidget = self:InitSliderWidget(options:FindChild("RefreshInterval"), self.refreshIntervalMin, self.refreshIntervalMax, self.refreshIntervalTick, self.settings.refreshInterval, 2, function (value)
					self.settings.refreshInterval = value
					self.parent.timer:Set(value)
				end)
				self.maxRowsSliderWidget = self:InitSliderWidget(options:FindChild("MaxRows"), self.maxRowsMin, self.maxRowsMax, self.maxRowsTick, self.settings.memberMaxRows, 0, function (value)
					self.settings.memberMaxRows = value
					self.parent:ArrangeMembers()
				end)
				options:FindChild("SortByClass"):SetData(1)
				options:FindChild("SortByRole"):SetData(2)
				options:FindChild("SortByName"):SetData(3)
				options:FindChild("SortByOrder"):SetData(4)
				options:FindChild(SortIdToName[self.settings.sortBy]):SetCheck(true)
			elseif wndHandler:GetName() == "MemberCell" then
				options:FindChild("ColorByClass"):SetData(1)
				options:FindChild("ColorByHealth"):SetData(2)
				options:FindChild(ColorIdToName[self.settings.colorBy]):SetCheck(true)

				options:FindChild("ShieldsBelowHealth"):SetCheck(self.settings.memberShieldsBelowHealth)
				options:FindChild("ClassIcon"):SetCheck(self.settings.memberShowClassIcon)
				options:FindChild("TargetOnHover"):SetCheck(self.settings.targetOnHover)
				options:FindChild("HintArrowOnHover"):SetCheck(self.settings.hintArrowOnHover)
				self.memberHeight = self:InitSliderWidget(options:FindChild("Height"), self.memberHeightMin, self.memberHeightMax, self.memberHeightTick, self.settings.memberHeight, 0, function (value)
					self.settings.memberHeight = value
					self.parent:ArrangeMemberFrames()
					self.parent:ArrangeMembers()
				end)
				self.memberWidth = self:InitSliderWidget(options:FindChild("Width"), self.memberWidthMin, self.memberWidthMax, self.memberWidthTick, self.settings.memberWidth, 0, function (value)
					self.settings.memberWidth = value
					self.parent:ArrangeMemberFrames()
					self.parent:ArrangeMembers()
				end)
			end
		end
	end
end

function Options:Hide()
	if self.wndMain then
		self.wndMain:Close()
		self.wndMain:Destroy()
	end
	self.wndMain = nil
end

function Options:Toggle(xmlDoc)
	if self.wndMain then
		self:Hide()
	else
		self:Show(xmlDoc)
	end
end

function Options:OnClose(wndHandler)
	self:Hide()
end

function Options.round(num, digits)
	local mult = 10^(digits or 0)
	return floor(num * mult + .5) / mult
end



function Options:OnTargetOnHover(wndHandler, wndControl)
	self.settings.targetOnHover = wndControl:IsChecked()
end

function Options:OnHintArrowOnHover(wndHandler, wndControl)
	self.settings.hintArrowOnHover = wndControl:IsChecked()
end

function Options:OnShowClassIcon(wndHandler, wndControl)
	self.settings.memberShowClassIcon = wndControl:IsChecked()
	self.parent:UpdateClassIcons()
end

function Options:OnShieldsBelowHealth(wndHandler, wndControl)
	self.settings.memberShieldsBelowHealth = wndControl:IsChecked()
	self.parent:ArrangeMemberFrames()
	self.parent:ArrangeMembers()
end

function Options:OnSortBy(wndHandler, wndControl)
	self.settings.sortBy = wndControl:GetData()
	self.parent:ArrangeMembers()
end

function Options:OnColorBy(wndHandler, wndControl)
	self.settings.colorBy = wndControl:GetData()
	self.parent:UpdateColorBy()
end

function Options:OnQueryBeginDragDrop(wndHandler, wndControl, nX, nY)
	SendVarToRover("QueryBeginDragDrop", {wndHandler, wndControl, nX, nY}, 0)
	Apollo.BeginDragDrop(wndControl, "iwas", "Icon_SkillMind_UI_espr_rpls", 5)
	return true
end

function Options:OnDragDrop(...)
	SendVarToRover("OnDragDrop", {...}, 0)
end

function Options:OnQueryDragDrop(...)
	SendVarToRover("OnQueryDragDrop", {...}, 0)
	return Apollo.DragDropQueryResult.Accept
end


function Options:InitSliderWidget(frame, min, max, tick, value, roundDigits, callback)
	frame:SetData({
		callback = callback,
		digits = roundDigits
	})
	frame:FindChild("Slider"):SetMinMax(min, max, tick)
	frame:FindChild("Slider"):SetValue(value)
	frame:FindChild("Input"):SetText(tostring(value))
	frame:FindChild("Min"):SetText(tostring(min))
	frame:FindChild("Max"):SetText(tostring(max))
	return frame
end

function Options:OnSliderWidget(wndHandler, wndControl, value)
	value = self:UpdateSliderWidget(wndHandler, value)
	wndHandler:GetParent():GetData().callback(value)
end

function Options:UpdateSliderWidget(wndHandler, value)
	local parent = wndHandler:GetParent()
	if wndHandler:GetName() == "Input" then
		value = tonumber(value)
		if not value then
			return nil
		end
	else
		value = self.round(value, wndHandler:GetParent():GetData().digits)
		parent:FindChild("Input"):SetText(tostring(value))
	end
	parent:FindChild("Slider"):SetValue(value)
	return value
end

function Options:GetAddonVersion()
	return XmlDoc.CreateFromFile("toc.xml"):ToTable().Version
end



-- a, r, g, b
function Options.HexToNumbers(hex)
	hex = tonumber(hex, 16) or 0
	return bit.rshift(hex, 24) / 255, bit.band(bit.rshift(hex, 16), 0xff) / 255, bit.band(bit.rshift(hex, 8), 0xff) / 255, bit.band(hex, 0xff) / 255
end


Apollo.RegisterPackage(Options, "Vince:VRF:Options-1", 1, {})
