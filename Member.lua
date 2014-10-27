local VinceRaidFrames = Apollo.GetAddon("VinceRaidFrames")
local Utilities = Apollo.GetPackage("Vince:VRF:Utilities-1").tPackage

local WindowLocationNew = WindowLocation.new

local setmetatable = setmetatable
local ipairs = ipairs
local abs = math.abs
local floor = math.floor

local ktIdToClassSprite =
{
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
}

local tTargetMarkSpriteMap = {
	"Icon_Windows_UI_CRB_Marker_Bomb",
	"Icon_Windows_UI_CRB_Marker_Ghost",
	"Icon_Windows_UI_CRB_Marker_Mask",
	"Icon_Windows_UI_CRB_Marker_Octopus",
	"Icon_Windows_UI_CRB_Marker_Pig",
	"Icon_Windows_UI_CRB_Marker_Chicken",
	"Icon_Windows_UI_CRB_Marker_Toaster",
	"Icon_Windows_UI_CRB_Marker_UFO"
}

local FoodBuffName = GameLib.GetSpell(48443):GetName()

local MarkerPixie = {
	cr = "ffffffff",
	loc = {
		fPoints = {1, .5, 1, .5},
		nOffsets = {-22, -10, -2, 10}
	}
}


local Member = {}
Member.__index = Member
function Member:OnLoad()
	self.previousTarget = nil
end
function Member:new(unit, groupMember, parent)
	local o = {
		unit = unit,
		name = groupMember and groupMember.strCharacterName or unit:GetName(),
		groupMember = groupMember,
		version = nil, -- updated on iccomm messages
		readyCheckMode = false,
		frame = nil,
		draggable = false,
		parent = parent,
		xmlDoc = parent.xmlDoc,
		settings = parent.settings,
		classId = groupMember and groupMember.eClassId or unit:GetClassId(),
		classColor = nil,
		classIconPixie = nil,
		targetMarkerPixie = nil,
		hasAggro = false,
		potionPixie = nil,
		foodPixie = nil,
		lastHealthColor = nil,
		lastFoodSprite = "",
		health = nil,
		flash = nil,
		text = nil,
		timer = nil,
		outOfRange = false,
		dead = false,
		online = true,
		targeted = false,
		hovered = false,
		lastHealthAnchorPoint = -1,
		lastShieldAnchorPoint = -1,
		lastAbsorbAnchorPoint = -1
	}
	setmetatable(o, self)

	o:Init(parent.wndMain)

	return o
end

function Member:Init(parent)
	self.frame = Apollo.LoadForm(self.xmlDoc, "Member", parent, Member)

	self.classColor = self.settings.classColors[self.classId]
	self.lowHealthColor = {Utilities.RGB2HSV(self.settings.memberLowHealthColor.r, self.settings.memberLowHealthColor.g, self.settings.memberLowHealthColor.b)}
	self.highHealthColor = {Utilities.RGB2HSV(self.settings.memberHighHealthColor.r, self.settings.memberHighHealthColor.g, self.settings.memberHighHealthColor.b)}

	self.container = self.frame:FindChild("Container")
	self.overlay = self.frame:FindChild("Overlay")
	self.healthOverlay = self.frame:FindChild("HealthOverlay")
	self.health = self.frame:FindChild("HealthBar")
	self.shield = self.frame:FindChild("ShieldBar")
	self.absorb = self.frame:FindChild("AbsorbBar")
	self.flash = self.frame:FindChild("Flash")
	self.text = self.frame:FindChild("Text")

	self:Arrange()
	self:ShowClassIcon(self.settings.memberShowClassIcon)

	self.text:SetFont(self.settings.memberFont)
	self:SetNameColor(self.settings.memberColor)

	self.frame:SetData(self)
	self.container:SetData(self)
	self.flash:Show(false, true)
	--	o:SetReadyCheckMode()
	self:UnsetReadyCheckMode()
	self:Refresh(false, self.unit, self.groupMember)

	-- Bug: SetTarget() isn't updated on reloadui
end

function Member:SetName(name)
	self.text:SetText(name)
end

function Member:GetWidth()
	return self.settings.memberWidth + (self.settings.memberShowTargetMarker and 20 or 0)
end

function Member:GetHeight()
	return self.settings.memberHeight
end

