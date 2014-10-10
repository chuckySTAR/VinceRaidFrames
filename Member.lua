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

local ColorByClass = 1
local ColorByHealth = 2


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
		hovered = false
	}
	setmetatable(o, self)

	o:Init(parent.wndMain)

	return o
end

function Member:Init(parent)
	self.frame = Apollo.LoadForm(self.xmlDoc, "Member", parent, Member)

	self.classColor = self.settings.classColors[self.classId]

	self.memberOverlay = self.frame:FindChild("MemberOverlay")
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

	self.text:SetText(self.name)
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

function Member:GetWidth()
	return self.settings.memberWidth + (self.settings.memberShowTargetMarker and 20 or 0)
end

function Member:GetHeight()
	return self.settings.memberHeight
end

function Member:Arrange()
	self.frame:SetAnchorOffsets(0, 0, self:GetWidth(), self:GetHeight())
	self.container:SetAnchorOffsets(0, 0, self.settings.memberShowTargetMarker and -20 or 0, 0)
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
	if color == ColorByClass and not self.readyCheckMode then
		self:SetHealthColor(self.classColor)
--	elseif color == ColorByHealth then
--		self:Refresh()
	end
end


function Member:Refresh(readyCheckMode, unit, groupMember)
	self.groupMember = groupMember
	self.readyCheckMode = readyCheckMode
	self.unit = unit and unit or self.unit

	local health
	local shield
	local absorb

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

	-- Todo: Remember last status in order to optimse useless function calls
	if self.outOfRange and not self.dead and self.online then
		self.frame:SetOpacity(self.settings.memberOutOfRangeOpacity, 5)
	else
		self.frame:SetOpacity(1, 5)
	end

	self:RefreshNameColor()

--	if not readyCheckMode and self.settings.colorBy == ColorByHealth then
--		self:SetHealthColor(self.GetColorBetween(self.settings.memberLowHealthColor, self.settings.memberHighHealthColor, health))
--	end

    if self.settings.memberFillLeftToRight then
		self.health:SetAnchorPoints(0, 0, health, 1)
		self.shield:SetAnchorPoints(0, 0, shield, 1)
		self.absorb:SetAnchorPoints(0, 0, absorb, 1)
	else
		self.health:SetAnchorPoints(1 - health, 0, 1, 1)
		self.shield:SetAnchorPoints(0, 0, 1 - shield, 1)
		self.absorb:SetAnchorPoints(0, 0, 1 - absorb, 1)
	end

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
	self:SetHealthColor(self.classColor)
	
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

function Member:SetDraggable(draggable)
	self.draggable = draggable
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
	if wndHandler:GetData().draggable then
		Apollo.BeginDragDrop(wndControl, "Member", "sprResourceBar_Sprint_RunIconSilver", 0)
		return true
	end
	return false
end

function Member:OnMemberClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	local data = wndHandler:GetData()
	if data.unit then
		self.previousTarget = data.unit
		GameLib.SetTargetUnit(data.unit)
	end
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", data.frame, data.unit and data.unit:GetName() or data.groupMember.strCharacterName, data.unit)
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
	if data.settings.targetOnHover then
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

function Member.round(num, digits)
	local mult = 10^(digits or 0)
	return floor(num * mult + .5) / mult
end

function Member.GetColorBetween(from, to, position)
	return ("%02X%02X%02X"):format(((to.r - from.r) * position + from.r) * 255, ((to.g - from.g) * position + from.g) * 255, ((to.b - from.b) * position + from.b) * 255)
end

Apollo.RegisterPackage(Member, "Vince:VRF:Member-1", 1, {})
