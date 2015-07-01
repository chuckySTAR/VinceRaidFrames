local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")
local Utilities = VinceRaidFrames.Utilities

local round = Utilities.Round

local floor = math.floor
local tostring = tostring
local tonumber = tonumber

local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage
local L = GeminiLocale:GetLocale("VinceRaidFrames", true)

local SortIdToName = {
	[1] = "SortByClass",
	[2] = "SortByRole",
	[3] = "SortByName",
	[4] = "SortByOrder"
}

local ColorIdToName = {
	[VinceRaidFrames.ColorBy.Class] = "ColorByClass",
	[VinceRaidFrames.ColorBy.Health] = "ColorByHealth",
	[VinceRaidFrames.ColorBy.FixedColor] = "FixedColor"
}

local NamingModeIdToName = {
	[VinceRaidFrames.NamingMode.Default] = "NamingModeDefault",
	[VinceRaidFrames.NamingMode.Shorten] = "NamingModeShorten",
	[VinceRaidFrames.NamingMode.Custom] = "NamingModeCustom"
}

local Options = {}
function Options:Init(parent)
	Apollo.LinkAddon(parent, self)

	self.parent = parent
	self.xmlDoc = nil
	self.wndMain = nil
	self.activeCategory = nil
	self.closeBtn = nil

	self.refreshIntervalMin = .04
	self.refreshIntervalMax = 2
	self.refreshIntervalTick = .1

	self.memberColumnsMin = 1
	self.memberColumnsMax = 10
	self.memberColumnsTick = 1

	self.backgroundAlphaMin = 0
	self.backgroundAlphaMax = 1
	self.backgroundAlphaTick = .1

	self.alphaMin = 0
	self.alphaMax = 1
	self.alphaTick = .1

	self.rangeFilterMin = 0
	self.rangeFilterMax = 1000
	self.rangeFilterTick = 5

	self.rangeAlphaMin = 0
	self.rangeAlphaMax = 1
	self.rangeAlphaTick = .1

	self.memberHeightMin = 5
	self.memberHeightMax = 100
	self.memberHeightTick = 1

	self.memberWidthMin = 20
	self.memberWidthMax = 200
	self.memberWidthTick = 1


	self.memberShieldWidthMin = 1
	self.memberShieldWidthMax = 50
	self.memberShieldWidthTick = 1

	self.memberAbsorbWidthMin = 1
	self.memberAbsorbWidthMax = 50
	self.memberAbsorbWidthTick = 1

	self.memberShieldHeightMin = 1
	self.memberShieldHeightMax = 30
	self.memberShieldHeightTick = 1

	self.memberAbsorbHeightMin = 1
	self.memberAbsorbHeightMax = 30
	self.memberAbsorbHeightTick = 1
end

function Options:Show(xmlDoc)
	if self.wndMain then
		self.wndMain:Invoke()
	else
		self.activeCategory = nil
		self.xmlDoc = xmlDoc
		self.wndMain = Apollo.LoadForm(xmlDoc, "VinceRaidFramesOptions", "DefaultStratum", self)
		self.categories = self.wndMain:FindChild("Categories")
		self.content = self.wndMain:FindChild("Content")
		self.closeBtn = self.wndMain:FindChild("CloseBtn")
		self.categoryGeneral = self.wndMain:FindChild("General")

		self.categoryGeneral:SetCheck(true)
		self:OnCategorySelect(self.categoryGeneral)
		GeminiLocale:TranslateWindow(L, self.wndMain)

		local title = self.wndMain:FindChild("Title")
		title:SetText(title:GetText() .. " v" .. Utilities.GetAddonVersion())

		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Vince Raid Frames Options", nSaveVersion = 2})
	end
end

function Options:OnCategorySelect(wndHandler)
	local categoryName = wndHandler:GetName()