function Member:Arrange()
	self.frame:SetAnchorOffsets(0, 0, self:GetWidth() + self.settings.memberPaddingLeft + self.settings.memberPaddingRight, self:GetHeight() + self.settings.memberPaddingTop + self.settings.memberPaddingBottom)
	self.container:SetAnchorOffsets(self.settings.memberPaddingLeft, self.settings.memberPaddingTop, -self.settings.memberPaddingRight, self.settings.memberPaddingBottom)
	if self.settings.memberShieldsBelowHealth then
		self.frame:FindChild("Health"):SetAnchorOffsets(1, 1, -1, -1 - self.settings.memberShieldHeight - self.settings.memberAbsorbHeight)

		self.frame:FindChild("Shield"):SetAnchorPoints(0, 1, 1, 1)
		self.frame:FindChild("Shield"):SetAnchorOffsets(1, -1 - self.settings.memberShieldHeight, -1, -1)

		self.frame:FindChild("Absorption"):SetAnchorPoints(0, 1, 1, 1)
		self.frame:FindChild("Absorption"):SetAnchorOffsets(1, -1 - self.settings.memberAbsorbHeight - self.settings.memberShieldHeight, -1, -1 - self.settings.memberShieldHeight)
	else
		self.frame:FindChild("Health"):SetAnchorOffsets(1, 1, -1 - self.settings.memberShieldWidth - self.settings.memberAbsorbWidth, -1)

		self.frame:FindChild("Shield"):SetAnchorPoints(1, 0, 1, 1)
		self.frame:FindChild("Shield"):SetAnchorOffsets(-1 - self.settings.memberShieldWidth - self.settings.memberAbsorbWidth, 1, -1 - self.settings.memberAbsorbWidth, -1)

		self.frame:FindChild("Absorption"):SetAnchorPoints(1, 0, 1, 1)
		self.frame:FindChild("Absorption"):SetAnchorOffsets(-1 - self.settings.memberAbsorbWidth, 1, -1, -1)
	end
end

function Member:SetAggro(aggro)
	self.hasAggro = aggro
	if aggro then
		self:SetNameColor(self.settings.memberAggroTextColor)
	else
		self:RefreshNameColor()
	end
end

function Member:ShowClassIcon(show)
	if show then
		self.classIconBGPixie = self.healthOverlay:AddPixie({
			cr = "ffffffff",
			strSprite = "AbilitiesSprites:spr_TierFrame",
			loc = {
				fPoints = {0, .5, 0, .5},
				nOffsets = {1, -9, 19, 9}
			}
		})
		self.classIconPixie = self.healthOverlay:AddPixie({
			cr = "ffffffff",
			strSprite = "IconSprites:" .. ktIdToClassSprite[self.classId],
			loc = {
				fPoints = {0, .5, 0, .5},
				nOffsets = {2, -8, 18, 8}
			}
		})
		self.text:SetAnchorOffsets(21, 0, 70, 0)
	else
		if self.classIconPixie then
			self.healthOverlay:DestroyPixie(self.classIconBGPixie)
			self.healthOverlay:DestroyPixie(self.classIconPixie)
			self.text:SetAnchorOffsets(5, 0, 70, 0)
			self.classIconPixie = nil
			self.classIconBGPixie = nil
		end
	end
end

function Member:UpdateColorBy(color)
	if color == VinceRaidFrames.ColorBy.Class and not self.readyCheckMode then
		self:SetHealthColor(self.classColor)
	elseif color == VinceRaidFrames.ColorBy.Health then
		self:Refresh(self.readyCheckMode, nil, self.groupMember)
	end
end


function Member:Refresh(readyCheckMode, unit, groupMember)
	self.groupMember = groupMember
	self.readyCheckMode = readyCheckMode
	self.unit = unit and unit or self.unit

	local health
	local shield
	local absorb
	local wasOnline = self.online

	if groupMember then
		health = groupMember.nHealth / groupMember.nHealthMax
		shield = groupMember.nShield / groupMember.nShieldMax
		absorb = groupMember.nAbsorptionMax == 0 and 0 or groupMember.nAbsorption / groupMember.nAbsorptionMax

		self.outOfRange = groupMember.nHealthMax == 0 or not unit or not unit:IsValid()
		self.dead = groupMember.nHealth == 0 and groupMember.nHealthMax ~= 0
		self.online = groupMember.bIsOnline
	else
		health = unit:GetHealth() / unit:GetMaxHealth()
		shield = unit:GetShieldCapacity() / unit:GetShieldCapacityMax()
		absorb = unit:GetAbsorptionMax() == 0 and 0 or unit:GetAbsorptionValue() / unit:GetAbsorptionMax()

		self.outOfRange = false
		self.dead = unit:IsDead()
		self.online = true
	end

	if not wasOnline and self.online then
		Event_FireGenericEvent("VinceRaidFrames_Group_Online", self.name)
	elseif wasOnline and not self.online then
		Event_FireGenericEvent("VinceRaidFrames_Group_Offline", self.name)
	end

	if self.outOfRange and not self.dead and self.online then
		self.frame:SetOpacity(self.settings.memberOutOfRangeOpacity, 5)
	else
		self.frame:SetOpacity(1, 5)
	end

	self:RefreshNameColor()
