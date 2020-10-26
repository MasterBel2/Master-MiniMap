------------------------------------------------------------------------------------------------------------
-- Metadata
------------------------------------------------------------------------------------------------------------

-- https://github.com/MasterBel2/Master-MiniMap
-- https://github.com/MasterBel2/Master-GUI-Framework

function widget:GetInfo()
	return {
		name = "MasterBel2's MiniMap",
		desc = "A minimap built on MasterBel2's GUI framework",
		author = "MasterBel2",
		date = "October 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

------------------------------------------------------------------------------------------------------------
-- Framework
------------------------------------------------------------------------------------------------------------

local MasterFramework
local requiredFrameworkVersion = 1

------------------------------------------------------------------------------------------------------------
-- Includes
------------------------------------------------------------------------------------------------------------

local min = math.min

local gl_DrawMiniMap = gl.DrawMiniMap
local gl_ConfigMiniMap = gl.ConfigMiniMap

------------------------------------------------------------------------------------------------------------
-- Controlling the MiniMap
------------------------------------------------------------------------------------------------------------

local cachedX = 0
local cachedY = 0 
local cachedWidth = 0 
local cachedHeight = 0
local shouldUpdateShadow = true

local minimap = { width = 0, height = 0 }

function minimap:Layout()
	if minimap.width ~= cachedWidth or minimap.height ~= cachedHeight then
		minimap.width = cachedWidth
		minimap.height = cachedHeight
		gl_ConfigMiniMap(cachedX, cachedY, cachedWidth, cachedHeight)
		shouldUpdateShadow = true
	end
end

function minimap:Draw(x, y)
	if x ~= cachedX or y ~= cachedY then
		cachedX = x
		cachedY = y
		gl_ConfigMiniMap(x, y, cachedWidth, cachedHeight)
	end
	gl_DrawMiniMap()
end

-- A placeholder for the minimap as the Margin's content. The margin is rounded and expensive to redraw,
-- but the minimap must be redrawn every frame, so we'll put this inside the margine at negligible cost
-- and stack the minimap on top.
local minimapShadow = { width = 0, height = 0 }

function minimapShadow:Layout()
	if shouldUpdateShadow then
		minimapShadow.width = cachedWidth
		minimapShadow.height = cachedHeight
		shouldUpdateShadow = false
	end
end

function minimapShadow:Draw() end

local function ResizeMiniMap(targetWidth, targetHeight)
	if shouldPreserveAspectRatio then
		local factor = min(targetWidth / cachedWidth, targetHeight / cachedHeight)
		cachedWidth = cachedWidth * factor
		cachedHeight = cachedHeight * factor
	end
end

------------------------------------------------------------------------------------------------------------
-- Setup/Shutdown
------------------------------------------------------------------------------------------------------------

local restoreCommand

function widget:Initialize()
	MasterFramework = WG.MasterFramework[requiredFrameworkVersion]
	if not MasterFramework then
		Spring.Echo("[WidgetName] Error: MasterFramework " .. requiredFrameworkVersion .. " not found! Removing self.")
		widgetHandler:RemoveWidget(self)
		return
	end

	-- Spring surrenders drawing control of minimap and hands that over to us. 
	gl.SlaveMiniMap(true)

	-- Understand shape of minimap before modifying anything
	local minimapLeft,minimapBottom,minimapWidth,minimapHeight,_,_ = Spring.GetMiniMapGeometry()
	cachedWidth = minimapWidth
	cachedHeight = minimapHeight

	-- Save previous minimap settings. Will restore on shutdown
	restoreCommand = string.format("minimap geometry %i %i %i %i", minimapLeft, minimapBottom, minimapWidth, minimapHeight)

	-- the background won't change, so wrap it in a Rasterizer to make sure it's only called once.
	-- See declaration of minimapShadow for an elaboration of why this is structured this way.
	local margin = MasterFramework:Rasterizer(MasterFramework:MarginAroundRect(minimapShadow, 0, 0, 5, 5, { MasterFramework:Color(0, 0, 0, 0.55) }, 5))
	local stackInPlace = MasterFramework:StackInPlace({ margin, minimap }, 0, 1)
	local frame = MasterFramework:FrameOfReference(0, 1, stackInPlace)
	MasterFramework.elements.minimap = frame
end

function widget:Shutdown()
	MasterFramework.elements.minimap = nil
	-- Return the minimap to its prior geometry.
	Spring.SendCommands(restoreCommand)

	-- Release the minimap and return it to its unaltered size/position.
	gl.SlaveMiniMap(false)
end