--	if self.activeCategory ~= wndHandler:GetName() then

	self.activeCategory = categoryName
	self.content:DestroyChildren()
	local options = Apollo.LoadForm(self.xmlDoc, "Options" .. categoryName, self.content, self)
	self.options = options
	if options then
		GeminiLocale:TranslateWindow(L, self.wndMain)

		if categoryName == "General" then
			self.refreshIntervalSliderWidget = self:InitSliderWidget(options:FindChild("RefreshInterval"), self.refreshIntervalMin, self.refreshIntervalMax, self.refreshIntervalTick, self.parent.settings.refreshInterval, 2, function (value)
				self.parent.settings.refreshInterval = value
				self.parent.timer:Set(value)
				self.parent.timer:Stop()
			end)
			self.memberColumnsSliderWidget = self:InitSliderWidget(options:FindChild("Columns"), self.memberColumnsMin, self.memberColumnsMax, self.memberColumnsTick, self.parent.settings.memberColumns, 0, function (value)
				self.parent.settings.memberColumns = value
				self.parent:ArrangeMembers()
			end)
			self.backgroundAlphaSliderWidget = self:InitSliderWidget(options:FindChild("BackgroundAlpha"), self.backgroundAlphaMin, self.backgroundAlphaMax, self.backgroundAlphaTick, self.parent.settings.backgroundAlpha, 2, function (value)
				self.parent.settings.backgroundAlpha = value
				if self.parent.wndMain then
					self.parent.wndMain:SetBGColor(("%02x000000"):format(value * 255))
				end
			end)
			self.alphaSliderWidget = self:InitSliderWidget(options:FindChild("Alpha"), self.alphaMin, self.alphaMax, self.alphaTick, self.parent.settings.alpha, 2, function (value)
				self.parent.settings.alpha = value
				if self.parent.wndMain then
					self.parent.wndMain:SetOpacity(value, 100)
				end
			end)
			self.rangeFilterSliderWidget = self:InitSliderWidget(options:FindChild("RangeFilter"), self.rangeFilterMin, self.rangeFilterMax, self.rangeFilterTick, self.parent.settings.memberOutOfRange, 0, function (value)
				self.parent.settings.memberOutOfRange = value
			end)
			self.rangeAlphaWidget = self:InitSliderWidget(options:FindChild("RangeAlpha"), self.rangeAlphaMin, self.rangeAlphaMax, self.rangeAlphaTick, self.parent.settings.memberOutOfRangeOpacity, 2, function (value)
				self.parent.settings.memberOutOfRangeOpacity = value
			end)


			options:FindChild("HideInGroups"):SetCheck(self.parent.settings.hideInGroups)
			options:FindChild("HideCarbinesGroupDisplay"):SetCheck(self.parent.settings.hideCarbinesGroupDisplay)
			options:FindChild("SortVertical"):SetCheck(self.parent.settings.sortVertical)

			options:FindChild("SortByClass"):SetData(1)
			options:FindChild("SortByRole"):SetData(2)
			options:FindChild("SortByName"):SetData(3)
			options:FindChild("SortByOrder"):SetData(4)
			options:FindChild(SortIdToName[self.parent.settings.sortBy]):SetCheck(true)
		elseif categoryName == "MemberCell" then
			options:FindChild("ColorByClass"):SetData(VinceRaidFrames.ColorBy.Class)
			options:FindChild("ColorByHealth"):SetData(VinceRaidFrames.ColorBy.Health)
			options:FindChild("FixedColor"):SetData(VinceRaidFrames.ColorBy.FixedColor)
			options:FindChild(ColorIdToName[self.parent.settings.colorBy]):SetCheck(true)

			self:InitCheckboxWidget{
				checkbox = options:FindChild("FlashInterrupts"),
				value = self.parent.settings.memberFlashInterrupts,
				callback = function (value)
					self.parent.settings.memberFlashInterrupts = value
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("FlashDispels"),
				value = self.parent.settings.memberFlashDispels,
				callback = function (value)
					self.parent.settings.memberFlashDispels = value
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("ShowArrow"),
				value = self.parent.settings.memberShowArrow,
				callback = function (value)
					self.parent.settings.memberShowArrow = value

					if not value then
						Apollo.RemoveEventHandler("VarChange_FrameCount", self.parent)
						self.parent:HideMemberArrows()
					else
						if self.parent.wndMain:IsShown() then
							Apollo.RegisterEventHandler("VarChange_FrameCount", "OnVarChange_FrameCount", self.parent)
						end
					end
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("BuffIconsOutOfFight"),
				value = self.parent.settings.memberBuffIconsOutOfFight,
				callback = function (value)
					self.parent.settings.memberBuffIconsOutOfFight = value

					if not value then
						self.parent:RemoveBuffIcons()
					end
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("ShowShieldBar"),
				value = self.parent.settings.memberShowShieldBar,
				callback = function (value)
					self.parent.settings.memberShowShieldBar = value

					self.parent:ArrangeMemberFrames()
					self.parent:ArrangeMembers()
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("ShowAbsorbBar"),
				value = self.parent.settings.memberShowAbsorbBar,
				callback = function (value)
					self.parent.settings.memberShowAbsorbBar = value

					self.parent:ArrangeMemberFrames()
					self.parent:ArrangeMembers()
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("ShieldsBelowHealth"),
				value = self.parent.settings.memberShieldsBelowHealth,
				callback = function (value)
					self.parent.settings.memberShieldsBelowHealth = value

					self:ToggleShieldWidthHeight()

					self.parent:ArrangeMemberFrames()
					self.parent:ArrangeMembers()
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("ClassIcon"),
				value = self.parent.settings.memberShowClassIcon,
				callback = function (value)
					self.parent.settings.memberShowClassIcon = value
					self.parent:UpdateClassIcons()
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("TargetOnHover"),
				value = self.parent.settings.targetOnHover,
				callback = function (value)
					self.parent.settings.targetOnHover = value
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("HintArrowOnHover"),
				value = self.parent.settings.hintArrowOnHover,
				callback = function (value)
					self.parent.settings.hintArrowOnHover = value
				end
			}
			self:InitCheckboxWidget{
				checkbox = options:FindChild("CleanseIndicator"),
				value = self.parent.settings.memberCleanseIndicator,
				callback = function (value)
					self.parent.settings.memberCleanseIndicator = value
				end
			}