--	self:RefreshTargetMarker(unit)

	if not readyCheckMode and self.settings.colorBy == VinceRaidFrames.ColorBy.Health then
		self:SetHealthColor(Utilities.GetColorBetween(self.lowHealthColor, self.highHealthColor, health))
	end

    if self.settings.memberFillLeftToRight then
--		self.health:SetAnchorPoints(0, 0, health, 1)
--		self.shield:SetAnchorPoints(0, 0, shield, 1)
--		self.absorb:SetAnchorPoints(0, 0, absorb, 1)

		if health ~= self.lastHealthAnchorPoint then
			self.health:TransitionMove(WindowLocationNew({fPoints = {0, 0, health, 1}}), .05)
			self.lastHealthAnchorPoint = health
		end
		if shield ~= self.lastShieldAnchorPoint then
			self.shield:TransitionMove(WindowLocationNew({fPoints = {0, 0, shield, 1}}), .05)
			self.lastShieldAnchorPoint = shield
		end
		if absorb ~= self.lastAbsorbAnchorPoint then
			self.absorb:TransitionMove(WindowLocationNew({fPoints = {0, 0, absorb, 1}}), .05)
			self.lastAbsorbAnchorPoint = absorb
		end
	else
		self.health:SetAnchorPoints(1 - health, 0, 1, 1)
		self.shield:SetAnchorPoints(0, 0, 1 - shield, 1)
		self.absorb:SetAnchorPoints(0, 0, 1 - absorb, 1)
	end
	
	if readyCheckMode then
		self:RefreshBuffIcons()
		if groupMember and groupMember.bHasSetReady then
			if not groupMember.bReady then
				self:SetHealthColor("ff0000")
			elseif not self.potionPixie or not self.foodPixie then
				self:SetHealthColor("ffff00")
			else
				self:SetHealthColor("00ff00")
			end
		end
	end
end

function Member:RefreshTargetMarker(unit)
	if unit and self.settings.memberShowTargetMarker then
		local sprite = tTargetMarkSpriteMap[unit:GetTargetMarker()]
		if sprite then
			MarkerPixie.strSprite = sprite
			if not self.targetMarkerPixie then
				self.targetMarkerPixie = self.memberOverlay:AddPixie(MarkerPixie)
			elseif sprite ~= self.targetMarkerSprite then
				self.memberOverlay:UpdatePixie(self.targetMarkerPixie, MarkerPixie)
			end
			self.targetMarkerSprite = sprite
		elseif not sprite then
			self.memberOverlay:DestroyPixie(self.targetMarkerPixie)
			self.targetMarkerPixie = nil
			self.targetMarkerSprite = ""
		end
	elseif self.targetMarkerPixie then
		self.memberOverlay:DestroyPixie(self.targetMarkerPixie)
		self.targetMarkerPixie = nil
		self.targetMarkerSprite = ""
	end
end

function Member:RefreshBuffIcons()
	if self.unit then
		local potionFound = false
		local foodFound = false
		local buffs = self.unit:GetBuffs()
		if buffs then
			for key, buff in ipairs(buffs.arBeneficial) do
				local potionSprite = self.settings.potions[buff.splEffect:GetId()]
				local foodSprite = buff.splEffect:GetName() == FoodBuffName and "IconSprites:Icon_ItemMisc_UI_Item_Sammich"
				if potionSprite then
					potionFound = true
					self:AddPotion(potionSprite)
				end
				if foodSprite then
					foodFound = true
					self:AddFood(foodSprite)
				end
				if potionFound and foodFound then
					break
				end
			end
		end
		if not potionFound then
			self:RemovePotion()
		end
		if not foodFound then
			self:RemoveFood()
		end
	end
end

function Member:RefreshNameColor()
	if not self.hasAggro then
		if not self.online then
			self:SetNameColor(self.settings.memberOfflineTextColor)
		elseif self.dead then
			self:SetNameColor(self.settings.memberDeadTextColor)
		else
			self:SetNameColor(self.settings.memberColor)
		end
	end
end

function Member:SetNameColor(color)
    self.text:SetTextColor(color)
end

function Member:SetReadyCheckMode()
	self:SetHealthColor("cccccc")
end

function Member:UnsetReadyCheckMode()
	self.readyCheckMode = false
	self:UpdateColorBy(self.settings.colorBy)
	
	self:RemovePotion()
	self:RemoveFood()
end

function Member:GetBuffIconOffsets(position)
	return -(position + 1) * self.settings.memberIconSizes - 1 -2 * position, -self.settings.memberIconSizes / 2, -position * self.settings.memberIconSizes - 1 -2 * position, self.settings.memberIconSizes / 2
end