--			options:FindChild("FixedShieldLength"):SetCheck(true)
--			options:FindChild("FixedShieldLength"):Enable(false)

			self:ToggleShieldWidthHeight()

			self.memberHeight = self:InitSliderWidget(options:FindChild("Height"), self.memberHeightMin, self.memberHeightMax, self.memberHeightTick, self.parent.settings.memberHeight, 0, function (value)
				self.parent.settings.memberHeight = value
				self.parent:ArrangeMemberFrames()
				self.parent:ArrangeMembers()
			end)
			self.memberWidth = self:InitSliderWidget(options:FindChild("Width"), self.memberWidthMin, self.memberWidthMax, self.memberWidthTick, self.parent.settings.memberWidth, 0, function (value)
				self.parent.settings.memberWidth = value
				self.parent:ArrangeMemberFrames()
				self.parent:ArrangeMembers()
			end)


			self.memberShieldWidth = self:InitSliderWidget(options:FindChild("ShieldWidth"), self.memberShieldWidthMin, self.memberShieldWidthMax, self.memberShieldWidthTick, self.parent.settings.memberShieldWidth, 0, function (value)
				self.parent.settings.memberShieldWidth = value
				self.parent:ArrangeMemberFrames()
				self.parent:ArrangeMembers()
			end)
			self.memberAbsorbWidth = self:InitSliderWidget(options:FindChild("AbsorbWidth"), self.memberAbsorbWidthMin, self.memberAbsorbWidthMax, self.memberAbsorbWidthTick, self.parent.settings.memberAbsorbWidth, 0, function (value)
				self.parent.settings.memberAbsorbWidth = value
				self.parent:ArrangeMemberFrames()
				self.parent:ArrangeMembers()
			end)

			self.memberShieldHeight = self:InitSliderWidget(options:FindChild("ShieldHeight"), self.memberShieldHeightMin, self.memberShieldHeightMax, self.memberShieldHeightTick, self.parent.settings.memberShieldHeight, 0, function (value)
				self.parent.settings.memberShieldHeight = value
				self.parent:ArrangeMemberFrames()
				self.parent:ArrangeMembers()
			end)
			self.memberAbsorbHeight = self:InitSliderWidget(options:FindChild("AbsorbHeight"), self.memberAbsorbHeightMin, self.memberAbsorbHeightMax, self.memberAbsorbHeightTick, self.parent.settings.memberAbsorbHeight, 0, function (value)
				self.parent.settings.memberAbsorbHeight = value
				self.parent:ArrangeMemberFrames()
				self.parent:ArrangeMembers()
			end)

			local paddingLeft = options:FindChild("PaddingLeft")
			local paddingTop = options:FindChild("PaddingTop")
			local paddingRight = options:FindChild("PaddingRight")
			local paddingBottom = options:FindChild("PaddingBottom")
			paddingLeft:SetText(self.parent.settings.memberPaddingLeft)
			paddingLeft:SetData("memberPaddingLeft")
			paddingTop:SetText(self.parent.settings.memberPaddingTop)
			paddingTop:SetData("memberPaddingTop")
			paddingRight:SetText(self.parent.settings.memberPaddingRight)
			paddingRight:SetData("memberPaddingRight")
			paddingBottom:SetText(self.parent.settings.memberPaddingBottom)
			paddingBottom:SetData("memberPaddingBottom")

			self:InitColorWidget{
				editBox = options:FindChild("FixedColorInput"),
				value = self.parent.settings.memberBackgroundColor,
				callback = function (value)
					self.parent.settings.memberBackgroundColor = value
					self.parent:UpdateColorBy()
				end
			}

		elseif categoryName == "Colors" then
			self:InitColorWidget{
				editBox = options:FindChild("WarriorColor"),
				value = self.parent.settings.classColors[GameLib.CodeEnumClass.Warrior],
				callback = function (value)
					self.parent.settings.classColors[GameLib.CodeEnumClass.Warrior] = value
					self.parent:UpdateClassColors()
				end
			}
			self:InitColorWidget{
				editBox = options:FindChild("EngineerColor"),
				value = self.parent.settings.classColors[GameLib.CodeEnumClass.Engineer],
				callback = function (value)
					self.parent.settings.classColors[GameLib.CodeEnumClass.Engineer] = value
					self.parent:UpdateClassColors()
				end
			}
			self:InitColorWidget{
				editBox = options:FindChild("EsperColor"),
				value = self.parent.settings.classColors[GameLib.CodeEnumClass.Esper],
				callback = function (value)
					self.parent.settings.classColors[GameLib.CodeEnumClass.Esper] = value
					self.parent:UpdateClassColors()
				end
			}
			self:InitColorWidget{
				editBox = options:FindChild("MedicColor"),
				value = self.parent.settings.classColors[GameLib.CodeEnumClass.Medic],
				callback = function (value)
					self.parent.settings.classColors[GameLib.CodeEnumClass.Medic] = value
					self.parent:UpdateClassColors()
				end
			}
			self:InitColorWidget{
				editBox = options:FindChild("StalkerColor"),
				value = self.parent.settings.classColors[GameLib.CodeEnumClass.Stalker],
				callback = function (value)
					self.parent.settings.classColors[GameLib.CodeEnumClass.Stalker] = value
					self.parent:UpdateClassColors()
				end
			}
			self:InitColorWidget{
				editBox = options:FindChild("SpellslingerColor"),
				value = self.parent.settings.classColors[GameLib.CodeEnumClass.Spellslinger],
				callback = function (value)
					self.parent.settings.classColors[GameLib.CodeEnumClass.Spellslinger] = value
					self.parent:UpdateClassColors()
				end
			}

		elseif categoryName == "Names" then
			options:FindChild("NamingModeDefault"):SetData(VinceRaidFrames.NamingMode.Default)
			options:FindChild("NamingModeShorten"):SetData(VinceRaidFrames.NamingMode.Shorten)
			options:FindChild("NamingModeCustom"):SetData(VinceRaidFrames.NamingMode.Custom)
			options:FindChild(NamingModeIdToName[self.parent.settings.namingMode]):SetCheck(true)

			self:FillCustomNamesGrid()
		elseif categoryName == "Indicators" then