function Member:AddPotion(sprite)
	if self.potionPixie then
		return
	end

	if self.foodPixie then
		self.overlay:UpdatePixie(self.foodPixie, {
			cr = "ffffffff",
			strSprite = self.lastFoodSprite,
			loc = {
				fPoints = {1, .5, 1, .5},
				nOffsets = {self:GetBuffIconOffsets(1)}
			}
		})
	end

	self.potionPixie = self.overlay:AddPixie({
		cr = "ffffffff",
		strSprite = sprite,
		loc = {
			fPoints = {1, .5, 1, .5},
			nOffsets = {self:GetBuffIconOffsets(0)}
		}
	})
end

function Member:AddFood(sprite)
	if self.foodPixie then
		return
	end
	self.lastFoodSprite = sprite

	local position = 0
	if self.potionPixie then
		position = position + 1
	end

	self.foodPixie = self.overlay:AddPixie({
		cr = "ffffffff",
		strSprite = sprite,
		loc = {
			fPoints = {1, .5, 1, .5},
			nOffsets = {self:GetBuffIconOffsets(position)}
		}
	})
end

function Member:RemovePotion()
	if self.potionPixie then
		if self.foodPixie then
			self.overlay:UpdatePixie(self.foodPixie, {
				cr = "ffffffff",
				strSprite = self.lastFoodSprite,
				loc = {
					fPoints = {1, .5, 1, .5},
					nOffsets = {self:GetBuffIconOffsets(0)}
				}
			})
		end
		
		self.overlay:DestroyPixie(self.potionPixie)
		self.potionPixie = nil
	end
end

function Member:RemoveFood()
	if self.foodPixie then
		self.overlay:DestroyPixie(self.foodPixie)
		self.foodPixie = nil
	end
end

function Member:Interrupted(amount)
	if self.timer then
		self.timer:Start()
	else
		self.timer = ApolloTimer.Create(self.settings.interruptFlashDuration, false, "OnInterruptedEnd", self)
	end
	self.flash:Show(true, true)
end

function Member:UpdateHealthAlpha()
	if self.targeted then
		self:SetHealthAlpha("2x:bb")
	elseif self.hovered then
		self:SetHealthAlpha("2x:88")
	else
		self:SetHealthAlpha("ff")
	end
end

function Member:SetTarget()
	self.targeted = true
	self:UpdateHealthAlpha()
end

function Member:UnsetTarget()
	self.targeted = false
	self:UpdateHealthAlpha()
end

function Member:SetHealthColor(color)
	self.lastHealthColor = color
	self.health:SetBGColor((self.lastHealthAlpha or "ff") .. color)
end

function Member:SetHealthAlpha(alpha)
	self.lastHealthAlpha = alpha
	self.health:SetBGColor(alpha .. self.lastHealthColor)
end

function Member:OnDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	GroupLib.SwapOrder(wndHandler:GetData().groupMember.nMemberIdx, wndSource:GetData().groupMember.nMemberIdx)
end

function Member:OnQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType ~= "Member" then
		return Apollo.DragDropQueryResult.Ignore
	end
	return Apollo.DragDropQueryResult.Accept
end

function Member:OnQueryBeginDragDrop(wndHandler, wndControl, nX, nY)
	if wndHandler:GetData().parent.editMode then
		Apollo.BeginDragDrop(wndControl, "Member", "sprResourceBar_Sprint_RunIconSilver", 0)
		return true
	end
	return false
end

function Member:OnMemberClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	self = wndHandler:GetData()
	if self.unit then
		self.previousTarget = self.unit
		GameLib.SetTargetUnit(self.unit)
	end
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", self.frame, self.name, self.unit)
	end
end

function Member:OnMouseEnter(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	self = wndHandler:GetData()
	self.hovered = true
	self:UpdateHealthAlpha()
	if self.unit then
		if self.settings.hintArrowOnHover then
			self.unit:ShowHintArrow()
		end
		if self.settings.targetOnHover then
			self.previousTarget = GameLib.GetPlayerUnit():GetTarget()
			GameLib.SetTargetUnit(self.unit)
		end
	end
end

function Member:OnMouseExit(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	self = wndHandler:GetData()
	self.hovered = false
	self:UpdateHealthAlpha()
	if self.settings.targetOnHover then
		GameLib.SetTargetUnit(self.previousTarget)
	end
end

function Member:OnMemberDown(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndHandler ~= wndControl or not wndHandler or not bDoubleClick then
		return
	end
	-- dbl click
end

function Member:OnInterruptedEnd()
	self.flash:Show(false)
end

function Member:Hide()
	self.frame:Show(false, false)
end

function Member:Show()
	self.frame:Show(true, false)
end

function Member:Destroy()
	self.frame:Destroy()
end

Apollo.RegisterPackage(Member, "Vince:VRF:Member-1", 1, {})