--			local indicators = {
--				"Health Bar",
--				"Health Text",
--				"Shield Bar",
--				"Shield Text",
--				"Absorb Bar",
--				"Absorb Text",
--				"Mana Bar",
--				"Mana Text",
--				"Name",
--				"Offline",
--				"Death",
--				"Aggro",
--				"Arrow",
--				"Auras",
--				"Interrupt",
--				"Interrupt Armor",
--				"Cleanse",
--				"Range",
--				"Class",
--				"Role",
--				"Path"
--			}
			local indicators = {
				"Health",
				"Shield",
				"Absorb",
				"Mana",
				"Name",
				"Offline",
				"Death",
				"Aggro",
				"Arrow",
				"Auras",
				"Interrupt",
				"Interrupt Armor",
				"Cleanse",
				"Range",
				"Class",
				"Role",
				"Path",
				"Avatar",
				"Ready"
			}
			local grid = options:FindChild("IndicatorsGrid")
			grid:DeleteAll()
			for i, indicator in ipairs(indicators) do
				local row = grid:AddRow(indicator)
			end
			grid:SetSortColumn(1, true)
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



function Options:OnBottomLeftTextMouseButtonUp()
	if GameLib.GetRealmName() == "Jabbit" then
		Event_FireGenericEvent("GenericEvent_ChatLogWhisper", "Vince Addons")
	end
end



function Options:FillCustomNamesGrid()
	local grid = self.options:FindChild("Grid")
	grid:DeleteAll()
	for origName, newName in pairs(self.parent.settings.names) do
		local row = grid:AddRow("")
		grid:SetCellText(row, 1, origName)
		grid:SetCellText(row, 2, newName)
	end
	grid:SetSortColumn(grid:GetSortColumn() or 1, grid:IsSortAscending())
end

function Options:UpdateNameGridInputBoxes()
	local grid = self.options:FindChild("Grid")
	local nameInput = self.options:FindChild("NameInput")
	local customNameInput = self.options:FindChild("CustomNameInput")
	local row = grid:GetCurrentRow()
	nameInput:SetText(grid:GetCellText(row, 1))
	customNameInput:SetText(grid:GetCellText(row, 2))
	customNameInput:SetFocus()
end

function Options:OnNameGridItemClick(wndControl, wndHandler, iRow, iCol, eMouseButton)
	self:UpdateNameGridInputBoxes()
end

function Options:OnNameGridSort()
	self:UpdateNameGridInputBoxes()
end

function Options:OnNewCustomName()
	local nameInput = self.options:FindChild("NameInput")
	local customNameInput = self.options:FindChild("CustomNameInput")
	self.parent.settings.names[nameInput:GetText()] = customNameInput:GetText()
	nameInput:SetText("")
	nameInput:ClearFocus()
	customNameInput:SetText("")
	customNameInput:ClearFocus()
	self:FillCustomNamesGrid()
	self.parent:RenameMembers()
end

function Options:OnHideCarbinesGroupDisplay(wndHandler, wndControl)
	self.parent.settings.hideCarbinesGroupDisplay = wndControl:IsChecked()
	self.parent:HookGroupDisplay(self.parent.settings.hideCarbinesGroupDisplay)
end

function Options:OnHideInGroups(wndHandler, wndControl)
	self.parent.settings.hideInGroups = wndControl:IsChecked()
	self.parent:Show()
end

function Options:OnSortVertical(wndHandler, wndControl)
	self.parent.settings.sortVertical = wndControl:IsChecked()
	self.parent:ArrangeMembers()
end

function Options:ToggleShieldWidthHeight()
	if self.parent.settings.memberShieldsBelowHealth then
		self.options:FindChild("ShieldHeight"):Show(true, true)
		self.options:FindChild("AbsorbHeight"):Show(true, true)
		self.options:FindChild("ShieldWidth"):Show(false, true)
		self.options:FindChild("AbsorbWidth"):Show(false, true)
	else
		self.options:FindChild("ShieldWidth"):Show(true, true)
		self.options:FindChild("AbsorbWidth"):Show(true, true)
		self.options:FindChild("ShieldHeight"):Show(false, true)
		self.options:FindChild("AbsorbHeight"):Show(false, true)
	end
end

function Options:OnSortBy(wndHandler, wndControl)
	self.parent.settings.sortBy = wndControl:GetData()
	self.parent:ArrangeMembers()
end

function Options:OnColorBy(wndHandler, wndControl)
	self.parent.settings.colorBy = wndControl:GetData()
	self.parent:UpdateColorBy()
end

function Options:OnNamingMode(wndHandler, wndControl)
	self.parent.settings.namingMode = wndControl:GetData()
	self.parent:RenameMembers()
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

function Options:InitColorWidget(data)
	data.editBox:SetData{
		callback = data.callback
	}
	data.editBox:SetText(data.value)
	data.editBox:SetMaxTextLength(6)
	data.editBox:SetTextColor("ff" .. data.value)
	data.editBox:AddEventHandler("EditBoxChanged", "OnColorWidgetEditBoxChanged")
end

function Options:OnColorWidgetEditBoxChanged(wndHandler, wndControl)
	local text = wndHandler:GetText()
	local value = tonumber(text, 16) and text:len() == 6 and text or "ffffff"
	wndHandler:SetTextColor("ff" .. value)
	wndHandler:GetData().callback(value)
end

function Options:InitCheckboxWidget(data)
	data.checkbox:SetData{
		callback = data.callback
	}
	data.checkbox:SetCheck(data.value)
	data.checkbox:AddEventHandler("ButtonCheck", "OnCheckboxWidget")
	data.checkbox:AddEventHandler("ButtonUncheck", "OnCheckboxWidget")
end

function Options:OnCheckboxWidget(wndHandler, wndControl)
	wndHandler:GetData().callback(wndControl:IsChecked())
end

function Options:OnResetColors()
	self.parent.settings.classColors = TableUtil:Copy(self.parent.defaultSettings.classColors)
	local colors = self.wndMain:FindChild("Colors")
	colors:SetCheck(true)
	self:OnCategorySelect(colors)
	self.parent:UpdateClassColors()
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
		value = round(value, wndHandler:GetParent():GetData().digits)
		parent:FindChild("Input"):SetText(tostring(value))
	end
	parent:FindChild("Slider"):SetValue(value)
	return value
end

function Options:OnMemberPadding(wndHandler)
	local data = wndHandler:GetData()
	local value = floor(tonumber(wndHandler:GetText()) or 0)
	self.parent.settings[data] = value
	self.parent:ArrangeMemberFrames()
	self.parent:ArrangeMembers()
end

VinceRaidFrames.Options = Options
