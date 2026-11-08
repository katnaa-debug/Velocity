local __axiomGlassFactories = {}
local __axiomGlassCache = {}
local function __axiomGlassRequire(name)
    local cached = __axiomGlassCache[name]
    if cached ~= nil then
        return cached
    end
    local factory = __axiomGlassFactories[name]
    if not factory then
        error("Unknown internal glass module: " .. tostring(name), 2)
    end
    local exported = factory()
    if exported == nil then
        error("Internal glass module returned nil: " .. tostring(name), 2)
    end
    __axiomGlassCache[name] = exported
    return exported
end

__axiomGlassFactories['Config'] = function()


local Config = {}

Config.TAG_NAME = "GlassmorphicUI"

Config.SAMPLING_CELL_SIZE = 11
Config.SAMPLE_TIME_BUDGET = 2.5e-3
Config.LIQUID_TIME_BUDGET = 3.5e-3
Config.TEMPORAL_SMOOTHING = 0.6
Config.RESIZE_DEBOUNCE = 1 / 25
Config.RESIZE_MAX_WAIT = 1 / 10 -- layout interval for never-settling tweens
Config.MIN_OUTPUT_RESOLUTION = 32 -- floor of the step-down ladder
Config.EDGE_DENSITY_BOOST = 3 -- edge density multiplier; refracted fetches concentrate there
Config.DEBUG_SAMPLING_HEATMAP = false -- render sampler density instead of glass

Config.DEBUG_OVERLAY = nil :: string? -- "sdf-contours" | "melt-contours" | "normals" | "cell-centers" | "cell-centers-uniform" | "grid-view" | "grid-view-flat"
Config.DEBUG_RAW_DISTANCE_FIELD = false -- use raw distance field depth and normal
Config.DEBUG_FROST_NO_PREMULTIPLY = false -- frost without coverage premultiply, showing tint bleed
Config.DEBUG_UNIFORM_WARP = false -- flat density warp to show rim smears demand warp removes
Config.DEBUG_BILINEAR_FETCH = false -- bilinear grid fetch to show cell lattice (set ChromaticAberration 0)
Config.DEBUG_FROST_NEAREST_LEVEL = false -- single blur call to show plateaus and pops

Config.PARALLEL_ENABLED = false
Config.PARALLEL_WORKER_COUNT = 8
Config.PARALLEL_MIN_OUTPUT_PIXELS = 72 * 72 -- message copies cost more than pass below this
Config.PARALLEL_CHUNK_PIXELS = 64 * 1024 -- output px per worker per frame
Config.PARALLEL_TIMEOUT_FRAMES = 300 -- ~5s before in-flight pass counts as lost
Config.PARALLEL_RESIZE_SETTLE = 0.25 -- relayout settle time before passes scatter again
Config.FROST_WORKER_COUNT = 3 -- EditableImageBlur.BlurAsync workers for the parallel route's frost

Config.DEFAULT_CORNER_RADIUS = UDim.new(0.4, 0) -- used when no UICorner or attribute supplies a radius
Config.DEFAULT_SUPER_ELLIPSE_FACTOR = 3 -- corner exponent; 2 is a circle, higher is squarer
Config.DEFAULT_THICKNESS = UDim.new(0.15, 0) -- depth of the refracting band
Config.DEFAULT_REFRACTION_FACTOR = 2.1
Config.DEFAULT_CHROMATIC_ABERRATION = 0.2 -- per-channel displacement spread; red fetches this fraction farther, blue this fraction shorter
Config.DEFAULT_FRESNEL_SIZE = UDim.new(0.1, 0)
Config.DEFAULT_FRESNEL_HARDNESS = 40
Config.DEFAULT_FRESNEL_INTENSITY = 25
Config.DEFAULT_GLARE_SIZE = UDim.new(0.2, 0)
Config.DEFAULT_GLARE_HARDNESS = 40
Config.DEFAULT_GLARE_INTENSITY = 70
Config.DEFAULT_GLARE_CONVERGENCE = 90
Config.DEFAULT_GLARE_OPPOSITE_SIDE = 50
Config.DEFAULT_GLARE_ANGLE = -50 -- degrees
Config.DEFAULT_BLUR_RADIUS = UDim.new(0.06, 0) -- the gaussian sigma is a third of the resolved px
Config.DEFAULT_MAX_OUTPUT_RESOLUTION = 192 -- max axis of the output image

Config.MIN_BLUR_SIGMA = 0.1

Config.BLUR_RADIUS_ATTRIBUTE_NAME = "BlurRadius"
Config.TRANSPARENCY_ATTRIBUTE_NAME = "Transparency"

Config.LIQUID_PARAM_ATTRIBUTES = {
	"CornerRadius",
	"SuperEllipseFactor",
	"Thickness",
	"RefractionFactor",
	"ChromaticAberration",
	"FresnelSize",
	"FresnelHardness",
	"FresnelIntensity",
	"GlareSize",
	"GlareHardness",
	"GlareIntensity",
	"GlareConvergence",
	"GlareOppositeSide",
	"GlareAngle",
	"MaxOutputResolution",
}

return Config
end

__axiomGlassFactories['EditableImageBlur'] = function()
local Blur = {}
function Blur.Blur(options)
    local pixels = options.pixelBuffer
    local w, h = math.floor(options.width), math.floor(options.height)
    if w < 1 or h < 1 then return end
    local radius = math.clamp(math.floor((options.blurRadius or 0) * 1.25 + 0.5), 0, 20)
    if radius == 0 then return end
    local temp = buffer.create(w * h * 4)
    local diameter = radius * 2 + 1
    local skipAlpha = options.skipAlpha == true
    for y = 0, h-1 do
        local row = y*w*4
        for c = 0, 3 do
            local total = 0
            for dx = -radius, radius do
                total += buffer.readu8(pixels, row + math.clamp(dx, 0, w-1)*4 + c)
            end
            for x = 0, w-1 do
                local offset = row+x*4+c
                buffer.writeu8(temp, offset, math.clamp(math.floor(total / diameter + 0.5), 0, 255))
                local outgoing = math.clamp(x-radius, 0, w-1)
                local incoming = math.clamp(x+radius+1, 0, w-1)
                total += buffer.readu8(pixels, row+incoming*4+c) - buffer.readu8(pixels, row+outgoing*4+c)
            end
        end
    end
    for x = 0, w-1 do
        for c = 0, 3 do
            if not (skipAlpha and c == 3) then
                local total = 0
                for dy=-radius, radius do
                    total += buffer.readu8(temp, (math.clamp(dy, 0, h-1)*w+x)*4+c)
                end
                for y=0, h-1 do
                    local index = (y*w+x)*4+c
                    buffer.writeu8(pixels, index, math.clamp(math.floor(total / diameter + 0.5),0,255))
                    local outgoing = math.clamp(y-radius, 0, h-1)
                    local incoming = math.clamp(y+radius+1, 0, h-1)
                    total += buffer.readu8(temp,(incoming*w+x)*4+c) - buffer.readu8(temp,(outgoing*w+x)*4+c)
                end
            end
        end
    end
end
function Blur.BlurAsync(options)
    Blur.Blur(options)
end
return Blur
end

__axiomGlassFactories['PixelColorApproximation'] = function()
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Sampler = {}
local lastRefresh = -100
local candidates = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false
local lastCharacter = nil
local function refresh()
    if os.clock() - lastRefresh < 0.6 then return end
    lastRefresh = os.clock()
    table.clear(candidates)
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("GuiObject") and obj.Visible and obj.BackgroundTransparency < 1 then
            local screen = obj:FindFirstAncestorOfClass("ScreenGui")
            if screen and screen.Enabled then
                table.insert(candidates, {Object = obj, Screen = screen, DisplayOrder = screen.DisplayOrder, ZIndex = obj.ZIndex})
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.DisplayOrder ~= b.DisplayOrder then return a.DisplayOrder < b.DisplayOrder end
        return a.ZIndex < b.ZIndex
    end)
end
local function sceneColor(x, y)
    local camera = Workspace.CurrentCamera
    local sky = Lighting.FogColor
    local ambient = Lighting.OutdoorAmbient
    if not camera then return math.max(0.02, sky.R), math.max(0.02, sky.G), math.max(0.02, sky.B) end
    local viewport = camera.ViewportSize
    local ray = camera:ViewportPointToRay(math.clamp(x, 0, viewport.X), math.clamp(y, 0, viewport.Y), 0)
    local player = Players.LocalPlayer
    local character = player and player.Character
    if lastCharacter ~= character then
        lastCharacter = character
        params.FilterDescendantsInstances = character and {character} or {}
    end
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 900, params)
    if not hit then
        local gradient = math.clamp(0.5 + ray.Direction.Y * 0.5, 0, 1)
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        local c = sky
        if atmosphere then
            c = sky:Lerp(atmosphere.Color, 0.28 + 0.3 * gradient)
        else
            c = sky:Lerp(ambient, 0.15 + gradient * 0.25)
        end
        return c.R, c.G, c.B
    end
    local color
    if hit.Instance:IsA("BasePart") then
        color = hit.Instance.Color
    elseif hit.Instance:IsA("Terrain") then
        local success, terrainColor = pcall(function() return hit.Instance:GetMaterialColor(hit.Material) end)
        color = success and terrainColor or Color3.fromRGB(116, 134, 108)
    else
        color = sky
    end
    local sunDirection = Lighting:GetSunDirection()
    local light = math.max(0, hit.Normal:Dot(sunDirection))
    local exposure = math.clamp(0.34 + light * 0.53 + Lighting.Brightness * 0.055, 0.2, 1.25)
    local r = math.clamp(color.R * exposure + ambient.R * 0.18, 0, 1)
    local g = math.clamp(color.G * exposure + ambient.G * 0.18, 0, 1)
    local b = math.clamp(color.B * exposure + ambient.B * 0.18, 0, 1)
    if hit.Material == Enum.Material.Neon then
        r, g, b = color.R, color.G, color.B
    elseif hit.Material == Enum.Material.Glass then
        r = r * 0.78 + sky.R * 0.22
        g = g * 0.78 + sky.G * 0.22
        b = b * 0.78 + sky.B * 0.22
    end
    local distance = (hit.Position - ray.Origin).Magnitude
    local fogEnd = Lighting.FogEnd
    if fogEnd < 100000 and fogEnd > 0 then
        local fraction = math.clamp((distance - Lighting.FogStart) / math.max(fogEnd - Lighting.FogStart, 1), 0, 1)
        r = r * (1 - fraction) + sky.R * fraction
        g = g * (1 - fraction) + sky.G * fraction
        b = b * (1 - fraction) + sky.B * fraction
    end
    return r, g, b
end
function Sampler:GetColorXY(x, y, pane, footprint)
    local r, g, b = sceneColor(x, y)
    refresh()
    local ownScreen = pane and pane:FindFirstAncestorOfClass("ScreenGui")
    local maxOrder = ownScreen and ownScreen.DisplayOrder or math.huge
    for _, entry in ipairs(candidates) do
        local obj = entry.Object
        if obj.Parent and entry.Screen ~= ownScreen and entry.DisplayOrder <= maxOrder then
            local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
            if x >= pos.X and y >= pos.Y and x <= pos.X + size.X and y <= pos.Y + size.Y then
                local visible = true
                local ancestor = obj.Parent
                while ancestor and ancestor:IsA("GuiObject") do
                    if not ancestor.Visible then visible = false; break end
                    if ancestor.ClipsDescendants then
                        local p, z = ancestor.AbsolutePosition, ancestor.AbsoluteSize
                        if x < p.X or y < p.Y or x > p.X + z.X or y > p.Y + z.Y then visible = false; break end
                    end
                    ancestor = ancestor.Parent
                end
                if visible then
                    local c = obj.BackgroundColor3
                    local alpha = 1 - obj.BackgroundTransparency
                    r, g, b = r * (1-alpha) + c.R*alpha, g*(1-alpha)+c.G*alpha, b*(1-alpha)+c.B*alpha
                end
            end
        end
    end
    return r, g, b
end
return Sampler
end

__axiomGlassFactories['Dependencies'] = function()
return {
    EditableImageBlur = __axiomGlassRequire("EditableImageBlur"),
    PixelColorApproximation = __axiomGlassRequire("PixelColorApproximation"),
}
end

__axiomGlassFactories['Liquid.Types'] = function()


export type LiquidParams = {
	cornerRadius: number, -- px
	superEllipseFactor: number, -- corner exponent; 2 is circle, higher is squarer
	thickness: number, -- slab depth and refracting band width in px
	refractionFactor: number, -- refractive index ratio, 1 = no refraction
	chromaticAberration: number, -- per-channel displacement spread, 0-1, 0 disables
	fresnelSize: number, -- px reach of the rim fresnel, 0 disables
	fresnelHardness: number, -- 0-1
	fresnelIntensity: number, -- 0-1, recon-time not baked
	glareSize: number, -- px reach of the rim glare, 0 disables
	glareHardness: number, -- 0-1
	glareIntensity: number, -- 0-1.2
	glareConvergence: number, -- 0-1; how tightly the glare hugs its axis
	glareOppositeSide: number, -- 0-1 strength of the second lobe
	glareAngle: number, -- radians
	maxOutputResolution: number, -- max axis of the output EditableImage
}

export type GeometryEntry = {
	Key: string,
	Refs: number,
	Ready: boolean,
	WinW: number, -- window px
	WinH: number,
	OutW: number, -- output image px
	OutH: number,
	StepX: number, -- window px per output px
	StepY: number,
	DispMap: buffer, -- interleaved i16 pairs per pixel
	AuxMap: buffer, -- u8 fresnel, u8 glare, u8 alpha, one unused pad byte per pixel
	Phase: number, -- 1 = geometry stage 1, 2 = stage 2, 3 = done
	Row: number, -- next row for the current phase
	Params: LiquidParams,
	RawField: boolean, -- debug flag for raw distance field
}

export type ReconJob = {
	Out: buffer, -- output RGBA, OutW x OutH
	Disp: buffer,
	Aux: buffer,
	Grid: buffer, -- source grid RGBA, GridW x GridH
	GridW: number,
	GridH: number,
	OutW: number,
	OutH: number,
	StepX: number, -- window px per output px
	StepY: number,
	WarpX: buffer, -- per-grid-row window-x to grid-column LUTs
	WarpY: buffer, -- window-y -> grid-row LUT
	TintR: number, -- 0-1
	TintG: number,
	TintB: number,
	TintAlpha: number, -- 0-1, tint mix weight against backdrop
	RedScale: number, -- dispersion multiplier; green is 1
	BlueScale: number,
	BlurSigma: number, -- frost sigma in output px
	FresnelIntensity: number, -- rim composite weight
	RimEnabled: boolean, -- true when rim fresnel or glare enabled
	BilinearFetch: boolean?, -- debug flag
	Row: number, -- next row to reconstruct
	RowEnd: number, -- exclusive end row
}

return {}
end

__axiomGlassFactories['Liquid.Refraction'] = function()


local Refraction = {}

Refraction.DISP_CONST = 0.05 * math.sqrt(2) * 1000

Refraction.FETCH_ROOM = 0.9

function Refraction.edgeFactorAt(d: number, thickness: number, invRefFactor: number): number
	if d < 0 or d >= thickness then
		return 0
	end
	local x = 1 - d / thickness
	local sinI = x * x -- in [0, 1], so the asin calls stay in domain
	local thetaI = math.asin(sinI)
	local thetaT = math.asin(sinI * invRefFactor)
	return math.tan(thetaI - thetaT)
end

function Refraction.dispersionScales(aberration: number): (number, number)
	return 1 + aberration, 1 - aberration
end

return Refraction
end

__axiomGlassFactories['Liquid.Shape'] = function()


local Types = __axiomGlassRequire("Liquid.Types")

type LiquidParams = Types.LiquidParams

local Shape = {}

function Shape.sdfRoundedRect(qx: number, qy: number, radius: number, n: number, invN: number): number
	if qx > 0 and qy > 0 then
		return (qx ^ n + qy ^ n) ^ invN - radius
	end
	local ddx, ddy = qx - radius, qy - radius
	local mx = if ddx > 0 then ddx else 0
	local my = if ddy > 0 then ddy else 0
	local inner = if ddx > ddy then ddx else ddy
	return math.sqrt(mx * mx + my * my) + (if inner < 0 then inner else 0)
end

function Shape.deriveShape(
	params: LiquidParams,
	winW: number,
	winH: number
): (number, number, number, number, number, number, number)
	local halfW, halfH = winW / 2, winH / 2
	local radius = math.min(params.cornerRadius, halfW, halfH)
	local n = params.superEllipseFactor
	return halfW, halfH, radius, halfW - radius, halfH - radius, n, 1 / n
end

return Shape
end

__axiomGlassFactories['Liquid.Warp'] = function()


local Shape = __axiomGlassRequire("Liquid.Shape")
local Refraction = __axiomGlassRequire("Liquid.Refraction")
local Types = __axiomGlassRequire("Liquid.Types")

type LiquidParams = Types.LiquidParams

local sdfRoundedRect = Shape.sdfRoundedRect
local deriveShape = Shape.deriveShape
local edgeFactorAt = Refraction.edgeFactorAt
local DISP_CONST = Refraction.DISP_CONST
local FETCH_ROOM = Refraction.FETCH_ROOM

local WARP_CDF_STEPS = 1024 -- density integration resolution
local WARP_LUT_SIZE = 512 -- window-position to grid-coord map entries
local WARP_LUT_MAX = WARP_LUT_SIZE - 1
local DEMAND_BINS = 128 -- resolution of the depth-demand profile and its field samples
local DEMAND_SCAN_STEPS = 512 -- depths pushed through the refraction profile
local WARP_DENSITY_FLOOR = 0.35 -- keeps unread bands warm for blur and warm-start

local Warp = {}

Warp.WARP_LUT_MAX = WARP_LUT_MAX

function Warp.warpKey(
	gridW: number,
	gridH: number,
	winW: number,
	winH: number,
	params: LiquidParams,
	maxDensity: number
): string
	return string.format(
		"%d:%d:%d:%d:%.1f:%.2f:%.2f:%.3f:%.4f:%.2f",
		gridW,
		gridH,
		math.round(winW),
		math.round(winH),
		params.cornerRadius,
		params.superEllipseFactor,
		params.thickness,
		params.refractionFactor,
		params.chromaticAberration,
		maxDensity
	)
end

local function smoothHistogram(demand: { number })
	for _ = 1, 2 do
		local prev = demand[1]
		for b = 1, DEMAND_BINS do
			local current = demand[b]
			local following = if b < DEMAND_BINS then demand[b + 1] else current
			demand[b] = (prev + 2 * current + following) * 0.25
			prev = current
		end
	end
end

local function sampleDemand(demand: { number }, exactBin: number): number
	if exactBin < 0 then
		exactBin = 0
	elseif exactBin > DEMAND_BINS - 1 then
		exactBin = DEMAND_BINS - 1
	end
	local b0 = exactBin // 1
	local fraction = exactBin - b0
	local d0 = demand[b0 + 1]
	local d1 = demand[math.min(b0 + 2, DEMAND_BINS)]
	return d0 + (d1 - d0) * fraction
end

local cdfScratch: { number } = table.create(WARP_CDF_STEPS + 1)

local function buildAxisFromDemand(
	demand: { number },
	gridN: number,
	extent: number,
	maxDensity: number,
	positions: buffer,
	positionsOffset: number,
	lut: buffer,
	lutOffset: number
)
	smoothHistogram(demand)

	local invBinWidth = DEMAND_BINS / (extent / 2)

	local step = extent / WARP_CDF_STEPS
	local cdf = cdfScratch
	local total = 0
	cdf[1] = 0
	for i = 1, WARP_CDF_STEPS do
		local x = (i - 0.5) * step
		local density = math.clamp(
			sampleDemand(demand, math.min(x, extent - x) * invBinWidth - 0.5),
			WARP_DENSITY_FLOOR,
			maxDensity
		)
		total += density * step
		cdf[i + 1] = total
	end

	local walkIndex = 1
	for i = 0, gridN - 1 do
		local target = (i + 0.5) / gridN * total
		while walkIndex < WARP_CDF_STEPS and cdf[walkIndex + 1] < target do
			walkIndex += 1
		end
		local c0 = cdf[walkIndex]
		local c1 = cdf[walkIndex + 1]
		local fraction = if c1 > c0 then (target - c0) / (c1 - c0) else 0
		buffer.writef32(positions, positionsOffset + i * 4, (walkIndex - 1 + fraction) * step)
	end

	local gridScale = gridN / total
	for j = 0, WARP_LUT_MAX do
		local exactStep = j / WARP_LUT_MAX * WARP_CDF_STEPS
		local i0 = math.min(exactStep // 1, WARP_CDF_STEPS - 1)
		local fraction = exactStep - i0
		local mass = cdf[i0 + 1] + (cdf[i0 + 2] - cdf[i0 + 1]) * fraction
		buffer.writef32(lut, lutOffset + j * 4, math.clamp(mass * gridScale - 0.5, 0, gridN - 1))
	end
end

function Warp.buildWarp(
	gridW: number,
	gridH: number,
	winW: number,
	winH: number,
	params: LiquidParams,
	maxDensity: number,
	uniform: boolean?
): (buffer, buffer, buffer, buffer)
	local halfW, halfH, radius, insetX, insetY, n, invN = deriveShape(params, winW, winH)
	local halfMin = math.min(halfW, halfH)
	local thickness = params.thickness
	local invRefFactor = 1 / params.refractionFactor
	local spread = params.chromaticAberration

	local depthBin = halfMin / DEMAND_BINS
	local invDepthBin = 1 / depthBin
	local demand = table.create(DEMAND_BINS, if uniform then 1 else 0)
	if not uniform then
		local scanStep = halfMin / DEMAND_SCAN_STEPS
		local weight = scanStep * invDepthBin / 3
		local maxScale = edgeFactorAt(0, thickness, invRefFactor) * DISP_CONST
		local roomBase = FETCH_ROOM * halfMin
		for i = 0, DEMAND_SCAN_STEPS - 1 do
			local p = (i + 0.5) * scanStep
			local reach = edgeFactorAt(p, thickness, invRefFactor) * DISP_CONST
			if maxScale > roomBase then
				local room = halfMin - p + roomBase
				if maxScale > room then
					reach = reach * room / maxScale
				end
			end
			for channel = -1, 1 do
				local fetch = (p + reach * (1 + channel * spread)) * invDepthBin // 1
				if fetch < 0 then
					fetch = 0
				elseif fetch > DEMAND_BINS - 1 then
					fetch = DEMAND_BINS - 1
				end
				demand[fetch + 1] += weight
			end
		end
		smoothHistogram(demand)
	end

	local function demandAt(x: number, y: number): number
		local d = sdfRoundedRect(math.abs(x - halfW) - insetX, math.abs(y - halfH) - insetY, radius, n, invN)
		return sampleDemand(demand, -d * invDepthBin - 0.5)
	end

	local marginalY = table.create(DEMAND_BINS, 0)
	local marginalStepX = winW / DEMAND_BINS
	local marginalStepY = halfH / DEMAND_BINS
	for by = 0, DEMAND_BINS - 1 do
		local y = (by + 0.5) * marginalStepY
		local sum = 0
		for bx = 0, DEMAND_BINS - 1 do
			sum += demandAt((bx + 0.5) * marginalStepX, y)
		end
		marginalY[by + 1] = sum / DEMAND_BINS
	end
	local positionsY = buffer.create(gridH * 4)
	local lutY = buffer.create(WARP_LUT_SIZE * 4)
	buildAxisFromDemand(marginalY, gridH, winH, maxDensity, positionsY, 0, lutY, 0)

	local positionsX = buffer.create(gridW * gridH * 4)
	local lutX = buffer.create(WARP_LUT_SIZE * gridH * 4)
	local slice = table.create(DEMAND_BINS, 0)
	local sliceStep = halfW / DEMAND_BINS
	for j = 0, gridH - 1 do
		local rowY = buffer.readf32(positionsY, j * 4)
		for bx = 1, DEMAND_BINS do
			slice[bx] = demandAt((bx - 0.5) * sliceStep, rowY)
		end
		buildAxisFromDemand(slice, gridW, winW, maxDensity, positionsX, j * gridW * 4, lutX, j * WARP_LUT_SIZE * 4)
	end

	return positionsX, lutX, positionsY, lutY
end

local function warpLookup(lut: buffer, base: number, idx: number): number
	if idx < 0 then
		idx = 0
	elseif idx > WARP_LUT_MAX then
		idx = WARP_LUT_MAX
	end
	local i0 = idx // 1
	local fraction = idx - i0
	local g0 = buffer.readf32(lut, (base + i0) * 4)
	local g1 = buffer.readf32(lut, (base + (if i0 < WARP_LUT_MAX then i0 + 1 else i0)) * 4)
	return g0 + (g1 - g0) * fraction
end
Warp.warpLookup = warpLookup

local function warpLookupX(lutX: buffer, gy: number, gridHm1: number, idx: number): number
	local j0 = gy // 1
	local fj = gy - j0
	if j0 >= gridHm1 then
		j0 = gridHm1
		fj = 0
	end
	local g0 = warpLookup(lutX, j0 * WARP_LUT_SIZE, idx)
	if fj <= 0 then
		return g0
	end
	return g0 + (warpLookup(lutX, (j0 + 1) * WARP_LUT_SIZE, idx) - g0) * fj
end
Warp.warpLookupX = warpLookupX

return Warp
end

__axiomGlassFactories['Liquid.Geometry'] = function()


local Shape = __axiomGlassRequire("Liquid.Shape")
local Refraction = __axiomGlassRequire("Liquid.Refraction")
local Types = __axiomGlassRequire("Liquid.Types")

type LiquidParams = Types.LiquidParams
type GeometryEntry = Types.GeometryEntry

local sdfRoundedRect = Shape.sdfRoundedRect
local deriveShape = Shape.deriveShape
local edgeFactorAt = Refraction.edgeFactorAt
local DISP_CONST = Refraction.DISP_CONST
local FETCH_ROOM = Refraction.FETCH_ROOM

local MELT_SPAN_FLOOR = 0.25
local DISP_FIXED_SCALE = 16 -- Q11.4 fixed point: the i16 maps store displacement px * 16
local ROWS_PER_CLOCK_CHECK = 4 -- geometry build rows between deadline checks

local Geometry = {}

Geometry.DISP_FIXED_SCALE = DISP_FIXED_SCALE
Geometry.MELT_SPAN_FLOOR = MELT_SPAN_FLOOR

local function rimFactor(depth: number, k: number, hardness: number): number
	local b = 1 + hardness - depth * k
	if b <= 0 then
		return 0
	end
	local b2 = b * b
	return math.min(b2 * b2 * b, 1)
end

local function rimK(size: number): number?
	return if size > 0 then (500 / size) ^ 2 / 1500 else nil
end

function Geometry.geometryKey(
	winW: number,
	winH: number,
	outW: number,
	outH: number,
	params: LiquidParams,
	rawField: boolean?
): string
	return (if rawField then "raw:" else "")
		.. string.format(
			"%d:%d:%d:%d:%.1f:%.2f:%.2f:%.3f:%.1f:%.3f:%.1f:%.3f:%.3f:%.3f:%.3f:%.4f",
			math.round(winW),
			math.round(winH),
			outW,
			outH,
			params.cornerRadius,
			params.superEllipseFactor,
			params.thickness,
			params.refractionFactor,
			params.fresnelSize,
			params.fresnelHardness,
			params.glareSize,
			params.glareHardness,
			params.glareIntensity,
			params.glareConvergence,
			params.glareOppositeSide,
			params.glareAngle
		)
end

local geometryCache: { [string]: GeometryEntry } = {}

function Geometry.acquireGeometry(
	winW: number,
	winH: number,
	outW: number,
	outH: number,
	params: LiquidParams,
	key: string,
	rawField: boolean?
): GeometryEntry
	local entry = geometryCache[key]
	if entry then
		entry.Refs += 1
		return entry
	end

	local pixelBytes = outW * outH * 4
	local newEntry: GeometryEntry = {
		Key = key,
		Refs = 1,
		Ready = false,
		WinW = winW,
		WinH = winH,
		OutW = outW,
		OutH = outH,
		StepX = winW / outW,
		StepY = winH / outH,
		DispMap = buffer.create(pixelBytes),
		AuxMap = buffer.create(pixelBytes),
		Phase = 1,
		Row = 0,
		Params = params,
		RawField = rawField == true,
	}
	geometryCache[key] = newEntry
	return newEntry
end

function Geometry.releaseGeometry(entry: GeometryEntry)
	entry.Refs -= 1
	if entry.Refs <= 0 then
		geometryCache[entry.Key] = nil
	end
end

local function buildSdfRows(entry: GeometryEntry, deadline: number)
	local aux = entry.AuxMap
	local params = entry.Params
	local outW, outH = entry.OutW, entry.OutH
	local stepX, stepY = entry.StepX, entry.StepY
	local centerX, centerY, radius, insetX, insetY, n, invN = deriveShape(params, entry.WinW, entry.WinH)
	local fresnelHardness = params.fresnelHardness
	local fresnelK = rimK(params.fresnelSize)
	local invMaskStep = 1 / math.max(stepX, stepY)

	local row = entry.Row
	while row < outH do
		local py = (row + 0.5) * stepY - centerY
		local qy = math.abs(py) - insetY
		local rowOffset = row * outW * 4
		for x = 0, outW - 1 do
			local px = (x + 0.5) * stepX - centerX
			local qx = math.abs(px) - insetX
			local d = sdfRoundedRect(qx, qy, radius, n, invN)
			local depth = -d

			local offset = rowOffset + x * 4
			local fresnel = if fresnelK then rimFactor(depth, fresnelK, fresnelHardness) else 0
			buffer.writeu8(aux, offset, math.round(fresnel * 255))
			buffer.writeu8(aux, offset + 2, math.round(math.clamp(0.5 - d * invMaskStep, 0, 1) * 255))
		end
		row += 1
		if row % ROWS_PER_CLOCK_CHECK == 0 and os.clock() >= deadline then
			break
		end
	end

	if row >= outH then
		entry.Phase = 2
		entry.Row = 0
	else
		entry.Row = row
	end
end

local function buildDisplacementRows(entry: GeometryEntry, deadline: number)
	local disp, aux = entry.DispMap, entry.AuxMap
	local params = entry.Params
	local rawField = entry.RawField
	local outW, outH = entry.OutW, entry.OutH
	local stepX, stepY = entry.StepX, entry.StepY
	local centerX, centerY, radius, insetX, insetY, n, invN = deriveShape(params, entry.WinW, entry.WinH)
	local halfMin = math.min(centerX, centerY)
	local invMeltSpan = 1 / math.max(radius, MELT_SPAN_FLOOR * halfMin)
	local thickness = params.thickness
	local invRefFactor = 1 / params.refractionFactor
	local glareHardness = params.glareHardness
	local glareK = rimK(params.glareSize)
	local glareIntensity = params.glareIntensity
	local glareOpposite = params.glareOppositeSide
	local glareExponent = 0.1 + params.glareConvergence * 2
	local glareAngleBias = params.glareAngle - math.pi / 4
	local twoPi = 2 * math.pi
	local room = FETCH_ROOM * halfMin
	local maxScale = edgeFactorAt(0, thickness, invRefFactor) * DISP_CONST
	local zeroDepth = if glareK then math.max(thickness, (1 + glareHardness) / glareK) else thickness

	local function contourAt(apx: number, apy: number, d: number): (number, number, number, number)
		local v = d * invMeltSpan
		if v > 1 then
			v = 1
		end
		local beta = v * v * v * (v * (v * 6 - 15) + 10)
		local rho = radius - d + beta * (halfMin - radius)
		if rho < 0 then
			rho = 0
		end
		local m = 2 + (n - 2) * (1 - beta)
		local qx = apx - (centerX - d - rho)
		local qy = apy - (centerY - d - rho)
		local g
		if qx > 0 and qy > 0 then
			g = (qx ^ m + qy ^ m) ^ (1 / m) - rho
		else
			g = (if qx > qy then qx else qy) - rho
		end
		return g, qx, qy, m
	end

	local row = entry.Row
	while row < outH do
		local rowBase = row * outW
		local py = (row + 0.5) * stepY - centerY
		local absPy = math.abs(py)
		local sy = if py >= 0 then 1 else -1
		for x = 0, outW - 1 do
			local offset = (rowBase + x) * 4
			if buffer.readu8(aux, offset + 2) == 0 then
				continue
			end
			local px = (x + 0.5) * stepX - centerX
			local absPx = math.abs(px)
			local sx = if px >= 0 then 1 else -1

			local depth: number, qx: number, qy: number, m: number
			if rawField then
				qx, qy, m = absPx - insetX, absPy - insetY, n
				depth = -sdfRoundedRect(qx, qy, radius, n, invN)
				if depth < 0 then
					depth = 0
				elseif depth > zeroDepth then
					continue
				end
			else
				if contourAt(absPx, absPy, zeroDepth) < 0 then
					continue
				end

				depth = 0
				local g
				g, qx, qy, m = contourAt(absPx, absPy, 0)
				if g < 0 then
					local lo, hi = 0, halfMin
					for _ = 1, 20 do
						local mid = (lo + hi) * 0.5
						if contourAt(absPx, absPy, mid) < 0 then
							lo = mid
						else
							hi = mid
						end
					end
					depth = (lo + hi) * 0.5
					g, qx, qy, m = contourAt(absPx, absPy, depth)
				end
			end

			local dirX, dirY
			if qx > 0 and qy > 0 then
				dirX = sx * qx ^ (m - 1)
				dirY = sy * qy ^ (m - 1)
			elseif qy >= qx then
				dirX = 0
				dirY = sy
			else
				dirX = sx
				dirY = 0
			end

			local len = math.sqrt(dirX * dirX + dirY * dirY)
			local dispX, dispY = 0, 0
			local glare = 0
			if len > 1e-9 then
				local invLen = 1 / len
				local nx, ny = dirX * invLen, dirY * invLen

				local scale = edgeFactorAt(depth, thickness, invRefFactor) * DISP_CONST
				if maxScale > room then
					local reach = px * nx + py * ny + room
					if maxScale > reach then
						scale = scale * reach / maxScale
					end
				end
				dispX = -nx * scale
				dispY = -ny * scale

				if glareK then
					local geo = rimFactor(depth, glareK, glareHardness)
					if geo > 0 then
						local angle = math.atan2(-ny, nx)
						if angle < 0 then
							angle += twoPi
						end
						local a = (angle + glareAngleBias) * 2
						local farside = (a > 1.5 * math.pi and a < 3.5 * math.pi) or a < -0.5 * math.pi
						local af = (0.5 + math.sin(a) * 0.5)
							* 1.2
							* (if farside then glareOpposite else 1)
							* glareIntensity
						glare = math.clamp(af ^ glareExponent, 0, 1) * geo
					end
				end
			end

			buffer.writei16(disp, offset, math.clamp(math.round(dispX * DISP_FIXED_SCALE), -32767, 32767))
			buffer.writei16(disp, offset + 2, math.clamp(math.round(dispY * DISP_FIXED_SCALE), -32767, 32767))
			buffer.writeu8(aux, offset + 1, math.round(glare * 255))
		end
		row += 1
		if row % ROWS_PER_CLOCK_CHECK == 0 and os.clock() >= deadline then
			break
		end
	end

	if row >= outH then
		entry.Phase = 3
	else
		entry.Row = row
	end
end

function Geometry.stepGeometry(entry: GeometryEntry, deadline: number): boolean
	if entry.Ready then
		return true
	end
	if entry.Phase == 1 then
		buildSdfRows(entry, deadline)
	end
	if entry.Phase == 2 and os.clock() < deadline then
		buildDisplacementRows(entry, deadline)
	end
	if entry.Phase == 3 then
		entry.Ready = true
	end
	return entry.Ready
end

return Geometry
end

__axiomGlassFactories['Liquid.Reconstruct'] = function()


local Warp = __axiomGlassRequire("Liquid.Warp")
local Geometry = __axiomGlassRequire("Liquid.Geometry")
local Types = __axiomGlassRequire("Liquid.Types")

type ReconJob = Types.ReconJob

local warpLookup = Warp.warpLookup
local warpLookupX = Warp.warpLookupX
local WARP_LUT_MAX = Warp.WARP_LUT_MAX

local INV_DISP_FIXED_SCALE = 1 / Geometry.DISP_FIXED_SCALE
local INV_255 = 1 / 255

local band = bit32.band
local rshift = bit32.rshift

local Reconstruct = {}

local function clearColor(tintR: number, tintG: number, tintB: number): number
	return (tintR * 255 + 0.5) // 1 + ((tintG * 255 + 0.5) // 1) * 0x100 + ((tintB * 255 + 0.5) // 1) * 0x10000
end
Reconstruct.clearColor = clearColor

function Reconstruct.resampleGridBilinear(
	old: buffer,
	oldW: number,
	oldH: number,
	new: buffer,
	newW: number,
	newH: number
)
	local oldWm1, oldHm1 = oldW - 1, oldH - 1
	local scaleX, scaleY = oldW / newW, oldH / newH
	for y = 0, newH - 1 do
		local sampleY = math.clamp((y + 0.5) * scaleY - 0.5, 0, oldHm1)
		local y0 = sampleY // 1
		local fy = sampleY - y0
		local y1 = if y0 < oldHm1 then y0 + 1 else y0
		local rowBase0 = y0 * oldW
		local rowBase1 = y1 * oldW
		local rowOffset = y * newW * 4
		for x = 0, newW - 1 do
			local sampleX = math.clamp((x + 0.5) * scaleX - 0.5, 0, oldWm1)
			local x0 = sampleX // 1
			local fx = sampleX - x0
			local x1 = if x0 < oldWm1 then x0 + 1 else x0

			local o00 = (rowBase0 + x0) * 4
			local o10 = (rowBase0 + x1) * 4
			local o01 = (rowBase1 + x0) * 4
			local o11 = (rowBase1 + x1) * 4
			local w11 = fx * fy
			local w10 = fx - w11
			local w01 = fy - w11
			local w00 = 1 - fx - fy + w11

			local offset = rowOffset + x * 4
			for channel = 0, 2 do
				local value = buffer.readu8(old, o00 + channel) * w00
					+ buffer.readu8(old, o10 + channel) * w10
					+ buffer.readu8(old, o01 + channel) * w01
					+ buffer.readu8(old, o11 + channel) * w11
				buffer.writeu8(new, offset + channel, math.round(value))
			end
			buffer.writeu8(new, offset + 3, 255)
		end
	end
end



local function cubicWeights(t: number): (number, number, number, number)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (2 * t2 - t3 - t), 0.5 * (3 * t3 - 5 * t2 + 2), 0.5 * (4 * t2 - 3 * t3 + t), 0.5 * (t3 - t2)
end

local function cubicTaps(coordinate: number, limit: number): (number, number, number, number, number)
	local base = coordinate // 1
	local before = if base > 0 then base - 1 else 0
	local after = if base < limit then base + 1 else base
	local far = if after < limit then after + 1 else after
	return before * 4, base * 4, after * 4, far * 4, coordinate - base
end

local function cubicRowFetch(
	grid: buffer,
	rowBase: number,
	xm4: number,
	x04: number,
	x14: number,
	x24: number,
	w0: number,
	w1: number,
	w2: number,
	w3: number
): (number, number, number)
	local c0 = buffer.readu32(grid, rowBase + xm4)
	local c1 = buffer.readu32(grid, rowBase + x04)
	local c2 = buffer.readu32(grid, rowBase + x14)
	local c3 = buffer.readu32(grid, rowBase + x24)
	return band(c0, 0xFF) * w0 + band(c1, 0xFF) * w1 + band(c2, 0xFF) * w2 + band(c3, 0xFF) * w3,
		band(rshift(c0, 8), 0xFF) * w0 + band(rshift(c1, 8), 0xFF) * w1 + band(rshift(c2, 8), 0xFF) * w2 + band(
			rshift(c3, 8),
			0xFF
		) * w3,
		band(rshift(c0, 16), 0xFF) * w0 + band(rshift(c1, 16), 0xFF) * w1 + band(rshift(c2, 16), 0xFF) * w2 + band(
			rshift(c3, 16),
			0xFF
		) * w3
end

local function cubicChannel(
	grid: buffer,
	gridW: number,
	gridWm1: number,
	gridHm1: number,
	gx: number,
	gy: number,
	shift: number
): number
	if gx < 0 then
		gx = 0
	elseif gx > gridWm1 then
		gx = gridWm1
	end
	if gy < 0 then
		gy = 0
	elseif gy > gridHm1 then
		gy = gridHm1
	end
	local xm4, x04, x14, x24, tx = cubicTaps(gx, gridWm1)
	local ym4, y04, y14, y24, ty = cubicTaps(gy, gridHm1)
	local wx0, wx1, wx2, wx3 = cubicWeights(tx)
	local wy0, wy1, wy2, wy3 = cubicWeights(ty)
	local rb0, rb1, rb2, rb3 = ym4 * gridW, y04 * gridW, y14 * gridW, y24 * gridW
	local row0 = band(rshift(buffer.readu32(grid, rb0 + xm4), shift), 0xFF) * wx0
		+ band(rshift(buffer.readu32(grid, rb0 + x04), shift), 0xFF) * wx1
		+ band(rshift(buffer.readu32(grid, rb0 + x14), shift), 0xFF) * wx2
		+ band(rshift(buffer.readu32(grid, rb0 + x24), shift), 0xFF) * wx3
	local row1 = band(rshift(buffer.readu32(grid, rb1 + xm4), shift), 0xFF) * wx0
		+ band(rshift(buffer.readu32(grid, rb1 + x04), shift), 0xFF) * wx1
		+ band(rshift(buffer.readu32(grid, rb1 + x14), shift), 0xFF) * wx2
		+ band(rshift(buffer.readu32(grid, rb1 + x24), shift), 0xFF) * wx3
	local row2 = band(rshift(buffer.readu32(grid, rb2 + xm4), shift), 0xFF) * wx0
		+ band(rshift(buffer.readu32(grid, rb2 + x04), shift), 0xFF) * wx1
		+ band(rshift(buffer.readu32(grid, rb2 + x14), shift), 0xFF) * wx2
		+ band(rshift(buffer.readu32(grid, rb2 + x24), shift), 0xFF) * wx3
	local row3 = band(rshift(buffer.readu32(grid, rb3 + xm4), shift), 0xFF) * wx0
		+ band(rshift(buffer.readu32(grid, rb3 + x04), shift), 0xFF) * wx1
		+ band(rshift(buffer.readu32(grid, rb3 + x14), shift), 0xFF) * wx2
		+ band(rshift(buffer.readu32(grid, rb3 + x24), shift), 0xFF) * wx3
	return row0 * wy0 + row1 * wy1 + row2 * wy2 + row3 * wy3
end

function Reconstruct.reconstructRows(job: ReconJob, deadline: number): boolean
	local out, disp, aux, grid = job.Out, job.Disp, job.Aux, job.Grid
	local gridW = job.GridW
	local gridWm1, gridHm1 = job.GridW - 1, job.GridH - 1
	local outW, outH = job.OutW, job.OutH
	local rowEnd = job.RowEnd
	local stepX, stepY = job.StepX, job.StepY
	local warpX, warpY = job.WarpX, job.WarpY
	local lutScaleX = WARP_LUT_MAX / (stepX * outW)
	local lutScaleY = WARP_LUT_MAX / (stepY * outH)
	local tintAlpha = job.TintAlpha
	local keep = 1 - tintAlpha
	local tintR = job.TintR * 255 * tintAlpha
	local tintG = job.TintG * 255 * tintAlpha
	local tintB = job.TintB * 255 * tintAlpha
	local redScale, blueScale = job.RedScale, job.BlueScale
	local dispersing = redScale ~= 1
	local bilinear = job.BilinearFetch == true
	local clear = clearColor(job.TintR, job.TintG, job.TintB)

	if job.TintAlpha >= 1 then
		local row = job.Row
		while row < rowEnd do
			local rowOffset = row * outW * 4
			for x = 0, outW - 1 do
				local offset = rowOffset + x * 4
				buffer.writeu32(out, offset, clear + buffer.readu8(aux, offset + 2) * 0x1000000)
			end
			row += 1
			if os.clock() >= deadline then
				break
			end
		end
		job.Row = row
		return row >= rowEnd
	end

	local row = job.Row
	while row < rowEnd do
		local wy = (row + 0.5) * stepY
		local rowGY = warpLookup(warpY, 0, wy * lutScaleY)
		local rowOffset = row * outW * 4
		for x = 0, outW - 1 do
			local offset = rowOffset + x * 4
			local alpha = buffer.readu8(aux, offset + 2)
			if alpha == 0 then
				buffer.writeu32(out, offset, clear) -- outside the shape
			else
				local dispX = buffer.readi16(disp, offset) * INV_DISP_FIXED_SCALE
				local dispY = buffer.readi16(disp, offset + 2) * INV_DISP_FIXED_SCALE
				local r: number, g: number, b: number
				if dispersing and (dispX ~= 0 or dispY ~= 0) then
					local wx = (x + 0.5) * stepX
					local redY, greenY, blueY
					if dispY == 0 then
						redY, greenY, blueY = rowGY, rowGY, rowGY
					else
						redY = warpLookup(warpY, 0, (wy + dispY * redScale) * lutScaleY)
						greenY = warpLookup(warpY, 0, (wy + dispY) * lutScaleY)
						blueY = warpLookup(warpY, 0, (wy + dispY * blueScale) * lutScaleY)
					end
					local redX = warpLookupX(warpX, redY, gridHm1, (wx + dispX * redScale) * lutScaleX)
					local greenX = warpLookupX(warpX, greenY, gridHm1, (wx + dispX) * lutScaleX)
					local blueX = warpLookupX(warpX, blueY, gridHm1, (wx + dispX * blueScale) * lutScaleX)
					r = cubicChannel(grid, gridW, gridWm1, gridHm1, redX, redY, 0)
					g = cubicChannel(grid, gridW, gridWm1, gridHm1, greenX, greenY, 8)
					b = cubicChannel(grid, gridW, gridWm1, gridHm1, blueX, blueY, 16)
				else
					local gy = if dispY == 0 then rowGY else warpLookup(warpY, 0, (wy + dispY) * lutScaleY)
					local gx = warpLookupX(warpX, gy, gridHm1, ((x + 0.5) * stepX + dispX) * lutScaleX)
					if bilinear then
						local x0 = gx // 1
						local fx = gx - x0
						local x1 = if x0 < gridWm1 then x0 + 1 else x0
						local y0 = gy // 1
						local fy = gy - y0
						local y1 = if y0 < gridHm1 then y0 + 1 else y0
						local c00 = buffer.readu32(grid, (y0 * gridW + x0) * 4)
						local c10 = buffer.readu32(grid, (y0 * gridW + x1) * 4)
						local c01 = buffer.readu32(grid, (y1 * gridW + x0) * 4)
						local c11 = buffer.readu32(grid, (y1 * gridW + x1) * 4)
						local w11 = fx * fy
						local w10 = fx - w11
						local w01 = fy - w11
						local w00 = 1 - fx - fy + w11
						r = band(c00, 0xFF) * w00
							+ band(c10, 0xFF) * w10
							+ band(c01, 0xFF) * w01
							+ band(c11, 0xFF) * w11
						g = band(rshift(c00, 8), 0xFF) * w00
							+ band(rshift(c10, 8), 0xFF) * w10
							+ band(rshift(c01, 8), 0xFF) * w01
							+ band(rshift(c11, 8), 0xFF) * w11
						b = band(rshift(c00, 16), 0xFF) * w00
							+ band(rshift(c10, 16), 0xFF) * w10
							+ band(rshift(c01, 16), 0xFF) * w01
							+ band(rshift(c11, 16), 0xFF) * w11
					else
						local xm4, x04, x14, x24, tx = cubicTaps(gx, gridWm1)
						local ym4, y04, y14, y24, ty = cubicTaps(gy, gridHm1)
						local wx0, wx1, wx2, wx3 = cubicWeights(tx)
						local wy0, wy1, wy2, wy3 = cubicWeights(ty)
						local r0, g0, b0 = cubicRowFetch(grid, ym4 * gridW, xm4, x04, x14, x24, wx0, wx1, wx2, wx3)
						local r1, g1, b1 = cubicRowFetch(grid, y04 * gridW, xm4, x04, x14, x24, wx0, wx1, wx2, wx3)
						local r2, g2, b2 = cubicRowFetch(grid, y14 * gridW, xm4, x04, x14, x24, wx0, wx1, wx2, wx3)
						local r3, g3, b3 = cubicRowFetch(grid, y24 * gridW, xm4, x04, x14, x24, wx0, wx1, wx2, wx3)
						r = r0 * wy0 + r1 * wy1 + r2 * wy2 + r3 * wy3
						g = g0 * wy0 + g1 * wy1 + g2 * wy2 + g3 * wy3
						b = b0 * wy0 + b1 * wy1 + b2 * wy2 + b3 * wy3
					end
				end
				if r < 0 then
					r = 0
				elseif r > 255 then
					r = 255
				end
				if g < 0 then
					g = 0
				elseif g > 255 then
					g = 255
				end
				if b < 0 then
					b = 0
				elseif b > 255 then
					b = 255
				end
				r = r * keep + tintR
				g = g * keep + tintG
				b = b * keep + tintB
				buffer.writeu32(
					out,
					offset,
					(r + 0.5) // 1 + (g + 0.5) // 1 * 0x100 + (b + 0.5) // 1 * 0x10000 + alpha * 0x1000000
				)
			end
		end
		row += 1
		if os.clock() >= deadline then
			break
		end
	end

	job.Row = row
	return row >= rowEnd
end

function Reconstruct.compositeRim(out: buffer, aux: buffer, pixelCount: number, fresnelIntensity: number)
	local fresnelScale = fresnelIntensity * 0.7 * INV_255
	for offset = 0, pixelCount * 4 - 4, 4 do
		if buffer.readu8(aux, offset + 2) ~= 0 then
			local wf = buffer.readu8(aux, offset) * fresnelScale
			local wg = buffer.readu8(aux, offset + 1) * INV_255
			local white = wf + wg - wf * wg
			if white > 0 then
				local r = buffer.readu8(out, offset)
				local g = buffer.readu8(out, offset + 1)
				local b = buffer.readu8(out, offset + 2)
				buffer.writeu8(out, offset, (r + (255 - r) * white + 0.5) // 1)
				buffer.writeu8(out, offset + 1, (g + (255 - g) * white + 0.5) // 1)
				buffer.writeu8(out, offset + 2, (b + (255 - b) * white + 0.5) // 1)
			end
		end
	end
end

return Reconstruct
end

__axiomGlassFactories['Liquid.Heatmap'] = function()


local Warp = __axiomGlassRequire("Liquid.Warp")
local Types = __axiomGlassRequire("Liquid.Types")

type ReconJob = Types.ReconJob

local warpLookup = Warp.warpLookup
local warpLookupX = Warp.warpLookupX
local WARP_LUT_MAX = Warp.WARP_LUT_MAX

local HEAT_STOPS = {
	{ 20, 20, 120 }, -- deep blue: ~1/8x uniform and below
	{ 0, 150, 255 },
	{ 0, 220, 120 }, -- green: around uniform
	{ 255, 220, 0 },
	{ 255, 40, 0 }, -- red: ~32x uniform and above
}
local HEAT_LOG_MIN = -3
local HEAT_LOG_MAX = 5

local Heatmap = {}

function Heatmap.renderDensityHeatmap(job: ReconJob)
	local out, aux = job.Out, job.Aux
	local outW, outH = job.OutW, job.OutH
	local stepX, stepY = job.StepX, job.StepY
	local warpX, warpY = job.WarpX, job.WarpY
	local gridHm1 = job.GridH - 1
	local lutScaleX = WARP_LUT_MAX / (stepX * outW)
	local lutScaleY = WARP_LUT_MAX / (stepY * outH)
	local baseX = job.GridW / (stepX * outW) -- uniform grid cells per window px
	local baseY = job.GridH / (stepY * outH)
	local logRange = HEAT_LOG_MAX - HEAT_LOG_MIN
	local stopCount = #HEAT_STOPS

	for y = 1, outH do
		local wy = (y - 0.5) * stepY
		local gy = warpLookup(warpY, 0, wy * lutScaleY)
		local slopeY = (
			warpLookup(warpY, 0, (wy + 0.5 * stepY) * lutScaleY)
			- warpLookup(warpY, 0, (wy - 0.5 * stepY) * lutScaleY)
		) / stepY
		local ry = math.max(slopeY / baseY, 1e-4)
		local rowOffset = (y - 1) * outW * 4
		for x = 1, outW do
			local offset = rowOffset + (x - 1) * 4
			local alpha = buffer.readu8(aux, offset + 2)
			if alpha == 0 then
				buffer.writeu32(out, offset, 0)
			else
				local wx = (x - 0.5) * stepX
				local slopeX = (
					warpLookupX(warpX, gy, gridHm1, (wx + 0.5 * stepX) * lutScaleX)
					- warpLookupX(warpX, gy, gridHm1, (wx - 0.5 * stepX) * lutScaleX)
				) / stepX
				local rx = math.max(slopeX / baseX, 1e-4)
				local t = math.clamp((math.log(rx * ry, 2) - HEAT_LOG_MIN) / logRange, 0, 1)
				local scaled = t * (stopCount - 1)
				local i0 = math.min(scaled // 1, stopCount - 2)
				local fraction = scaled - i0
				local c0 = HEAT_STOPS[i0 + 1]
				local c1 = HEAT_STOPS[i0 + 2]
				local r = c0[1] + (c1[1] - c0[1]) * fraction
				local g = c0[2] + (c1[2] - c0[2]) * fraction
				local b = c0[3] + (c1[3] - c0[3]) * fraction
				buffer.writeu32(
					out,
					offset,
					(r + 0.5) // 1 + (g + 0.5) // 1 * 0x100 + (b + 0.5) // 1 * 0x10000 + alpha * 0x1000000
				)
			end
		end
	end

	job.Row = outH
end

return Heatmap
end

__axiomGlassFactories['Liquid.DebugOverlay'] = function()


local Shape = __axiomGlassRequire("Liquid.Shape")
local Geometry = __axiomGlassRequire("Liquid.Geometry")
local Types = __axiomGlassRequire("Liquid.Types")

type ReconJob = Types.ReconJob
type LiquidParams = Types.LiquidParams

local sdfRoundedRect = Shape.sdfRoundedRect
local deriveShape = Shape.deriveShape
local MELT_SPAN_FLOOR = Geometry.MELT_SPAN_FLOOR

local band = bit32.band
local rshift = bit32.rshift

local CONTOUR_LEVELS = 9 -- family contours drawn between the rim and the center
local SWEEP_RATE = 0.15 -- animated sweep contours per second
local ARC_STEPS = 24 -- parametric steps along one corner arc

local DebugOverlay = {}

local function blendPixel(out: buffer, offset: number, r: number, g: number, b: number, a: number)
	local keep = 1 - a
	buffer.writeu8(out, offset, (buffer.readu8(out, offset) * keep + r * a + 0.5) // 1)
	buffer.writeu8(out, offset + 1, (buffer.readu8(out, offset + 1) * keep + g * a + 0.5) // 1)
	buffer.writeu8(out, offset + 2, (buffer.readu8(out, offset + 2) * keep + b * a + 0.5) // 1)
end

local function splat(
	out: buffer,
	outW: number,
	outH: number,
	x: number,
	y: number,
	radius: number,
	r: number,
	g: number,
	b: number,
	strength: number
)
	local invRadius = 1 / radius
	local x0 = math.max((x - radius) // 1, 0)
	local x1 = math.min((x + radius) // 1, outW - 1)
	local y0 = math.max((y - radius) // 1, 0)
	local y1 = math.min((y + radius) // 1, outH - 1)
	for py = y0, y1 do
		local dy = py + 0.5 - y
		for px = x0, x1 do
			local dx = px + 0.5 - x
			local w = 1 - math.sqrt(dx * dx + dy * dy) * invRadius
			if w > 0 then
				blendPixel(out, (py * outW + px) * 4, r, g, b, strength * w)
			end
		end
	end
end

local function strokePolyline(
	out: buffer,
	outW: number,
	outH: number,
	points: { number },
	radius: number,
	r: number,
	g: number,
	b: number,
	strength: number
)
	local ax, ay = points[1], points[2]
	splat(out, outW, outH, ax, ay, radius, r, g, b, strength)
	for i = 3, #points - 1, 2 do
		local bx, by = points[i], points[i + 1]
		local dx, dy = bx - ax, by - ay
		local length = math.sqrt(dx * dx + dy * dy)
		if length > 1e-6 then
			local steps = math.max(math.ceil(length / 0.75), 1)
			for k = 1, steps do
				local t = k / steps
				splat(out, outW, outH, ax + dx * t, ay + dy * t, radius, r, g, b, strength)
			end
		end
		ax, ay = bx, by
	end
end

local function strokeLine(
	out: buffer,
	outW: number,
	outH: number,
	points: { number },
	width: number,
	r: number,
	g: number,
	b: number,
	strength: number
)
	strokePolyline(out, outW, outH, points, width * 2, 0, 0, 0, strength * 0.4)
	strokePolyline(out, outW, outH, points, width, r, g, b, strength)
end

local function contourQuadrant(hx: number, hy: number, rho: number, m: number): { number }
	local points = { 0, hy }
	local cornerX, cornerY = hx - rho, hy - rho
	if rho > 1e-3 then
		local power = 2 / m
		for k = ARC_STEPS, 0, -1 do
			local t = k / ARC_STEPS * (math.pi / 2)
			table.insert(points, cornerX + rho * math.cos(t) ^ power)
			table.insert(points, cornerY + rho * math.sin(t) ^ power)
		end
	else
		table.insert(points, hx)
		table.insert(points, hy)
	end
	table.insert(points, hx)
	table.insert(points, 0)
	return points
end

local function drawFamilyContour(
	job: ReconJob,
	halfW: number,
	halfH: number,
	family: (d: number) -> (number, number),
	d: number,
	width: number,
	r: number,
	g: number,
	b: number,
	strength: number
)
	local hx, hy = halfW - d, halfH - d
	if hx <= 0 or hy <= 0 then
		return
	end
	local rho, m = family(d)
	local quadrant = contourQuadrant(hx, hy, rho, m)
	local out, outW, outH = job.Out, job.OutW, job.OutH
	local invStepX, invStepY = 1 / job.StepX, 1 / job.StepY
	for sy = -1, 1, 2 do
		for sx = -1, 1, 2 do
			local mirrored = table.create(#quadrant)
			for i = 1, #quadrant - 1, 2 do
				table.insert(mirrored, (halfW + sx * quadrant[i]) * invStepX)
				table.insert(mirrored, (halfH + sy * quadrant[i + 1]) * invStepY)
			end
			strokeLine(out, outW, outH, mirrored, width, r, g, b, strength)
		end
	end
end

function DebugOverlay.drawContourOverlay(job: ReconJob, params: LiquidParams, melt: boolean)
	local winW, winH = job.StepX * job.OutW, job.StepY * job.OutH
	local halfW, halfH, radius, _, _, n = deriveShape(params, winW, winH)
	local halfMin = math.min(halfW, halfH)
	local invMeltSpan = 1 / math.max(radius, MELT_SPAN_FLOOR * halfMin)

	local function family(d: number): (number, number)
		if melt then
			local v = d * invMeltSpan
			if v > 1 then
				v = 1
			end
			local beta = v * v * v * (v * (v * 6 - 15) + 10)
			return math.max(radius - d + beta * (halfMin - radius), 0), 2 + (n - 2) * (1 - beta)
		end
		return math.max(radius - d, 0), n
	end

	for level = 1, CONTOUR_LEVELS do
		local d = level / (CONTOUR_LEVELS + 1) * halfMin
		drawFamilyContour(job, halfW, halfH, family, d, 1.2, 255, 255, 255, 0.55)
	end
	if melt then
		local sweep = (os.clock() * SWEEP_RATE % 1) * CONTOUR_LEVELS / (CONTOUR_LEVELS + 1) * halfMin
		drawFamilyContour(job, halfW, halfH, family, sweep, 1.8, 255, 190, 70, 0.95)
	end
end

function DebugOverlay.drawNormalOverlay(job: ReconJob, params: LiquidParams, rawField: boolean)
	local out, aux = job.Out, job.Aux
	local outW, outH = job.OutW, job.OutH
	local stepX, stepY = job.StepX, job.StepY
	local winW, winH = stepX * outW, stepY * outH
	local halfW, halfH, radius, insetX, insetY, n, invN = deriveShape(params, winW, winH)
	local halfMin = math.min(halfW, halfH)
	local invMeltSpan = 1 / math.max(radius, MELT_SPAN_FLOOR * halfMin)
	local thickness = params.thickness

	local function contourAt(apx: number, apy: number, d: number): (number, number, number, number)
		local v = d * invMeltSpan
		if v > 1 then
			v = 1
		end
		local beta = v * v * v * (v * (v * 6 - 15) + 10)
		local rho = radius - d + beta * (halfMin - radius)
		if rho < 0 then
			rho = 0
		end
		local m = 2 + (n - 2) * (1 - beta)
		local qx = apx - (halfW - d - rho)
		local qy = apy - (halfH - d - rho)
		local g
		if qx > 0 and qy > 0 then
			g = (qx ^ m + qy ^ m) ^ (1 / m) - rho
		else
			g = (if qx > qy then qx else qy) - rho
		end
		return g, qx, qy, m
	end

	local spacing = math.max(math.min(outW, outH) / 16, 7) -- output px between arrows
	local shaft = spacing * 0.36 -- half-length of an arrow
	local head = spacing * 0.3
	local rows = (outH / spacing) // 1
	local columns = (outW / spacing) // 1
	for row = 0, rows - 1 do
		local y = (row + 0.5) * spacing + (outH - rows * spacing) / 2
		local wy = y * stepY
		local py = wy - halfH
		local absPy = math.abs(py)
		local sy = if py >= 0 then 1 else -1
		for column = 0, columns - 1 do
			local x = (column + 0.5) * spacing + (outW - columns * spacing) / 2
			if buffer.readu8(aux, ((y // 1) * outW + x // 1) * 4 + 2) == 0 then
				continue
			end
			local wx = x * stepX
			local px = wx - halfW
			local absPx = math.abs(px)
			local sx = if px >= 0 then 1 else -1

			local depth: number, qx: number, qy: number, m: number
			if rawField then
				qx, qy, m = absPx - insetX, absPy - insetY, n
				depth = math.max(-sdfRoundedRect(qx, qy, radius, n, invN), 0)
			else
				depth = 0
				local g
				g, qx, qy, m = contourAt(absPx, absPy, 0)
				if g < 0 then
					local lo, hi = 0, halfMin
					for _ = 1, 20 do
						local mid = (lo + hi) * 0.5
						if contourAt(absPx, absPy, mid) < 0 then
							lo = mid
						else
							hi = mid
						end
					end
					depth = (lo + hi) * 0.5
					g, qx, qy, m = contourAt(absPx, absPy, depth)
				end
			end
			if depth >= thickness then
				continue
			end

			local dirX, dirY
			if qx > 0 and qy > 0 then
				dirX = sx * qx ^ (m - 1)
				dirY = sy * qy ^ (m - 1)
			elseif qy >= qx then
				dirX = 0
				dirY = sy
			else
				dirX = sx
				dirY = 0
			end
			local length = math.sqrt(dirX * dirX + dirY * dirY)
			if length < 1e-9 then
				continue
			end
			dirX, dirY = dirX / length, dirY / length

			local tipX, tipY = x + dirX * shaft, y + dirY * shaft
			local headX = -dirX * 0.82 -- cos(±145 degrees) folded into the
			local headY = -dirY * 0.82 -- rotation applied to the direction
			local sideX, sideY = -dirY * 0.57, dirX * 0.57
			strokeLine(out, outW, outH, {
				x - dirX * shaft,
				y - dirY * shaft,
				tipX,
				tipY,
				tipX + (headX + sideX) * head,
				tipY + (headY + sideY) * head,
				tipX,
				tipY,
				tipX + (headX - sideX) * head,
				tipY + (headY - sideY) * head,
			}, 1, 255, 255, 255, 0.85)
		end
	end
end

function DebugOverlay.drawCellCenterOverlay(job: ReconJob, gridPosX: buffer, gridPosY: buffer, uniform: boolean)
	local out = job.Out
	local outW, outH = job.OutW, job.OutH
	local gridW, gridH = job.GridW, job.GridH
	local invStepX, invStepY = 1 / job.StepX, 1 / job.StepY
	local cellW = job.StepX * outW / gridW -- uniform spacing in window px
	local cellH = job.StepY * outH / gridH
	for j = 0, gridH - 1 do
		local y = (if uniform then (j + 0.5) * cellH else buffer.readf32(gridPosY, j * 4)) * invStepY
		local rowBase = j * gridW
		for i = 0, gridW - 1 do
			local x = (if uniform then (i + 0.5) * cellW else buffer.readf32(gridPosX, (rowBase + i) * 4)) * invStepX
			splat(out, outW, outH, x, y, 2.2, 0, 0, 0, 0.5)
			splat(out, outW, outH, x, y, 1.2, 255, 255, 255, 0.95)
		end
	end
end

function DebugOverlay.renderGridView(job: ReconJob, frontIndex: number, highlightFront: boolean)
	local out, grid = job.Out, job.Grid
	local outW, outH = job.OutW, job.OutH
	local gridW, gridH = job.GridW, job.GridH
	local cellCount = gridW * gridH
	local invCellCount = 1 / cellCount
	local newest = frontIndex - 1
	local boostScale = if highlightFront then 0.65 else 0
	for y = 0, outH - 1 do
		local gridRow = y * gridH // outH * gridW
		local rowOffset = y * outW * 4
		for x = 0, outW - 1 do
			local cell = gridRow + x * gridW // outW
			local color = buffer.readu32(grid, cell * 4)
			local age = (newest - cell) % cellCount * invCellCount
			local fade = 1 - age
			local fade4 = fade * fade * fade * fade
			local boost = fade4 * fade4 * fade4 * boostScale -- a tail about a tenth of the walk long
			local r = band(color, 0xFF)
			local g = band(rshift(color, 8), 0xFF)
			local b = band(rshift(color, 16), 0xFF)
			buffer.writeu32(
				out,
				rowOffset + x * 4,
				(r + (255 - r) * boost + 0.5) // 1
					+ ((g + (255 - g) * boost + 0.5) // 1) * 0x100
					+ ((b + (255 - b) * boost + 0.5) // 1) * 0x10000
					+ 0xFF000000
			)
		end
	end
	job.Row = outH
end

return DebugOverlay
end

__axiomGlassFactories['Liquid'] = function()


local Types = __axiomGlassRequire("Liquid.Types")
local Refraction = __axiomGlassRequire("Liquid.Refraction")
local Warp = __axiomGlassRequire("Liquid.Warp")
local Geometry = __axiomGlassRequire("Liquid.Geometry")
local Reconstruct = __axiomGlassRequire("Liquid.Reconstruct")
local Heatmap = __axiomGlassRequire("Liquid.Heatmap")
local DebugOverlay = __axiomGlassRequire("Liquid.DebugOverlay")

export type LiquidParams = Types.LiquidParams
export type GeometryEntry = Types.GeometryEntry
export type ReconJob = Types.ReconJob

return {
	dispersionScales = Refraction.dispersionScales,

	warpKey = Warp.warpKey,
	buildWarp = Warp.buildWarp,

	geometryKey = Geometry.geometryKey,
	acquireGeometry = Geometry.acquireGeometry,
	releaseGeometry = Geometry.releaseGeometry,
	stepGeometry = Geometry.stepGeometry,

	clearColor = Reconstruct.clearColor,
	resampleGridBilinear = Reconstruct.resampleGridBilinear,
	reconstructRows = Reconstruct.reconstructRows,
	compositeRim = Reconstruct.compositeRim,

	renderDensityHeatmap = Heatmap.renderDensityHeatmap,

	drawContourOverlay = DebugOverlay.drawContourOverlay,
	drawNormalOverlay = DebugOverlay.drawNormalOverlay,
	drawCellCenterOverlay = DebugOverlay.drawCellCenterOverlay,
	renderGridView = DebugOverlay.renderGridView,
}
end

__axiomGlassFactories['GlassObject'] = function()


local Liquid = __axiomGlassRequire("Liquid")

export type ParallelWorkerState = {
	Actor: Actor,
	Slot: number, -- results key this worker's chunk strings land under
	RowNext: number, -- next absolute row expected back from this worker
	RowEnd: number, -- exclusive end of this worker's band
	AwaitingRows: number, -- rows in the chunk currently in flight; 0 once the band is done
}

export type ParallelPending = {
	PassId: number,
	Job: Liquid.ReconJob, -- Job.Out gathers the bands; the finish stages then read the job on the main thread
	Results: SharedTable, -- workers write chunk strings into per-band slots here
	Workers: { ParallelWorkerState },
	FramesWaited: number, -- frames since any chunk arrived, for the timeout
}

export type GlassObject = {
	Window: GuiObject,
	Pane: ImageLabel, -- library-owned child; not clipped by window UICorner so full mask shows
	EditableImage: EditableImage?,
	WarnedImageCreateFailure: boolean,
	Initialized: boolean, -- window has been parented and configured
	Parented: boolean, -- mirrors Window.Parent to skip per-pixel Instance reads
	Pixels: buffer, -- u8 RGBA grid accumulator, row-major
	Scratch: buffer, -- grid snapshot for reconstruction
	PixelCount: number,
	PixelIndex: number, -- 0-based byte offset into Pixels
	Resolution: Vector2, -- source-grid resolution
	ResolutionX: number, -- Resolution.X as plain number for hot path
	GridPosX: buffer?, -- f32 per grid cell, x center in window coordinates (each row has its own warp)
	GridPosY: buffer?, -- f32 per grid row, y center
	WarpLutX: buffer?, -- per-row window-x to grid-column lookup tables
	WarpLutY: buffer?, -- window-y to grid-row lookup table
	WarpKey: string?, -- input signature of the built warp; skips rebuilds when unchanged
	WindowPositionX: number,
	WindowPositionY: number,
	WindowColor: { number },
	BlurRadius: number, -- resolved px, converted to output-px sigma by frost
	Paused: boolean,
	LiquidParams: Liquid.LiquidParams?,
	Geometry: Liquid.GeometryEntry?,
	OutputResolution: Vector2,
	OutPixels: buffer?, -- u8 RGBA reconstruction target
	OutBlend: buffer?, -- base-level blur copy the frost's level mix reads from
	ReconJob: Liquid.ReconJob?, -- non-nil while a synchronous reconstruction pass is in flight
	ParallelJob: ParallelPending?, -- non-nil while the worker pool runs this window's pass
	ParallelId: number, -- the window's identity in worker-side caches; 0 until the first scatter
	MapsGeneration: number, -- bumped when the warp or geometry maps rebuild; workers cache the maps keyed by it
	FinishToken: {}?, -- identity token for the in-flight finish thread; clearing it cancels a stale finish before it uploads
	ForceRecon: boolean,
	GridWritesSinceRecon: number,
	FramesSinceRecon: number,
	SamplesLastFrame: number, -- backdrop samples this window got last frame, for the debug stats
	PendingLayout: boolean, -- a layout change is being debounced
	LastLayoutRequestClock: number,
	FirstLayoutRequestClock: number, -- when the pending debounce began
	LadderCap: number, -- resolution cap imposed by the step-down ladder
	UICornerConnection: RBXScriptConnection?,
	Connections: { RBXScriptConnection }, -- disconnected when the window is removed
}

local GlassObject = {}

GlassObject.list = {} :: { GlassObject }
GlassObject.byWindow = setmetatable({} :: { [GuiObject]: GlassObject }, { __mode = "k" })

function GlassObject.addToUpdateList(glassObject: GlassObject)
	if not table.find(GlassObject.list, glassObject) then
		table.insert(GlassObject.list, glassObject)
	end
end

function GlassObject.removeFromUpdateList(glassObject: GlassObject)
	local index = table.find(GlassObject.list, glassObject)
	if index then
		table.remove(GlassObject.list, index)
	end
end

function GlassObject.isOpaque(glassObject: GlassObject): boolean
	return glassObject.WindowColor[4] >= 1
end

function GlassObject.create(Window: GuiObject): GlassObject
	local windowColor = Window.BackgroundColor3
	local initialPixels = buffer.create(4)
	buffer.writeu32(initialPixels, 0, Liquid.clearColor(windowColor.R, windowColor.G, windowColor.B) + 0xFF000000)

	local pane = Instance.new("ImageLabel")
	pane.Name = "GlassPane"
	pane.Size = UDim2.fromScale(1, 1)
	pane.BackgroundTransparency = 1
	pane.BorderSizePixel = 0
	pane.ZIndex = -999999
	pane.Parent = Window

	local glassObject = {
		Window = Window,
		Pane = pane,
		EditableImage = nil :: EditableImage?,
		WarnedImageCreateFailure = false,
		Initialized = false,
		Parented = Window.Parent ~= nil,
		Pixels = initialPixels,
		Scratch = buffer.create(4),
		PixelCount = 1,
		PixelIndex = 0,
		Resolution = Vector2.one,
		ResolutionX = 1,
		GridPosX = nil :: buffer?,
		GridPosY = nil :: buffer?,
		WarpLutX = nil :: buffer?,
		WarpLutY = nil :: buffer?,
		WarpKey = nil :: string?,
		WindowPositionX = 0,
		WindowPositionY = 0,
		WindowColor = {
			windowColor.R,
			windowColor.G,
			windowColor.B,
			1 - Window.BackgroundTransparency,
		},
		BlurRadius = 1, -- resolved px; Attributes.updateWindowBlur refreshes it once the window has a size
		Paused = false,
		LiquidParams = nil :: Liquid.LiquidParams?,
		Geometry = nil :: Liquid.GeometryEntry?,
		OutputResolution = Vector2.zero,
		OutPixels = nil :: buffer?,
		OutBlend = nil :: buffer?,
		ReconJob = nil :: Liquid.ReconJob?,
		ParallelJob = nil :: ParallelPending?,
		ParallelId = 0,
		MapsGeneration = 0,
		FinishToken = nil :: {}?,
		ForceRecon = false,
		GridWritesSinceRecon = 0,
		FramesSinceRecon = 0,
		SamplesLastFrame = 0,
		PendingLayout = false,
		LastLayoutRequestClock = 0,
		FirstLayoutRequestClock = 0,
		LadderCap = math.huge,
		UICornerConnection = nil :: RBXScriptConnection?,
		Connections = {} :: { RBXScriptConnection },
	}
	GlassObject.byWindow[Window] = glassObject
	return glassObject
end

return GlassObject
end

__axiomGlassFactories['Attributes'] = function()


local Liquid = __axiomGlassRequire("Liquid")
local Config = __axiomGlassRequire("Config")
local GlassObject = __axiomGlassRequire("GlassObject")

type GlassObject = GlassObject.GlassObject

local function getNumberAttribute(Window: Instance, name: string): number?
	local value = Window:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

local function clampedAttribute(Window: Instance, name: string, default: number, min: number, max: number): number
	return math.clamp(getNumberAttribute(Window, name) or default, min, max)
end

local function getUDimAttribute(Window: Instance, name: string): UDim?
	local value = Window:GetAttribute(name)
	return if typeof(value) == "UDim" then value else nil
end

local function resolveUDim(value: UDim, minAxis: number): number
	return value.Offset + value.Scale * minAxis
end

local Attributes = {}

Attributes.getNumberAttribute = getNumberAttribute

function Attributes.parseLiquidParams(glassObject: GlassObject, winW: number, winH: number): Liquid.LiquidParams
	local Window = glassObject.Window
	local minAxis = math.min(winW, winH)
	local halfMinAxis = minAxis / 2

	local function lengthAttribute(name: string, default: UDim, min: number, max: number): number
		return math.clamp(resolveUDim(getUDimAttribute(Window, name) or default, minAxis), min, max)
	end

	local function percentAttribute(name: string, default: number, max: number): number
		return clampedAttribute(Window, name, default, 0, max) / 100
	end

	local cornerRadius: number?
	local cornerAttribute = getUDimAttribute(Window, "CornerRadius")
	if cornerAttribute then
		cornerRadius = resolveUDim(cornerAttribute, minAxis)
	else
		local uiCorner = Window:FindFirstChildWhichIsA("UICorner")
		if uiCorner then
			cornerRadius = resolveUDim(uiCorner.CornerRadius, minAxis)
		end
	end
	local resolvedCornerRadius = cornerRadius or resolveUDim(Config.DEFAULT_CORNER_RADIUS, minAxis)

	return {
		cornerRadius = math.clamp(resolvedCornerRadius, 0, halfMinAxis),
		superEllipseFactor = clampedAttribute(Window, "SuperEllipseFactor", Config.DEFAULT_SUPER_ELLIPSE_FACTOR, 2, 7),
		thickness = lengthAttribute("Thickness", Config.DEFAULT_THICKNESS, 1, minAxis),
		refractionFactor = clampedAttribute(Window, "RefractionFactor", Config.DEFAULT_REFRACTION_FACTOR, 1, 4),
		chromaticAberration = clampedAttribute(
			Window,
			"ChromaticAberration",
			Config.DEFAULT_CHROMATIC_ABERRATION,
			0,
			1
		),
		fresnelSize = lengthAttribute("FresnelSize", Config.DEFAULT_FRESNEL_SIZE, 0, minAxis),
		fresnelHardness = percentAttribute("FresnelHardness", Config.DEFAULT_FRESNEL_HARDNESS, 100),
		fresnelIntensity = percentAttribute("FresnelIntensity", Config.DEFAULT_FRESNEL_INTENSITY, 100),
		glareSize = lengthAttribute("GlareSize", Config.DEFAULT_GLARE_SIZE, 0, minAxis),
		glareHardness = percentAttribute("GlareHardness", Config.DEFAULT_GLARE_HARDNESS, 100),
		glareIntensity = percentAttribute("GlareIntensity", Config.DEFAULT_GLARE_INTENSITY, 120),
		glareConvergence = percentAttribute("GlareConvergence", Config.DEFAULT_GLARE_CONVERGENCE, 100),
		glareOppositeSide = percentAttribute("GlareOppositeSide", Config.DEFAULT_GLARE_OPPOSITE_SIDE, 100),
		glareAngle = math.rad(
			math.clamp(getNumberAttribute(Window, "GlareAngle") or Config.DEFAULT_GLARE_ANGLE, -180, 180)
		),
		maxOutputResolution = math.round(
			clampedAttribute(Window, "MaxOutputResolution", Config.DEFAULT_MAX_OUTPUT_RESOLUTION, 16, 1024)
		),
	}
end

function Attributes.updateWindowBlur(glassObject: GlassObject)
	local Window = glassObject.Window
	local radius = getUDimAttribute(Window, Config.BLUR_RADIUS_ATTRIBUTE_NAME) or Config.DEFAULT_BLUR_RADIUS
	local absoluteSize = Window.AbsoluteSize
	local minAxis = math.min(absoluteSize.X, absoluteSize.Y)
	glassObject.BlurRadius = math.clamp(resolveUDim(radius, minAxis), 1, math.max(minAxis, 1))
	glassObject.ForceRecon = true
end

return Attributes
end

__axiomGlassFactories['Layout'] = function()


local Liquid = __axiomGlassRequire("Liquid")
local Config = __axiomGlassRequire("Config")
local Attributes = __axiomGlassRequire("Attributes")
local GlassObject = __axiomGlassRequire("GlassObject")

type GlassObject = GlassObject.GlassObject

local Layout = {}

function Layout.update(glassObject: GlassObject)
	local Window = glassObject.Window
	if not Window then
		return
	end
	glassObject.PendingLayout = false

	local absoluteSize = Window.AbsoluteSize
	local winW, winH = math.round(absoluteSize.X), math.round(absoluteSize.Y)
	if winW <= 0 or winH <= 0 then
		return
	end

	Attributes.updateWindowBlur(glassObject)

	local params = Attributes.parseLiquidParams(glassObject, winW, winH)
	glassObject.LiquidParams = params

	local outputCap = math.min(params.maxOutputResolution, glassObject.LadderCap)
	local maxAxis = math.max(winW, winH)
	local outputScale = maxAxis / math.min(outputCap, maxAxis)
	local outW = math.max(math.floor(winW / outputScale + 0.5), 1)
	local outH = math.max(math.floor(winH / outputScale + 0.5), 1)
	local outputResolution = Vector2.new(outW, outH)

	local samplerSize = Config.SAMPLING_CELL_SIZE
	local gridW = math.max(winW // samplerSize, 1)
	local gridH = math.max(winH // samplerSize, 1)
	local gridResolution = Vector2.new(gridW, gridH)

	local uniformWarp = Config.DEBUG_UNIFORM_WARP
	local warpKey = Liquid.warpKey(gridW, gridH, winW, winH, params, Config.EDGE_DENSITY_BOOST)
		.. (if uniformWarp then ":uniform" else "")
	if warpKey ~= glassObject.WarpKey then
		debug.profilebegin("GlassWarpBuild")
		local gridPosX, warpLutX, gridPosY, warpLutY =
			Liquid.buildWarp(gridW, gridH, winW, winH, params, Config.EDGE_DENSITY_BOOST, uniformWarp)
		glassObject.GridPosX, glassObject.WarpLutX = gridPosX, warpLutX
		glassObject.GridPosY, glassObject.WarpLutY = gridPosY, warpLutY
		glassObject.WarpKey = warpKey
		glassObject.MapsGeneration += 1
		debug.profileend()
	end

	if gridResolution ~= glassObject.Resolution then
		local pixelCount = gridW * gridH
		local bufferLength = pixelCount * 4
		local newPixels = buffer.create(bufferLength)
		Liquid.resampleGridBilinear(
			glassObject.Pixels,
			glassObject.Resolution.X,
			glassObject.Resolution.Y,
			newPixels,
			gridW,
			gridH
		)
		glassObject.Pixels = newPixels
		glassObject.Scratch = buffer.create(bufferLength)
		glassObject.PixelCount = pixelCount
		glassObject.Resolution = gridResolution
		glassObject.ResolutionX = gridW
		if glassObject.PixelIndex >= bufferLength then
			glassObject.PixelIndex = 0
		end
	end

	if outputResolution ~= glassObject.OutputResolution then
		glassObject.OutPixels = buffer.create(outW * outH * 4)
		glassObject.OutputResolution = outputResolution
	end

	local rawField = Config.DEBUG_RAW_DISTANCE_FIELD
	local key = Liquid.geometryKey(winW, winH, outW, outH, params, rawField)
	local geometry = glassObject.Geometry
	if not geometry or geometry.Key ~= key then
		if geometry then
			Liquid.releaseGeometry(geometry)
		end
		glassObject.Geometry = Liquid.acquireGeometry(winW, winH, outW, outH, params, key, rawField)
		glassObject.MapsGeneration += 1
	end

	glassObject.ReconJob = nil
	glassObject.ParallelJob = nil
	glassObject.FinishToken = nil
	glassObject.ForceRecon = true
end

function Layout.request(glassObject: GlassObject)
	if glassObject.Geometry then
		if not glassObject.PendingLayout then
			glassObject.PendingLayout = true
			glassObject.FirstLayoutRequestClock = os.clock()
		end
		glassObject.LastLayoutRequestClock = os.clock()
	else
		Layout.update(glassObject)
	end
end

function Layout.stepDownResolution(glassObject: GlassObject)
	local refused = math.max(glassObject.OutputResolution.X, glassObject.OutputResolution.Y)
	if refused > Config.MIN_OUTPUT_RESOLUTION then
		glassObject.LadderCap = math.max(math.floor(refused / 2), Config.MIN_OUTPUT_RESOLUTION)
		Layout.update(glassObject)
	end
end

return Layout
end

__axiomGlassFactories['Sampler'] = function()


local Dependencies = __axiomGlassRequire("Dependencies")
local Config = __axiomGlassRequire("Config")
local GlassObject = __axiomGlassRequire("GlassObject")

type GlassObject = GlassObject.GlassObject

local PixelColorApproximation = Dependencies.PixelColorApproximation

local Sampler = {}

function Sampler.processNextPixel(glassObject: GlassObject, skipTween: boolean?): boolean
	if not glassObject.Parented then
		return false
	end

	local Pixels, PixelIndex = glassObject.Pixels, glassObject.PixelIndex
	local bufferLength = glassObject.PixelCount * 4

	local gridPosX, gridPosY = glassObject.GridPosX, glassObject.GridPosY
	if not gridPosX or not gridPosY then
		return false
	end

	local resolutionX = glassObject.ResolutionX
	local indexFloor4 = PixelIndex // 4
	local xIndex = indexFloor4 % resolutionX
	local rowOffset = (indexFloor4 // resolutionX) * 4
	local posX = buffer.readf32(gridPosX, PixelIndex)
	local posY = buffer.readf32(gridPosY, rowOffset)

	local spacingX = math.max(
		if xIndex > 0 then posX - buffer.readf32(gridPosX, PixelIndex - 4) else 0,
		if xIndex < resolutionX - 1 then buffer.readf32(gridPosX, PixelIndex + 4) - posX else 0
	)
	local lastRowOffset = (glassObject.PixelCount // resolutionX - 1) * 4
	local spacingY = math.max(
		if rowOffset > 0 then posY - buffer.readf32(gridPosY, rowOffset - 4) else 0,
		if rowOffset < lastRowOffset then buffer.readf32(gridPosY, rowOffset + 4) - posY else 0
	)

	local sampleR, sampleG, sampleB = PixelColorApproximation:GetColorXY(
		posX + glassObject.WindowPositionX,
		posY + glassObject.WindowPositionY,
		glassObject.Pane,
		math.max(spacingX, spacingY)
	)

	if skipTween then
		buffer.writeu8(Pixels, PixelIndex, math.clamp(math.round(sampleR * 255), 0, 255))
		buffer.writeu8(Pixels, PixelIndex + 1, math.clamp(math.round(sampleG * 255), 0, 255))
		buffer.writeu8(Pixels, PixelIndex + 2, math.clamp(math.round(sampleB * 255), 0, 255))
		glassObject.GridWritesSinceRecon += 1
	else
		local smoothing = Config.TEMPORAL_SMOOTHING
		local prevR = buffer.readu8(Pixels, PixelIndex)
		local prevG = buffer.readu8(Pixels, PixelIndex + 1)
		local prevB = buffer.readu8(Pixels, PixelIndex + 2)
		local newR = math.clamp(math.round(prevR + (sampleR * 255 - prevR) * smoothing), 0, 255)
		local newG = math.clamp(math.round(prevG + (sampleG * 255 - prevG) * smoothing), 0, 255)
		local newB = math.clamp(math.round(prevB + (sampleB * 255 - prevB) * smoothing), 0, 255)
		if newR ~= prevR or newG ~= prevG or newB ~= prevB then
			buffer.writeu8(Pixels, PixelIndex, newR)
			buffer.writeu8(Pixels, PixelIndex + 1, newG)
			buffer.writeu8(Pixels, PixelIndex + 2, newB)
			glassObject.GridWritesSinceRecon += 1
		end
	end

	PixelIndex += 4
	if PixelIndex >= bufferLength then
		PixelIndex = 0
	end

	glassObject.PixelIndex = PixelIndex
	return true
end

return Sampler
end

__axiomGlassFactories['Frost'] = function()


local Liquid = __axiomGlassRequire("Liquid")
local Config = __axiomGlassRequire("Config")

export type BlurFunction = ({
	pixelBuffer: buffer,
	width: number,
	height: number,
	blurRadius: number,
}) -> ()

local function levelVariance(level: number): number
	return (level + 1) * (3 * level + 4) / 3
end

local function exactLevel(variance: number): number
	return (math.sqrt(1 + 36 * variance) - 7) / 6
end

local function levelBelow(variance: number): number
	return math.floor(exactLevel(variance))
end

local function levelAbove(variance: number): number
	return math.max(math.ceil(exactLevel(variance)), 0)
end

local function levelSigma(level: number): number
	return math.sqrt((2 * level + 2) ^ 2 - 1) / 2
end

local function ensureBuffer(existing: buffer?, length: number): buffer
	return if existing and buffer.len(existing) == length then existing else buffer.create(length)
end

local Frost = {}

function Frost.apply(job: Liquid.ReconJob, blur: BlurFunction, blendScratch: buffer?): buffer?
	local outPixels = job.Out
	local outW, outH = job.OutW, job.OutH
	local sigma = job.BlurSigma
	if sigma < Config.MIN_BLUR_SIGMA then
		return blendScratch
	end

	local length = buffer.len(outPixels)

	local premultiplied = not Config.DEBUG_FROST_NO_PREMULTIPLY
	if premultiplied then
		debug.profilebegin("GlassFrostPremul")
		for i = 0, length - 4, 4 do
			local alpha = buffer.readu8(outPixels, i + 3)
			if alpha == 0 then
				buffer.writeu32(outPixels, i, 0)
			elseif alpha < 255 then
				local scale = alpha / 255
				buffer.writeu8(outPixels, i, (buffer.readu8(outPixels, i) * scale + 0.5) // 1)
				buffer.writeu8(outPixels, i + 1, (buffer.readu8(outPixels, i + 1) * scale + 0.5) // 1)
				buffer.writeu8(outPixels, i + 2, (buffer.readu8(outPixels, i + 2) * scale + 0.5) // 1)
			end
		end
		debug.profileend()
	end

	if Config.DEBUG_FROST_NEAREST_LEVEL then
		blur({
			pixelBuffer = outPixels,
			width = outW,
			height = outH,
			blurRadius = sigma,
		})
	else
		local variance = sigma * sigma
		local baseLevel = levelBelow(variance)
		local residual = variance
		if baseLevel >= 0 then
			residual -= levelVariance(baseLevel)
			blur({
				pixelBuffer = outPixels,
				width = outW,
				height = outH,
				blurRadius = levelSigma(baseLevel),
			})
		end
		if residual > 1e-3 then
			local topLevel = levelAbove(residual)
			local blendWeight = math.min(residual / levelVariance(topLevel), 1)
			local base = ensureBuffer(blendScratch, length)
			blendScratch = base
			buffer.copy(base, 0, outPixels)
			blur({
				pixelBuffer = outPixels,
				width = outW,
				height = outH,
				blurRadius = levelSigma(topLevel),
			})
			debug.profilebegin("GlassFrostMix")
			for i = 0, length - 1 do
				local baseByte = buffer.readu8(base, i)
				buffer.writeu8(
					outPixels,
					i,
					(baseByte + (buffer.readu8(outPixels, i) - baseByte) * blendWeight + 0.5) // 1
				)
			end
			debug.profileend()
		end
	end

	local aux = job.Aux
	local clearColor = Liquid.clearColor(job.TintR, job.TintG, job.TintB)
	debug.profilebegin("GlassFrostNormalize")
	for i = 0, length - 4, 4 do
		local maskAlpha = buffer.readu8(aux, i + 2)
		if maskAlpha == 0 then
			buffer.writeu32(outPixels, i, clearColor)
		elseif premultiplied then
			local coverage = buffer.readu8(outPixels, i + 3)
			local scale = if coverage > 0 then 255 / coverage else 0
			for channel = i, i + 2 do
				buffer.writeu8(
					outPixels,
					channel,
					math.min((buffer.readu8(outPixels, channel) * scale + 0.5) // 1, 255)
				)
			end
			buffer.writeu8(outPixels, i + 3, maskAlpha)
		else
			buffer.writeu8(outPixels, i + 3, maskAlpha)
		end
	end
	debug.profileend()

	return blendScratch
end

return Frost
end

__axiomGlassFactories['Composite'] = function()


local Liquid = __axiomGlassRequire("Liquid")
local Frost = __axiomGlassRequire("Frost")

local Composite = {}

function Composite.run(job: Liquid.ReconJob, blur: Frost.BlurFunction, blendScratch: buffer?): buffer?
	if job.TintAlpha < 1 then
		blendScratch = Frost.apply(job, blur, blendScratch)
	end
	if job.RimEnabled then
		debug.profilebegin("GlassRim")
		Liquid.compositeRim(job.Out, job.Aux, job.OutW * job.OutH, job.FresnelIntensity)
		debug.profileend()
	end
	return blendScratch
end

return Composite
end

__axiomGlassFactories['Parallel'] = function()
local Parallel = {}
function Parallel.shouldUse()
    return false
end
function Parallel.scatter()
    return nil
end
function Parallel.poll()
    return "failed"
end
function Parallel.forget()
end
return Parallel
end

__axiomGlassFactories['Recon'] = function()


local AssetService = game:GetService("AssetService")

local Liquid = __axiomGlassRequire("Liquid")
local Config = __axiomGlassRequire("Config")
local Composite = __axiomGlassRequire("Composite")
local Dependencies = __axiomGlassRequire("Dependencies")
local Layout = __axiomGlassRequire("Layout")
local Parallel = __axiomGlassRequire("Parallel")
local GlassObject = __axiomGlassRequire("GlassObject")

type GlassObject = GlassObject.GlassObject

local EditableImageBlur = Dependencies.EditableImageBlur

local function ensureEditableImage(glassObject: GlassObject, resolution: Vector2): EditableImage?
	local existing = glassObject.EditableImage
	if existing and existing.Size == resolution then
		return existing
	end

	local function tryCreate()
		return pcall(AssetService.CreateEditableImage, AssetService, {
			Size = resolution,
		})
	end
	local success, editableImage = tryCreate()
	if (not success or not editableImage) and existing then
		existing:Destroy()
		glassObject.EditableImage = nil
		existing = nil
		success, editableImage = tryCreate()
	end
	if not success or not editableImage then
		if not glassObject.WarnedImageCreateFailure then
			glassObject.WarnedImageCreateFailure = true
			warn(
				"GlassmorphicUI could not create an EditableImage:",
				if success then "budget exhausted" else editableImage
			)
		end
		return nil
	end
	glassObject.WarnedImageCreateFailure = false

	if existing then
		existing:Destroy()
	end
	glassObject.EditableImage = editableImage
	glassObject.Pane.ImageContent = Content.fromObject(editableImage)

	return editableImage
end

local function makeJob(glassObject: GlassObject, grid: buffer): Liquid.ReconJob?
	local geometry = glassObject.Geometry
	local params = glassObject.LiquidParams
	local outPixels = glassObject.OutPixels
	local warpLutX, warpLutY = glassObject.WarpLutX, glassObject.WarpLutY
	if not geometry or not geometry.Ready or not params or not outPixels or not warpLutX or not warpLutY then
		return nil
	end

	local resolution = glassObject.Resolution
	local WindowColor = glassObject.WindowColor
	local outW, outH = glassObject.OutputResolution.X, glassObject.OutputResolution.Y
	local redScale, blueScale = Liquid.dispersionScales(params.chromaticAberration)
	return {
		Out = outPixels,
		Disp = geometry.DispMap,
		Aux = geometry.AuxMap,
		Grid = grid,
		GridW = resolution.X,
		GridH = resolution.Y,
		OutW = outW,
		OutH = outH,
		StepX = geometry.StepX,
		StepY = geometry.StepY,
		WarpX = warpLutX,
		WarpY = warpLutY,
		TintR = WindowColor[1],
		TintG = WindowColor[2],
		TintB = WindowColor[3],
		TintAlpha = WindowColor[4],
		RedScale = redScale,
		BlueScale = blueScale,
		BlurSigma = math.min((glassObject.BlurRadius / 3) / geometry.StepX, math.max(outW, outH) / 2),
		FresnelIntensity = params.fresnelIntensity,
		RimEnabled = (params.fresnelSize > 0 and params.fresnelIntensity > 0)
			or (params.glareSize > 0 and params.glareIntensity > 0),
		BilinearFetch = Config.DEBUG_BILINEAR_FETCH,
		Row = 0,
		RowEnd = outH,
	}
end

local function startRecon(glassObject: GlassObject): boolean
	local job = makeJob(glassObject, glassObject.Scratch)
	if not job then
		return false
	end
	if not GlassObject.isOpaque(glassObject) then
		debug.profilebegin("GlassSnapshot")
		buffer.copy(glassObject.Scratch, 0, glassObject.Pixels)
		debug.profileend()
	end
	glassObject.ReconJob = job
	glassObject.ForceRecon = false
	glassObject.GridWritesSinceRecon = 0
	glassObject.FramesSinceRecon = 0

	if Config.DEBUG_SAMPLING_HEATMAP then
		Liquid.renderDensityHeatmap(job)
	elseif Config.DEBUG_OVERLAY == "grid-view" or Config.DEBUG_OVERLAY == "grid-view-flat" then
		Liquid.renderGridView(job, glassObject.PixelIndex // 4, Config.DEBUG_OVERLAY == "grid-view")
	end
	if Config.DEBUG_OVERLAY == "grid-view" or Config.DEBUG_OVERLAY == "melt-contours" then
		glassObject.ForceRecon = true
	end
	return true
end

local function upload(glassObject: GlassObject, outPixels: buffer)
	debug.profilebegin("GlassUpload")
	local editableImage = ensureEditableImage(glassObject, glassObject.OutputResolution)
	if editableImage then
		editableImage:WritePixelsBuffer(Vector2.zero, glassObject.OutputResolution, outPixels)
	else
		Layout.stepDownResolution(glassObject)
		glassObject.ForceRecon = true
	end
	debug.profileend()
end

local function applyDebugOverlay(glassObject: GlassObject, job: Liquid.ReconJob)
	local overlay = Config.DEBUG_OVERLAY
	local params = glassObject.LiquidParams
	if not overlay or not params then
		return
	end
	if overlay == "sdf-contours" or overlay == "melt-contours" then
		Liquid.drawContourOverlay(job, params, overlay == "melt-contours")
	elseif overlay == "normals" then
		Liquid.drawNormalOverlay(job, params, Config.DEBUG_RAW_DISTANCE_FIELD)
	elseif overlay == "cell-centers" or overlay == "cell-centers-uniform" then
		local gridPosX, gridPosY = glassObject.GridPosX, glassObject.GridPosY
		if gridPosX and gridPosY then
			Liquid.drawCellCenterOverlay(job, gridPosX, gridPosY, overlay == "cell-centers-uniform")
		end
	end
end

local function finishRecon(glassObject: GlassObject, job: Liquid.ReconJob)
	glassObject.ReconJob = nil
	if
		not (
			Config.DEBUG_SAMPLING_HEATMAP
			or Config.DEBUG_OVERLAY == "grid-view"
			or Config.DEBUG_OVERLAY == "grid-view-flat"
		)
	then
		glassObject.OutBlend = Composite.run(job, EditableImageBlur.Blur, glassObject.OutBlend)
		applyDebugOverlay(glassObject, job)
	end
	upload(glassObject, job.Out)
end

local function blurOnPool(config: { pixelBuffer: buffer, width: number, height: number, blurRadius: number })
	EditableImageBlur.BlurAsync({
		pixelBuffer = config.pixelBuffer,
		width = config.width,
		height = config.height,
		blurRadius = config.blurRadius,
		workerCount = Config.FROST_WORKER_COUNT,
	})
end

local function finishParallel(glassObject: GlassObject, job: Liquid.ReconJob)
	local token = {}
	glassObject.FinishToken = token
	task.spawn(function()
		local blendScratch = Composite.run(job, blurOnPool, glassObject.OutBlend)
		if glassObject.FinishToken ~= token then
			return
		end
		glassObject.OutBlend = blendScratch
		glassObject.FinishToken = nil
		upload(glassObject, job.Out)
	end)
end

local Recon = {}

function Recon.advance(glassObject: GlassObject, deadline: number, startIfIdle: boolean)
	if glassObject.FinishToken then
		return
	end

	local pending = glassObject.ParallelJob
	if pending then
		debug.profilebegin("GlassGather")
		local status = Parallel.poll(glassObject, pending)
		debug.profileend()
		if status == "pending" then
			return
		end
		glassObject.ParallelJob = nil
		if status == "done" then
			finishParallel(glassObject, pending.Job)
		else
			glassObject.ForceRecon = true
		end
		return
	end

	local job = glassObject.ReconJob
	if not job then
		if not startIfIdle then
			return
		end
		if deadline ~= math.huge and Parallel.shouldUse(glassObject) then
			local parallelJob = makeJob(glassObject, glassObject.Pixels)
			if parallelJob then
				debug.profilebegin("GlassScatter")
				local newPending = Parallel.scatter(glassObject, parallelJob)
				debug.profileend()
				if newPending then
					glassObject.ParallelJob = newPending
					glassObject.ForceRecon = false
					glassObject.GridWritesSinceRecon = 0
					glassObject.FramesSinceRecon = 0
					return
				end
			end
		end
		if not startRecon(glassObject) then
			return
		end
		job = glassObject.ReconJob
	end
	if job then
		debug.profilebegin("GlassReconstruct")
		local completed = Liquid.reconstructRows(job, deadline)
		debug.profileend()
		if completed then
			finishRecon(glassObject, job)
		end
	end
end

return Recon
end

__axiomGlassFactories['Scheduler'] = function()


local Liquid = __axiomGlassRequire("Liquid")
local Config = __axiomGlassRequire("Config")
local GlassObject = __axiomGlassRequire("GlassObject")
local Sampler = __axiomGlassRequire("Sampler")
local Layout = __axiomGlassRequire("Layout")
local Recon = __axiomGlassRequire("Recon")

type GlassObject = GlassObject.GlassObject

local glassObjectUpdateIndex = 1
local liquidUpdateIndex = 1

local Scheduler = {}

function Scheduler.totalUpdate(glassObject: GlassObject)
	debug.profilebegin("GlassTotalUpdate")
	Layout.update(glassObject)
	local geometry = glassObject.Geometry
	if geometry and not geometry.Ready then
		Liquid.stepGeometry(geometry, math.huge)
		glassObject.ForceRecon = true
	end

	if not GlassObject.isOpaque(glassObject) then
		local startPixel = glassObject.PixelIndex
		while Sampler.processNextPixel(glassObject, true) do
			if glassObject.PixelIndex == startPixel then
				break
			end
		end
	end

	glassObject.ReconJob = nil
	glassObject.ParallelJob = nil
	glassObject.FinishToken = nil
	Recon.advance(glassObject, math.huge, true)
	debug.profileend()
end

local function stepLiquid(glassObject: GlassObject, deadline: number)
	glassObject.FramesSinceRecon += 1

	if glassObject.PendingLayout then
		local now = os.clock()
		if
			now - glassObject.LastLayoutRequestClock >= Config.RESIZE_DEBOUNCE
			or now - glassObject.FirstLayoutRequestClock >= Config.RESIZE_MAX_WAIT
		then
			Layout.update(glassObject)
		end
	end

	local geometry = glassObject.Geometry
	if not geometry then
		return
	end
	if not geometry.Ready then
		debug.profilebegin("GlassGeometry")
		local geometryReady = Liquid.stepGeometry(geometry, deadline)
		debug.profileend()
		if geometryReady then
			glassObject.ForceRecon = true
		else
			return
		end
	end

	Recon.advance(glassObject, deadline, glassObject.ForceRecon or glassObject.GridWritesSinceRecon > 0)
end

function Scheduler.update()
	local glassObjects = GlassObject.list
	local totalGlassObjects = #glassObjects
	if totalGlassObjects == 0 then
		return
	end

	local sampleDeadline = os.clock() + Config.SAMPLE_TIME_BUDGET
	local updateIndex = glassObjectUpdateIndex
	local idleStreak = 0
	local frameStartIndex: { [GlassObject]: number } = {}
	local refreshed: { [GlassObject]: boolean } = {}
	local sampleCounts: { [GlassObject]: number } = {}
	debug.profilebegin("GlassSampling")
	while os.clock() < sampleDeadline do
		local glassObject = glassObjects[updateIndex]
		local progressed = false
		if glassObject and not refreshed[glassObject] and not GlassObject.isOpaque(glassObject) then
			if frameStartIndex[glassObject] == nil then
				frameStartIndex[glassObject] = glassObject.PixelIndex
			end
			progressed = Sampler.processNextPixel(glassObject, false)
			if progressed then
				sampleCounts[glassObject] = (sampleCounts[glassObject] or 0) + 1
				if glassObject.PixelIndex == frameStartIndex[glassObject] then
					refreshed[glassObject] = true
				end
			end
		end
		if progressed then
			idleStreak = 0
		else
			idleStreak += 1
			if idleStreak >= totalGlassObjects then
				break
			end
		end
		updateIndex += 1

		if updateIndex > totalGlassObjects then
			updateIndex = 1
		end
	end
	debug.profileend()
	glassObjectUpdateIndex = updateIndex

	for _, glassObject in glassObjects do
		glassObject.SamplesLastFrame = sampleCounts[glassObject] or 0
	end

	debug.profilebegin("GlassLiquid")
	local liquidDeadline = os.clock() + Config.LIQUID_TIME_BUDGET
	local liquidIndex = liquidUpdateIndex
	for _ = 1, totalGlassObjects do
		if liquidIndex > totalGlassObjects then
			liquidIndex = 1
		end
		local glassObject = glassObjects[liquidIndex]
		liquidIndex += 1
		if glassObject then
			stepLiquid(glassObject, liquidDeadline)
		end
		if os.clock() >= liquidDeadline then
			break
		end
	end
	debug.profileend()
	liquidUpdateIndex = liquidIndex
end

return Scheduler
end

__axiomGlassFactories['Window'] = function()


local Liquid = __axiomGlassRequire("Liquid")
local Config = __axiomGlassRequire("Config")
local GlassObject = __axiomGlassRequire("GlassObject")
local Attributes = __axiomGlassRequire("Attributes")
local Layout = __axiomGlassRequire("Layout")
local Scheduler = __axiomGlassRequire("Scheduler")
local Parallel = __axiomGlassRequire("Parallel")

type GlassObject = GlassObject.GlassObject

local Window = {}

local function initializeWindow(glassObject: GlassObject)
	local window = glassObject.Window
	if not window or glassObject.Initialized then
		return
	end
	glassObject.Initialized = true

	if window:GetAttribute(Config.TRANSPARENCY_ATTRIBUTE_NAME) == nil then
		window:SetAttribute(Config.TRANSPARENCY_ATTRIBUTE_NAME, window.BackgroundTransparency)
	end
	window.BackgroundTransparency = 1
	Window.bindUICorner(glassObject)
end

local function onInitialParented(Object: GuiObject, callback: () -> nil)
	if Object:IsDescendantOf(game) then
		task.spawn(callback)
	else
		local initializeConnection
		initializeConnection = Object.AncestryChanged:Connect(function()
			if not Object:IsDescendantOf(game) then
				return
			end

			initializeConnection:Disconnect()

			if
				Object.Size.X.Offset == 0
				and Object.Size.Y.Offset == 0
				and Object.Size.X.Scale == 0
				and Object.Size.Y.Scale == 0
			then
				task.wait()
			else
				local destroyed = false
				local destroyingConnection = Object.Destroying:Connect(function()
					destroyed = true
				end)
				local absoluteSize = Object.AbsoluteSize
				while task.wait() do
					if destroyed then
						return
					end
					if absoluteSize.X ~= 0 or absoluteSize.Y ~= 0 then
						break
					end
					absoluteSize = Object.AbsoluteSize
				end
				destroyingConnection:Disconnect()
			end

			callback()
		end)
	end
end

local function updateWindowPosition(glassObject: GlassObject)
	local window = glassObject.Window
	local absolutePosition = window.AbsolutePosition
	glassObject.WindowPositionX = absolutePosition.X
	glassObject.WindowPositionY = absolutePosition.Y
end

local function updateWindowColor(glassObject: GlassObject)
	local window = glassObject.Window
	if not window then
		return
	end
	local tintTransparency = Attributes.getNumberAttribute(window, Config.TRANSPARENCY_ATTRIBUTE_NAME)
		or 1 - glassObject.WindowColor[4]
	local windowColor = window.BackgroundColor3
	glassObject.WindowColor[1] = windowColor.R
	glassObject.WindowColor[2] = windowColor.G
	glassObject.WindowColor[3] = windowColor.B
	glassObject.WindowColor[4] = 1 - math.clamp(tintTransparency, 0, 1)
	glassObject.ForceRecon = true
end

local function updateWindowSize(glassObject: GlassObject)
	local absoluteSize = glassObject.Window.AbsoluteSize
	if absoluteSize.X == 0 or absoluteSize.Y == 0 then
		return
	end
	Layout.request(glassObject)
end

function Window.bindUICorner(glassObject: GlassObject)
	if glassObject.UICornerConnection then
		glassObject.UICornerConnection:Disconnect()
		glassObject.UICornerConnection = nil
	end
	local window = glassObject.Window
	if not window then
		return
	end
	local uiCorner = window:FindFirstChildWhichIsA("UICorner")
	if uiCorner then
		glassObject.UICornerConnection = uiCorner:GetPropertyChangedSignal("CornerRadius"):Connect(function()
			Layout.request(glassObject)
		end)
	end
end

local function watchProperties(glassObject: GlassObject)
	local window = glassObject.Window
	local connections = glassObject.Connections

	table.insert(
		connections,
		window.AncestryChanged:Connect(function()
			glassObject.Parented = window.Parent ~= nil
		end)
	)
	table.insert(
		connections,
		window:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			updateWindowPosition(glassObject)
		end)
	)
	table.insert(
		connections,
		window:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			updateWindowSize(glassObject)
		end)
	)
	table.insert(
		connections,
		window:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			updateWindowColor(glassObject)
		end)
	)
	table.insert(
		connections,
		window:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
			if glassObject.Initialized and window.BackgroundTransparency ~= 1 then
				window.BackgroundTransparency = 1
			end
		end)
	)
	table.insert(
		connections,
		window:GetAttributeChangedSignal(Config.BLUR_RADIUS_ATTRIBUTE_NAME):Connect(function()
			Attributes.updateWindowBlur(glassObject)
		end)
	)
	table.insert(
		connections,
		window:GetAttributeChangedSignal(Config.TRANSPARENCY_ATTRIBUTE_NAME):Connect(function()
			updateWindowColor(glassObject)
		end)
	)
	for _, attributeName in Config.LIQUID_PARAM_ATTRIBUTES do
		table.insert(
			connections,
			window:GetAttributeChangedSignal(attributeName):Connect(function()
				if attributeName == "MaxOutputResolution" then
					glassObject.LadderCap = math.huge
				end
				if glassObject.Initialized then
					Layout.request(glassObject)
				end
			end)
		)
	end
	local function onChildChanged(child: Instance)
		if child:IsA("UICorner") and glassObject.Initialized then
			Window.bindUICorner(glassObject)
			Layout.request(glassObject)
		end
	end
	table.insert(connections, window.ChildAdded:Connect(onChildChanged))
	table.insert(connections, window.ChildRemoved:Connect(onChildChanged))
end

function Window.setup(guiObject: GuiObject)
	if GlassObject.byWindow[guiObject] then
		return guiObject
	end

	local glassObject = GlassObject.create(guiObject)
	watchProperties(glassObject)

	table.insert(
		glassObject.Connections,
		guiObject.Destroying:Connect(function()
			Window.removeInstance(guiObject)
		end)
	)

	onInitialParented(guiObject, function()
		initializeWindow(glassObject)
		updateWindowColor(glassObject)
		updateWindowPosition(glassObject)
		updateWindowSize(glassObject)
		Attributes.updateWindowBlur(glassObject)

		Scheduler.totalUpdate(glassObject)

		if not glassObject.Paused then
			GlassObject.addToUpdateList(glassObject)
		end
	end)

	return guiObject
end

function Window.addInstance(instance: Instance)
	if instance:IsA("GuiObject") then
		Window.setup(instance)
	end
end

function Window.removeInstance(instance: Instance)
	if instance:IsA("GuiObject") then
		local glassObject = GlassObject.byWindow[instance]
		if glassObject then
			GlassObject.byWindow[instance] = nil
			GlassObject.removeFromUpdateList(glassObject)

			for _, connection in glassObject.Connections do
				connection:Disconnect()
			end
			if glassObject.UICornerConnection then
				glassObject.UICornerConnection:Disconnect()
			end
			if glassObject.Geometry then
				Liquid.releaseGeometry(glassObject.Geometry)
			end
			if glassObject.EditableImage then
				glassObject.EditableImage:Destroy()
			end
			Parallel.forget(glassObject)
			glassObject.FinishToken = nil
			glassObject.Pane:Destroy()

			table.clear(glassObject)
			table.freeze(glassObject)
		end
	end
end

return Window
end

__axiomGlassFactories['init'] = function()


local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = __axiomGlassRequire("Config")
local GlassObject = __axiomGlassRequire("GlassObject")
local Scheduler = __axiomGlassRequire("Scheduler")
local Window = __axiomGlassRequire("Window")

local GlassmorphicUI = {}

export type DebugStats = {
	GridResolution: Vector2, -- source-grid cells per axis
	OutputResolution: Vector2, -- output image px per axis
	SamplesLastFrame: number, -- backdrop samples this window got last frame
	GridWritesSinceRecon: number, -- grid cells actually changed since the last pass started
	FramesSinceRecon: number,
	ReconRoute: "parallel" | "sync" | "idle", -- what the current reconstruction pass runs on
}

function GlassmorphicUI.new(): Frame
	local window = Instance.new("Frame")
	window.Size = UDim2.fromOffset(200, 200)
	window.BackgroundColor3 = Color3.fromRGB(200, 220, 245)
	window.BorderSizePixel = 0
	window.BackgroundTransparency = 1
	window.Name = "GlassmorphicUI"
	window:AddTag(Config.TAG_NAME)

	Window.setup(window)

	return window
end

function GlassmorphicUI.setDefaultBlurRadius(radius: UDim)
	if typeof(radius) ~= "UDim" then
		return
	end
	Config.DEFAULT_BLUR_RADIUS = radius
end

function GlassmorphicUI.applyGlassToImageLabel(ImageLabel: ImageLabel)
	if typeof(ImageLabel) == "Instance" and ImageLabel:IsA("GuiObject") then
		GlassmorphicUI.addGlassBackground(ImageLabel)
	end
end

function GlassmorphicUI.addGlassBackground(GuiObject: GuiObject): GuiObject
	if typeof(GuiObject) ~= "Instance" or not GuiObject:IsA("GuiObject") then
		error("Expected GuiObject, got " .. typeof(GuiObject))
	end
	GuiObject:AddTag(Config.TAG_NAME)
	return GuiObject
end

function GlassmorphicUI.forceUpdate(window: GuiObject): GuiObject
	local glassObject = GlassObject.byWindow[window]
	if glassObject then
		Scheduler.totalUpdate(glassObject)
	end
	return window
end

function GlassmorphicUI.getDebugStats(window: GuiObject): DebugStats?
	local glassObject = GlassObject.byWindow[window]
	if not glassObject then
		return nil
	end
	return {
		GridResolution = glassObject.Resolution,
		OutputResolution = glassObject.OutputResolution,
		SamplesLastFrame = glassObject.SamplesLastFrame,
		GridWritesSinceRecon = glassObject.GridWritesSinceRecon,
		FramesSinceRecon = glassObject.FramesSinceRecon,
		ReconRoute = if glassObject.ParallelJob then "parallel" elseif glassObject.ReconJob then "sync" else "idle",
	} :: DebugStats
end

function GlassmorphicUI.pauseUpdates(window: GuiObject): GuiObject
	local glassObject = GlassObject.byWindow[window]
	if glassObject then
		glassObject.Paused = true
		GlassObject.removeFromUpdateList(glassObject)
	end
	return window
end

function GlassmorphicUI.resumeUpdates(window: GuiObject): GuiObject
	local glassObject = GlassObject.byWindow[window]
	if glassObject then
		glassObject.Paused = false
		GlassObject.addToUpdateList(glassObject)
	end
	return window
end

CollectionService:GetInstanceRemovedSignal(Config.TAG_NAME):Connect(Window.removeInstance)
CollectionService:GetInstanceAddedSignal(Config.TAG_NAME):Connect(Window.addInstance)
for _, tagged in CollectionService:GetTagged(Config.TAG_NAME) do
	Window.addInstance(tagged)
end

RunService.Heartbeat:Connect(function()
	Scheduler.update()
end)

GlassmorphicUI.DEFAULT_CORNER_RADIUS = Config.DEFAULT_CORNER_RADIUS
GlassmorphicUI.DEFAULT_SUPER_ELLIPSE_FACTOR = Config.DEFAULT_SUPER_ELLIPSE_FACTOR
GlassmorphicUI.DEFAULT_THICKNESS = Config.DEFAULT_THICKNESS
GlassmorphicUI.DEFAULT_REFRACTION_FACTOR = Config.DEFAULT_REFRACTION_FACTOR
GlassmorphicUI.DEFAULT_CHROMATIC_ABERRATION = Config.DEFAULT_CHROMATIC_ABERRATION
GlassmorphicUI.DEFAULT_FRESNEL_SIZE = Config.DEFAULT_FRESNEL_SIZE
GlassmorphicUI.DEFAULT_FRESNEL_HARDNESS = Config.DEFAULT_FRESNEL_HARDNESS
GlassmorphicUI.DEFAULT_FRESNEL_INTENSITY = Config.DEFAULT_FRESNEL_INTENSITY
GlassmorphicUI.DEFAULT_GLARE_SIZE = Config.DEFAULT_GLARE_SIZE
GlassmorphicUI.DEFAULT_GLARE_HARDNESS = Config.DEFAULT_GLARE_HARDNESS
GlassmorphicUI.DEFAULT_GLARE_INTENSITY = Config.DEFAULT_GLARE_INTENSITY
GlassmorphicUI.DEFAULT_GLARE_CONVERGENCE = Config.DEFAULT_GLARE_CONVERGENCE
GlassmorphicUI.DEFAULT_GLARE_OPPOSITE_SIDE = Config.DEFAULT_GLARE_OPPOSITE_SIDE
GlassmorphicUI.DEFAULT_GLARE_ANGLE = Config.DEFAULT_GLARE_ANGLE
GlassmorphicUI.DEFAULT_BLUR_RADIUS = Config.DEFAULT_BLUR_RADIUS
GlassmorphicUI.DEFAULT_MAX_OUTPUT_RESOLUTION = Config.DEFAULT_MAX_OUTPUT_RESOLUTION

return table.freeze(GlassmorphicUI)
end

local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")
local isMobile = UIS.TouchEnabled

local function getFS()
    local g = (getgenv and getgenv()) or _G or {}
    local env = (getfenv and getfenv()) or {}
    return {
        isfolder = isfolder or env.isfolder or g.isfolder,
        makefolder = makefolder or env.makefolder or g.makefolder,
        listfiles = listfiles or listdir or env.listfiles or env.listdir or g.listfiles or g.listdir,
        readfile = readfile or env.readfile or g.readfile,
        writefile = writefile or env.writefile or g.writefile,
        delfile = delfile or deletefile or env.delfile or env.deletefile or g.delfile or g.deletefile
    }
end

local function safeIsFolder(path)
    local fs = getFS()
    if fs.isfolder then
        local s, res = pcall(fs.isfolder, path)
        return s and res
    end
    return false
end

local function safeMakeFolder(path)
    local fs = getFS()
    if fs.makefolder and not safeIsFolder(path) then
        pcall(fs.makefolder, path)
    end
end

local function safeWriteFile(path, content)
    local fs = getFS()
    if fs.writefile then
        return pcall(fs.writefile, path, content)
    end
    return false, "writefile not supported"
end

local function safeReadFile(path)
    local fs = getFS()
    if fs.readfile then
        local s, content = pcall(fs.readfile, path)
        if s then return content end
    end
    return nil
end

local function safeDelFile(path)
    local fs = getFS()
    if fs.delfile then
        return pcall(fs.delfile, path)
    end
    return false
end

local function safeListFiles(folder)
    local fs = getFS()
    if not fs.listfiles then return {} end
    local s, files = pcall(fs.listfiles, folder)
    if s and type(files) == "table" and next(files) ~= nil then return files end
    local s2, files2 = pcall(fs.listfiles, folder .. "/")
    if s2 and type(files2) == "table" and next(files2) ~= nil then return files2 end
    local s3, files3 = pcall(fs.listfiles, "./" .. folder)
    if s3 and type(files3) == "table" and next(files3) ~= nil then return files3 end
    local s4, files4 = pcall(fs.listfiles, "")
    if not s4 or type(files4) ~= "table" then
        s4, files4 = pcall(fs.listfiles)
    end
    if s4 and type(files4) == "table" then
        local matched = {}
        local targetFolder = folder:lower():gsub("[/\\]+$", "")
        for _, f in pairs(files4) do
            local fStr = tostring(f):lower():gsub("\\", "/")
            if fStr:find(targetFolder .. "/", 1, true) then
                table.insert(matched, f)
            end
        end
        if #matched > 0 then return matched end
    end
    if s and type(files) == "table" then return files end
    return {}
end

local function parseAsset(input)
	if not input or input == "" then return "" end
	local str = tostring(input):match("^%s*(.-)%s*$")
	if str == "" then return "" end
	if str:match("^rbxthumb://") or str:match("^rbxasset://textures") then 
		return str 
	end
	local id = str:match("(%d+)")
	if id then 
		return "rbxthumb://type=Asset&id=" .. id .. "&w=420&h=420"
	end
	return str
end

local function getFirstChar(str)
	if not str or str == "" then return "" end
	for _, code in utf8.codes(str) do
		return string.upper(utf8.char(code))
	end
	return string.upper(string.sub(str, 1, 1))
end

local function truncateTwoDots(text, font, size, maxW)
	if not text or text == "" then return "" end
	if maxW <= 10 then return ".." end
	local full = TextService:GetTextSize(text, size, font, Vector2.new(10000, 100))
	if full.X <= maxW then return text end
	local dotsW = TextService:GetTextSize("..", size, font, Vector2.new(10000, 100)).X
	local avail = maxW - dotsW
	if avail <= 0 then return ".." end
	local len = utf8.len(text) or #text
	for i = len, 1, -1 do
		local offset = utf8.offset(text, i + 1)
		local sub = string.sub(text, 1, offset and (offset - 1) or i)
		local s = TextService:GetTextSize(sub, size, font, Vector2.new(10000, 100))
		if s.X <= avail then
			return sub .. ".."
		end
	end
	return ".."
end

local Library = {}
Library.__index = Library

local THEME = {
	Accent = Color3.fromRGB(110, 100, 255), 
	Background = Color3.fromRGB(24, 23, 35),
	Sidebar = Color3.fromRGB(20, 19, 30),
	Card = Color3.fromRGB(34, 32, 48),
	CardHover = Color3.fromRGB(42, 40, 58),
	Element = Color3.fromRGB(24, 23, 35),
	ElementHover = Color3.fromRGB(32, 31, 45),
	Outlines = Color3.fromRGB(50, 48, 68),
	Input = Color3.fromRGB(16, 15, 23),
	Text = Color3.fromRGB(245, 245, 250),
	TextMuted = Color3.fromRGB(145, 142, 165),
	CloseBtn = Color3.fromRGB(255, 87, 87),
	BackgroundTrans = 0,
	HUDTransparency = 0,
	BgImageTrans = 1,
	CardTrans = 0,
	ElementTrans = 0,
	InputTrans = 0,
	TextFont = "Gotham",
	SubtextFont = "Gotham",
	BackgroundImage = "",
	TogglePosition = "Right",
	InternalOutlines = "Off",
	ElementStyle = 1,
	TopbarAlign = "Right",
	MainOutlineEnabled = false,
	CloseAnimation = 1
}

local function ApplyTheme(obj, themeKey, prop)
	prop = prop or "BackgroundColor3"
	obj:SetAttribute("ThemeProp_" .. prop, themeKey)
	CS:AddTag(obj, "ThemeBind")
	if prop == "Font" then
		pcall(function() obj[prop] = Enum.Font[THEME[themeKey]] end)
	elseif prop == "Image" and themeKey == "BackgroundImage" then
		obj[prop] = parseAsset(THEME[themeKey])
	else
		obj[prop] = THEME[themeKey]
	end
end

local function UpdateTheme(themeKey, value)
	THEME[themeKey] = value
	for _, obj in ipairs(CS:GetTagged("ThemeBind")) do
		for attrName, attrValue in pairs(obj:GetAttributes()) do
			if string.sub(attrName, 1, 10) == "ThemeProp_" and attrValue == themeKey then
				local prop = string.sub(attrName, 11)
				if prop == "Font" then
					pcall(function() obj[prop] = Enum.Font[value] end)
				elseif prop == "Image" and themeKey == "BackgroundImage" then
					obj[prop] = parseAsset(value)
				else
					obj[prop] = value
				end
			end
		end
	end
end

local function UpdateTogglePosition(posMode)
	THEME.TogglePosition = posMode
	local isCompact = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4)
	local edge = isCompact and 5 or 7
	local boxSize = isCompact and 18 or 24
	for _, toggleBox in ipairs(CS:GetTagged("ToggleBoxBind")) do
		if posMode == "Left" then
			toggleBox.AnchorPoint = Vector2.new(0, 0.5)
			toggleBox.Position = UDim2.new(0, edge, 0.5, 0)
		else
			toggleBox.AnchorPoint = Vector2.new(1, 0.5)
			toggleBox.Position = UDim2.new(1, -edge, 0.5, 0)
		end
	end
	for _, label in ipairs(CS:GetTagged("ToggleLabelBind")) do
		if posMode == "Left" then
			label.Position = UDim2.new(0, edge + boxSize + 7, 0, 0)
			label.Size = UDim2.new(1, -(edge + boxSize + 15), 1, 0)
		else
			label.Position = UDim2.new(0, 15, 0, 0)
			label.Size = UDim2.new(1, -60, 1, 0)
		end
	end
	for _, combo in ipairs(CS:GetTagged("ComboToggleBind")) do
		combo:SetAttribute("TogglePos", posMode)
	end
end

local function UpdateTopbarAlign(align)
	THEME.TopbarAlign = align
	for _, layout in ipairs(CS:GetTagged("TopbarLayoutBind")) do
		if align == "Left" then
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		else
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		end
	end
	for _, padding in ipairs(CS:GetTagged("TopbarPaddingBind")) do
		if align == "Left" then
			padding.PaddingLeft = UDim.new(0, 14)
			padding.PaddingRight = UDim.new(0, 0)
		else
			padding.PaddingLeft = UDim.new(0, 0)
			padding.PaddingRight = UDim.new(0, 14)
		end
	end
	for _, search in ipairs(CS:GetTagged("SearchContainerBind")) do
		search.LayoutOrder = (align == "Left") and 3 or 1
	end
	for _, prof in ipairs(CS:GetTagged("ProfileBlockBind")) do
		prof.LayoutOrder = 2
	end
	for _, btn in ipairs(CS:GetTagged("CloseBtnBind")) do
		btn.LayoutOrder = (align == "Left") and 1 or 3
	end
	for _, descLabel in ipairs(CS:GetTagged("TopbarDescLabelBind")) do
		if align == "Left" then
			descLabel.Position = UDim2.new(0, 440, 0, 0)
			descLabel.Size = UDim2.new(1, -455, 1, 0)
			descLabel.TextXAlignment = Enum.TextXAlignment.Right
		else
			descLabel.Position = UDim2.new(0, 15, 0, 0)
			descLabel.Size = UDim2.new(1, -455, 1, 0)
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

local FontsList = {}
for _, font in pairs(Enum.Font:GetEnumItems()) do
	if font.Name ~= "Unknown" then table.insert(FontsList, font.Name) end
end
table.sort(FontsList)

local shortKeys = {
	LeftControl = "LC", RightControl = "RC", LeftShift = "LS", RightShift = "RS",
	LeftAlt = "LA", RightAlt = "RA",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	LeftBracket = "[", RightBracket = "]", Semicolon = ";", Quote = "'",
	Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
	Minus = "-", Equals = "=", Backquote = "`",
	Space = "Spc", Tab = "Tab", CapsLock = "Caps", Escape = "Esc",
	Return = "Ent", KeypadZero = "Num0", KeypadOne = "Num1", KeypadTwo = "Num2",
	KeypadThree = "Num3", KeypadFour = "Num4", KeypadFive = "Num5", KeypadSix = "Num6",
	KeypadSeven = "Num7", KeypadEight = "Num8", KeypadNine = "Num9"
}

local function resolveKeycode(value)
	if value == false then return Enum.KeyCode.Unknown end
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then return value end
	if type(value) == "string" then
		local name = value:match("^Enum%.KeyCode%.(.+)$") or value
		return Enum.KeyCode[name]
	end
	return nil
end

local function getShortKey(keyObj)
	if type(keyObj) == "string" then return keyObj end
	if not keyObj or keyObj == Enum.KeyCode.Unknown then return "None" end
	return shortKeys[keyObj.Name] or keyObj.Name
end

local SEARCH_ICON_ID = "rbxassetid://118685771787843"
local SETTINGS_ICON_ID = "rbxassetid://7059346373"

function Library.CreateWindow(arg1, arg2)
	local config = (arg1 == Library and arg2) or (type(arg1) == "table" and arg1) or {}
	local title = config.Title or "iu"
	local searchPlaceholder = config.SearchPlaceholder or "Search components..."
	local logoRaw = config.Logo or config.LogoIcon
	local logoIconId = logoRaw and parseAsset(logoRaw) or nil
	local description = config.Description 
	local isInitiallyCollapsed = (config.Collapsed == true) or (config.SidebarCollapsed == true)
	local notifPosition = config.NotificationPosition or "BottomRight"
	local configFolder = config.ConfigFolder or "AxiomConfigs"
	local motionConfig = config.Motion ~= false
	local motionDuration = math.clamp(tonumber(config.MotionDuration) or 0.24, 0.05, 1.5)
	local glassConfig = config.GlassMode == true
	local glassModule = config.GlassModule
	local glassModuleErrorShown = false
	local function loadEmbeddedGlass()
		if glassModule then return glassModule end
		local ok, result = pcall(__axiomGlassRequire, "init")
		if ok then
			glassModule = result
		elseif not glassModuleErrorShown then
			glassModuleErrorShown = true
			warn("AxiomUI: embedded GlassmorphicUI could not start:", result)
		end
		return glassModule
	end
	if glassConfig then loadEmbeddedGlass() end
	local glassAttached = {}
	local glassBudget = math.clamp(tonumber(config.GlassSurfaceBudget) or (isMobile and 2 or 5), 1, 12)
	local glassResolution = math.clamp(tonumber(config.GlassResolution) or (isMobile and 96 or 160), 32, 256)
	local glassStrength = math.clamp(tonumber(config.GlassStrength) or 0.55, 0, 1)
	local backgroundMode = config.AnimatedBackground or "None"
	local backgroundIntensity = math.clamp(tonumber(config.BackgroundIntensity) or 0.65, 0, 1)
	local watermarkEnabled = (config.Watermark == true) or (config.Watermark == nil and true)
	
	local customTheme = type(config.Theme) == "table" and config.Theme or {}
	local function getSetting(key, fallback)
		if customTheme[key] ~= nil then return customTheme[key] end
		if config[key] ~= nil then return config[key] end
		return fallback
	end
	for k in pairs(THEME) do
		local v = getSetting(k)
		if v ~= nil then THEME[k] = v end
	end
	THEME.HUDTransparency = math.clamp(tonumber(THEME.HUDTransparency) or 0, 0, 1)
	local openKeybind = resolveKeycode(getSetting("OpenKeybind")) or Enum.KeyCode.RightShift
	watermarkEnabled = getSetting("ShowWatermark", config.Watermark ~= false)
	local showSearchBar = getSetting("ShowSearchBar", true)
	local showProfile = getSetting("ShowProfile", true)
	local keybindsEnabled = getSetting("ShowKeybindsHUD", nil)
	if keybindsEnabled == nil then
		if config.Keybinds ~= nil then keybindsEnabled = config.Keybinds
		elseif config.KeybindsMenu ~= nil then keybindsEnabled = config.KeybindsMenu
		elseif config.KeybindsHUD ~= nil then keybindsEnabled = config.KeybindsHUD
		else keybindsEnabled = true end
	end
	local cornerRadiusNum = tonumber(getSetting("CornerRadius", 20)) or 20
	local elCornerRadiusNum = tonumber(getSetting("ElementsCornerRadius", cornerRadiusNum)) or cornerRadiusNum
	local hudCornerRadiusNum = tonumber(getSetting("HUDCornerRadius", 10)) or 10
	local MAIN_CORNER = UDim.new(0, cornerRadiusNum)
	local GLOBAL_CORNER = UDim.new(0, elCornerRadiusNum)

	local function UpdateElementCorners(radius)
		elCornerRadiusNum = radius
		GLOBAL_CORNER = UDim.new(0, radius)
		for _, corner in ipairs(CS:GetTagged("ElementCorner")) do
			corner.CornerRadius = GLOBAL_CORNER
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModernDashboardGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local success, _ = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
	if not success then screenGui.Parent = LP:WaitForChild("PlayerGui") end

	local Window = { 
		Tabs = {}, 
		CurrentTab = nil,
		_connections = {},
		_styleCallbacks = {},
		ActivePopupClose = nil,
		IsEditMode = false,
		_searchRegistry = {},
		_configElements = {},
		_themeElements = {},
		_themeControls = {},
		ConfigFolder = configFolder,
		ThemeFolder = "AxiomUIThemes"
	}

	local notifHolder = Instance.new("Frame")
	notifHolder.Name = "NotificationHolder"
	notifHolder.BackgroundTransparency = 1
	notifHolder.Size = isMobile and UDim2.new(0, 280, 1, -120) or UDim2.new(0, 300, 1, -40)
	notifHolder.ZIndex = 100000
	notifHolder.Parent = screenGui

	local notifLayout = Instance.new("UIListLayout")
	notifLayout.Padding = UDim.new(0, 10)
	notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	
	local notifScale = Instance.new("UIScale")
	notifScale.Scale = isMobile and 0.65 or 1
	notifScale.Parent = notifHolder

	local isNotifTop = string.find(notifPosition, "Top") ~= nil
	local isNotifLeft = string.find(notifPosition, "Left") ~= nil

	if isNotifTop and isNotifLeft then
		notifHolder.AnchorPoint = Vector2.new(0, 0)
		notifHolder.Position = isMobile and UDim2.new(0, 12, 0, 70) or UDim2.new(0, 20, 0, 20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	elseif isNotifTop and not isNotifLeft then
		notifHolder.AnchorPoint = Vector2.new(1, 0)
		notifHolder.Position = isMobile and UDim2.new(1, -12, 0, 70) or UDim2.new(1, -20, 0, 20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	elseif not isNotifTop and isNotifLeft then
		notifHolder.AnchorPoint = Vector2.new(0, 1)
		notifHolder.Position = isMobile and UDim2.new(0, 12, 1, -90) or UDim2.new(0, 20, 1, -20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	else 
		notifHolder.AnchorPoint = Vector2.new(1, 1)
		notifHolder.Position = isMobile and UDim2.new(1, -12, 1, -90) or UDim2.new(1, -20, 1, -20)
		notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	notifLayout.Parent = notifHolder

	local notifCount = 0

	function Window:Notify(notifConfig)
		local nTitle = notifConfig.Title or "Notification"
		local nContent = notifConfig.Description or notifConfig.Content or ""
		local nDuration = notifConfig.Duration or 5
		local nIcon = parseAsset(notifConfig.Icon)
		local isCompactNotif = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4)

		notifCount = notifCount + 1

		local notifWrapper = Instance.new("Frame")
		notifWrapper.Name = "NotifWrapper"
		notifWrapper.BackgroundTransparency = 1
		notifWrapper.Size = UDim2.new(1, 0, 0, 0)
		notifWrapper.AutomaticSize = Enum.AutomaticSize.Y
		notifWrapper.Parent = notifHolder
		
		if isNotifTop then
			notifWrapper.LayoutOrder = -notifCount
		else
			notifWrapper.LayoutOrder = notifCount
		end

		local notif = Instance.new("Frame")
		notif.Name = "Notification"
		notif.Size = UDim2.new(1, 0, 0, 0)
		notif.AutomaticSize = Enum.AutomaticSize.Y
		notif.BackgroundTransparency = 1
		notif.Parent = notifWrapper
		
		ApplyTheme(notif, "Background", "BackgroundColor3")
		ApplyTheme(notif, "HUDTransparency", "BackgroundTransparency")
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		corner.Parent = notif
		CS:AddTag(corner, "HUDCorner")

		local stroke = Instance.new("UIStroke")
		stroke.Name = "NotificationStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 1
		stroke.Enabled = THEME.MainOutlineEnabled
		stroke.Parent = notif
		ApplyTheme(stroke, "Outlines", "Color")
		CS:AddTag(stroke, "NotificationStrokeBind")

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, isCompactNotif and 10 or 15)
		pad.PaddingBottom = UDim.new(0, isCompactNotif and 10 or 15)
		pad.PaddingLeft = UDim.new(0, isCompactNotif and 11 or 15)
		pad.PaddingRight = UDim.new(0, isCompactNotif and 11 or 15)
		pad.Parent = notif

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, isCompactNotif and 8 or 12)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = notif

		local topContent = Instance.new("Frame")
		topContent.Name = "TopContent"
		topContent.Size = UDim2.new(1, 0, 0, 0)
		topContent.AutomaticSize = Enum.AutomaticSize.Y
		topContent.BackgroundTransparency = 1
		topContent.LayoutOrder = 1
		topContent.Parent = notif

		local topLayout = Instance.new("UIListLayout")
		topLayout.FillDirection = Enum.FillDirection.Horizontal
		topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		topLayout.Padding = UDim.new(0, isCompactNotif and 9 or 12)
		topLayout.SortOrder = Enum.SortOrder.LayoutOrder
		topLayout.Parent = topContent

		local hasIcon = (nIcon and nIcon ~= "")
		local iconSize = isCompactNotif and 28 or 36
		
		local iconImg
		if hasIcon then
			iconImg = Instance.new("ImageLabel")
			iconImg.Size = UDim2.new(0, iconSize, 0, iconSize)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = nIcon
			iconImg.LayoutOrder = isNotifLeft and 2 or 1
			iconImg.Parent = topContent
			ApplyTheme(iconImg, "Text", "ImageColor3")
		end

		local txtFrame = Instance.new("Frame")
		txtFrame.BackgroundTransparency = 1
		txtFrame.Size = UDim2.new(1, hasIcon and -(iconSize + (isCompactNotif and 9 or 12)) or 0, 0, 0)
		txtFrame.AutomaticSize = Enum.AutomaticSize.Y
		txtFrame.LayoutOrder = isNotifLeft and 1 or 2
		txtFrame.Parent = topContent

		local txtLayout = Instance.new("UIListLayout")
		txtLayout.FillDirection = Enum.FillDirection.Vertical
		txtLayout.Padding = UDim.new(0, 3)
		txtLayout.Parent = txtFrame

		local titleLbl = Instance.new("TextLabel")
		titleLbl.BackgroundTransparency = 1
		titleLbl.Size = UDim2.new(1, 0, 0, 0)
		titleLbl.AutomaticSize = Enum.AutomaticSize.Y
		titleLbl.TextWrapped = true
		titleLbl.TextXAlignment = isNotifLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		titleLbl.TextSize = isCompactNotif and 13 or 15
		titleLbl.Text = nTitle
		titleLbl.Font = Enum.Font.GothamMedium
		titleLbl.Parent = txtFrame
		ApplyTheme(titleLbl, "Text", "TextColor3")
		ApplyTheme(titleLbl, "TextFont", "Font")

		local descLbl = Instance.new("TextLabel")
		descLbl.BackgroundTransparency = 1
		descLbl.Size = UDim2.new(1, 0, 0, 0)
		descLbl.AutomaticSize = Enum.AutomaticSize.Y
		descLbl.TextWrapped = true
		descLbl.TextXAlignment = isNotifLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		descLbl.TextSize = isCompactNotif and 11 or 13
		descLbl.Text = nContent
		descLbl.Parent = txtFrame
		ApplyTheme(descLbl, "TextMuted", "TextColor3")
		ApplyTheme(descLbl, "SubtextFont", "Font")

		local bottomContainer = Instance.new("Frame")
		bottomContainer.Name = "BottomContainer"
		bottomContainer.Size = UDim2.new(1, 0, 0, isCompactNotif and 16 or 20)
		bottomContainer.BackgroundTransparency = 1
		bottomContainer.LayoutOrder = 2
		bottomContainer.Parent = notif

		local badgeW = isCompactNotif and 36 or 40
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Size = UDim2.new(1, -(badgeW + 8), 0, isCompactNotif and 3 or 4)
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0, 0, 0.5, 0)
		track.BorderSizePixel = 0
		track.Parent = bottomContainer
		ApplyTheme(track, "Input", "BackgroundColor3")
		ApplyTheme(track, "InputTrans", "BackgroundTransparency")
		
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track
		
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BorderSizePixel = 0
		fill.Parent = track
		ApplyTheme(fill, "Accent", "BackgroundColor3")
		
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local timeBadge = Instance.new("Frame")
		timeBadge.Name = "TimeBadge"
		timeBadge.Size = UDim2.new(0, badgeW, 1, 0)
		timeBadge.AnchorPoint = Vector2.new(1, 0.5)
		timeBadge.Position = UDim2.new(1, 0, 0.5, 0)
		timeBadge.BorderSizePixel = 0
		timeBadge.Parent = bottomContainer
		ApplyTheme(timeBadge, "Input", "BackgroundColor3")
		ApplyTheme(timeBadge, "InputTrans", "BackgroundTransparency")

		local timeBadgeCorner = Instance.new("UICorner")
		timeBadgeCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		timeBadgeCorner.Parent = timeBadge
		CS:AddTag(timeBadgeCorner, "HUDCorner")

		local timeBadgeStroke = Instance.new("UIStroke")
		timeBadgeStroke.Name = "TimeBadgeStroke"
		timeBadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		timeBadgeStroke.Thickness = 1
		timeBadgeStroke.Parent = timeBadge
		ApplyTheme(timeBadgeStroke, "Outlines", "Color")

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Name = "TimeLabel"
		timeLabel.Size = UDim2.new(1, 0, 1, 0)
		timeLabel.Position = UDim2.new(0, 0, 0, -1)
		timeLabel.BackgroundTransparency = 1
		timeLabel.TextSize = isCompactNotif and 10 or 11
		timeLabel.TextXAlignment = Enum.TextXAlignment.Center
		timeLabel.Text = string.format("%.1fs", nDuration)
		timeLabel.Parent = timeBadge
		ApplyTheme(timeLabel, "TextMuted", "TextColor3")
		ApplyTheme(timeLabel, "SubtextFont", "Font")

		notif.Position = isNotifLeft and UDim2.new(0, -350, 0, 0) or UDim2.new(0, 350, 0, 0)
		
		notif.BackgroundTransparency = 1
		TS:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			BackgroundTransparency = THEME.HUDTransparency,
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()

		TS:Create(fill, TweenInfo.new(nDuration, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0)
		}):Play()

		local startTime = os.clock()
		local connection
		local lastFormatted = ""
		connection = RS.RenderStepped:Connect(function()
			local remaining = math.max(0, nDuration - (os.clock() - startTime))
			local formatted = string.format("%.1fs", remaining)
			if formatted ~= lastFormatted then
				lastFormatted = formatted
				timeLabel.Text = formatted
			end
			if remaining <= 0 then
				if connection then 
					connection:Disconnect() 
					connection = nil 
				end
			end
		end)
		
		local function closeNotification()
			local fadeOut = TS:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				Position = isNotifLeft and UDim2.new(0, -350, 0, 0) or UDim2.new(0, 350, 0, 0)
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if connection then 
					connection:Disconnect() 
					connection = nil 
				end
				notifWrapper:Destroy()
			end)
		end

		task.delay(nDuration, closeNotification)
		
		local api = {}
		function api:SetTitle(newTitle)
			if titleLbl then titleLbl.Text = newTitle end
		end
		function api:SetDescription(newDesc)
			if descLbl then descLbl.Text = newDesc end
		end
		function api:SetIcon(newIcon)
			if iconImg then iconImg.Image = parseAsset(newIcon) end
		end
		function api:Close()
			closeNotification()
		end
		return api
	end

	local function attachStroke(obj, tag)
		local s = Instance.new("UIStroke")
		s.Name = obj.Name .. "Stroke"
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = 1
		if tag == "BlockStroke" then
			s.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
		else
			s.Enabled = (THEME.InternalOutlines == "Only Elements" or THEME.InternalOutlines == "All")
		end
		s.Parent = obj
		ApplyTheme(s, "Outlines", "Color")
		CS:AddTag(s, tag)
		return s
	end

	local mobileBindOrder = 0

	local function createMobileBindButton(text, callback)
		local btn = Instance.new("TextButton")
		btn.Name = "MobileBindButton"
		btn.Size = UDim2.new(0, 48, 0, 48)
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		mobileBindOrder = mobileBindOrder + 1
		btn.Position = UDim2.new(1, -78, 1, -180 - ((mobileBindOrder - 1) * 54))
		btn.AutoButtonColor = false
		btn.BackgroundTransparency = 0
		btn.Text = text or "None"
		btn.TextSize = 13
		btn.TextWrapped = true
		btn.Font = Enum.Font.GothamMedium
		btn.Active = true
		btn.ZIndex = 100001
		btn.Parent = screenGui
		ApplyTheme(btn, "Element", "BackgroundColor3")
		ApplyTheme(btn, "ElementTrans", "BackgroundTransparency")
		ApplyTheme(btn, "Text", "TextColor3")
		ApplyTheme(btn, "TextFont", "Font")

		local corner = Instance.new("UICorner")
		corner.CornerRadius = GLOBAL_CORNER
		corner.Parent = btn
		CS:AddTag(corner, "ElementCorner")

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn
		ApplyTheme(stroke, "Outlines", "Color")
		CS:AddTag(stroke, "ElementStroke")

		local dragging, dragInput, dragStart, startPos, moved = false, nil, nil, nil, false
		table.insert(Window._connections, btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				moved = false
				dragStart = input.Position
				startPos = btn.Position
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if conn then conn:Disconnect() end
					end
				end)
				table.insert(Window._connections, conn)
			end
		end))
		table.insert(Window._connections, btn.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
				dragInput = input
			end
		end))
		table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
			if dragging and input == dragInput then
				local delta = input.Position - dragStart
				if delta.Magnitude > 8 then moved = true end
				btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
		table.insert(Window._connections, btn.MouseButton1Click:Connect(function()
			if not moved then callback() end
		end))
		return btn
	end

	local function createMobileToggle(parent, callback)
		local box = Instance.new("TextButton")
		box.Name = "MobileBindToggle"
		box.Size = UDim2.new(0, 20, 0, 20)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 0
		box.Text = ""
		box.ZIndex = 5
		box.Parent = parent

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = box
		ApplyTheme(stroke, "Outlines", "Color")

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.AnchorPoint = Vector2.new(0.5, 0.5)
		fill.Position = UDim2.new(0.5, 0, 0.5, 0)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(0, 0, 0, 0)
		fill.Parent = box
		ApplyTheme(fill, "Accent", "BackgroundColor3")

		local corner = Instance.new("UICorner")
		corner.CornerRadius = GLOBAL_CORNER
		corner.Parent = box
		CS:AddTag(corner, "ElementCorner")

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = GLOBAL_CORNER
		fillCorner.Parent = fill
		CS:AddTag(fillCorner, "ElementCorner")

		local enabled = false
		local mobileBtn
		local function setEnabled(value)
			enabled = value
			if enabled then
				ApplyTheme(stroke, "Accent", "Color")
				fill.Size = UDim2.new(1, -6, 1, -6)
			else
				ApplyTheme(stroke, "Outlines", "Color")
				fill.Size = UDim2.new(0, 0, 0, 0)
			end
			callback(enabled, function()
				if mobileBtn then
					mobileBtn:Destroy()
					mobileBtn = nil
				end
			end, function(btn)
				mobileBtn = btn
			end)
		end
		table.insert(Window._connections, box.MouseButton1Click:Connect(function()
			setEnabled(not enabled)
		end))
		return box, setEnabled, function() return mobileBtn end
	end

	local initShadows = true
	if customTheme.DropShadows ~= nil then
		initShadows = (customTheme.DropShadows == true)
	elseif config.DropShadows ~= nil then
		initShadows = (config.DropShadows == true)
	end

	local SIDEBAR_STATE = {
		Position = customTheme.SidebarPosition or config.SidebarPosition or "Left",
		Detached = getSetting("DetachedSidebar", false),
		ShadowsEnabled = initShadows
	}

	local editModeGui = Instance.new("Frame")
	editModeGui.Name = "EditModeVisuals"
	editModeGui.Size = UDim2.fromScale(1, 1)
	editModeGui.BackgroundTransparency = 1
	editModeGui.Active = false
	editModeGui.ZIndex = 0
	editModeGui.Parent = screenGui
	local editModeDim = Instance.new("Frame")
	editModeDim.Name = "EditBackdrop"
	editModeDim.Size = UDim2.fromScale(1, 1)
	editModeDim.BackgroundColor3 = Color3.fromRGB(5, 9, 18)
	editModeDim.BackgroundTransparency = 1
	editModeDim.BorderSizePixel = 0
	editModeDim.ZIndex = 0
	editModeDim.Visible = false
	editModeDim.Parent = screenGui
	
	local gridOverlay = Instance.new("ImageLabel")
	gridOverlay.Name = "GridOverlay"
	gridOverlay.Size = UDim2.new(1, 0, 1, 0)
	gridOverlay.BackgroundTransparency = 1
	gridOverlay.Image = "rbxassetid://6233510619"
	gridOverlay.ScaleType = Enum.ScaleType.Tile
	gridOverlay.TileSize = UDim2.new(0, 80, 0, 80)
	gridOverlay.ImageTransparency = 1
	gridOverlay.ImageColor3 = Color3.fromRGB(255, 255, 255)
	gridOverlay.Parent = editModeGui

	local editModeCC = Instance.new("ColorCorrectionEffect")
	editModeCC.Name = "UI_EditMode_CC"
	editModeCC.Saturation = 0
	editModeCC.Parent = Lighting
	
	local uiScaleValue = isMobile and 0.65 or 1
	local finalW, finalH
	do
		local targetSize = config.WindowSize or Vector2.new(950, 600)
		local reqW = typeof(targetSize) == "Vector2" and targetSize.X or targetSize[1] or 950
		local reqH = typeof(targetSize) == "Vector2" and targetSize.Y or targetSize[2] or 600
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		local maxAvailW = (viewport.X / uiScaleValue) - 40 
		local maxAvailH = (viewport.Y / uiScaleValue) - 40 
		local minUIW = isMobile and 350 or 500
		local minUIH = isMobile and 250 or 350
		finalW = math.clamp(reqW, minUIW, math.max(minUIW, maxAvailW))
		finalH = math.clamp(reqH, minUIH, math.max(minUIH, maxAvailH))
	end

	local wrapper = Instance.new("Frame")
	wrapper.Name = "Wrapper"
	wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
	wrapper.Size = UDim2.new(0, finalW, 0, finalH)
	wrapper.Position = UDim2.new(0.5, 0, 0.5, 0)
	wrapper.BackgroundTransparency = 1
	wrapper.Active = true 
	wrapper.Parent = screenGui

	do
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = uiScaleValue
		uiScale.Parent = wrapper
	end

	local contentWrapper = Instance.new("Frame")
	contentWrapper.Name = "ContentWrapper"
	contentWrapper.Size = UDim2.new(1, 0, 1, 0)
	contentWrapper.BackgroundTransparency = 1
	contentWrapper.Parent = wrapper

	local shadowFolder = Instance.new("Frame")
	shadowFolder.Name = "Shadows"
	shadowFolder.Size = UDim2.new(1, 0, 1, 0)
	shadowFolder.BackgroundTransparency = 1
	shadowFolder.Visible = SIDEBAR_STATE.ShadowsEnabled
	shadowFolder.ZIndex = 0
	shadowFolder.Parent = contentWrapper

	local sidebarShadowFolder = Instance.new("Frame")
	sidebarShadowFolder.Name = "SidebarShadows"
	sidebarShadowFolder.Size = UDim2.new(1, 0, 1, 0)
	sidebarShadowFolder.BackgroundTransparency = 1
	sidebarShadowFolder.ZIndex = 0
	sidebarShadowFolder.Visible = false
	sidebarShadowFolder.Parent = contentWrapper

	local shadowLayers = 8
	for i = 1, shadowLayers do
		local trans = 0.8 + (i * 0.02)
		local shadow = Instance.new("Frame")
		shadow.Name = "ShadowLayer" .. i
		shadow.BackgroundTransparency = 1
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, 0) 
		shadow.Size = UDim2.new(1, 0, 1, 0)
		shadow.ZIndex = 0
		shadow.BorderSizePixel = 0
		shadow.Parent = shadowFolder
		
		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
		shadowCorner.Parent = shadow
		CS:AddTag(shadowCorner, "MainCorner")
		
		local shadowStroke = Instance.new("UIStroke")
		shadowStroke.Name = "ShadowStroke"
		shadowStroke.Color = Color3.fromRGB(0, 0, 0)
		shadowStroke.Transparency = trans
		shadowStroke:SetAttribute("TargetTransparency", trans)
		shadowStroke.Thickness = i * 2.5
		shadowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		shadowStroke.Enabled = SIDEBAR_STATE.ShadowsEnabled
		shadowStroke.Parent = shadow

		local sidebarShadow = Instance.new("Frame")
		sidebarShadow.Name = "ShadowLayer" .. i
		sidebarShadow.BackgroundTransparency = 1
		sidebarShadow.AnchorPoint = Vector2.new(0.5, 0.5)
		sidebarShadow.Position = UDim2.new(0.5, 0, 0.5, 0) 
		sidebarShadow.Size = UDim2.new(1, 0, 1, 0)
		sidebarShadow.ZIndex = 0
		sidebarShadow.BorderSizePixel = 0
		sidebarShadow.Parent = sidebarShadowFolder
		
		local sidebarShadowCorner = Instance.new("UICorner")
		sidebarShadowCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
		sidebarShadowCorner.Parent = sidebarShadow
		CS:AddTag(sidebarShadowCorner, "MainCorner")
		
		local sidebarShadowStroke = Instance.new("UIStroke")
		sidebarShadowStroke.Name = "ShadowStroke"
		sidebarShadowStroke.Color = Color3.fromRGB(0, 0, 0)
		sidebarShadowStroke.Transparency = trans
		sidebarShadowStroke:SetAttribute("TargetTransparency", trans)
		sidebarShadowStroke.Thickness = i * 2.5
		sidebarShadowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		sidebarShadowStroke.Enabled = (SIDEBAR_STATE.ShadowsEnabled and SIDEBAR_STATE.Detached)
		sidebarShadowStroke.Parent = sidebarShadow
	end

	local main = Instance.new("CanvasGroup")
	main.Name = "MainFrame"
	main.Size = UDim2.new(1, 0, 1, 0)
	main.Position = UDim2.new(0, 0, 0, 0)
	main.BorderSizePixel = 0
	main.ZIndex = 2
	main.BackgroundTransparency = 1
	main.Parent = contentWrapper
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = MAIN_CORNER
	mainCorner.Parent = main
	CS:AddTag(mainCorner, "MainCorner")

	local mainOutlineStroke = Instance.new("UIStroke")
	mainOutlineStroke.Name = "MainOutlineStroke"
	mainOutlineStroke.Enabled = false 
	mainOutlineStroke.Thickness = 1
	mainOutlineStroke.Parent = main
	ApplyTheme(mainOutlineStroke, "Outlines", "Color")

	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.ZIndex = 0 
	bgImage.BackgroundTransparency = 1
	bgImage.ScaleType = Enum.ScaleType.Crop
	bgImage.Parent = main
	ApplyTheme(bgImage, "BgImageTrans", "ImageTransparency")
	ApplyTheme(bgImage, "BackgroundImage", "Image")

	local bgColorOverlay = Instance.new("Frame")
	bgColorOverlay.Name = "BackgroundColorOverlay"
	bgColorOverlay.Size = UDim2.new(1, 0, 1, 0)
	bgColorOverlay.ZIndex = 1 
	bgColorOverlay.BorderSizePixel = 0
	bgColorOverlay.Parent = main
	ApplyTheme(bgColorOverlay, "Background", "BackgroundColor3")
	ApplyTheme(bgColorOverlay, "BackgroundTrans", "BackgroundTransparency")

	local glassLayer = Instance.new("Frame")
	glassLayer.Name = "AxiomGlassSurface"
	glassLayer.BackgroundTransparency = 1
	glassLayer.BorderSizePixel = 0
	glassLayer.Size = UDim2.fromScale(1, 1)
	glassLayer.ZIndex = 2
	glassLayer.Parent = main
	local glassCorner = Instance.new("UICorner")
	glassCorner.CornerRadius = MAIN_CORNER
	glassCorner.Parent = glassLayer
	local glassGradient = Instance.new("UIGradient")
	glassGradient.Rotation = 110
	glassGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(190, 209, 238)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 100, 133))
	})
	glassGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72),
		NumberSequenceKeypoint.new(0.5, 0.96),
		NumberSequenceKeypoint.new(1, 0.84)
	})
	glassGradient.Parent = glassLayer
	local glassStroke = Instance.new("UIStroke")
	glassStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glassStroke.Thickness = 1.5
	glassStroke.Parent = glassLayer
	local glassStrokeGradient = Instance.new("UIGradient")
	glassStrokeGradient.Rotation = 115
	glassStrokeGradient.Color = ColorSequence.new(Color3.fromRGB(240, 247, 255), Color3.fromRGB(93, 117, 153))
	glassStrokeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.13),
		NumberSequenceKeypoint.new(0.55, 0.75),
		NumberSequenceKeypoint.new(1, 0.25)
	})
	glassStrokeGradient.Parent = glassStroke
	local glassOriginals = setmetatable({}, {__mode = "k"})
	local glassStyleOriginals = setmetatable({}, {__mode = "k"})
	local function attachRealGlass(target)
		if not glassConfig or not glassModule or not glassModule.addGlassBackground or glassAttached[target] then return false end
		if typeof(target) ~= "Instance" or not target:IsA("GuiObject") then return false end
		local count = 0
		for surface in pairs(glassAttached) do
			if surface.Parent then count += 1 else glassAttached[surface] = nil end
		end
		if count >= glassBudget then return false end
		local ok, message = pcall(function()
			glassOriginals[target] = target.BackgroundTransparency
			target:SetAttribute("MaxOutputResolution", target == glassLayer and glassResolution or math.max(48, math.floor(glassResolution * 0.65)))
			target:SetAttribute("BlurRadius", UDim.new(0, math.floor(4 + 11 * glassStrength)))
			target:SetAttribute("Thickness", UDim.new(0, math.floor(6 + 11 * glassStrength)))
			target:SetAttribute("CornerRadius", UDim.new(0, target == glassLayer and cornerRadiusNum or elCornerRadiusNum))
			target:SetAttribute("RefractionFactor", 1.8 + 0.5 * glassStrength)
			target:SetAttribute("FresnelIntensity", 23)
			target:SetAttribute("GlareIntensity", 38)
			target:SetAttribute("ChromaticAberration", 0.08)
			target:SetAttribute("Transparency", math.clamp(0.51 + glassStrength * 0.27, 0.1, 0.89))
			glassModule.addGlassBackground(target)
		end)
		if ok then glassAttached[target] = true else warn("AxiomUI Glass surface:", message) end
		return ok
	end
	local function styleGlassStroke(obj)
		if not obj:IsA("UIStroke") then return end
		if not (CS:HasTag(obj, "ElementStroke") or CS:HasTag(obj, "BlockStroke") or obj.Name == "RangeTrackStroke" or obj.Name == "MainOutlineStroke") then return end
		if not glassStyleOriginals[obj] then
			glassStyleOriginals[obj] = {Thickness = obj.Thickness, Transparency = obj.Transparency, Enabled = obj.Enabled}
		end
		local state = glassStyleOriginals[obj]
		local gradient = obj:FindFirstChild("AxiomGlassRim")
		if glassConfig then
			obj.Enabled = true
			obj.Thickness = 1.4
			obj.Transparency = 0.16
			if not gradient then
				gradient = Instance.new("UIGradient")
				gradient.Name = "AxiomGlassRim"
				gradient.Rotation = 118
				gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(238, 250, 255)), ColorSequenceKeypoint.new(0.52, THEME.Outlines), ColorSequenceKeypoint.new(1, Color3.fromRGB(149, 174, 210))})
				gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.03), NumberSequenceKeypoint.new(0.55, 0.62), NumberSequenceKeypoint.new(1, 0.17)})
				gradient.Parent = obj
			end
			gradient.Enabled = true
		else
			obj.Thickness = state.Thickness
			obj.Transparency = state.Transparency
			obj.Enabled = state.Enabled
			if gradient then gradient.Enabled = false end
		end
	end
	local function styleGlassControl(obj)
		if not obj:IsA("GuiObject") or obj == glassLayer then return end
		if obj.Name ~= "ElementContainer" and obj.Name ~= "RangeTrack" and obj.Name ~= "SliderTrack" and obj.Name ~= "ValueBox" then return end
		if obj.BackgroundTransparency >= 0.98 and not glassStyleOriginals[obj] then return end
		if not glassStyleOriginals[obj] then glassStyleOriginals[obj] = {Transparency = obj.BackgroundTransparency} end
		if glassConfig then
			obj.BackgroundTransparency = math.max(glassStyleOriginals[obj].Transparency, 0.34 + glassStrength * 0.28)
		else
			obj.BackgroundTransparency = glassStyleOriginals[obj].Transparency
		end
	end
	local function styleGlassSurfaceCandidate(obj)
		if not obj:IsA("GuiObject") then return end
		if obj.Name == "ColorPopup" or obj.Name == "DropdownPopup" then
			if not obj:GetAttribute("AxiomGlassPopupBound") then
				obj:SetAttribute("AxiomGlassPopupBound", true)
				obj:GetPropertyChangedSignal("Visible"):Connect(function()
					if glassConfig and obj.Visible then
						attachRealGlass(obj)
					elseif not obj.Visible and glassAttached[obj] then
						pcall(function() obj:RemoveTag("GlassmorphicUI") end)
						if glassOriginals[obj] ~= nil then obj.BackgroundTransparency = glassOriginals[obj] end
						glassAttached[obj] = nil
					end
				end)
			end
			if glassConfig and obj.Visible then attachRealGlass(obj) end
		elseif not glassConfig then
			return
		elseif obj.Name:sub(-6) == "_Block" then
			local count = 0
			for surface in pairs(glassAttached) do if surface.Parent then count += 1 end end
			if count < math.max(1, glassBudget - 1) then attachRealGlass(obj) end
		end
	end
	local function setGlass(enabled)
		glassConfig = enabled == true
		if glassConfig then loadEmbeddedGlass() end
		glassLayer.BackgroundColor3 = Color3.fromRGB(220, 232, 255)
		glassLayer.BackgroundTransparency = glassConfig and (0.93 - 0.07 * glassStrength) or 1
		glassStroke.Enabled = glassConfig
		glassGradient.Enabled = glassConfig
		bgColorOverlay.BackgroundTransparency = glassConfig and math.max(THEME.BackgroundTrans, 0.62 + 0.25 * glassStrength) or THEME.BackgroundTrans
		if glassConfig then
			attachRealGlass(glassLayer)
		else
			for surface in pairs(glassAttached) do
				pcall(function() surface:RemoveTag("GlassmorphicUI") end)
				if surface ~= glassLayer and surface.Parent and glassOriginals[surface] ~= nil then
					surface.BackgroundTransparency = glassOriginals[surface]
				end
				glassAttached[surface] = nil
			end
		end
		for _, obj in ipairs(screenGui:GetDescendants()) do
			if obj:IsA("UIStroke") then styleGlassStroke(obj)
			elseif obj:IsA("GuiObject") then
				styleGlassControl(obj)
				styleGlassSurfaceCandidate(obj)
			end
		end
	end
	table.insert(Window._connections, screenGui.DescendantAdded:Connect(function(obj)
		if not glassConfig then return end
		if obj:IsA("UIStroke") then task.defer(function() if obj.Parent then styleGlassStroke(obj) end end)
		elseif obj:IsA("GuiObject") then
			task.defer(function()
				if obj.Parent then styleGlassControl(obj); styleGlassSurfaceCandidate(obj) end
			end)
		end
	end))

	local ambientLayer = Instance.new("Frame")
	ambientLayer.Name = "AxiomAmbientBackground"
	ambientLayer.BackgroundTransparency = 1
	ambientLayer.Size = UDim2.fromScale(1, 1)
	ambientLayer.ClipsDescendants = true
	ambientLayer.ZIndex = 2
	ambientLayer.Parent = main
	local ambientNodes = {}
	local ambientToken = 0
	local ambientRandom = Random.new()
	local ambientConnections = {}
	local function clearAmbient()
		ambientToken += 1
		for _, connection in ipairs(ambientConnections) do connection:Disconnect() end
		table.clear(ambientConnections)
		for _, node in ipairs(ambientNodes) do node:Destroy() end
		table.clear(ambientNodes)
	end
	local function ambientDot(x, y, diameter)
		local dot = Instance.new("Frame")
		dot.Name = "AmbientDot"
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(diameter, diameter)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(x, y)
		dot.BackgroundColor3 = THEME.Accent
		dot.BackgroundTransparency = 1
		dot.ZIndex = 2
		dot.Parent = ambientLayer
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		table.insert(ambientNodes, dot)
		return dot
	end
	local function setAmbient(mode)
		clearAmbient()
		backgroundMode = mode or "None"
		if backgroundMode == "None" then return end
		local token = ambientToken
		if backgroundMode == "Aurora" then
			for i = 1, 4 do
				local beam = Instance.new("Frame")
				beam.Name = "AuroraRibbon"
				beam.BorderSizePixel = 0
				beam.BackgroundColor3 = THEME.Accent
				beam.BackgroundTransparency = 0.68 + i * 0.06
				beam.Size = UDim2.fromScale(0.34, 1.5)
				beam.AnchorPoint = Vector2.new(0.5, 0.5)
				beam.Position = UDim2.fromScale((i-1)*0.35, 0.5)
				beam.Rotation = 30
				beam.ZIndex = 2
				beam.Parent = ambientLayer
				local fade = Instance.new("UIGradient")
				fade.Rotation = 0
				fade.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 1 - 0.32*backgroundIntensity), NumberSequenceKeypoint.new(1, 1)})
				fade.Parent = beam
				table.insert(ambientNodes, beam)
				task.spawn(function()
					while token == ambientToken and beam.Parent and screenGui.Parent do
						local duration = ambientRandom:NextNumber(6, 11)
						local animation = TS:Create(beam, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
							Position = UDim2.fromScale(ambientRandom:NextNumber(-0.2, 1.2), 0.5),
							Rotation = ambientRandom:NextNumber(20, 50)
						})
						animation:Play()
						task.wait(duration)
					end
				end)
			end
			return
		end
		if backgroundMode == "Comets" then
			for i = 1, 12 do
				local dot = ambientDot(ambientRandom:NextNumber(), ambientRandom:NextNumber(), 2)
				local tail = Instance.new("Frame")
				tail.Name = "CometTrail"
				tail.AnchorPoint = Vector2.new(1, 0.5)
				tail.BackgroundColor3 = THEME.Accent
				tail.BackgroundTransparency = 0.88
				tail.BorderSizePixel = 0
				tail.Size = UDim2.fromOffset(38, 1)
				tail.Parent = dot
				table.insert(ambientNodes, tail)
				task.spawn(function()
					while token == ambientToken and dot.Parent and screenGui.Parent do
						local duration = ambientRandom:NextNumber(2, 5)
						dot.Position = UDim2.fromScale(ambientRandom:NextNumber(-0.25, 0.2), ambientRandom:NextNumber(0.05, 0.95))
						dot.BackgroundTransparency = 1 - backgroundIntensity * 0.6
						TS:Create(dot, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = dot.Position + UDim2.fromScale(1.1, -0.3), BackgroundTransparency = 1}):Play()
						task.wait(duration + ambientRandom:NextNumber(0.1, 2))
					end
				end)
			end
			return
		end
		if backgroundMode == "Constellation" then
			local pairsList = {}
			for i = 1, 13 do
				local x, y = ambientRandom:NextNumber(0.04, 0.96), ambientRandom:NextNumber(0.06, 0.94)
				local dot = ambientDot(x, y, 3)
				local target = ambientDot(x + 0.02, y + 0.02, 2)
				local line = Instance.new("Frame")
				line.Name = "AmbientConnection"
				line.BorderSizePixel = 0
				line.AnchorPoint = Vector2.new(0, 0.5)
				line.BackgroundColor3 = THEME.Accent
				line.BackgroundTransparency = 1
				line.ZIndex = 2
				line.Parent = ambientLayer
				table.insert(ambientNodes, line)
				table.insert(pairsList, {dot, target, line})
				for _, point in ipairs({dot, target}) do
					task.spawn(function()
						while token == ambientToken and point.Parent and screenGui.Parent do
							local duration = ambientRandom:NextNumber(3, 6)
							TS:Create(point, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
								Position = UDim2.fromScale(ambientRandom:NextNumber(0.04, 0.96), ambientRandom:NextNumber(0.06, 0.94)),
								BackgroundTransparency = 1 - ambientRandom:NextNumber(0.25, 0.7) * backgroundIntensity
							}):Play()
							task.wait(duration)
						end
					end)
				end
			end
			local elapsed = 0
			table.insert(ambientConnections, RS.RenderStepped:Connect(function(dt)
				elapsed += dt
				if elapsed < 1 / 24 then return end
				elapsed = 0
				local size = ambientLayer.AbsoluteSize
				if size.X <= 0 or size.Y <= 0 then return end
				for _, pair in ipairs(pairsList) do
					local first, second, line = pair[1], pair[2], pair[3]
					local ax = first.Position.X.Scale * size.X
					local ay = first.Position.Y.Scale * size.Y
					local bx = second.Position.X.Scale * size.X
					local by = second.Position.Y.Scale * size.Y
					local dx, dy = bx - ax, by - ay
					local distance = math.sqrt(dx * dx + dy * dy)
					line.Position = UDim2.fromOffset(ax, ay)
					line.Size = UDim2.fromOffset(distance, 1)
					line.Rotation = math.deg(math.atan2(dy, dx))
					line.BackgroundTransparency = math.clamp(0.76 + distance / math.max(size.X, size.Y) * 0.4 - backgroundIntensity * 0.13, 0.68, 1)
				end
			end))
			return
		end
		local columns = backgroundMode == "DotMatrix" and 11 or 9
		local rows = backgroundMode == "DotMatrix" and 8 or 7
		for i = 1, columns * rows do
			local x = ((i - 1) % columns + 0.5) / columns
			local y = (math.floor((i - 1) / columns) + 0.5) / rows
			local dot = ambientDot(x, y, backgroundMode == "PulseGrid" and 3 or 2)
			task.spawn(function()
				while token == ambientToken and dot.Parent and screenGui.Parent do
					local duration = ambientRandom:NextNumber(1.4, 3.6)
					local island = (math.sin(x * 15 + os.clock() * 0.5) + math.cos(y * 12 - os.clock() * 0.4)) * 0.25 + 0.5
					local opacity = ambientRandom:NextNumber() < island and ambientRandom:NextNumber(0.2, 0.7) * backgroundIntensity or 0
					TS:Create(dot, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						BackgroundTransparency = 1 - opacity,
						Size = UDim2.fromOffset(backgroundMode == "PulseGrid" and 2 + opacity * 3 or 2, backgroundMode == "PulseGrid" and 2 + opacity * 3 or 2)
					}):Play()
					task.wait(duration)
				end
			end)
		end
	end
	function Window:SetGlassMode(enabled, strength)
		if strength ~= nil then glassStrength = math.clamp(tonumber(strength) or glassStrength, 0, 1) end
		setGlass(enabled)
		if glassConfig then
			for surface in pairs(glassAttached) do
				if surface.Parent then
					surface:SetAttribute("BlurRadius", UDim.new(0, math.floor(4 + 11 * glassStrength)))
					surface:SetAttribute("Transparency", math.clamp(0.51 + glassStrength * 0.27, 0.1, 0.89))
				end
			end
		end
	end
	function Window:SetAnimatedBackground(mode, intensity)
		if intensity ~= nil then backgroundIntensity = math.clamp(tonumber(intensity) or backgroundIntensity, 0, 1) end
		if mode ~= "None" and mode ~= "Constellation" and mode ~= "DotMatrix" and mode ~= "PulseGrid" and mode ~= "Aurora" and mode ~= "Comets" then return false end
		setAmbient(mode)
		return true
	end
	function Window:SetGlassQuality(level)
		if level == "Low" then
			glassResolution = 72
			glassBudget = 2
		elseif level == "High" then
			glassResolution = isMobile and 128 or 224
			glassBudget = isMobile and 3 or 7
		elseif level == "Balanced" then
			glassResolution = isMobile and 96 or 160
			glassBudget = isMobile and 2 or 5
		else return false end
		for surface in pairs(glassAttached) do
			if surface.Parent then
				surface:SetAttribute("MaxOutputResolution", surface == glassLayer and glassResolution or math.max(48, math.floor(glassResolution * 0.65)))
			end
		end
		return true
	end
	function Window:GetGlassStats()
		local stats = {}
		if glassModule and glassModule.getDebugStats then
			for target in pairs(glassAttached) do
				local status = glassModule.getDebugStats(target)
				if status then stats[target.Name] = status end
			end
		end
		return stats
	end
	function Window:SetMotion(enabled, duration)
		motionConfig = enabled ~= false
		if duration ~= nil then motionDuration = math.clamp(tonumber(duration) or motionDuration, 0.05, 1.5) end
	end
	function Window:Animate(target, properties, duration, easing)
		if typeof(target) ~= "Instance" or type(properties) ~= "table" then return nil end
		if not motionConfig then
			for property, value in pairs(properties) do pcall(function() target[property] = value end) end
			return nil
		end
		local tween = TS:Create(target, TweenInfo.new(duration or motionDuration, easing or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties)
		tween:Play()
		return tween
	end
	table.insert(Window._connections, screenGui.Destroying:Connect(clearAmbient))
	setGlass(glassConfig)
	setAmbient(backgroundMode)
	local motionButtons = setmetatable({}, {__mode = "k"})
	local function bindButtonMotion(btn)
		if not btn:IsA("GuiButton") or motionButtons[btn] then return end
		motionButtons[btn] = true
		if btn.Name == "MinHandle" or btn.Name == "MaxHandle" then return end
		local scale = btn:FindFirstChildOfClass("UIScale")
		if not scale then scale = Instance.new("UIScale"); scale.Name = "AxiomInteractionScale"; scale.Parent = btn end
		local normalScale = scale.Scale
		local hovering = false
		local held = false
		local currentTween
		local function animateButton()
			if not btn.Parent then return end
			local target = normalScale * (held and 0.955 or (hovering and 1.025 or 1))
			if not motionConfig then scale.Scale = normalScale; return end
			if currentTween then currentTween:Cancel() end
			currentTween = TS:Create(scale, TweenInfo.new(math.min(0.17, motionDuration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = target})
			currentTween:Play()
		end
		btn.MouseEnter:Connect(function() hovering = true; animateButton() end)
		btn.MouseLeave:Connect(function() hovering = false; held = false; animateButton() end)
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then held = true; animateButton() end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then held = false; animateButton() end
		end)
	end
	for _, child in ipairs(screenGui:GetDescendants()) do bindButtonMotion(child) end
	table.insert(Window._connections, screenGui.DescendantAdded:Connect(bindButtonMotion))

	local dragArea = Instance.new("Frame")
	dragArea.Name = "DragArea"
	dragArea.Size = UDim2.new(1, 0, 0, 60)
	dragArea.BackgroundTransparency = 1
	dragArea.Active = true
	dragArea.ZIndex = 10
	dragArea.Parent = wrapper

	local dragging, dragInput, dragStart, startPos
	local targetPos = wrapper.Position
	local dragConn = nil

	local function startDragLoop()
		if dragConn then return end
		dragConn = RS.RenderStepped:Connect(function(dt)
			if not wrapper.Parent then
				if dragConn then dragConn:Disconnect(); dragConn = nil end
				return
			end
			local diffX = math.abs(wrapper.Position.X.Offset - targetPos.X.Offset)
			local diffY = math.abs(wrapper.Position.Y.Offset - targetPos.Y.Offset)
			if diffX > 0.1 or diffY > 0.1 then
				wrapper.Position = wrapper.Position:Lerp(targetPos, 1 - math.exp(-28 * dt))
			else
				wrapper.Position = targetPos
				if not dragging then
					dragConn:Disconnect()
					dragConn = nil
				end
			end
		end)
		table.insert(Window._connections, dragConn)
	end

	table.insert(Window._connections, dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetPos
			startDragLoop()
			local inputEndConn
			inputEndConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					inputEndConn:Disconnect()
				end
			end)
			table.insert(Window._connections, inputEndConn)
		end
	end))

	table.insert(Window._connections, dragArea.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			startDragLoop()
		end
	end))

	local resizeHitbox = Instance.new("TextButton")
	resizeHitbox.Name = "ResizeHitbox"
	resizeHitbox.Size = UDim2.new(0, isMobile and 64 or 50, 0, isMobile and 64 or 50)
	resizeHitbox.Position = UDim2.new(1, 10, 1, 10) 
	resizeHitbox.AnchorPoint = Vector2.new(1, 1)
	resizeHitbox.BackgroundTransparency = 1
	resizeHitbox.Text = ""
	resizeHitbox.Active = true
	resizeHitbox.ZIndex = 20
	resizeHitbox.Parent = wrapper

	local arcOuterStroke, topCap, leftCap
	do
		local WINDOW_CORNER = cornerRadiusNum
		local GAP = 5
		local STROKE_THICKNESS = 4
		local R_CENTER = WINDOW_CORNER + GAP 
		local FRAME_RADIUS = R_CENTER - (STROKE_THICKNESS / 2) 
		local OUTER_RADIUS = R_CENTER + (STROKE_THICKNESS / 2) 
		local CAP_OFFSET = 4 
		local CAP_X = math.sqrt(math.max(0, R_CENTER^2 - CAP_OFFSET^2)) + 0.5 
		local CAP_SIZE = STROKE_THICKNESS + 0.6 
		
		local arcMaster = Instance.new("Frame")
		arcMaster.Name = "ArcMaster"
		arcMaster.Size = UDim2.new(0, OUTER_RADIUS, 0, OUTER_RADIUS)
		arcMaster.Position = UDim2.new(1, -WINDOW_CORNER, 1, -WINDOW_CORNER) 
		arcMaster.BackgroundTransparency = 1
		arcMaster.ZIndex = 3
		arcMaster.Parent = contentWrapper

		local arcClipped = Instance.new("Frame")
		arcClipped.Name = "ArcClipped"
		arcClipped.Size = UDim2.new(1, -CAP_OFFSET, 1, -CAP_OFFSET)
		arcClipped.Position = UDim2.new(0, CAP_OFFSET, 0, CAP_OFFSET)
		arcClipped.BackgroundTransparency = 1
		arcClipped.ClipsDescendants = true
		arcClipped.Parent = arcMaster

		local arcOuter = Instance.new("Frame")
		arcOuter.Name = "ArcOuter"
		arcOuter.Size = UDim2.new(0, FRAME_RADIUS * 2, 0, FRAME_RADIUS * 2) 
		arcOuter.Position = UDim2.new(0, -CAP_OFFSET, 0, -CAP_OFFSET) 
		arcOuter.AnchorPoint = Vector2.new(0.5, 0.5) 
		arcOuter.BackgroundTransparency = 1
		arcOuter.Parent = arcClipped
		
		local arcOuterCorner = Instance.new("UICorner")
		arcOuterCorner.CornerRadius = UDim.new(0, FRAME_RADIUS)
		arcOuterCorner.Parent = arcOuter
		CS:AddTag(arcOuterCorner, "MainCorner")

		arcOuterStroke = Instance.new("UIStroke")
		arcOuterStroke.Name = "ArcOuterStroke"
		arcOuterStroke.Thickness = STROKE_THICKNESS
		arcOuterStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border 
		arcOuterStroke.Parent = arcOuter
		ApplyTheme(arcOuterStroke, "TextMuted", "Color")

		topCap = Instance.new("Frame")
		topCap.Name = "TopCap"
		topCap.Size = UDim2.new(0, CAP_SIZE, 0, CAP_SIZE)
		topCap.Position = UDim2.new(0, CAP_X, 0, CAP_OFFSET) 
		topCap.AnchorPoint = Vector2.new(0.5, 0.5)
		topCap.BorderSizePixel = 0
		topCap.Parent = arcMaster
		ApplyTheme(topCap, "TextMuted", "BackgroundColor3")
		
		local topCapCorner = Instance.new("UICorner")
		topCapCorner.CornerRadius = UDim.new(1, 0)
		topCapCorner.Parent = topCap

		leftCap = topCap:Clone()
		leftCap.Name = "LeftCap"
		leftCap.Position = UDim2.new(0, CAP_OFFSET, 0, CAP_X) 
		leftCap.Parent = arcMaster
	end

	local resizing = false
	local resizeStartPos, resizeStartSize

	table.insert(Window._connections, resizeHitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStartPos = input.Position
			resizeStartSize = wrapper.AbsoluteSize
			local inputEndConn
			inputEndConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
					inputEndConn:Disconnect()
				end
			end)
			table.insert(Window._connections, inputEndConn)
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local scaleMultiplier = isMobile and 0.65 or 1
			local delta = (input.Position - resizeStartPos) / scaleMultiplier
			local sw, sh = screenGui.AbsoluteSize.X, screenGui.AbsoluteSize.Y
			local minResW = isMobile and 350 or 500
			local minResH = isMobile and 250 or 350
			local maxResW = math.max(minResW, (sw / scaleMultiplier) - 40)
			local maxResH = math.max(minResH, (sh / scaleMultiplier) - 40)
			wrapper.Size = UDim2.new(0, math.clamp(resizeStartSize.X + (delta.X * 2), minResW, maxResW), 0, math.clamp(resizeStartSize.Y + (delta.Y * 2), minResH, maxResH))
		end
	end))

	Window.Overlay = Instance.new("TextButton")
	Window.Overlay.Name = "PopupOverlay"
	Window.Overlay.Size = UDim2.new(1, 0, 1, 0)
	Window.Overlay.BackgroundTransparency = 1
	Window.Overlay.Text = ""
	Window.Overlay.ZIndex = 100000
	Window.Overlay.Visible = false
	Window.Overlay.Parent = screenGui 

	Window.ClosePopup = function()
		if Window.ActivePopup then
			local p = Window.ActivePopup
			Window.ActivePopup = nil
			if Window.ActivePopupClose then
				Window.ActivePopupClose()
				Window.ActivePopupClose = nil
			else
				p.Visible = false
				if not Window.ActivePopup then Window.Overlay.Visible = false end
			end
		end
	end

	table.insert(Window._connections, Window.Overlay.MouseButton1Click:Connect(Window.ClosePopup))

	local MIN_SIDEBAR_WIDTH = isMobile and 48 or 58 
	local MAX_SIDEBAR_WIDTH = isMobile and 150 or 210
	local currentSidebarWidth = getSetting("SidebarWidth", isInitiallyCollapsed and MIN_SIDEBAR_WIDTH or MAX_SIDEBAR_WIDTH)
	local savedSidebarWidth = currentSidebarWidth

	local sidebarVisuals = Instance.new("Frame")
	sidebarVisuals.Name = "SidebarVisuals"
	sidebarVisuals.Size = UDim2.new(0, currentSidebarWidth, 1, 0)
	sidebarVisuals.BorderSizePixel = 0
	sidebarVisuals.ZIndex = 3 
	sidebarVisuals.BackgroundTransparency = 1 
	sidebarVisuals.Parent = main
	
	local svCorner = Instance.new("UICorner")
	svCorner.CornerRadius = MAIN_CORNER
	svCorner.Parent = sidebarVisuals
	CS:AddTag(svCorner, "MainCorner")

	local sidebarBgImage = Instance.new("ImageLabel")
	sidebarBgImage.Name = "SidebarBackgroundImage"
	sidebarBgImage.Size = UDim2.new(1, 0, 1, 0)
	sidebarBgImage.ZIndex = 0 
	sidebarBgImage.BackgroundTransparency = 1
	sidebarBgImage.ScaleType = Enum.ScaleType.Crop
	sidebarBgImage.Visible = false
	sidebarBgImage.Parent = sidebarVisuals
	ApplyTheme(sidebarBgImage, "BgImageTrans", "ImageTransparency")
	ApplyTheme(sidebarBgImage, "BackgroundImage", "Image")

	local sidebarBase = Instance.new("Frame")
	sidebarBase.Name = "SidebarBase"
	sidebarBase.Size = UDim2.new(1, 0, 1, 0)
	sidebarBase.ZIndex = 1
	sidebarBase.BorderSizePixel = 0
	sidebarBase.Parent = sidebarVisuals
	ApplyTheme(sidebarBase, "Sidebar", "BackgroundColor3")
	ApplyTheme(sidebarBase, "BackgroundTrans", "BackgroundTransparency")
	
	local sidebarBaseCorner = Instance.new("UICorner")
	sidebarBaseCorner.CornerRadius = MAIN_CORNER
	sidebarBaseCorner.Parent = sidebarBase
	CS:AddTag(sidebarBaseCorner, "MainCorner")

	local sidebarFiller = Instance.new("Frame")
	sidebarFiller.Name = "SidebarFiller"
	sidebarFiller.ZIndex = 1
	sidebarFiller.BorderSizePixel = 0
	sidebarFiller.Parent = sidebarVisuals
	ApplyTheme(sidebarFiller, "Sidebar", "BackgroundColor3")
	ApplyTheme(sidebarFiller, "BackgroundTrans", "BackgroundTransparency")

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, currentSidebarWidth, 1, 0)
	sidebar.BorderSizePixel = 0
	sidebar.BackgroundTransparency = 1
	sidebar.ZIndex = 5
	sidebar.Parent = main
	
	local sidebarCorner = Instance.new("UICorner")
	sidebarCorner.CornerRadius = MAIN_CORNER
	sidebarCorner.Parent = sidebar
	CS:AddTag(sidebarCorner, "MainCorner")

	local sidebarOutlineStroke = Instance.new("UIStroke")
	sidebarOutlineStroke.Name = "SidebarOutlineStroke"
	sidebarOutlineStroke.Enabled = false 
	sidebarOutlineStroke.Thickness = 1
	sidebarOutlineStroke.Parent = sidebar
	ApplyTheme(sidebarOutlineStroke, "Outlines", "Color")

	local logoContainer = Instance.new("Frame")
	logoContainer.Name = "LogoContainer"
	logoContainer.Size = UDim2.new(1, 0, 0, 60)
	logoContainer.Position = UDim2.new(0, 0, 0, -2)
	logoContainer.BackgroundTransparency = 1
	logoContainer.ClipsDescendants = true
	logoContainer.Parent = sidebar

	local logoLayout = Instance.new("UIListLayout")
	logoLayout.Name = "LogoLayout"
	logoLayout.FillDirection = Enum.FillDirection.Horizontal
	logoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	logoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	logoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logoLayout.Padding = UDim.new(0, 10)
	logoLayout.Parent = logoContainer
	
	local logoPadding = Instance.new("UIPadding")
	logoPadding.Name = "LogoPadding"
	logoPadding.PaddingLeft = UDim.new(0, 0)
	logoPadding.Parent = logoContainer

	local logoImage, logoLabel
	if logoIconId and logoIconId ~= "" then
		logoImage = Instance.new("ImageLabel")
		logoImage.Name = "LogoImage"
		logoImage.Size = UDim2.new(0, 32, 0, 32) 
		logoImage.BackgroundTransparency = 1
		logoImage.Image = logoIconId
		logoImage.LayoutOrder = 1
		logoImage.Parent = logoContainer
	end

	logoLabel = Instance.new("TextLabel")
	logoLabel.Name = "LogoLabel"
	logoLabel.AutomaticSize = Enum.AutomaticSize.X
	logoLabel.Size = UDim2.new(0, 0, 1, 0)
	logoLabel.BackgroundTransparency = 1
	logoLabel.TextSize = 30 
	logoLabel.Text = title
	logoLabel.TextTruncate = Enum.TextTruncate.AtEnd
	logoLabel.LayoutOrder = 2
	logoLabel.Parent = logoContainer
	ApplyTheme(logoLabel, "Text", "TextColor3")
	ApplyTheme(logoLabel, "TextFont", "Font")

	local sidebarDivider = Instance.new("Frame")
	sidebarDivider.Name = "SidebarDivider"
	sidebarDivider.Size = UDim2.new(1, 0, 0, 1)
	sidebarDivider.Position = UDim2.new(0, 0, 0, 60)
	sidebarDivider.BorderSizePixel = 0
	sidebarDivider.ZIndex = 6
	sidebarDivider.Parent = sidebar
	ApplyTheme(sidebarDivider, "Outlines", "BackgroundColor3")

	local tabList = Instance.new("ScrollingFrame")
	tabList.Name = "TabList"
	tabList.Size = UDim2.new(1, -20, 1, (description and type(description) == "string") and -140 or -90) 
	tabList.Position = UDim2.new(0, 10, 0, 75)
	tabList.BackgroundTransparency = 1
	tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabList.ScrollBarThickness = 2
	tabList.Parent = sidebar
	ApplyTheme(tabList, "Outlines", "ScrollBarImageColor3")

	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Name = "TabListLayout"
	tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	tabListLayout.Padding = UDim.new(0, 4)
	tabListLayout.Parent = tabList

	local tabListPadding = Instance.new("UIPadding")
	tabListPadding.Name = "TabListPadding"
	tabListPadding.PaddingTop = UDim.new(0, 2)
	tabListPadding.PaddingBottom = UDim.new(0, 2)
	tabListPadding.PaddingLeft = UDim.new(0, 2)
	tabListPadding.PaddingRight = UDim.new(0, 2)
	tabListPadding.Parent = tabList
	
	local settingsContainer = Instance.new("Frame")
	settingsContainer.Name = "SettingsContainer"
	settingsContainer.Size = UDim2.new(0, 70, 1, 0)
	settingsContainer.Position = UDim2.new(1, -70, 0, 0)
	settingsContainer.BackgroundTransparency = 1
	settingsContainer.Visible = false
	settingsContainer.Parent = sidebar

	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.FillDirection = Enum.FillDirection.Horizontal
	settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	settingsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	settingsLayout.Padding = UDim.new(0, 4)
	settingsLayout.Parent = settingsContainer

	local dividerContainer = Instance.new("Frame")
	dividerContainer.Name = "DividerContainer"
	dividerContainer.Size = UDim2.new(1, 0, 0, 16)
	dividerContainer.BackgroundTransparency = 1
	dividerContainer.LayoutOrder = 9998
	dividerContainer.Parent = tabList

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.8, 0, 0, 1)
	divider.Position = UDim2.new(0.5, 0, 0.5, 0)
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.BorderSizePixel = 0
	divider.Parent = dividerContainer
	ApplyTheme(divider, "Outlines", "BackgroundColor3")

	local descLabel = nil
	if description and type(description) == "string" then
		descLabel = Instance.new("TextLabel")
		descLabel.Name = "DescLabel"
		descLabel.Size = UDim2.new(1, -16, 0, 36)
		descLabel.Position = UDim2.new(0, 8, 1, -44)
		descLabel.BackgroundTransparency = 1
		descLabel.TextSize = 11
		descLabel.TextWrapped = true
		descLabel.ClipsDescendants = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Center
		descLabel.TextYAlignment = Enum.TextYAlignment.Bottom
		descLabel.Text = description
		descLabel.Parent = sidebar
		ApplyTheme(descLabel, "TextMuted", "TextColor3")
		ApplyTheme(descLabel, "SubtextFont", "Font")
	end

	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, -currentSidebarWidth, 0, 60)
	topbar.Position = UDim2.new(0, currentSidebarWidth, 0, 0)
	topbar.BackgroundTransparency = 1
	topbar.ClipsDescendants = true
	topbar.ZIndex = 5
	topbar.Parent = main

	local topbarDivider = Instance.new("Frame")
	topbarDivider.Name = "TopbarDivider"
	topbarDivider.Size = UDim2.new(1, -currentSidebarWidth, 0, 1) 
	topbarDivider.Position = UDim2.new(0, currentSidebarWidth, 0, 60)
	topbarDivider.BorderSizePixel = 0
	topbarDivider.ZIndex = 6
	topbarDivider.Parent = main
	ApplyTheme(topbarDivider, "Outlines", "BackgroundColor3")

	local topbarDescLabel = nil
	if description and type(description) == "string" then
		topbarDescLabel = Instance.new("TextLabel")
		topbarDescLabel.Name = "TopbarDescLabel"
		topbarDescLabel.Size = UDim2.new(1, -455, 1, 0)
		topbarDescLabel.Position = UDim2.new(0, 15, 0, 0)
		topbarDescLabel.BackgroundTransparency = 1
		topbarDescLabel.TextSize = 11
		topbarDescLabel.TextWrapped = true
		topbarDescLabel.TextTruncate = Enum.TextTruncate.AtEnd
		topbarDescLabel.ClipsDescendants = true
		topbarDescLabel.TextYAlignment = Enum.TextYAlignment.Center
		topbarDescLabel.TextXAlignment = Enum.TextXAlignment.Left
		topbarDescLabel.Text = description
		topbarDescLabel.ZIndex = 6
		topbarDescLabel.Visible = false
		topbarDescLabel.Parent = topbar
		ApplyTheme(topbarDescLabel, "TextMuted", "TextColor3")
		ApplyTheme(topbarDescLabel, "SubtextFont", "Font")
		CS:AddTag(topbarDescLabel, "TopbarDescLabelBind")
	end

	local topbarControls = Instance.new("Frame")
	topbarControls.Name = "TopbarControls"
	topbarControls.Size = UDim2.new(1, 0, 1, 0)
	topbarControls.BackgroundTransparency = 1
	topbarControls.ZIndex = 5
	topbarControls.Parent = topbar

	local topbarLayout = Instance.new("UIListLayout")
	topbarLayout.Name = "TopbarLayout"
	topbarLayout.FillDirection = Enum.FillDirection.Horizontal
	topbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	topbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topbarLayout.Padding = UDim.new(0, 15)
	topbarLayout.Parent = topbarControls
	CS:AddTag(topbarLayout, "TopbarLayoutBind")

	local topbarPadding = Instance.new("UIPadding")
	topbarPadding.Name = "TopbarPadding"
	topbarPadding.PaddingRight = UDim.new(0, 14)
	topbarPadding.Parent = topbarControls
	CS:AddTag(topbarPadding, "TopbarPaddingBind")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 42, 0, 42)
	closeBtn.Text = "" 
	closeBtn.AutoButtonColor = false
	closeBtn.LayoutOrder = 3
	closeBtn.ZIndex = 50
	closeBtn.Parent = topbarControls
	ApplyTheme(closeBtn, "Card", "BackgroundColor3")
	ApplyTheme(closeBtn, "CardTrans", "BackgroundTransparency")
	CS:AddTag(closeBtn, "CloseBtnBind")
	
	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = MAIN_CORNER
	closeBtnCorner.Parent = closeBtn
	CS:AddTag(closeBtnCorner, "MainCorner")
	
	attachStroke(closeBtn, "BlockStroke")

	local crossLine1 = Instance.new("Frame")
	crossLine1.Name = "CrossLine1"
	crossLine1.Size = UDim2.new(0, 14, 0, 1) 
	crossLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
	crossLine1.AnchorPoint = Vector2.new(0.5, 0.5)
	crossLine1.Rotation = 45
	crossLine1.BorderSizePixel = 0
	crossLine1.Parent = closeBtn
	ApplyTheme(crossLine1, "TextMuted", "BackgroundColor3")

	local crossLine2 = crossLine1:Clone()
	crossLine2.Name = "CrossLine2"
	crossLine2.Rotation = -45
	crossLine2.Parent = closeBtn

	local profileBlock = Instance.new("Frame")
	profileBlock.Name = "ProfileBlock"
	profileBlock.AutomaticSize = Enum.AutomaticSize.X 
	profileBlock.Size = UDim2.new(0, 0, 0, 42)
	profileBlock.LayoutOrder = 2
	profileBlock.Parent = topbarControls
	ApplyTheme(profileBlock, "Card", "BackgroundColor3")
	ApplyTheme(profileBlock, "CardTrans", "BackgroundTransparency")
	CS:AddTag(profileBlock, "ProfileBlockBind")
	
	local profileBlockCorner = Instance.new("UICorner")
	profileBlockCorner.CornerRadius = MAIN_CORNER
	profileBlockCorner.Parent = profileBlock
	CS:AddTag(profileBlockCorner, "MainCorner")
	
	attachStroke(profileBlock, "BlockStroke")

	do
		local profilePadding = Instance.new("UIPadding")
		profilePadding.Name = "ProfilePadding"
		profilePadding.PaddingLeft = UDim.new(0, 15)
		profilePadding.PaddingRight = UDim.new(0, 5)
		profilePadding.Parent = profileBlock

		local profileLayout = Instance.new("UIListLayout")
		profileLayout.Name = "ProfileLayout"
		profileLayout.FillDirection = Enum.FillDirection.Horizontal
		profileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
		profileLayout.Padding = UDim.new(0, 10)
		profileLayout.Parent = profileBlock

		local namesContainer = Instance.new("Frame")
		namesContainer.Name = "NamesContainer"
		namesContainer.AutomaticSize = Enum.AutomaticSize.X
		namesContainer.Size = UDim2.new(0, 0, 1, 0)
		namesContainer.BackgroundTransparency = 1
		namesContainer.LayoutOrder = 1
		namesContainer.Parent = profileBlock

		local namesLayout = Instance.new("UIListLayout")
		namesLayout.Name = "NamesLayout"
		namesLayout.FillDirection = Enum.FillDirection.Vertical
		namesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		namesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		namesLayout.Padding = UDim.new(0, 2)
		namesLayout.Parent = namesContainer

		local displayName = Instance.new("TextLabel")
		displayName.Name = "DisplayName"
		displayName.AutomaticSize = Enum.AutomaticSize.X
		displayName.Size = UDim2.new(0, 0, 0, 14)
		displayName.BackgroundTransparency = 1
		displayName.TextSize = 13
		displayName.Text = LP.DisplayName
		displayName.TextTruncate = Enum.TextTruncate.AtEnd
		displayName.Parent = namesContainer
		ApplyTheme(displayName, "Text", "TextColor3")
		ApplyTheme(displayName, "TextFont", "Font")

		local userName = Instance.new("TextLabel")
		userName.Name = "UserName"
		userName.AutomaticSize = Enum.AutomaticSize.X
		userName.Size = UDim2.new(0, 0, 0, 12)
		userName.BackgroundTransparency = 1
		userName.TextSize = 11
		userName.Text = "@" .. LP.Name
		userName.TextTruncate = Enum.TextTruncate.AtEnd
		userName.Parent = namesContainer
		ApplyTheme(userName, "TextMuted", "TextColor3")
		ApplyTheme(userName, "SubtextFont", "Font")

		local avatarImage = Instance.new("ImageLabel")
		avatarImage.Name = "AvatarImage"
		avatarImage.Size = UDim2.new(0, 32, 0, 32)
		avatarImage.BackgroundTransparency = 1
		avatarImage.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		avatarImage.LayoutOrder = 2
		avatarImage.Parent = profileBlock
		
		local avatarCorner = Instance.new("UICorner")
		avatarCorner.CornerRadius = UDim.new(1, 0)
		avatarCorner.Parent = avatarImage
	end

	local searchContainer = Instance.new("Frame")
	searchContainer.Name = "SearchContainer"
	searchContainer.Size = UDim2.new(0, 230, 0, 42)
	searchContainer.ClipsDescendants = true
	searchContainer.LayoutOrder = 1
	searchContainer.Parent = topbarControls
	ApplyTheme(searchContainer, "Card", "BackgroundColor3")
	ApplyTheme(searchContainer, "CardTrans", "BackgroundTransparency")
	CS:AddTag(searchContainer, "SearchContainerBind")
	
	local searchContainerCorner = Instance.new("UICorner")
	searchContainerCorner.CornerRadius = MAIN_CORNER
	searchContainerCorner.Parent = searchContainer
	CS:AddTag(searchContainerCorner, "MainCorner")
	
	attachStroke(searchContainer, "BlockStroke")

	local searchInput = Instance.new("TextBox")
	searchInput.Name = "SearchInput"
	searchInput.Size = UDim2.new(1, -45, 1, 0)
	searchInput.Position = UDim2.new(0, 15, 0, 0)
	searchInput.BackgroundTransparency = 1
	searchInput.TextSize = 13
	searchInput.PlaceholderText = searchPlaceholder
	searchInput.Text = ""
	searchInput.ClipsDescendants = true
	searchInput.TextXAlignment = Enum.TextXAlignment.Left
	searchInput.Parent = searchContainer
	ApplyTheme(searchInput, "Text", "TextColor3")
	ApplyTheme(searchInput, "TextMuted", "PlaceholderColor3")
	ApplyTheme(searchInput, "TextFont", "Font")

	local searchIcon = Instance.new("ImageLabel")
	searchIcon.Name = "SearchIcon"
	searchIcon.Size = UDim2.new(0, 20, 0, 20)
	searchIcon.Position = UDim2.new(1, -32, 0.5, -10)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Image = SEARCH_ICON_ID
	searchIcon.Parent = searchContainer
	ApplyTheme(searchIcon, "TextMuted", "ImageColor3")

	local pagesFolder = Instance.new("Frame")
	pagesFolder.Name = "PagesFolder"
	pagesFolder.Size = UDim2.new(1, -currentSidebarWidth, 1, -60) 
	pagesFolder.Position = UDim2.new(0, currentSidebarWidth, 0, 60)
	pagesFolder.BackgroundTransparency = 1
	pagesFolder.ClipsDescendants = true
	pagesFolder.ZIndex = 5
	pagesFolder.Parent = main

	local searchPage = Instance.new("Frame")
	searchPage.Name = "SearchPage"
	searchPage.Size = UDim2.new(1, 0, 1, 0)
	searchPage.Position = UDim2.new(0, 0, 0, 0)
	searchPage.BackgroundTransparency = 1
	searchPage.ClipsDescendants = true
	searchPage.Visible = false
	searchPage.Parent = pagesFolder

	local searchPageContent = Instance.new("ScrollingFrame")
	searchPageContent.Name = "PageContent"
	searchPageContent.Size = UDim2.new(1, 0, 1, 0)
	searchPageContent.BackgroundTransparency = 1
	searchPageContent.ScrollBarThickness = 0
	searchPageContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	searchPageContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	searchPageContent.Parent = searchPage
	
	local spPadding = Instance.new("UIPadding")
	spPadding.PaddingTop = UDim.new(0, 14) 
	spPadding.PaddingBottom = UDim.new(0, 14)
	spPadding.PaddingLeft = UDim.new(0, 14)
	spPadding.PaddingRight = UDim.new(0, 14)
	spPadding.Parent = searchPageContent

	local spLayout = Instance.new("UIListLayout")
	spLayout.FillDirection = Enum.FillDirection.Horizontal
	spLayout.SortOrder = Enum.SortOrder.LayoutOrder
	spLayout.Padding = UDim.new(0, 14)
	spLayout.Parent = searchPageContent

	local searchLeftCol = Instance.new("Frame")
	searchLeftCol.Size = UDim2.new(0.5, -7, 0, 0)
	searchLeftCol.AutomaticSize = Enum.AutomaticSize.Y
	searchLeftCol.BackgroundTransparency = 1
	searchLeftCol.Parent = searchPageContent
	local slLayout = Instance.new("UIListLayout")
	slLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slLayout.Padding = UDim.new(0, 14)
	slLayout.Parent = searchLeftCol

	local searchRightCol = Instance.new("Frame")
	searchRightCol.Size = UDim2.new(0.5, -7, 0, 0)
	searchRightCol.AutomaticSize = Enum.AutomaticSize.Y
	searchRightCol.BackgroundTransparency = 1
	searchRightCol.Parent = searchPageContent
	local srLayout = Instance.new("UIListLayout")
	srLayout.SortOrder = Enum.SortOrder.LayoutOrder
	srLayout.Padding = UDim.new(0, 14)
	srLayout.Parent = searchRightCol

	local function updateSearchTabStyle(style)
		if style == 3 or style == 4 then
			searchLeftCol.Size = UDim2.new(0.5, -4, 0, 0)
			searchRightCol.Size = UDim2.new(0.5, -4, 0, 0)
			spPadding.PaddingTop = UDim.new(0, 8)
			spPadding.PaddingBottom = UDim.new(0, 8)
			spPadding.PaddingLeft = UDim.new(0, 8)
			spPadding.PaddingRight = UDim.new(0, 8)
			spLayout.Padding = UDim.new(0, 8)
			slLayout.Padding = UDim.new(0, 8)
			srLayout.Padding = UDim.new(0, 8)
		else
			searchLeftCol.Size = UDim2.new(0.5, -7, 0, 0)
			searchRightCol.Size = UDim2.new(0.5, -7, 0, 0)
			spPadding.PaddingTop = UDim.new(0, 14)
			spPadding.PaddingBottom = UDim.new(0, 14)
			spPadding.PaddingLeft = UDim.new(0, 14)
			spPadding.PaddingRight = UDim.new(0, 14)
			spLayout.Padding = UDim.new(0, 14)
			slLayout.Padding = UDim.new(0, 14)
			srLayout.Padding = UDim.new(0, 14)
		end
	end
	table.insert(Window._styleCallbacks, updateSearchTabStyle)
	updateSearchTabStyle(THEME.ElementStyle)

	local function ConstructBlockUI(bName, bIcon, parent)
		local blockContainer = Instance.new("Frame")
		blockContainer.Name = bName .. "_Block"
		blockContainer.Size = UDim2.new(1, 0, 0, 0)
		blockContainer.AutomaticSize = Enum.AutomaticSize.Y
		blockContainer.Parent = parent
		ApplyTheme(blockContainer, "Card", "BackgroundColor3")
		ApplyTheme(blockContainer, "CardTrans", "BackgroundTransparency")
		
		local currentElRadius = 6
		for _, c in ipairs(CS:GetTagged("ElementCorner")) do
			currentElRadius = c.CornerRadius.Offset
			break
		end
		
		local blockContainerCorner = Instance.new("UICorner")
		blockContainerCorner.CornerRadius = UDim.new(0, currentElRadius)
		blockContainerCorner.Parent = blockContainer
		CS:AddTag(blockContainerCorner, "ElementCorner")

		local blockStroke = Instance.new("UIStroke")
		blockStroke.Name = "BlockStroke"
		blockStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
		blockStroke.Thickness = 1
		blockStroke.Parent = blockContainer
		ApplyTheme(blockStroke, "Outlines", "Color")
		CS:AddTag(blockStroke, "BlockStroke")

		local blockPadding = Instance.new("UIPadding")
		blockPadding.Name = "BlockPadding"
		blockPadding.PaddingTop = UDim.new(0, 12)
		blockPadding.PaddingBottom = UDim.new(0, 12)
		blockPadding.PaddingLeft = UDim.new(0, 12)
		blockPadding.PaddingRight = UDim.new(0, 12)
		blockPadding.Parent = blockContainer

		local blockLayout = Instance.new("UIListLayout")
		blockLayout.Name = "BlockLayout"
		blockLayout.FillDirection = Enum.FillDirection.Vertical
		blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
		blockLayout.Padding = UDim.new(0, 6)
		blockLayout.Parent = blockContainer

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, 20)
		header.BackgroundTransparency = 1
		header.LayoutOrder = 0
		header.Parent = blockContainer

		local headerLayout = Instance.new("UIListLayout")
		headerLayout.Name = "HeaderLayout"
		headerLayout.FillDirection = Enum.FillDirection.Horizontal
		headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		headerLayout.Padding = UDim.new(0, 8)
		headerLayout.Parent = header

		local blockIconLabel
		if bIcon and bIcon ~= "" then
			blockIconLabel = Instance.new("ImageLabel")
			blockIconLabel.Name = "BlockIcon"
			blockIconLabel.Size = UDim2.new(0, 26, 0, 26)
			blockIconLabel.BackgroundTransparency = 1
			blockIconLabel.Image = bIcon
			blockIconLabel.Parent = header
			ApplyTheme(blockIconLabel, "Text", "ImageColor3")
		end

		local blockTitle = Instance.new("TextLabel")
		blockTitle.Name = "BlockTitle"
		blockTitle.AutomaticSize = Enum.AutomaticSize.X
		blockTitle.Size = UDim2.new(0, 0, 1, 0)
		blockTitle.BackgroundTransparency = 1
		blockTitle.TextSize = 13
		blockTitle.TextTruncate = Enum.TextTruncate.AtEnd
		blockTitle.Text = bName
		blockTitle.Parent = header
		ApplyTheme(blockTitle, "Text", "TextColor3")
		ApplyTheme(blockTitle, "TextFont", "Font")

		local blockDivider = Instance.new("Frame")
		blockDivider.Name = "BlockDivider"
		blockDivider.Size = UDim2.new(1, 0, 0, 1)
		blockDivider.BorderSizePixel = 0
		blockDivider.LayoutOrder = 1
		blockDivider.Parent = blockContainer
		ApplyTheme(blockDivider, "Outlines", "BackgroundColor3")

		local function updateBlockStyle(style)
			if style == 3 or style == 4 then
				blockPadding.PaddingTop = UDim.new(0, 8)
				blockPadding.PaddingBottom = UDim.new(0, 8)
				blockPadding.PaddingLeft = UDim.new(0, 8)
				blockPadding.PaddingRight = UDim.new(0, 8)
				blockLayout.Padding = UDim.new(0, 4)
				header.Size = UDim2.new(1, 0, 0, 22)
				if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 22, 0, 22) end
			else
				blockPadding.PaddingTop = UDim.new(0, 12)
				blockPadding.PaddingBottom = UDim.new(0, 12)
				blockPadding.PaddingLeft = UDim.new(0, 12)
				blockPadding.PaddingRight = UDim.new(0, 12)
				blockLayout.Padding = UDim.new(0, 6)
				header.Size = UDim2.new(1, 0, 0, 26)
				if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 26, 0, 26) end
			end
		end
		table.insert(Window._styleCallbacks, updateBlockStyle)
		updateBlockStyle(THEME.ElementStyle)

		return blockContainer
	end

	table.insert(Window._connections, searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(searchInput.Text)
		if q == "" then
			for _, entry in ipairs(Window._searchRegistry) do
				entry.UI.Parent = entry.OriginalParent
			end
			for _, b in ipairs(searchLeftCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end
			for _, b in ipairs(searchRightCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end
			
			searchPage.Visible = false
			if Window.CurrentTab and Window.CurrentTab.Page then
				Window.CurrentTab.Page.Visible = true
			end
		else
			if Window.CurrentTab and Window.CurrentTab.Page then
				Window.CurrentTab.Page.Visible = false
			end
			for _, entry in ipairs(Window._searchRegistry) do
				entry.UI.Parent = entry.OriginalParent
			end
			for _, b in ipairs(searchLeftCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end
			for _, b in ipairs(searchRightCol:GetChildren()) do if b:IsA("Frame") then b:Destroy() end end

			local matchedGroups = { Left = {}, Right = {} }
			local blocksOrder = { Left = {}, Right = {} }

			for _, entry in ipairs(Window._searchRegistry) do
				if string.find(entry.Name, q) then
					local side = entry.BlockSide
					local bName = entry.BlockName
					if not matchedGroups[side][bName] then
						matchedGroups[side][bName] = { Icon = entry.BlockIcon, Elements = {} }
						table.insert(blocksOrder[side], bName)
					end
					table.insert(matchedGroups[side][bName].Elements, entry)
				end
			end

			for side, col in pairs({ Left = searchLeftCol, Right = searchRightCol }) do
				for _, bName in ipairs(blocksOrder[side]) do
					local data = matchedGroups[side][bName]
					local mockBlock = ConstructBlockUI(bName, data.Icon, col)
					for _, entry in ipairs(data.Elements) do
						entry.UI.Parent = mockBlock
					end
				end
			end
			searchPage.Visible = true
		end
	end))

	local sidebarResizer = Instance.new("TextButton")
	sidebarResizer.Name = "SidebarResizer"
	sidebarResizer.Size = UDim2.new(0, 12, 1, 0)
	sidebarResizer.Position = UDim2.new(0, currentSidebarWidth, 0, 0)
	sidebarResizer.AnchorPoint = Vector2.new(0.5, 0)
	sidebarResizer.BackgroundTransparency = 1
	sidebarResizer.Text = ""
	sidebarResizer.AutoButtonColor = false
	sidebarResizer.ZIndex = 25
	sidebarResizer.Parent = main

	local resizerLine = Instance.new("Frame")
	resizerLine.Name = "ResizerLine"
	resizerLine.Size = UDim2.new(0, 1, 1, 0)
	resizerLine.Position = UDim2.new(0.5, 0, 0, 0)
	resizerLine.AnchorPoint = Vector2.new(0.5, 0)
	resizerLine.BorderSizePixel = 0
	resizerLine.Parent = sidebarResizer
	ApplyTheme(resizerLine, "Outlines", "BackgroundColor3")

	local function FullUpdateLayout()
		local isTopOrBottom = (SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom")
		local effWidth = isTopOrBottom and MIN_SIDEBAR_WIDTH or currentSidebarWidth
		local isCollapsed = effWidth < 115
		
		tabListLayout.Padding = UDim.new(0, (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 2 or 4)
		if isTopOrBottom then isCollapsed = true end

		sidebarResizer.Visible = not SIDEBAR_STATE.Detached

		if SIDEBAR_STATE.Detached then
			sidebarBgImage.Visible = true
			svCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
			sidebarBaseCorner.CornerRadius = UDim.new(0, cornerRadiusNum)
			sidebarCorner.CornerRadius = UDim.new(0, cornerRadiusNum)

			sidebar.Parent = contentWrapper
			sidebarVisuals.Parent = contentWrapper
			sidebarOutlineStroke.Enabled = THEME.MainOutlineEnabled
			sidebarOutlineStroke.Transparency = 0
			sidebarFiller.Visible = false
			topbar.Size = UDim2.new(1, 0, 0, 60)
			topbar.Position = UDim2.new(0, 0, 0, 0)
			pagesFolder.Size = UDim2.new(1, 0, 1, -60)
			pagesFolder.Position = UDim2.new(0, 0, 0, 60)
            
			topbarDivider.Size = UDim2.new(1, 0, 0, 1)
			topbarDivider.Position = UDim2.new(0, 0, 0, 60)

			if SIDEBAR_STATE.Position == "Left" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(0, -effWidth - 15, 0, 0)
			elseif SIDEBAR_STATE.Position == "Right" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(1, 15, 0, 0)
			elseif SIDEBAR_STATE.Position == "Top" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 0, -MIN_SIDEBAR_WIDTH - 15)
			elseif SIDEBAR_STATE.Position == "Bottom" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 1, 15)
			end
			
			sidebarVisuals.Size = sidebar.Size
			sidebarVisuals.Position = sidebar.Position
			
			sidebarShadowFolder.Visible = SIDEBAR_STATE.ShadowsEnabled
			sidebarShadowFolder.Size = sidebar.Size
			sidebarShadowFolder.Position = sidebar.Position
		else
			sidebarBgImage.Visible = false
			svCorner.CornerRadius = UDim.new(0, 0)
			sidebarBaseCorner.CornerRadius = UDim.new(0, 0)
			sidebarCorner.CornerRadius = UDim.new(0, 0)

			sidebar.Parent = main
			sidebarVisuals.Parent = main
			sidebarOutlineStroke.Enabled = false 
			sidebarFiller.Visible = false
			sidebarShadowFolder.Visible = false
			
			if SIDEBAR_STATE.Position == "Left" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(0, 0, 0, 0)
				topbar.Size = UDim2.new(1, -effWidth, 0, 60)
				topbar.Position = UDim2.new(0, effWidth, 0, 0)
				pagesFolder.Size = UDim2.new(1, -effWidth, 1, -60)
				pagesFolder.Position = UDim2.new(0, effWidth, 0, 60)
				topbarDivider.Size = UDim2.new(1, -effWidth, 0, 1)
				topbarDivider.Position = UDim2.new(0, effWidth, 0, 60)
				
				sidebarResizer.Size = UDim2.new(0, 12, 1, 0)
				sidebarResizer.Position = UDim2.new(0, effWidth, 0, 0)
				sidebarResizer.AnchorPoint = Vector2.new(0.5, 0)
				resizerLine.Size = UDim2.new(0, 1, 1, 0)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			elseif SIDEBAR_STATE.Position == "Right" then
				sidebar.Size = UDim2.new(0, effWidth, 1, 0)
				sidebar.Position = UDim2.new(1, -effWidth, 0, 0)
				topbar.Size = UDim2.new(1, -effWidth, 0, 60)
				topbar.Position = UDim2.new(0, 0, 0, 0)
				pagesFolder.Size = UDim2.new(1, -effWidth, 1, -60)
				pagesFolder.Position = UDim2.new(0, 0, 0, 60)
				topbarDivider.Size = UDim2.new(1, -effWidth, 0, 1)
				topbarDivider.Position = UDim2.new(0, 0, 0, 60)
				
				sidebarResizer.Size = UDim2.new(0, 12, 1, 0)
				sidebarResizer.Position = UDim2.new(1, -effWidth, 0, 0)
				sidebarResizer.AnchorPoint = Vector2.new(0.5, 0)
				resizerLine.Size = UDim2.new(0, 1, 1, 0)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			elseif SIDEBAR_STATE.Position == "Top" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 0, 0)
				topbar.Size = UDim2.new(1, 0, 0, 60)
				topbar.Position = UDim2.new(0, 0, 0, MIN_SIDEBAR_WIDTH)
				pagesFolder.Size = UDim2.new(1, 0, 1, -60 - MIN_SIDEBAR_WIDTH)
				pagesFolder.Position = UDim2.new(0, 0, 0, 60 + MIN_SIDEBAR_WIDTH)
				topbarDivider.Size = UDim2.new(1, 0, 0, 1)
				topbarDivider.Position = UDim2.new(0, 0, 0, 60 + MIN_SIDEBAR_WIDTH)
				
				sidebarResizer.Size = UDim2.new(1, 0, 0, 12)
				sidebarResizer.Position = UDim2.new(0, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebarResizer.AnchorPoint = Vector2.new(0, 0.5)
				resizerLine.Size = UDim2.new(1, 0, 0, 1)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			elseif SIDEBAR_STATE.Position == "Bottom" then
				sidebar.Size = UDim2.new(1, 0, 0, MIN_SIDEBAR_WIDTH)
				sidebar.Position = UDim2.new(0, 0, 1, -MIN_SIDEBAR_WIDTH)
				topbar.Size = UDim2.new(1, 0, 0, 60)
				topbar.Position = UDim2.new(0, 0, 0, 0)
				pagesFolder.Size = UDim2.new(1, 0, 1, -60 - MIN_SIDEBAR_WIDTH)
				pagesFolder.Position = UDim2.new(0, 0, 0, 60)
				topbarDivider.Size = UDim2.new(1, 0, 0, 1)
				topbarDivider.Position = UDim2.new(0, 0, 0, 60)
				
				sidebarResizer.Size = UDim2.new(1, 0, 0, 12)
				sidebarResizer.Position = UDim2.new(0, 0, 1, -MIN_SIDEBAR_WIDTH)
				sidebarResizer.AnchorPoint = Vector2.new(0, 0.5)
				resizerLine.Size = UDim2.new(1, 0, 0, 1)
				resizerLine.Position = UDim2.new(0.5, 0, 0.5, 0)
				resizerLine.AnchorPoint = Vector2.new(0.5, 0.5)
			end
			sidebarVisuals.Size = sidebar.Size
			sidebarVisuals.Position = sidebar.Position
		end

		if isTopOrBottom then
			logoContainer.Size = UDim2.new(0, 60, 1, 0)
			logoContainer.Position = UDim2.new(0, 0, 0, 0)
			logoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			logoPadding.PaddingLeft = UDim.new(0, 15)
			settingsContainer.Visible = true
			settingsContainer.Position = UDim2.new(1, -120, 0, 0)
			tabList.Position = UDim2.new(0, 60, 0, 0)
			tabList.Size = UDim2.new(1, -120, 1, 0)
			tabListLayout.FillDirection = Enum.FillDirection.Horizontal
			tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
			tabList.AutomaticCanvasSize = Enum.AutomaticSize.X
			
			if Window.SettingsTab and Window.SettingsTab.Button then
				Window.SettingsTab.Button.Parent = settingsContainer
				dividerContainer.Parent = settingsContainer
				dividerContainer.Size = UDim2.new(0, 16, 1, 0)
				divider.Size = UDim2.new(0, 1, 0.6, 0)
			end
		else
			logoContainer.Size = UDim2.new(1, 0, 0, 60)
			logoContainer.Position = UDim2.new(0, 0, 0, -2)
			logoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			logoPadding.PaddingLeft = UDim.new(0, 0)
			settingsContainer.Visible = false

			if isCollapsed then
				tabList.Position = UDim2.new(0, 0, 0, 75)
				tabList.Size = UDim2.new(1, 0, 1, (description and type(description) == "string") and -140 or -90)
			else
				tabList.Position = UDim2.new(0, 10, 0, 75)
				tabList.Size = UDim2.new(1, -20, 1, (description and type(description) == "string") and -140 or -90)
			end
			
			tabListLayout.FillDirection = Enum.FillDirection.Vertical
			tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
			tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			
			if Window.SettingsTab and Window.SettingsTab.Button then
				Window.SettingsTab.Button.Parent = tabList
				dividerContainer.Parent = tabList
				dividerContainer.Size = UDim2.new(1, 0, 0, 16)
				divider.Size = UDim2.new(0.8, 0, 0, 1)
			end
		end

		if logoImage then
			logoImage.Visible = true
			if logoLabel then logoLabel.Visible = not isCollapsed end
		else
			if logoLabel then
				logoLabel.Visible = true
				logoLabel.Text = isCollapsed and getFirstChar(title) or title
			end
		end
		if descLabel then descLabel.Visible = not isCollapsed end
		if topbarDescLabel then
			topbarDescLabel.Visible = isCollapsed
		end
		
		local btnSizeList = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 30 or 38
		local iconSizeList = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 22 or 26
		local letterSizeList = (THEME.ElementStyle == 3 or THEME.ElementStyle == 4) and 16 or 18

		for _, tab in ipairs(Window.Tabs) do
			local hasIcon = (tab.Icon ~= nil)
			if isTopOrBottom then
				tab.Button.Size = UDim2.new(0, 36, 0, 36)
				tab.Padding.PaddingLeft = UDim.new(0, 0)
				tab.Padding.PaddingRight = UDim.new(0, 0)
				tab.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				tab.Label.Visible = false

				if hasIcon then
					tab.Icon.Visible = true
					tab.Icon.Size = UDim2.new(0, 30, 0, 30)
					if tab.LetterLabel then tab.LetterLabel.Visible = false end
				else
					if tab.LetterLabel then 
						tab.LetterLabel.Visible = true 
						tab.LetterLabel.Size = UDim2.new(0, 30, 0, 30)
						tab.LetterLabel.TextSize = 24
					end
				end
			else
				if isCollapsed then
					tab.Button.Size = UDim2.new(0, 36, 0, 36)
					tab.Padding.PaddingLeft = UDim.new(0, 0)
					tab.Padding.PaddingRight = UDim.new(0, 0)
					tab.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					tab.Label.Visible = false

					if hasIcon then
						tab.Icon.Visible = true
						tab.Icon.Size = UDim2.new(0, 30, 0, 30)
						if tab.LetterLabel then tab.LetterLabel.Visible = false end
					else
						if tab.LetterLabel then 
							tab.LetterLabel.Visible = true 
							tab.LetterLabel.Size = UDim2.new(0, 30, 0, 30)
							tab.LetterLabel.TextSize = 24
						end
					end
				else
					tab.Button.Size = UDim2.new(1, -4, 0, btnSizeList)
					local isCurrent = (Window.CurrentTab == tab)
					tab.Padding.PaddingLeft = isCurrent and UDim.new(0, 22) or UDim.new(0, 15)
					tab.Padding.PaddingRight = UDim.new(0, 15)
					tab.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
					tab.Label.Visible = true
					tab.Label.Text = tab.Name

					if hasIcon then 
						tab.Icon.Visible = true 
						tab.Icon.Size = UDim2.new(0, iconSizeList, 0, iconSizeList) 
					end
					if tab.LetterLabel then 
						tab.LetterLabel.Visible = false 
						tab.LetterLabel.Size = UDim2.new(0, iconSizeList, 0, iconSizeList)
						tab.LetterLabel.TextSize = letterSizeList 
					end
				end
			end
		end
	end

	local function updateSidebarWidth(newWidth)
		currentSidebarWidth = math.clamp(newWidth, MIN_SIDEBAR_WIDTH, MAX_SIDEBAR_WIDTH)
		savedSidebarWidth = currentSidebarWidth
		local bound = Window._themeControls["Layout & Styles~Sidebar Width"]
		if bound and bound.API:Save().Value ~= currentSidebarWidth then
			bound.API:Set(currentSidebarWidth)
		end
		FullUpdateLayout()
	end

	local resizingSidebar = false
	local resizeSidebarStartPos, resizeSidebarStartWidth

	table.insert(Window._connections, sidebarResizer.InputBegan:Connect(function(input)
		if SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom" then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizingSidebar = true
			resizeSidebarStartPos = input.Position.X
			resizeSidebarStartWidth = currentSidebarWidth
			ApplyTheme(resizerLine, "Accent", "BackgroundColor3")

			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizingSidebar = false
					ApplyTheme(resizerLine, "Outlines", "BackgroundColor3")
					endConn:Disconnect()
				end
			end)
			table.insert(Window._connections, endConn)
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if resizingSidebar and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position.X - resizeSidebarStartPos
			if SIDEBAR_STATE.Position == "Right" then delta = -delta end
			updateSidebarWidth(resizeSidebarStartWidth + delta)
		end
	end))

	table.insert(Window._connections, sidebarResizer.MouseEnter:Connect(function()
		if SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom" then return end
		if not resizingSidebar then
			ApplyTheme(resizerLine, "Accent", "BackgroundColor3")
		end
	end))

	table.insert(Window._connections, sidebarResizer.MouseLeave:Connect(function()
		if SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom" then return end
		if not resizingSidebar then
			ApplyTheme(resizerLine, "Outlines", "BackgroundColor3")
		end
	end))

	local isDestroyed, isUIOpen = false, true
	local animInfo = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local currentActiveTween = nil

	local function getAnimHideTransform(animType)
		if animType == 2 then
			return UDim2.new(0, 0, 0, -20), UDim2.new(1, 0, 1, 0)
		elseif animType == 3 then
			return UDim2.new(0.025, 0, 0.025, 0), UDim2.new(0.95, 0, 0.95, 0)
		elseif animType == 4 then
			return UDim2.new(0, 25, 0, 0), UDim2.new(1, 0, 1, 0)
		else
			return UDim2.new(0, 0, 0, 20), UDim2.new(1, 0, 1, 0)
		end
	end

	local function PlayFadeAnim(show)
		if currentActiveTween then
			currentActiveTween:Cancel()
			currentActiveTween = nil
		end

		local aType = THEME.CloseAnimation or 1
		local hidePos, hideSize = getAnimHideTransform(aType)
		
		if show then
			wrapper.Visible = true
			contentWrapper.Position = hidePos
			contentWrapper.Size = hideSize
			
			currentActiveTween = TS:Create(contentWrapper, animInfo, {
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0)
			})
			currentActiveTween:Play()
			
			TS:Create(main, animInfo, {GroupTransparency = 0}):Play()
			
			if THEME.MainOutlineEnabled then
				TS:Create(mainOutlineStroke, animInfo, {Transparency = 0}):Play()
				if SIDEBAR_STATE.Detached then
					sidebarOutlineStroke.Enabled = true
					TS:Create(sidebarOutlineStroke, animInfo, {Transparency = 0}):Play()
				end
			end
			
			if SIDEBAR_STATE.ShadowsEnabled then
				for _, shadow in ipairs(shadowFolder:GetChildren()) do
					local stroke = shadow:FindFirstChild("ShadowStroke")
					if stroke then 
						stroke.Enabled = true
						TS:Create(stroke, animInfo, {Transparency = stroke:GetAttribute("TargetTransparency") or 0.8}):Play() 
					end
				end
				if SIDEBAR_STATE.Detached then
					for _, shadow in ipairs(sidebarShadowFolder:GetChildren()) do
						local stroke = shadow:FindFirstChild("ShadowStroke")
						if stroke then 
							stroke.Enabled = true
							TS:Create(stroke, animInfo, {Transparency = stroke:GetAttribute("TargetTransparency") or 0.8}):Play() 
						end
					end
				end
			end
			TS:Create(arcOuterStroke, animInfo, {Transparency = 0}):Play()
			TS:Create(topbarDivider, animInfo, {BackgroundTransparency = 0}):Play()
			TS:Create(sidebarDivider, animInfo, {BackgroundTransparency = 0}):Play()
			
		else
			Window.ClosePopup()
			
			currentActiveTween = TS:Create(contentWrapper, animInfo, {
				Position = hidePos,
				Size = hideSize
			})
			currentActiveTween:Play()
			
			TS:Create(main, animInfo, {GroupTransparency = 1}):Play()
			TS:Create(mainOutlineStroke, animInfo, {Transparency = 1}):Play()
			if sidebarOutlineStroke.Enabled then
				TS:Create(sidebarOutlineStroke, animInfo, {Transparency = 1}):Play()
			end
			
			for _, shadow in ipairs(shadowFolder:GetChildren()) do
				local stroke = shadow:FindFirstChild("ShadowStroke")
				if stroke then TS:Create(stroke, animInfo, {Transparency = 1}):Play() end
			end
			for _, shadow in ipairs(sidebarShadowFolder:GetChildren()) do
				local stroke = shadow:FindFirstChild("ShadowStroke")
				if stroke then TS:Create(stroke, animInfo, {Transparency = 1}):Play() end
			end
			TS:Create(arcOuterStroke, animInfo, {Transparency = 1}):Play()
			TS:Create(topbarDivider, animInfo, {BackgroundTransparency = 1}):Play()
			TS:Create(sidebarDivider, animInfo, {BackgroundTransparency = 1}):Play()
			
			
			local animRef = currentActiveTween
			animRef.Completed:Connect(function()
				if not isUIOpen and currentActiveTween == animRef then
					wrapper.Visible = false
				end
			end)
		end
	end

	table.insert(Window._connections, closeBtn.Activated:Connect(function()
		if isDestroyed then return end
		isDestroyed = true
		if Window.IsEditMode then 
			CAS:UnbindAction("AxiomEditSink") 
		end
		pcall(function() Window.ToggleEditMode(false) end)
		
		PlayFadeAnim(false)
		for _, conn in ipairs(Window._connections) do
			if conn.Connected then conn:Disconnect() end
		end
		table.clear(Window._connections)
		task.delay(0.4, function() 
			pcall(function() editModeCC:Destroy() end)
			pcall(function() screenGui:Destroy() end) 
		end)
	end))

	table.insert(Window._connections, closeBtn.MouseEnter:Connect(function() 
		TS:Create(crossLine1, TweenInfo.new(0.2), {BackgroundColor3 = THEME.CloseBtn}):Play() 
		TS:Create(crossLine2, TweenInfo.new(0.2), {BackgroundColor3 = THEME.CloseBtn}):Play() 
	end))
	table.insert(Window._connections, closeBtn.MouseLeave:Connect(function() 
		TS:Create(crossLine1, TweenInfo.new(0.2), {BackgroundColor3 = THEME.TextMuted}):Play() 
		TS:Create(crossLine2, TweenInfo.new(0.2), {BackgroundColor3 = THEME.TextMuted}):Play() 
	end))

	if isMobile then
		local mobileToggleUI = Instance.new("ImageButton")
		mobileToggleUI.Name = "MobileToggleUI"
		mobileToggleUI.Size = UDim2.new(0, 40, 0, 40)
		mobileToggleUI.AnchorPoint = Vector2.new(0.5, 0.5)
		mobileToggleUI.Position = UDim2.new(0.5, 0, 0, 30)
		mobileToggleUI.BackgroundColor3 = THEME.Sidebar
		mobileToggleUI.Image = (logoIconId and logoIconId ~= "") and logoIconId or "rbxassetid://118685771787843"
		mobileToggleUI.ZIndex = 999999
		mobileToggleUI.Parent = screenGui
		
		local mtCorner = Instance.new("UICorner")
		mtCorner.CornerRadius = UDim.new(0, 10)
		mtCorner.Parent = mobileToggleUI
		
		local mtStroke = Instance.new("UIStroke")
		mtStroke.Thickness = 1
		mtStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		mtStroke.Color = THEME.Outlines
		mtStroke.Parent = mobileToggleUI

		local mtDragging, mtDragStart, mtStartPos, mtMoved
		table.insert(Window._connections, mobileToggleUI.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				mtDragging = true
				mtMoved = false
				mtDragStart = input.Position
				mtStartPos = mobileToggleUI.Position
			end
		end))
		table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
			if mtDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - mtDragStart
				if delta.Magnitude > 5 then mtMoved = true end
				mobileToggleUI.Position = UDim2.new(mtStartPos.X.Scale, mtStartPos.X.Offset + delta.X, mtStartPos.Y.Scale, mtStartPos.Y.Offset + delta.Y)
			end
		end))
		table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				mtDragging = false
			end
		end))
		
		table.insert(Window._connections, mobileToggleUI.Activated:Connect(function()
			if mtMoved then return end
			isUIOpen = not isUIOpen
			PlayFadeAnim(isUIOpen)
		end))
	end

	table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
		if not Window._capturingOpenKeybind and input.KeyCode == openKeybind and not UIS:GetFocusedTextBox() then
			isUIOpen = not isUIOpen
			PlayFadeAnim(isUIOpen)
		end
	end))

	local themeEditorContainer = Instance.new("ScrollingFrame")
	themeEditorContainer.Name = "ThemeEditorContainer"
	themeEditorContainer.Size = UDim2.new(0, 565, 1, -40)
	themeEditorContainer.Position = UDim2.new(0, 20, 0.5, 0)
	themeEditorContainer.AnchorPoint = Vector2.new(0, 0.5)
	themeEditorContainer.BackgroundTransparency = 0.06
	themeEditorContainer.BorderSizePixel = 0
	ApplyTheme(themeEditorContainer, "Background", "BackgroundColor3")
	themeEditorContainer.ZIndex = 70
	themeEditorContainer.Visible = false
	themeEditorContainer.ScrollBarThickness = 0
	themeEditorContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	themeEditorContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	themeEditorContainer.Parent = screenGui

	local teScale = Instance.new("UIScale")
	teScale.Scale = isMobile and 0.65 or 1
	teScale.Parent = themeEditorContainer
	local themePanelCorner = Instance.new("UICorner")
	themePanelCorner.CornerRadius = UDim.new(0, 13)
	themePanelCorner.Parent = themeEditorContainer
	local themePanelStroke = Instance.new("UIStroke")
	themePanelStroke.Thickness = 1.5
	themePanelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	themePanelStroke.Parent = themeEditorContainer
	ApplyTheme(themePanelStroke, "Outlines", "Color")
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255), THEME.Outlines)
	panelGradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(1, 0.88)})
	panelGradient.Parent = themePanelStroke
	local editorDock = 1
	local editorBar = Instance.new("Frame")
	editorBar.Name = "AxiomEditorToolbar"
	editorBar.Size = UDim2.fromOffset(360, 34)
	editorBar.BackgroundTransparency = 0.08
	editorBar.BorderSizePixel = 0
	editorBar.ZIndex = 80
	editorBar.Visible = false
	editorBar.Parent = screenGui
	ApplyTheme(editorBar, "Card", "BackgroundColor3")
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 10)
	barCorner.Parent = editorBar
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 1
	barStroke.Color = THEME.Accent
	barStroke.Parent = editorBar
	local barTitle = Instance.new("TextLabel")
	barTitle.Size = UDim2.new(1, -146, 1, 0)
	barTitle.Position = UDim2.fromOffset(12, 0)
	barTitle.BackgroundTransparency = 1
	barTitle.Text = "AXIOM  /  LIVE EDITOR"
	barTitle.TextXAlignment = Enum.TextXAlignment.Left
	barTitle.TextSize = 11
	barTitle.ZIndex = 81
	barTitle.Parent = editorBar
	ApplyTheme(barTitle, "Text", "TextColor3")
	ApplyTheme(barTitle, "TextFont", "Font")
	local function addEditorButton(text, offset)
		local button = Instance.new("TextButton")
		button.Name = "Editor" .. text
		button.Size = UDim2.fromOffset(60, 25)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, offset, 0.5, 0)
		button.BackgroundTransparency = 0.18
		button.Text = text
		button.TextSize = 11
		button.ZIndex = 81
		button.Parent = editorBar
		ApplyTheme(button, "Element", "BackgroundColor3")
		ApplyTheme(button, "Text", "TextColor3")
		ApplyTheme(button, "TextFont", "Font")
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Parent = button
		ApplyTheme(stroke, "Outlines", "Color")
		return button
	end
	local editModeToggleAPI
	local editorDockButton = addEditorButton("Dock", -78)
	local editorExitButton = addEditorButton("Close", -10)
	editorDockButton.MouseButton1Click:Connect(function() editorDock = editorDock % 3 + 1 end)
	editorExitButton.MouseButton1Click:Connect(function()
		if editModeToggleAPI then editModeToggleAPI:Set(false) else Window.ToggleEditMode(false) end
	end)

	local themeEditorPad = Instance.new("UIPadding")
	themeEditorPad.PaddingTop = UDim.new(0, 15)
	themeEditorPad.PaddingBottom = UDim.new(0, 15)
	themeEditorPad.Parent = themeEditorContainer

	local themeEditorLayout = Instance.new("UIListLayout")
	themeEditorLayout.Name = "ThemeEditorLayout"
	themeEditorLayout.FillDirection = Enum.FillDirection.Horizontal
	themeEditorLayout.Padding = UDim.new(0, 15)
	themeEditorLayout.SortOrder = Enum.SortOrder.LayoutOrder
	themeEditorLayout.Parent = themeEditorContainer
	
	local themeEditorLeft = Instance.new("Frame")
	themeEditorLeft.Name = "ThemeLeftCol"
	themeEditorLeft.Size = UDim2.new(0.5, -7, 0, 0)
	themeEditorLeft.AutomaticSize = Enum.AutomaticSize.Y
	themeEditorLeft.BackgroundTransparency = 1
	themeEditorLeft.Parent = themeEditorContainer

	local tlLayout = Instance.new("UIListLayout")
	tlLayout.Padding = UDim.new(0, 15)
	tlLayout.Parent = themeEditorLeft

	local themeEditorRight = Instance.new("Frame")
	themeEditorRight.Name = "ThemeRightCol"
	themeEditorRight.Size = UDim2.new(0.5, -7, 0, 0)
	themeEditorRight.AutomaticSize = Enum.AutomaticSize.Y
	themeEditorRight.BackgroundTransparency = 1
	themeEditorRight.Parent = themeEditorContainer

	local trLayout = Instance.new("UIListLayout")
	trLayout.Padding = UDim.new(0, 15)
	trLayout.Parent = themeEditorRight

	local function updateThemeLayout(style)
		if style == 3 or style == 4 then
			themeEditorPad.PaddingTop = UDim.new(0, 8)
			themeEditorPad.PaddingBottom = UDim.new(0, 8)
			themeEditorLayout.Padding = UDim.new(0, 8)
			tlLayout.Padding = UDim.new(0, 8)
			trLayout.Padding = UDim.new(0, 8)
		else
			themeEditorPad.PaddingTop = UDim.new(0, 15)
			themeEditorPad.PaddingBottom = UDim.new(0, 15)
			themeEditorLayout.Padding = UDim.new(0, 15)
			tlLayout.Padding = UDim.new(0, 15)
			trLayout.Padding = UDim.new(0, 15)
		end
	end
	table.insert(Window._styleCallbacks, updateThemeLayout)
	updateThemeLayout(THEME.ElementStyle)

	local editModeBlur = Instance.new("BlurEffect")
	editModeBlur.Name = "AxiomEditBlur"
	editModeBlur.Size = 0
	editModeBlur.Parent = Lighting
	table.insert(Window._connections, screenGui.Destroying:Connect(function()
		editModeBlur:Destroy()
	end))
	local editModeLoop
	local editorLayoutClock = 0
	local editorToken = 0
	local function placeEditor()
		local viewport = screenGui.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then return end
		local compact = viewport.X < 850
		local width = compact and math.min(360, viewport.X - 24) or math.min(520, math.max(300, viewport.X * 0.34))
		local height = compact and math.min(370, viewport.Y * 0.47) or math.min(viewport.Y - 75, math.max(260, main.AbsoluteSize.Y - 16))
		local rightX = main.AbsolutePosition.X + main.AbsoluteSize.X + 12
		local leftX = main.AbsolutePosition.X - width - 12
		local rightFits = rightX + width < viewport.X - 10
		local leftFits = leftX > 10
		local x
		if editorDock == 1 and rightFits then x = rightX
		elseif editorDock == 2 and leftFits then x = leftX
		elseif editorDock == 3 then x = main.AbsolutePosition.X + main.AbsoluteSize.X * 0.5 - width * 0.5
		elseif rightFits then x = rightX
		elseif leftFits then x = leftX
		else x = viewport.X - width - 12 end
		x = math.clamp(x, 10, math.max(10, viewport.X - width - 10))
		local y = math.clamp(main.AbsolutePosition.Y, 42, math.max(42, viewport.Y - height - 12))
		if compact then y = math.max(42, viewport.Y - height - 12) end
		editorBar.Position = UDim2.fromOffset(x, y - 37)
		editorBar.Size = UDim2.fromOffset(width, 33)
		themeEditorContainer.AnchorPoint = Vector2.new(0, 0)
		themeEditorContainer.Size = UDim2.fromOffset(width, height)
		themeEditorContainer.Position = UDim2.fromOffset(x, y)
	end
	Window.ToggleEditMode = function(state)
		state = state == true
		if Window.IsEditMode == state then return end
		Window.IsEditMode = state
		editorToken += 1
		local token = editorToken
		if state then
			placeEditor()
			editModeDim.Visible = true
			editorBar.Visible = true
			themeEditorContainer.Visible = true
			local normal = isMobile and 0.65 or 1
			teScale.Scale = normal * 0.95
			TS:Create(teScale, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = normal}):Play()
			TS:Create(editModeDim, TweenInfo.new(0.3), {BackgroundTransparency = 0.43}):Play()
			editModeLoop = RS.RenderStepped:Connect(function(dt)
				UIS.MouseIconEnabled = true
				UIS.MouseBehavior = Enum.MouseBehavior.Default
				editorLayoutClock += dt
				if editorLayoutClock >= 0.08 then editorLayoutClock = 0; placeEditor() end
			end)
			CAS:BindAction("AxiomEditSink", function() return Enum.ContextActionResult.Sink end, false,
				Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3,
				Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space)
			TS:Create(editModeCC, TweenInfo.new(0.32), {Saturation = -0.12, Brightness = -0.16}):Play()
			TS:Create(editModeBlur, TweenInfo.new(0.32), {Size = isMobile and 7 or 12}):Play()
		else
			if editModeLoop then editModeLoop:Disconnect(); editModeLoop = nil end
			CAS:UnbindAction("AxiomEditSink")
			TS:Create(editModeCC, TweenInfo.new(0.3), {Saturation = 0, Brightness = 0}):Play()
			TS:Create(editModeBlur, TweenInfo.new(0.3), {Size = 0}):Play()
			TS:Create(editModeDim, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
			TS:Create(teScale, TweenInfo.new(0.22), {Scale = (isMobile and 0.65 or 1) * 0.96}):Play()
			task.delay(0.3, function()
				if token == editorToken then
					themeEditorContainer.Visible = false
					editorBar.Visible = false
					editModeDim.Visible = false
				end
			end)
		end
	end

	local function BuildElementAPI(blockContainer, bName, bIcon, bSide, tabName, isSettings)
		local BlockObj = {}
		local elementCount = 2

		local function RegisterElementAPI(type, elName, api)
			if not bName or not tabName or not elName then return end
			local uniqueId = tabName .. "~" .. bName .. "~" .. elName
			if isSettings then
				Window._themeElements[uniqueId] = { Type = type, API = api }
				Window._themeControls[bName .. "~" .. elName] = { Type = type, API = api }
				return
			end
			Window._configElements[uniqueId] = { Type = type, API = api }
		end

		local function RegisterElement(name, container)
			elementCount = elementCount + 1
			container.LayoutOrder = elementCount
			if bName and bSide and not isSettings then
				table.insert(Window._searchRegistry, {
					Name = string.lower(tostring(name)),
					UI = container,
					OriginalParent = blockContainer,
					BlockName = bName,
					BlockIcon = bIcon,
					BlockSide = bSide
				})
			end
		end

		local function CreateElementBase(height)
			local elContainer = Instance.new("Frame")
			elContainer.Name = "ElementContainer"
			elContainer.Size = UDim2.new(1, 0, 0, height or 38)
			elContainer.BorderSizePixel = 0
			elContainer.LayoutOrder = 2
			elContainer.Parent = blockContainer
			ApplyTheme(elContainer, "Element", "BackgroundColor3")
			ApplyTheme(elContainer, "ElementTrans", "BackgroundTransparency")
			
			local elContainerCorner = Instance.new("UICorner")
			elContainerCorner.CornerRadius = GLOBAL_CORNER
			elContainerCorner.Parent = elContainer
			CS:AddTag(elContainerCorner, "ElementCorner")
			
			local elStroke = Instance.new("UIStroke")
			elStroke.Name = "ElementStroke"
			elStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
			elStroke.Thickness = 1
			elStroke.Parent = elContainer
			ApplyTheme(elStroke, "Outlines", "Color")
			CS:AddTag(elStroke, "ElementStroke")

			return elContainer
		end
		
		local function AttachColorPicker(previewBox, initialColor, callback)
			local h, s, v = initialColor:ToHSV()
			local currentColor = initialColor
			
			local popup = Instance.new("CanvasGroup")
			popup.Name = "ColorPopup"
			popup.BorderSizePixel = 0
			popup.AnchorPoint = Vector2.new(1, 0)
			popup.GroupTransparency = 1
			popup.Visible = false
			popup.ZIndex = 100000
			popup.Parent = screenGui 
			ApplyTheme(popup, "Background", "BackgroundColor3")
			ApplyTheme(popup, "BackgroundTrans", "BackgroundTransparency")
			
			local popupCorner = Instance.new("UICorner")
			popupCorner.CornerRadius = UDim.new(0, 10)
			popupCorner.Parent = popup
			CS:AddTag(popupCorner, "ElementCorner")
			
			local popupStroke = attachStroke(popup, "ElementStroke")

			local popupPadding = Instance.new("UIPadding")
			popupPadding.Name = "PopupPadding"
			popupPadding.PaddingTop = UDim.new(0, 10)
			popupPadding.PaddingBottom = UDim.new(0, 10)
			popupPadding.PaddingLeft = UDim.new(0, 10)
			popupPadding.PaddingRight = UDim.new(0, 10)
			popupPadding.Parent = popup

			local popupLayout = Instance.new("UIListLayout")
			popupLayout.Name = "PopupLayout"
			popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
			popupLayout.Padding = UDim.new(0, 10)
			popupLayout.Parent = popup

			local rgbContainer = Instance.new("Frame")
			rgbContainer.Name = "RGBContainer"
			rgbContainer.Size = UDim2.new(1, 0, 0, 24)
			rgbContainer.BackgroundTransparency = 1
			rgbContainer.LayoutOrder = 1
			rgbContainer.Parent = popup

			local rgbLayout = Instance.new("UIListLayout")
			rgbLayout.FillDirection = Enum.FillDirection.Horizontal
			rgbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			rgbLayout.Padding = UDim.new(0, 8)
			rgbLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rgbLayout.Parent = rgbContainer

			local rInput, gInput, bInput
			local function createRGBBox(name, order, prefix)
				local box = Instance.new("Frame")
				box.Name = name .. "Box"
				box.Size = UDim2.new(0, 48, 1, 0)
				box.LayoutOrder = order
				box.Parent = rgbContainer
				ApplyTheme(box, "Input", "BackgroundColor3")
				ApplyTheme(box, "InputTrans", "BackgroundTransparency")

				local corner = Instance.new("UICorner")
				corner.CornerRadius = GLOBAL_CORNER
				corner.Parent = box
				CS:AddTag(corner, "ElementCorner")

				attachStroke(box, "ElementStroke")

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(0, 16, 1, 0)
				lbl.Position = UDim2.new(0, 4, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = prefix
				lbl.TextSize = 11
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = box
				ApplyTheme(lbl, "TextMuted", "TextColor3")
				ApplyTheme(lbl, "TextFont", "Font")

				local inp = Instance.new("TextBox")
				inp.Size = UDim2.new(1, -20, 1, 0)
				inp.Position = UDim2.new(0, 16, 0, 0)
				inp.BackgroundTransparency = 1
				inp.Text = "255"
				inp.TextSize = 11
				inp.Font = Enum.Font.Gotham
				inp.TextXAlignment = Enum.TextXAlignment.Center
				inp.Parent = box
				ApplyTheme(inp, "Text", "TextColor3")
				ApplyTheme(inp, "TextFont", "Font")
				return inp
			end

			rInput = createRGBBox("R", 1, "R:")
			gInput = createRGBBox("G", 2, "G:")
			bInput = createRGBBox("B", 3, "B:")

			local svSquare = Instance.new("TextButton")
			svSquare.Name = "SVSquare"
			svSquare.Size = UDim2.new(1, 0, 0, 160)
			svSquare.BackgroundColor3 = Color3.new(1, 1, 1)
			svSquare.BorderSizePixel = 0
			svSquare.AutoButtonColor = false
			svSquare.Text = ""
			svSquare.LayoutOrder = 2
			svSquare.Parent = popup
			
			local svSquareCorner = Instance.new("UICorner")
			svSquareCorner.CornerRadius = UDim.new(0, 6)
			svSquareCorner.Parent = svSquare
			CS:AddTag(svSquareCorner, "ElementCorner")

			local hueOverlay = Instance.new("Frame")
			hueOverlay.Name = "HueOverlay"
			hueOverlay.Size = UDim2.new(1, 0, 1, 0)
			hueOverlay.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			hueOverlay.BorderSizePixel = 0
			hueOverlay.Parent = svSquare
			
			local hueOverlayCorner = Instance.new("UICorner")
			hueOverlayCorner.CornerRadius = UDim.new(0, 6)
			hueOverlayCorner.Parent = hueOverlay
			CS:AddTag(hueOverlayCorner, "ElementCorner")
			
			local hueGrad = Instance.new("UIGradient")
			hueGrad.Name = "HueGradient"
			hueGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
			hueGrad.Parent = hueOverlay

			local blackOverlay = Instance.new("Frame")
			blackOverlay.Name = "BlackOverlay"
			blackOverlay.Size = UDim2.new(1, 0, 1, 0)
			blackOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
			blackOverlay.BorderSizePixel = 0
			blackOverlay.Parent = svSquare
			
			local blackOverlayCorner = Instance.new("UICorner")
			blackOverlayCorner.CornerRadius = UDim.new(0, 6)
			blackOverlayCorner.Parent = blackOverlay
			CS:AddTag(blackOverlayCorner, "ElementCorner")

			local blackGrad = Instance.new("UIGradient")
			blackGrad.Name = "BlackGradient"
			blackGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
			blackGrad.Rotation = 90
			blackGrad.Parent = blackOverlay

			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.Size = UDim2.new(0, 10, 0, 10)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(s, 0, 1 - v, 0)
			dot.BackgroundColor3 = Color3.new(1, 1, 1)
			dot.BorderSizePixel = 0
			dot.Parent = svSquare
			
			local dotCorner = Instance.new("UICorner")
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot
			
			local dotStroke = Instance.new("UIStroke")
			dotStroke.Name = "DotStroke"
			dotStroke.Color = Color3.new(0, 0, 0)
			dotStroke.Thickness = 1
			dotStroke.Parent = dot

			local hueSlider = Instance.new("TextButton")
			hueSlider.Name = "HueSlider"
			hueSlider.Size = UDim2.new(1, 0, 0, 12)
			hueSlider.BackgroundColor3 = Color3.new(1, 1, 1)
			hueSlider.BorderSizePixel = 0
			hueSlider.AutoButtonColor = false
			hueSlider.Text = ""
			hueSlider.LayoutOrder = 3
			hueSlider.Parent = popup
			
			local hueSliderCorner = Instance.new("UICorner")
			hueSliderCorner.CornerRadius = UDim.new(0, 6)
			hueSliderCorner.Parent = hueSlider
			CS:AddTag(hueSliderCorner, "ElementCorner")

			local rainbowGrad = Instance.new("UIGradient")
			rainbowGrad.Name = "RainbowGradient"
			rainbowGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
			})
			rainbowGrad.Parent = hueSlider

			local hueKnob = Instance.new("Frame")
			hueKnob.Name = "HueKnob"
			hueKnob.Size = UDim2.new(0, 4, 1, 4)
			hueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			hueKnob.BackgroundColor3 = Color3.new(1, 1, 1)
			hueKnob.BorderSizePixel = 0
			hueKnob.Parent = hueSlider
			
			local hueKnobCorner = Instance.new("UICorner")
			hueKnobCorner.CornerRadius = UDim.new(1, 0)
			hueKnobCorner.Parent = hueKnob
			CS:AddTag(hueKnobCorner, "ElementCorner")
			
			local hueKnobStroke = Instance.new("UIStroke")
			hueKnobStroke.Name = "HueKnobStroke"
			hueKnobStroke.Color = Color3.new(0, 0, 0)
			hueKnobStroke.Parent = hueKnob

			local function updateColors(fromRGB)
				if not fromRGB then
					currentColor = Color3.fromHSV(h, s, v)
					rInput.Text = tostring(math.round(currentColor.R * 255))
					gInput.Text = tostring(math.round(currentColor.G * 255))
					bInput.Text = tostring(math.round(currentColor.B * 255))
				else
					currentColor = Color3.fromHSV(h, s, v)
				end
				previewBox.BackgroundColor3 = currentColor
				hueOverlay.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				dot.Position = UDim2.new(s, 0, 1 - v, 0)
				hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
				callback(currentColor)
			end
			updateColors(false)

			local function onRGBFocusLost()
				local r = math.clamp(tonumber(rInput.Text) or math.round(currentColor.R * 255), 0, 255)
				local g = math.clamp(tonumber(gInput.Text) or math.round(currentColor.G * 255), 0, 255)
				local b = math.clamp(tonumber(bInput.Text) or math.round(currentColor.B * 255), 0, 255)
				rInput.Text = tostring(r)
				gInput.Text = tostring(g)
				bInput.Text = tostring(b)
				local newColor = Color3.fromRGB(r, g, b)
				h, s, v = newColor:ToHSV()
				updateColors(true)
			end
			
			table.insert(Window._connections, rInput.FocusLost:Connect(onRGBFocusLost))
			table.insert(Window._connections, gInput.FocusLost:Connect(onRGBFocusLost))
			table.insert(Window._connections, bInput.FocusLost:Connect(onRGBFocusLost))

			local popupTween
			local popupStrokeTween
			local popupFadeToken = 0
			table.insert(Window._connections, previewBox.MouseButton1Click:Connect(function()
				if Window.ActivePopup == popup then return Window.ClosePopup() end
				Window.ClosePopup()
				popupFadeToken = popupFadeToken + 1
				if popupTween then popupTween:Cancel() end
				if popupStrokeTween then popupStrokeTween:Cancel() end
				local absX = previewBox.AbsolutePosition.X - Window.Overlay.AbsolutePosition.X + previewBox.AbsoluteSize.X + 10
				local absY = previewBox.AbsolutePosition.Y - Window.Overlay.AbsolutePosition.Y
				popup.Parent = Window.Overlay
				popup.Position = UDim2.new(0, absX, 0, absY)
				Window.Overlay.Visible = true
				Window.ActivePopup = popup
				popup.Size = UDim2.new(0, 180 * 0.9, 0, 244 * 0.9)
				popup.GroupTransparency = 1
				popup.Visible = true
				if popupStroke then popupStroke.Transparency = 0 end
				Window.ActivePopupClose = function()
					popupFadeToken = popupFadeToken + 1
					local token = popupFadeToken
					if popupTween then popupTween:Cancel() end
					local fadeInfo = TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
					popupTween = TS:Create(popup, fadeInfo, {GroupTransparency = 1})
					popupTween:Play()
					if popupStroke then
						if popupStrokeTween then popupStrokeTween:Cancel() end
						popupStrokeTween = TS:Create(popupStroke, fadeInfo, {Transparency = 1})
						popupStrokeTween:Play()
					end
					local closeTween = popupTween
					closeTween.Completed:Once(function(playbackState)
						if playbackState ~= Enum.PlaybackState.Completed or token ~= popupFadeToken then return end
						popup.Visible = false
						if not Window.ActivePopup then Window.Overlay.Visible = false end
					end)
				end
				popupTween = TS:Create(popup, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
					GroupTransparency = 0,
					Size = UDim2.new(0, 180, 0, 244)
				})
				popupTween:Play()
			end))

			local draggingSV = false
			local function moveSV(input)
				local relX = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / svSquare.AbsoluteSize.X, 0, 1)
				local relY = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / svSquare.AbsoluteSize.Y, 0, 1)
				s = relX
				v = 1 - relY
				updateColors(false)
			end
			table.insert(Window._connections, svSquare.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = true; moveSV(input)
				end
			end))
			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					moveSV(input)
				end
			end))
			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = false
				end
			end))

			local draggingHue = false
			local function moveHue(input)
				local relX = math.clamp((input.Position.X - hueSlider.AbsolutePosition.X) / hueSlider.AbsoluteSize.X, 0, 1)
				h = relX
				updateColors(false)
			end
			table.insert(Window._connections, hueSlider.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingHue = true; moveHue(input)
				end
			end))
			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					moveHue(input)
				end
			end))
			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingHue = false
				end
			end))
			
			local api = {}
			function api:SetColor(c)
				h, s, v = c:ToHSV()
				updateColors(false)
			end
			return api
		end
		
		local function CreateAdvancedDropdown(dropConfig, isMulti, isSearch)
			local dropName = dropConfig.Name or "Dropdown"
			local options = dropConfig.Options or {}
			local callback = dropConfig.Callback or function() end
			local maxSelections = dropConfig.MaxSelections or math.huge
			local defaultOpt = dropConfig.Default
			
			local selectedItems = isMulti and {} or nil
			local selectedItem = not isMulti and defaultOpt or nil

			local container = CreateElementBase(38)

			local topBar = Instance.new("TextButton")
			topBar.Name = "DropdownTopBar"
			topBar.Size = UDim2.new(1, 0, 1, 0)
			topBar.BackgroundTransparency = 1
			topBar.BorderSizePixel = 0
			topBar.Text = ""
			topBar.Parent = container

			local label = Instance.new("TextLabel")
			label.Name = "DropdownLabel"
			label.Size = UDim2.new(0.52, -15, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = dropName
			label.Font = Enum.Font.Gotham
			label.Parent = topBar
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local selectedBox = Instance.new("Frame")
			selectedBox.Name = "SelectedBox"
			selectedBox.Size = UDim2.new(0.44, 0, 0, 28)
			selectedBox.AnchorPoint = Vector2.new(1, 0.5)
			selectedBox.Position = UDim2.new(1, -7, 0.5, 0) 
			selectedBox.BorderSizePixel = 0
			selectedBox.Parent = topBar
			ApplyTheme(selectedBox, "Input", "BackgroundColor3")
			ApplyTheme(selectedBox, "InputTrans", "BackgroundTransparency")
			
			local selectedBoxCorner = Instance.new("UICorner")
			selectedBoxCorner.CornerRadius = GLOBAL_CORNER
			selectedBoxCorner.Parent = selectedBox
			CS:AddTag(selectedBoxCorner, "ElementCorner")
			
			local selectedBoxStroke = attachStroke(selectedBox, "ElementStroke")

			local arrow = Instance.new("ImageLabel")
			arrow.Name = "Arrow"
			arrow.Size = UDim2.new(0, 14, 0, 14)
			arrow.AnchorPoint = Vector2.new(1, 0.5)
			arrow.Position = UDim2.new(1, -8, 0.5, 0)
			arrow.BackgroundTransparency = 1
			arrow.Image = "rbxassetid://10709790948" 
			arrow.Rotation = 180 
			arrow.ZIndex = 3
			arrow.Parent = selectedBox
			ApplyTheme(arrow, "TextMuted", "ImageColor3")

			local selectedText = Instance.new("TextLabel")
			selectedText.Name = "SelectedText"
			selectedText.Size = UDim2.new(1, -26, 1, 0) 
			selectedText.Position = UDim2.new(0, 6, 0, 0)
			selectedText.BackgroundTransparency = 1
			selectedText.BorderSizePixel = 0
			selectedText.TextSize = 12
			selectedText.Text = "Select..."
			selectedText.TextXAlignment = Enum.TextXAlignment.Center
			selectedText.TextTruncate = Enum.TextTruncate.AtEnd
			selectedText.Font = Enum.Font.Gotham
			selectedText.ZIndex = 2
			selectedText.Parent = selectedBox
			ApplyTheme(selectedText, "Text", "TextColor3")
			ApplyTheme(selectedText, "TextFont", "Font")

			local dropPopup = Instance.new("Frame")
			dropPopup.Name = "DropdownPopup"
			dropPopup.BorderSizePixel = 0
			dropPopup.AnchorPoint = Vector2.new(0, 0)
			dropPopup.Visible = false
			dropPopup.ClipsDescendants = true
			dropPopup.ZIndex = 100000 
			dropPopup.Parent = screenGui 
			ApplyTheme(dropPopup, "Input", "BackgroundColor3")
			ApplyTheme(dropPopup, "InputTrans", "BackgroundTransparency")
			
			local dropPopupCorner = Instance.new("UICorner")
			dropPopupCorner.CornerRadius = GLOBAL_CORNER
			dropPopupCorner.Parent = dropPopup
			CS:AddTag(dropPopupCorner, "ElementCorner")
			
			attachStroke(dropPopup, "ElementStroke")

			local headerBtn = Instance.new("TextButton")
			headerBtn.Name = "HeaderBtn"
			headerBtn.Size = UDim2.new(1, 0, 0, 28)
			headerBtn.BackgroundTransparency = 1
			headerBtn.BorderSizePixel = 0
			headerBtn.Text = ""
			headerBtn.ZIndex = 100001
			headerBtn.Parent = dropPopup

			local headerArrow = Instance.new("ImageLabel")
			headerArrow.Name = "HeaderArrow"
			headerArrow.Size = UDim2.new(0, 14, 0, 14)
			headerArrow.AnchorPoint = Vector2.new(1, 0.5)
			headerArrow.Position = UDim2.new(1, -8, 0.5, 0)
			headerArrow.BackgroundTransparency = 1
			headerArrow.Image = "rbxassetid://10709790948" 
			headerArrow.Rotation = 180 
			headerArrow.ZIndex = 100002
			headerArrow.Parent = headerBtn
			ApplyTheme(headerArrow, "TextMuted", "ImageColor3")

			local headerText = Instance.new("TextLabel")
			headerText.Name = "HeaderText"
			headerText.Size = UDim2.new(1, -26, 1, 0)
			headerText.Position = UDim2.new(0, 6, 0, 0)
			headerText.BackgroundTransparency = 1
			headerText.BorderSizePixel = 0
			headerText.TextSize = 12
			headerText.Text = "Select..."
			headerText.TextXAlignment = Enum.TextXAlignment.Center
			headerText.TextTruncate = Enum.TextTruncate.AtEnd
			headerText.Font = Enum.Font.Gotham
			headerText.ZIndex = 100002
			headerText.Parent = headerBtn
			ApplyTheme(headerText, "Text", "TextColor3")
			ApplyTheme(headerText, "TextFont", "Font")

			if defaultOpt then
				if isMulti and type(defaultOpt) == "table" then
					for _, opt in ipairs(defaultOpt) do
						if table.find(options, opt) and #selectedItems < maxSelections then
							table.insert(selectedItems, opt)
						end
					end
					if #selectedItems > 0 then
						local txt = table.concat(selectedItems, ", ")
						selectedText.Text = txt
						headerText.Text = txt
					end
				elseif not isMulti and table.find(options, defaultOpt) then
					selectedText.Text = defaultOpt
					headerText.Text = defaultOpt
				end
			end

			local dividerLine = Instance.new("Frame")
			dividerLine.Name = "DividerLine"
			dividerLine.Size = UDim2.new(1, -16, 0, 1)
			dividerLine.Position = UDim2.new(0.5, 0, 0, 28)
			dividerLine.AnchorPoint = Vector2.new(0.5, 0)
			dividerLine.BorderSizePixel = 0
			dividerLine.ZIndex = 100001
			dividerLine.Parent = dropPopup
			ApplyTheme(dividerLine, "Outlines", "BackgroundColor3")

			local scroll = Instance.new("ScrollingFrame")
			scroll.Name = "Scroll"
			scroll.Position = UDim2.new(0, 0, 0, 31)
			scroll.Size = UDim2.new(1, 0, 1, -(33 + (isSearch and 34 or 0)))
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.ScrollBarThickness = 2
			scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scroll.ZIndex = 100001
			scroll.Parent = dropPopup
			ApplyTheme(scroll, "Outlines", "ScrollBarImageColor3")

			local scrollLayout = Instance.new("UIListLayout")
			scrollLayout.Name = "ScrollLayout"
			scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
			scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			scrollLayout.Padding = UDim.new(0, 2)
			scrollLayout.Parent = scroll
			
			local scrollPadding = Instance.new("UIPadding")
			scrollPadding.Name = "ScrollPadding"
			scrollPadding.PaddingTop = UDim.new(0, 3)
			scrollPadding.PaddingBottom = UDim.new(0, 4)
			scrollPadding.PaddingLeft = UDim.new(0, 4)
			scrollPadding.PaddingRight = UDim.new(0, 4)
			scrollPadding.Parent = scroll

			local searchInputBar, sf
			if isSearch then
				sf = Instance.new("Frame")
				sf.Name = "SearchFrame"
				sf.Size = UDim2.new(1, -16, 0, 24)
				sf.Position = UDim2.new(0.5, 0, 0, 0)
				sf.AnchorPoint = Vector2.new(0.5, 1)
				sf.BorderSizePixel = 0
				sf.ZIndex = 100001
				sf.Parent = dropPopup
				ApplyTheme(sf, "Element", "BackgroundColor3")
				
				local sfc = Instance.new("UICorner")
				sfc.CornerRadius = GLOBAL_CORNER
				sfc.Parent = sf
				CS:AddTag(sfc, "ElementCorner")
				
				attachStroke(sf, "ElementStroke")
				
				searchInputBar = Instance.new("TextBox")
				searchInputBar.Size = UDim2.new(1, -10, 1, 0)
				searchInputBar.Position = UDim2.new(0, 5, 0, 0)
				searchInputBar.BackgroundTransparency = 1
				searchInputBar.TextSize = 12
				searchInputBar.PlaceholderText = "Search..."
				searchInputBar.Text = ""
				searchInputBar.TextXAlignment = Enum.TextXAlignment.Left
				searchInputBar.Font = Enum.Font.Gotham
				searchInputBar.ZIndex = 100002
				searchInputBar.Parent = sf
				ApplyTheme(searchInputBar, "Text", "TextColor3")
				ApplyTheme(searchInputBar, "TextMuted", "PlaceholderColor3")
				ApplyTheme(searchInputBar, "TextFont", "Font")
				
				searchInputBar:GetPropertyChangedSignal("Text"):Connect(function()
					local q = string.lower(searchInputBar.Text)
					for _, btn in ipairs(scroll:GetChildren()) do
						if btn:IsA("TextButton") then
							if q == "" or string.find(string.lower(btn.Name:sub(8)), q) then
								btn.Visible = true
							else
								btn.Visible = false
							end
						end
					end
				end)
			end

			local function updateVisuals()
				for _, btn in ipairs(scroll:GetChildren()) do
					if btn:IsA("TextButton") then
						local optName = btn.Name:sub(8)
						if isMulti and table.find(selectedItems, optName) then
							ApplyTheme(btn, "Accent", "TextColor3")
						else
							ApplyTheme(btn, "Text", "TextColor3")
						end
					end
				end
			end

			local function buildOptions(optsList)
				options = optsList
				for _, child in ipairs(scroll:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end
				for _, opt in ipairs(options) do
					local btn = Instance.new("TextButton")
					btn.Name = "Option_" .. opt
					btn.Size = UDim2.new(1, 0, 0, 24)
					btn.BackgroundTransparency = 1
					btn.BorderSizePixel = 0
					btn.AutoButtonColor = false
					btn.TextSize = 12
					btn.Text = opt
					btn.TextXAlignment = Enum.TextXAlignment.Center
					btn.TextTruncate = Enum.TextTruncate.AtEnd
					btn.Font = Enum.Font.Gotham
					btn.ZIndex = 100002
					btn.Parent = scroll
					ApplyTheme(btn, "TextFont", "Font")
					
					local btnCorner = Instance.new("UICorner")
					btnCorner.CornerRadius = GLOBAL_CORNER
					btnCorner.Parent = btn
					CS:AddTag(btnCorner, "ElementCorner")

					table.insert(Window._connections, btn.MouseEnter:Connect(function() 
						TS:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = THEME.ElementTrans}):Play()
						ApplyTheme(btn, "ElementHover", "BackgroundColor3")
					end))
					table.insert(Window._connections, btn.MouseLeave:Connect(function() 
						TS:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
					end))
					table.insert(Window._connections, btn.MouseButton1Click:Connect(function()
						if isMulti then
							local idx = table.find(selectedItems, opt)
							if idx then
								table.remove(selectedItems, idx)
							else
								if #selectedItems < maxSelections then
									table.insert(selectedItems, opt)
								end
							end
							local txt = #selectedItems > 0 and table.concat(selectedItems, ", ") or "Select..."
							selectedText.Text = txt
							headerText.Text = txt
							callback(selectedItems)
							updateVisuals()
						else
							selectedItem = opt
							selectedText.Text = opt
							headerText.Text = opt
							callback(opt)
							Window.ClosePopup()
						end
					end))
				end
				updateVisuals()
			end
			
			buildOptions(options)

			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					selectedBox.Size = UDim2.new(0.44, 0, 0, 28)
					selectedBox.AnchorPoint = Vector2.new(1, 0.5)
					selectedBox.Position = UDim2.new(1, -7, 0.5, 0)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 56)
					label.Size = UDim2.new(1, -24, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					selectedBox.Size = UDim2.new(1, -16, 0, 26) 
					selectedBox.AnchorPoint = Vector2.new(0, 0)
					selectedBox.Position = UDim2.new(0, 8, 0, 22) 
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					selectedBox.Size = UDim2.new(0.44, 0, 0, 22)
					selectedBox.AnchorPoint = Vector2.new(1, 0.5)
					selectedBox.Position = UDim2.new(1, -5, 0.5, 0)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 46)
					label.Size = UDim2.new(1, -24, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					selectedBox.Size = UDim2.new(1, -12, 0, 22) 
					selectedBox.AnchorPoint = Vector2.new(0, 0)
					selectedBox.Position = UDim2.new(0, 6, 0, 18) 
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, headerBtn.MouseButton1Click:Connect(function()
				Window.ClosePopup()
			end))

			local dropTrackConn = nil

			table.insert(Window._connections, topBar.MouseButton1Click:Connect(function()
				if Window.ActivePopup == dropPopup then 
					Window.ClosePopup()
					return 
				end
				Window.ClosePopup()
				
				if searchInputBar then searchInputBar.Text = "" end
				
				local absX = selectedBox.AbsolutePosition.X - Window.Overlay.AbsolutePosition.X
				local absY = selectedBox.AbsolutePosition.Y - Window.Overlay.AbsolutePosition.Y
				local boxW = selectedBox.AbsoluteSize.X
				local boxH = selectedBox.AbsoluteSize.Y

				dropPopup.Parent = Window.Overlay
				dropPopup.Position = UDim2.new(0, absX, 0, absY)

				local itemHeight = 26
				local visibleCount = math.clamp(#options, 1, 5)
				local extraH = isSearch and 34 or 0
				local targetH = boxH + 3 + (visibleCount * itemHeight) + 6 + extraH

				if sf then
					sf.Position = UDim2.new(0.5, 0, 0, targetH - 6)
				end

				dropPopup.Size = UDim2.new(0, boxW, 0, boxH)
				dropPopup.Visible = true
				
				selectedBox.BackgroundTransparency = 1
				selectedText.Visible = false
				arrow.Visible = false
				selectedBoxStroke.Enabled = false
				
				headerBtn.Size = UDim2.new(1, 0, 0, boxH)
				dividerLine.Position = UDim2.new(0.5, 0, 0, boxH)
				scroll.Position = UDim2.new(0, 0, 0, boxH + 3)
				scroll.Size = UDim2.new(1, 0, 1, -(boxH + 5 + extraH))

				Window.Overlay.Visible = true
				Window.ActivePopup = dropPopup

				if dropTrackConn then dropTrackConn:Disconnect() end
				dropTrackConn = RS.RenderStepped:Connect(function()
					if not dropPopup.Visible or not selectedBox.Parent then
						if dropTrackConn then dropTrackConn:Disconnect(); dropTrackConn = nil end
						return
					end
					local curX = selectedBox.AbsolutePosition.X - Window.Overlay.AbsolutePosition.X
					local curY = selectedBox.AbsolutePosition.Y - Window.Overlay.AbsolutePosition.Y
					dropPopup.Position = UDim2.new(0, curX, 0, curY)

					local scrollParent = selectedBox:FindFirstAncestorWhichIsA("ScrollingFrame")
					if scrollParent then
						local sTop = scrollParent.AbsolutePosition.Y - 15
						local sBottom = scrollParent.AbsolutePosition.Y + scrollParent.AbsoluteSize.Y + 15
						if selectedBox.AbsolutePosition.Y < sTop or selectedBox.AbsolutePosition.Y > sBottom then
							Window.ClosePopup()
						end
					end
				end)

				Window.ActivePopupClose = function()
					if dropTrackConn then
						dropTrackConn:Disconnect()
						dropTrackConn = nil
					end
					
					local closeTween = TS:Create(dropPopup, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
						Size = UDim2.new(0, boxW, 0, boxH)
					})
					closeTween:Play()
					
					TS:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Rotation = 180}):Play()
					TS:Create(headerArrow, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Rotation = 180}):Play()
					
					local conn
					conn = closeTween.Completed:Connect(function()
						conn:Disconnect()
						dropPopup.Visible = false
						
						ApplyTheme(selectedBox, "InputTrans", "BackgroundTransparency")
						selectedText.Visible = true
						arrow.Visible = true
						selectedBoxStroke.Enabled = (THEME.InternalOutlines == "Only Elements" or THEME.InternalOutlines == "All")

						if not Window.ActivePopup then Window.Overlay.Visible = false end
					end)
				end

				TS:Create(dropPopup, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, boxW, 0, targetH)
				}):Play()
				
				headerArrow.Rotation = 180
				arrow.Rotation = 180
				TS:Create(arrow, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Rotation = 0}):Play()
				TS:Create(headerArrow, TweenInfo.new(0.22, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Rotation = 0}):Play()
			end))
			RegisterElement(dropName, container)
			
			local api = {}
			function api:Set(newSelection)
				if isMulti then
					if type(newSelection) == "table" then
						selectedItems = {}
						for _, opt in ipairs(newSelection) do
							if table.find(options, opt) and #selectedItems < maxSelections then
								table.insert(selectedItems, opt)
							end
						end
					end
					local txt = #selectedItems > 0 and table.concat(selectedItems, ", ") or "Select..."
					if selectedText.Text ~= txt then
						selectedText.Text = txt
						headerText.Text = txt
						if dropPopup.Visible then updateVisuals() end
						callback(selectedItems)
					end
				else
					if selectedItem == newSelection then return end
					if table.find(options, newSelection) then
						selectedItem = newSelection
						selectedText.Text = newSelection
						headerText.Text = newSelection
						if dropPopup.Visible then updateVisuals() end
						callback(newSelection)
					end
				end
			end
			function api:SetOptions(newOpts)
				buildOptions(newOpts)
				if searchInputBar and searchInputBar.Text ~= "" then
					local q = string.lower(searchInputBar.Text)
					for _, btn in ipairs(scroll:GetChildren()) do
						if btn:IsA("TextButton") then
							if q == "" or string.find(string.lower(btn.Name:sub(8)), q) then
								btn.Visible = true
							else
								btn.Visible = false
							end
						end
					end
				end
			end
			function api:Save()
				return { Selected = isMulti and selectedItems or selectedItem }
			end
			function api:Load(val)
				if val.Selected ~= nil then
					api:Set(val.Selected)
				end
			end
			RegisterElementAPI("Dropdown", dropName, api)
			return api
		end

		function BlockObj:CreatePicture(picConfig)
			local name = picConfig.Name or "Picture"
			local imgId = parseAsset(picConfig.Image)
			local sizePct = math.clamp(picConfig.Size or 100, 0, 100)
			local desc = picConfig.Description or ""
			
			local container = CreateElementBase(0)
			container.Size = UDim2.new(1, 0, 0, 0)
			container.AutomaticSize = Enum.AutomaticSize.Y
			
			local contentFrame = Instance.new("Frame")
			contentFrame.Size = UDim2.new(1, 0, 0, 0)
			contentFrame.AutomaticSize = Enum.AutomaticSize.Y
			contentFrame.BackgroundTransparency = 1
			contentFrame.Parent = container
			
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 12)
			pad.PaddingBottom = UDim.new(0, 12)
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = contentFrame
			
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = imgId
			img.ScaleType = Enum.ScaleType.Crop
			img.Parent = contentFrame
			
			local imgCorner = Instance.new("UICorner")
			imgCorner.CornerRadius = GLOBAL_CORNER
			imgCorner.Parent = img
			CS:AddTag(imgCorner, "ElementCorner")
			
			local rightTextLbl = Instance.new("TextLabel")
			rightTextLbl.BackgroundTransparency = 1
			rightTextLbl.TextWrapped = true
			rightTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			rightTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			rightTextLbl.TextSize = 13
			rightTextLbl.Font = Enum.Font.Gotham
			rightTextLbl.Parent = contentFrame
			ApplyTheme(rightTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(rightTextLbl, "SubtextFont", "Font")

			local bottomTextLbl = Instance.new("TextLabel")
			bottomTextLbl.BackgroundTransparency = 1
			bottomTextLbl.TextWrapped = true
			bottomTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			bottomTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			bottomTextLbl.TextSize = 13
			bottomTextLbl.Font = Enum.Font.Gotham
			bottomTextLbl.Parent = contentFrame
			ApplyTheme(bottomTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(bottomTextLbl, "SubtextFont", "Font")
		
			local function updateLayout()
				if not contentFrame.Parent then return end
				local fullW = contentFrame.AbsoluteSize.X - 24 
				if fullW <= 0 then return end

				local imgW = math.floor(fullW * (sizePct / 100))
				local imgH = imgW 
				img.Size = UDim2.new(0, imgW, 0, imgH)
				img.Position = UDim2.new(0, 0, 0, 0)

				local textGapX = 14
				local textGapY = 10
				local availRightW = fullW - imgW - textGapX

				if sizePct == 100 or sizePct == 0 or availRightW < 40 or desc == "" then
					rightTextLbl.Visible = false
					bottomTextLbl.Visible = (desc ~= "")
					img.Visible = (sizePct > 0)
					bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
					bottomTextLbl.Position = UDim2.new(0, 0, 0, sizePct > 0 and (imgH + textGapY) or 0)
					bottomTextLbl.Text = desc
					bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
				else
					rightTextLbl.Visible = true
					img.Visible = true
					local len = string.len(desc)
					local l, r = 1, len
					local splitIdx = len
					while l <= r do
						local m = math.floor((l + r) / 2)
						local testStr = string.sub(desc, 1, m)
						local bounds = TextService:GetTextSize(testStr, 13, Enum.Font.Gotham, Vector2.new(availRightW, 10000))
						if bounds.Y > imgH then
							r = m - 1
						else
							splitIdx = m
							l = m + 1
						end
					end
					if splitIdx < len then
						local safeIdx = splitIdx
						while safeIdx > 0 and string.sub(desc, safeIdx, safeIdx):match("%S") do
							safeIdx = safeIdx - 1
						end
						if safeIdx > 0 then splitIdx = safeIdx end
					end
					local rightText = string.sub(desc, 1, splitIdx)
					local bottomText = string.sub(desc, splitIdx + 1)
					bottomText = string.gsub(bottomText, "^%s+", "")
					rightTextLbl.Position = UDim2.new(0, imgW + textGapX, 0, 0)
					rightTextLbl.Size = UDim2.new(0, availRightW, 0, imgH)
					rightTextLbl.Text = rightText
					rightTextLbl.AutomaticSize = Enum.AutomaticSize.None
					if bottomText ~= "" then
						bottomTextLbl.Visible = true
						bottomTextLbl.Position = UDim2.new(0, 0, 0, imgH + textGapY)
						bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
						bottomTextLbl.Text = bottomText
						bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
					else
						bottomTextLbl.Visible = false
					end
				end
			end
			
			table.insert(Window._connections, contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
			task.spawn(function()
				task.wait()
				updateLayout()
			end)
			
			RegisterElement(name, container)
			
			local api = {}
			function api:SetImage(id)
				img.Image = parseAsset(id)
			end
			function api:SetSize(pct)
				sizePct = math.clamp(pct, 0, 100)
				updateLayout()
			end
			function api:SetDescription(txt)
				desc = txt
				updateLayout()
			end
			return api
		end

		function BlockObj:CreateObject(objConfig)
			local name = objConfig.Name or "Object Preview"
			local rawObj = objConfig.Object
			local sizePct = math.clamp(objConfig.Size or 100, 0, 100)
			local desc = objConfig.Description or ""

			local container = CreateElementBase(0)
			container.Size = UDim2.new(1, 0, 0, 0)
			container.AutomaticSize = Enum.AutomaticSize.Y

			local contentFrame = Instance.new("Frame")
			contentFrame.Size = UDim2.new(1, 0, 0, 0)
			contentFrame.AutomaticSize = Enum.AutomaticSize.Y
			contentFrame.BackgroundTransparency = 1
			contentFrame.Parent = container

			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 12)
			pad.PaddingBottom = UDim.new(0, 12)
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = contentFrame

			local viewport = Instance.new("ViewportFrame")
			viewport.Name = "ObjectViewport"
			viewport.BackgroundTransparency = 1
			viewport.BorderSizePixel = 0
			viewport.ClipsDescendants = true
			viewport.Ambient = Color3.fromRGB(220, 220, 220)
			viewport.LightColor = Color3.fromRGB(255, 255, 255)
			viewport.LightDirection = Vector3.new(-1, -2, -1)
			viewport.Parent = contentFrame

			local worldModel = Instance.new("WorldModel")
			worldModel.Name = "ModelHolder"
			worldModel.Parent = viewport

			local camera = Instance.new("Camera")
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = 50
			camera.Parent = viewport
			viewport.CurrentCamera = camera

			local rightTextLbl = Instance.new("TextLabel")
			rightTextLbl.BackgroundTransparency = 1
			rightTextLbl.TextWrapped = true
			rightTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			rightTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			rightTextLbl.TextSize = 13
			rightTextLbl.Font = Enum.Font.Gotham
			rightTextLbl.Parent = contentFrame
			ApplyTheme(rightTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(rightTextLbl, "SubtextFont", "Font")

			local bottomTextLbl = Instance.new("TextLabel")
			bottomTextLbl.BackgroundTransparency = 1
			bottomTextLbl.TextWrapped = true
			bottomTextLbl.TextXAlignment = Enum.TextXAlignment.Left
			bottomTextLbl.TextYAlignment = Enum.TextYAlignment.Top
			bottomTextLbl.TextSize = 13
			bottomTextLbl.Font = Enum.Font.Gotham
			bottomTextLbl.Parent = contentFrame
			ApplyTheme(bottomTextLbl, "TextMuted", "TextColor3")
			ApplyTheme(bottomTextLbl, "SubtextFont", "Font")

			local function resolveInstance(input)
				if typeof(input) == "Instance" then
					if input:IsA("Player") then return input.Character or input.CharacterAdded:Wait() end
					return input
				elseif type(input) == "string" then
					local clean = input:match("^%s*['\"]?(.-)['\"]?%s*$") or input
					local lower = string.lower(clean)

					if lower == "character" or lower == "localplayer" or lower == "me" or lower == "player" 
					   or lower == "game.players.localplayer" or lower == "game.players.localplayer.character"
					   or lower == "players.localplayer" or lower == "players.localplayer.character" then
						return LP.Character or LP.CharacterAdded:Wait()
					end

					if workspace:FindFirstChild(clean) then return workspace:FindFirstChild(clean) end
					if Players:FindFirstChild(clean) then 
						local p = Players:FindFirstChild(clean)
						return p.Character or p.CharacterAdded:Wait()
					end

					local current = game
					for seg in string.gmatch(clean, "[^%.]+") do
						local segLower = string.lower(seg)
						if segLower == "game" then
							current = game
						elseif segLower == "workspace" then
							current = workspace
						elseif segLower == "players" then
							current = Players
						elseif segLower == "localplayer" and current == Players then
							current = LP.Character or LP.CharacterAdded:Wait()
						elseif segLower == "character" and current:IsA("Player") then
							current = current.Character or current.CharacterAdded:Wait()
						else
							current = current and current:FindFirstChild(seg)
						end
					end

					if current and current ~= game then 
						if current:IsA("Player") then return current.Character or current.CharacterAdded:Wait() end
						return current 
					end

					if input == LP.Name and LP.Character then return LP.Character end
				end
				return nil
			end

			local currentClone = nil
			local currentCenter = Vector3.new(0, 1.5, 0)
			local currentDistance = 7.5
			local rotX = 0
			local rotY = math.pi
			local renderConn = nil

			local function updateCamera()
				if not camera then return end
				local rotCFrame = CFrame.Angles(0, rotY, 0) * CFrame.Angles(rotX, 0, 0)
				local camPos = currentCenter + (rotCFrame * Vector3.new(0, 0, currentDistance))
				camera.CFrame = CFrame.lookAt(camPos, currentCenter)
			end

			local validCharParts = {
				HumanoidRootPart=true, Head=true, Torso=true,
				["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true,
				UpperTorso=true, LowerTorso=true,
				LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
				RightUpperArm=true, RightLowerArm=true, RightHand=true,
				LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
				RightUpperLeg=true, RightLowerLeg=true, RightFoot=true
			}

			local function loadTargetObject(target)
				if renderConn then renderConn:Disconnect(); renderConn = nil end
				if currentClone then currentClone:Destroy(); currentClone = nil end

				local src = resolveInstance(target)
				if not src and (target == nil or target == "Character") then
					src = LP.Character or LP.CharacterAdded:Wait()
				end
				if not src then return end

				local isChar = false
				if src == LP.Character or src:FindFirstChildOfClass("Humanoid") then
					isChar = true
					if src == LP.Character then
						local t = 0
						while not LP:HasAppearanceLoaded() and t < 2 do
							task.wait(0.1); t = t + 0.1
						end
					end
					if not src:FindFirstChild("HumanoidRootPart") and not src:FindFirstChild("Head") then
						task.wait(0.5)
					end
				end

				local archCache = {}
				archCache[src] = src.Archivable
				src.Archivable = true
				for _, desc in ipairs(src:GetDescendants()) do
					archCache[desc] = desc.Archivable
					pcall(function() desc.Archivable = true end)
				end

				local clone = src:Clone()

				for obj, arch in pairs(archCache) do
					if obj and obj.Parent then pcall(function() obj.Archivable = arch end) end
				end
				if not clone then return end

				if not clone:IsA("Model") and not clone:IsA("BasePart") then
					local wrapper = Instance.new("Model")
					wrapper.Name = clone.Name
					for _, child in ipairs(clone:GetChildren()) do
						child.Parent = wrapper
					end
					clone:Destroy()
					clone = wrapper
				end

				if isChar then
					for _, child in ipairs(clone:GetChildren()) do
						if child:IsA("Tool") or child:IsA("Folder") or child:IsA("Model") then
							child:Destroy()
						elseif child:IsA("BasePart") and not validCharParts[child.Name] then
							child:Destroy()
						end
					end

					for _, desc in ipairs(clone:GetDescendants()) do
						if desc:IsA("BasePart") and not validCharParts[desc.Name] then
							if not desc:FindFirstAncestorOfClass("Accessory") then
								desc:Destroy()
							end
						elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("Highlight") or desc:IsA("ParticleEmitter") or desc:IsA("Sound") or desc:IsA("LuaSourceContainer") then
							desc:Destroy()
						end
					end
				else
					for _, desc in ipairs(clone:GetDescendants()) do
						if desc:IsA("LuaSourceContainer") or desc:IsA("Sound") then
							desc:Destroy()
						end
					end
				end

				local motorMap = {}
				if isChar then
					for _, cloneDesc in ipairs(clone:GetDescendants()) do
						if cloneDesc:IsA("Motor6D") then
							local realDesc = src:FindFirstChild(cloneDesc.Name, true)
							if realDesc and realDesc:IsA("Motor6D") then
								table.insert(motorMap, {Real = realDesc, Clone = cloneDesc})
							end
						end
					end
				end

				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						if isChar then
							d.Anchored = false 
							if d.Name == "HumanoidRootPart" then
								d.Anchored = true
								d.Transparency = 1
							else
								d.LocalTransparencyModifier = 0
								if validCharParts[d.Name] or d:IsA("MeshPart") or d:FindFirstChildWhichIsA("DataModelMesh") then
									if d.Transparency >= 1 then
										d.Transparency = 0
									end
								end
							end
						else
							d.Anchored = true
						end
					end
				end

				local hum = clone:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				end

				clone.Parent = worldModel
				currentClone = clone
				local srcRoot = src:FindFirstChild("HumanoidRootPart") or (src:IsA("Model") and src.PrimaryPart) or src:FindFirstChildWhichIsA("BasePart") or (src:IsA("BasePart") and src)
				local cloneRoot = clone:FindFirstChild("HumanoidRootPart") or (clone:IsA("Model") and clone.PrimaryPart) or clone:FindFirstChildWhichIsA("BasePart") or (clone:IsA("BasePart") and clone)

				if not isChar then
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") and d.Transparency >= 1 and not d:IsA("MeshPart") and not d:FindFirstChildWhichIsA("DataModelMesh") and not d:FindFirstChildWhichIsA("Decal") then
							d:Destroy()
						end
					end
				end

				local cf, size
				if isChar then
					if cloneRoot then
						cloneRoot.CFrame = CFrame.new(0, 0, 0)
					end
					for _, pair in ipairs(motorMap) do
						pair.Clone.Transform = pair.Real.Transform
						pair.Clone.C0 = pair.Real.C0
						pair.Clone.C1 = pair.Real.C1
					end
					cf, size = clone:GetBoundingBox()
					currentCenter = cf.Position
				else
					if clone:IsA("Model") then
						clone.PrimaryPart = nil
						local tempCF = clone:GetBoundingBox()
						clone:PivotTo(clone:GetPivot() + (-tempCF.Position))
						cf, size = clone:GetBoundingBox()
						currentCenter = cf.Position
					elseif clone:IsA("BasePart") then
						clone.CFrame = CFrame.new(0, 0, 0)
						cf = clone.CFrame
						size = clone.Size
						currentCenter = Vector3.new(0, 0, 0)
					end
				end

				local maxDim = math.max(size.X, size.Y, size.Z)
				if maxDim <= 0.1 then maxDim = 5 end

				currentDistance = (maxDim / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.45
				rotX = 0
				rotY = math.pi
				updateCamera()

				renderConn = RS.RenderStepped:Connect(function()
					if not viewport.Parent then 
						if renderConn then renderConn:Disconnect(); renderConn = nil end
						return 
					end
					if not viewport.Visible or viewport.AbsoluteSize.X == 0 then return end
					if not src or not src.Parent then return end

					if isChar then
						if cloneRoot then
							cloneRoot.CFrame = CFrame.new(0, 0, 0)
						end
						for _, pair in ipairs(motorMap) do
							pair.Clone.Transform = pair.Real.Transform
							pair.Clone.C0 = pair.Real.C0
							pair.Clone.C1 = pair.Real.C1
						end
					else
						if srcRoot and srcRoot.Parent and (srcRoot:IsA("BasePart") or src:IsA("Model")) then
							local rot = (srcRoot.CFrame - srcRoot.CFrame.Position)
							if clone:IsA("Model") then
								clone:PivotTo(CFrame.new(currentCenter) * rot)
							elseif clone:IsA("BasePart") then
								clone.CFrame = CFrame.new(currentCenter) * rot
							end
						end
					end
					updateCamera()
				end)
			end

			task.spawn(function()
				task.wait(0.2)
				loadTargetObject(rawObj)
			end)

			table.insert(Window._connections, LP.CharacterAdded:Connect(function(newChar)
				if rawObj == nil or rawObj == "Character" or rawObj == LP.Character or (type(rawObj) == "string" and string.find(string.lower(rawObj), "character")) then
					task.wait(0.5)
					loadTargetObject(newChar)
				end
			end))

			local isRotating = false
			local lastMousePos = Vector2.new()

			table.insert(Window._connections, viewport.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					isRotating = true
					lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
				end
			end))

			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if isRotating and input.UserInputType == Enum.UserInputType.MouseMovement then
					local curPos = Vector2.new(input.Position.X, input.Position.Y)
					local delta = curPos - lastMousePos
					lastMousePos = curPos
					rotY = rotY - (delta.X * 0.015)
					rotX = math.clamp(rotX - (delta.Y * 0.015), -math.rad(80), math.rad(80))
				end
			end))

			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					isRotating = false
				end
			end))

			local function updateLayout()
				if not contentFrame.Parent then return end
				local fullW = contentFrame.AbsoluteSize.X - 24 
				if fullW <= 0 then return end

				local vpW = math.floor(fullW * (sizePct / 100))
				local vpH = vpW 
				viewport.Size = UDim2.new(0, vpW, 0, vpH)
				viewport.Position = UDim2.new(0, 0, 0, 0)

				local textGapX = 14
				local textGapY = 10
				local availRightW = fullW - vpW - textGapX

				if sizePct == 100 or sizePct == 0 or availRightW < 40 or desc == "" then
					rightTextLbl.Visible = false
					bottomTextLbl.Visible = (desc ~= "")
					viewport.Visible = (sizePct > 0)
					bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
					bottomTextLbl.Position = UDim2.new(0, 0, 0, sizePct > 0 and (vpH + textGapY) or 0)
					bottomTextLbl.Text = desc
					bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
				else
					rightTextLbl.Visible = true
					viewport.Visible = true
					local len = string.len(desc)
					local l, r = 1, len
					local splitIdx = len
					while l <= r do
						local m = math.floor((l + r) / 2)
						local testStr = string.sub(desc, 1, m)
						local bounds = TextService:GetTextSize(testStr, 13, Enum.Font.Gotham, Vector2.new(availRightW, 10000))
						if bounds.Y > vpH then
							r = m - 1
						else
							splitIdx = m
							l = m + 1
						end
					end
					if splitIdx < len then
						local safeIdx = splitIdx
						while safeIdx > 0 and string.sub(desc, safeIdx, safeIdx):match("%S") do
							safeIdx = safeIdx - 1
						end
						if safeIdx > 0 then splitIdx = safeIdx end
					end
					local rightText = string.sub(desc, 1, splitIdx)
					local bottomText = string.sub(desc, splitIdx + 1)
					bottomText = string.gsub(bottomText, "^%s+", "")
					rightTextLbl.Position = UDim2.new(0, vpW + textGapX, 0, 0)
					rightTextLbl.Size = UDim2.new(0, availRightW, 0, vpH)
					rightTextLbl.Text = rightText
					rightTextLbl.AutomaticSize = Enum.AutomaticSize.None
					if bottomText ~= "" then
						bottomTextLbl.Visible = true
						bottomTextLbl.Position = UDim2.new(0, 0, 0, vpH + textGapY)
						bottomTextLbl.Size = UDim2.new(1, 0, 0, 0)
						bottomTextLbl.Text = bottomText
						bottomTextLbl.AutomaticSize = Enum.AutomaticSize.Y
					else
						bottomTextLbl.Visible = false
					end
				end
			end

			table.insert(Window._connections, contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
			task.spawn(function()
				task.wait()
				updateLayout()
			end)

			RegisterElement(name, container)

			local api = {}
			function api:SetObject(newObj)
				rawObj = newObj
				loadTargetObject(newObj)
			end
			function api:SetSize(pct)
				sizePct = math.clamp(pct, 0, 100)
				updateLayout()
			end
			function api:SetDescription(txt)
				desc = txt
				updateLayout()
			end
			function api:ResetRotation()
				rotX = 0
				rotY = math.pi
			end
			return api
		end

		function BlockObj:CreateButton(btnConfig)
			local btnName = btnConfig.Name or "Button"
			local callback = btnConfig.Callback or function() end

			local btn = CreateElementBase(38)
			
			local btnInteractive = Instance.new("TextButton")
			btnInteractive.Name = "InteractiveButton"
			btnInteractive.Size = UDim2.new(1, 0, 1, 0)
			btnInteractive.BackgroundTransparency = 1
			btnInteractive.BorderSizePixel = 0
			btnInteractive.TextSize = 13
			btnInteractive.Text = btnName
			btnInteractive.TextTruncate = Enum.TextTruncate.AtEnd
			btnInteractive.Font = Enum.Font.Gotham
			btnInteractive.Parent = btn
			ApplyTheme(btnInteractive, "Text", "TextColor3")
			ApplyTheme(btnInteractive, "TextFont", "Font")

			local function updateStyle(style)
				if style == 3 or style == 4 then
					btn.Size = UDim2.new(1, 0, 0, 30)
					btnInteractive.TextSize = 12
				else
					btn.Size = UDim2.new(1, 0, 0, 38)
					btnInteractive.TextSize = 13
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, btnInteractive.MouseButton1Down:Connect(function()
				ApplyTheme(btn, "CardHover", "BackgroundColor3")
			end))
			table.insert(Window._connections, btnInteractive.MouseButton1Up:Connect(function()
				ApplyTheme(btn, "Element", "BackgroundColor3")
				callback()
			end))
			RegisterElement(btnName, btn)
			
			local api = {}
			function api:SetText(txt)
				btnInteractive.Text = txt
			end
			function api:SetCallback(cb)
				callback = cb
			end
			return api
		end
		
		function BlockObj:CreateButtonKeybind(cfg)
			local btnName = cfg.Name or "Button"
			local callback = cfg.Callback or function() end
			local bind = cfg.Default

			local el = CreateElementBase(38)
			
			local btnInteractive = Instance.new("TextButton")
			btnInteractive.Name = "InteractiveButton"
			btnInteractive.Size = UDim2.new(1, -50, 1, 0)
			btnInteractive.BackgroundTransparency = 1
			btnInteractive.BorderSizePixel = 0
			btnInteractive.TextSize = 13
			btnInteractive.Text = btnName
			btnInteractive.TextTruncate = Enum.TextTruncate.AtEnd
			btnInteractive.Font = Enum.Font.Gotham
			btnInteractive.Parent = el
			ApplyTheme(btnInteractive, "Text", "TextColor3")
			ApplyTheme(btnInteractive, "TextFont", "Font")
			
			local box = Instance.new("Frame")
			box.Name = "KeybindBox"
			box.Size = UDim2.new(0, 30, 0, 24)
			box.AutomaticSize = Enum.AutomaticSize.X
			box.AnchorPoint = Vector2.new(1, 0.5)
			box.Position = UDim2.new(1, -7, 0.5, 0)
			box.ZIndex = 5
			box.Parent = el
			ApplyTheme(box, "Input", "BackgroundColor3")
			ApplyTheme(box, "InputTrans", "BackgroundTransparency")
			
			local boxCorner = Instance.new("UICorner")
			boxCorner.CornerRadius = GLOBAL_CORNER
			boxCorner.Parent = box
			CS:AddTag(boxCorner, "ElementCorner")
			
			attachStroke(box, "ElementStroke")
			
			local bBtn = Instance.new("TextButton")
			bBtn.Name = "KeybindButton"
			bBtn.Size = UDim2.new(1,0,1,0)
			bBtn.BackgroundTransparency = 1
			bBtn.TextSize = 12
			bBtn.Text = getShortKey(bind)
			bBtn.Font = Enum.Font.Gotham
			bBtn.ZIndex = 6
			bBtn.Parent = box
			ApplyTheme(bBtn, "TextMuted", "TextColor3")
			ApplyTheme(bBtn, "TextFont", "Font")
			
			local mobileToggle, getMobileBtn
			if isMobile then
				mobileToggle, _, getMobileBtn = createMobileToggle(el, function(enabled, removeBtn, saveBtn)
					if enabled then
						saveBtn(createMobileBindButton(getShortKey(bind), callback))
					else
						removeBtn()
					end
				end)
			end

			local p = Instance.new("UIPadding")
			p.Name = "KeybindPadding"
			p.PaddingLeft = UDim.new(0,6)
			p.PaddingRight = UDim.new(0,6)
			p.Parent = bBtn

			local function updateStyle(style)
				local edge = (style == 3 or style == 4) and 5 or 7
				if style == 3 or style == 4 then
					el.Size = UDim2.new(1, 0, 0, 30)
					btnInteractive.TextSize = 12
					box.Size = UDim2.new(0, 30, 0, 20)
					bBtn.TextSize = 11
				else
					el.Size = UDim2.new(1, 0, 0, 38)
					btnInteractive.TextSize = 13
					box.Size = UDim2.new(0, 30, 0, 24)
					bBtn.TextSize = 12
				end

				box.AnchorPoint = Vector2.new(1, 0.5)
				box.Position = UDim2.new(1, -edge, 0.5, 0)
				btnInteractive.Position = UDim2.new(0, mobileToggle and 36 or 0, 0, 0)
				btnInteractive.Size = UDim2.new(1, -(50 + (mobileToggle and 36 or 0)), 1, 0)
				btnInteractive.TextXAlignment = Enum.TextXAlignment.Center
				if mobileToggle then
					mobileToggle.AnchorPoint = Vector2.new(0, 0.5)
					mobileToggle.Position = UDim2.new(0, 12, 0.5, 0)
					mobileToggle.Size = UDim2.new(0, 20, 0, 20)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, btnInteractive.MouseButton1Down:Connect(function()
				ApplyTheme(el, "CardHover", "BackgroundColor3")
			end))
			table.insert(Window._connections, btnInteractive.MouseButton1Up:Connect(function()
				ApplyTheme(el, "Element", "BackgroundColor3")
				callback()
			end))
			
			local isBinding = false
			
			table.insert(Window._connections, bBtn.MouseButton1Click:Connect(function() 
				isBinding = true
				bBtn.Text = "..."
				ApplyTheme(bBtn, "Accent", "TextColor3") 
			end))
			
			table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then return end
				if isBinding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						bind = input.KeyCode
						bBtn.Text = getShortKey(bind)
						ApplyTheme(bBtn, "TextMuted", "TextColor3")
						isBinding = false
					end
				else
					if bind and bind ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind then
						callback()
					end
				end
			end))
			RegisterElement(btnName, el)
			
			local api = {}
			function api:SetText(txt)
				btnInteractive.Text = txt
			end
			function api:SetKeybind(k)
				bind = k
				bBtn.Text = getShortKey(k)
				local mb = getMobileBtn and getMobileBtn()
				if mb then mb.Text = getShortKey(k) end
			end
			function api:SetCallback(cb)
				callback = cb
			end
			function api:Save()
				return { Bind = bind and bind.Name or nil }
			end
			function api:Load(val)
				if val.Bind then
					api:SetKeybind(Enum.KeyCode[val.Bind])
				end
			end
			RegisterElementAPI("ButtonKeybind", btnName, api)
			return api
		end

		function BlockObj:CreateToggle(cfg)
			local tglName = cfg.Name or "Toggle"
			local state = cfg.Default or false
			local callback = cfg.Callback or function() end

			local hasColorpicker = cfg.Colorpicker or (cfg.Color ~= nil)
			local hasColorpicker2 = cfg.Colorpicker2 or (cfg.Color2 ~= nil)
			local hasKeybind = (cfg.Keybind ~= nil)
			
			local bind = nil
			if typeof(cfg.Keybind) == "EnumItem" then
				bind = cfg.Keybind
			elseif cfg.Keybind == true then
				bind = Enum.KeyCode.Unknown
			end
			
			local defaultColor = cfg.Color or Color3.fromRGB(255, 255, 255)
			local defaultColor2 = cfg.Color2 or Color3.fromRGB(255, 255, 255)
			local isCombo = hasColorpicker or hasColorpicker2 or hasKeybind

			local container = CreateElementBase(38)
			if isCombo then
				container:SetAttribute("TogglePos", THEME.TogglePosition)
				CS:AddTag(container, "ComboToggleBind")
			end

			local fullBarBtn = Instance.new("TextButton")
			fullBarBtn.Name = "FullBarClick"
			fullBarBtn.Size = UDim2.new(1, 0, 1, 0)
			fullBarBtn.Position = UDim2.new(0, 0, 0, 0)
			fullBarBtn.BackgroundTransparency = 1
			fullBarBtn.BorderSizePixel = 0
			fullBarBtn.Text = ""
			fullBarBtn.ZIndex = 2
			fullBarBtn.Parent = container
			
			local label = Instance.new("TextLabel")
			label.Name = isCombo and "Label" or "ToggleLabel"
			label.Size = UDim2.new(1, -60, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = tglName
			label.Font = Enum.Font.Gotham
			label.ZIndex = 3
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")
			if not isCombo then CS:AddTag(label, "ToggleLabelBind") end

			local toggleBox = Instance.new("Frame")
			toggleBox.Name = "ToggleBox"
			toggleBox.Size = UDim2.new(0, 24, 0, 24)
			toggleBox.AnchorPoint = Vector2.new(1, 0.5)
			toggleBox.Position = UDim2.new(1, -7, 0.5, 0) 
			toggleBox.BackgroundTransparency = 1
			toggleBox.BorderSizePixel = 0
			toggleBox.ZIndex = 3
			toggleBox.Parent = container
			if not isCombo then CS:AddTag(toggleBox, "ToggleBoxBind") end
			
			local toggleBoxCorner = Instance.new("UICorner")
			toggleBoxCorner.CornerRadius = GLOBAL_CORNER
			toggleBoxCorner.Parent = toggleBox
			CS:AddTag(toggleBoxCorner, "ElementCorner")

			local toggleStroke = Instance.new("UIStroke")
			toggleStroke.Name = "ToggleStroke"
			toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			toggleStroke.Thickness = 1
			toggleStroke.Parent = toggleBox
			ApplyTheme(toggleStroke, state and "Accent" or "Outlines", "Color")

			local fill = Instance.new("Frame")
			fill.Name = "ToggleFill"
			fill.Position = UDim2.new(0.5, 0, 0.5, 0)
			fill.AnchorPoint = Vector2.new(0.5, 0.5)
			fill.BorderSizePixel = 0
			fill.ZIndex = 4
			fill.Parent = toggleBox
			ApplyTheme(fill, "Accent", "BackgroundColor3")
			
			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = GLOBAL_CORNER
			fillCorner.Parent = fill
			CS:AddTag(fillCorner, "ElementCorner")

			if state then fill.Size = UDim2.new(1, -10, 1, -10) else fill.Size = UDim2.new(0, 0, 0, 0) end

			local mobileToggle, getMobileBtn
			local previewBox, previewBox2, kbBox, kbBtn
			local currentColor = defaultColor
			local currentColor2 = defaultColor2
			local updateColors, updateColors2

			local function fireCallback()
				if not callback then return end
				if hasColorpicker and hasColorpicker2 and hasKeybind then
					callback(state, currentColor, currentColor2, bind)
				elseif hasColorpicker and hasColorpicker2 then
					callback(state, currentColor, currentColor2)
				elseif hasColorpicker and hasKeybind then
					callback(state, currentColor, bind)
				elseif hasColorpicker2 and hasKeybind then
					callback(state, currentColor2, bind)
				elseif hasColorpicker then
					callback(state, currentColor)
				elseif hasColorpicker2 then
					callback(state, currentColor2)
				elseif hasKeybind then
					callback(state, bind)
				else
					callback(state)
				end
			end
			
			if hasColorpicker then
				previewBox = Instance.new("TextButton")
				previewBox.Name = "PreviewBox"
				previewBox.BackgroundColor3 = defaultColor
				previewBox.BorderSizePixel = 0
				previewBox.Text = ""
				previewBox.ZIndex = 5
				previewBox.Parent = container
				
				local previewCorner = Instance.new("UICorner")
				previewCorner.CornerRadius = GLOBAL_CORNER
				previewCorner.Parent = previewBox
				CS:AddTag(previewCorner, "ElementCorner")
				
				local previewStroke = Instance.new("UIStroke")
				previewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				previewStroke.Thickness = 2
				previewStroke.Parent = previewBox
				ApplyTheme(previewStroke, "Outlines", "Color")
				
				updateColors = AttachColorPicker(previewBox, defaultColor, function(col)
					currentColor = col
					fireCallback()
				end)
			end

			if hasColorpicker2 then
				previewBox2 = Instance.new("TextButton")
				previewBox2.Name = "PreviewBox2"
				previewBox2.BackgroundColor3 = defaultColor2
				previewBox2.BorderSizePixel = 0
				previewBox2.Text = ""
				previewBox2.ZIndex = 5
				previewBox2.Parent = container
				
				local previewCorner2 = Instance.new("UICorner")
				previewCorner2.CornerRadius = GLOBAL_CORNER
				previewCorner2.Parent = previewBox2
				CS:AddTag(previewCorner2, "ElementCorner")
				
				local previewStroke2 = Instance.new("UIStroke")
				previewStroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				previewStroke2.Thickness = 2
				previewStroke2.Parent = previewBox2
				ApplyTheme(previewStroke2, "Outlines", "Color")
				
				updateColors2 = AttachColorPicker(previewBox2, defaultColor2, function(col)
					currentColor2 = col
					fireCallback()
				end)
			end
			
			if hasKeybind then
				kbBox = Instance.new("Frame")
				kbBox.Name = "KeybindBox"
				kbBox.BorderSizePixel = 0
				kbBox.AutomaticSize = Enum.AutomaticSize.X
				kbBox.ZIndex = 5
				kbBox.Parent = container
				ApplyTheme(kbBox, "Input", "BackgroundColor3")
				ApplyTheme(kbBox, "InputTrans", "BackgroundTransparency")
				
				local kbCorner = Instance.new("UICorner")
				kbCorner.CornerRadius = GLOBAL_CORNER
				kbCorner.Parent = kbBox
				CS:AddTag(kbCorner, "ElementCorner")
				attachStroke(kbBox, "ElementStroke")
				
				kbBtn = Instance.new("TextButton")
				kbBtn.Size = UDim2.new(1,0,1,0)
				kbBtn.BackgroundTransparency = 1
				kbBtn.Text = getShortKey(bind)
				kbBtn.Font = Enum.Font.Gotham
				kbBtn.ZIndex = 6
				kbBtn.Parent = kbBox
				ApplyTheme(kbBtn, "TextMuted", "TextColor3")
				ApplyTheme(kbBtn, "TextFont", "Font")

				local kbPad = Instance.new("UIPadding")
				kbPad.Name = "KeybindPadding"
				kbPad.PaddingLeft = UDim.new(0, 6)
				kbPad.PaddingRight = UDim.new(0, 6)
				kbPad.Parent = kbBtn
			end
			
			local function updateStyle(style)
				local isCompact = (style == 3 or style == 4)
				
				if not isCombo then
					container.Size = UDim2.new(1, 0, 0, isCompact and 30 or 38)
					label.TextSize = isCompact and 12 or 13
					
					local boxSize = isCompact and 18 or 24
					toggleBox.Size = UDim2.new(0, boxSize, 0, boxSize)
					
					local tPos = THEME.TogglePosition
					local edge = isCompact and 5 or 7
					
					if tPos == "Left" then
						toggleBox.AnchorPoint = Vector2.new(0, 0.5)
						toggleBox.Position = UDim2.new(0, edge, 0.5, 0)
						label.Position = UDim2.new(0, edge + boxSize + 7, 0, 0)
						label.Size = UDim2.new(1, -(edge + boxSize + 15), 1, 0)
					else
						toggleBox.AnchorPoint = Vector2.new(1, 0.5)
						toggleBox.Position = UDim2.new(1, -edge, 0.5, 0)
						label.Position = UDim2.new(0, 15, 0, 0)
						label.Size = UDim2.new(1, -60, 1, 0)
					end
				else
					container.Size = UDim2.new(1, 0, 0, isCompact and 30 or 38)
					label.TextSize = isCompact and 12 or 13
					
					local boxSize = isCompact and 18 or 24
					local kbH = isCompact and 20 or 24
					toggleBox.Size = UDim2.new(0, boxSize, 0, boxSize)
					
					if previewBox then previewBox.Size = UDim2.new(0, boxSize, 0, boxSize) end
					if previewBox2 then previewBox2.Size = UDim2.new(0, boxSize, 0, boxSize) end
					if kbBox then kbBox.Size = UDim2.new(0, 30, 0, kbH); kbBtn.TextSize = isCompact and 11 or 12 end
					
					local gap = 6
					local edge = isCompact and 5 or 7
					local tPos = container:GetAttribute("TogglePos") or THEME.TogglePosition
					
					if tPos == "Left" then
						toggleBox.AnchorPoint = Vector2.new(0, 0.5)
						toggleBox.Position = UDim2.new(0, edge, 0.5, 0)
						
						local rightOffset = edge
						
						if kbBox then
							kbBox.AnchorPoint = Vector2.new(1, 0.5)
							kbBox.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + 30 + gap
						end

						if previewBox2 then
							previewBox2.AnchorPoint = Vector2.new(1, 0.5)
							previewBox2.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + boxSize + gap
						end
						
						if previewBox then
							previewBox.AnchorPoint = Vector2.new(1, 0.5)
							previewBox.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + boxSize + gap
						end
						if mobileToggle then
							mobileToggle.AnchorPoint = Vector2.new(1, 0.5)
							mobileToggle.Position = UDim2.new(1, -rightOffset, 0.5, 0)
							rightOffset = rightOffset + 22 + gap
						end
						
						local leftOffset = edge + boxSize + gap
						label.Position = UDim2.new(0, leftOffset, 0, 0)
						label.Size = UDim2.new(1, -(leftOffset + rightOffset + 5), 1, 0)
						label.TextXAlignment = Enum.TextXAlignment.Left
					else
						toggleBox.AnchorPoint = Vector2.new(1, 0.5)
						toggleBox.Position = UDim2.new(1, -edge, 0.5, 0)
						
						local offset = edge + boxSize + gap
						if previewBox then
							previewBox.AnchorPoint = Vector2.new(1, 0.5)
							previewBox.Position = UDim2.new(1, -offset, 0.5, 0)
							offset = offset + boxSize + gap
						end

						if previewBox2 then
							previewBox2.AnchorPoint = Vector2.new(1, 0.5)
							previewBox2.Position = UDim2.new(1, -offset, 0.5, 0)
							offset = offset + boxSize + gap
						end
						
						if kbBox then
							kbBox.AnchorPoint = Vector2.new(1, 0.5)
							kbBox.Position = UDim2.new(1, -offset, 0.5, 0)
							offset = offset + 30 + gap
						end
						
						offset = offset + 5
						label.Position = UDim2.new(0, 15, 0, 0)
						label.Size = UDim2.new(1, -offset - 15, 1, 0)
						label.TextXAlignment = Enum.TextXAlignment.Left
					end
				end
			end
			
			table.insert(Window._styleCallbacks, updateStyle)
			if isCombo then container:GetAttributeChangedSignal("TogglePos"):Connect(function() updateStyle(THEME.ElementStyle) end) end
			updateStyle(THEME.ElementStyle)
			
			local function updateToggle()
				if state then
					ApplyTheme(toggleStroke, "Accent", "Color")
					TS:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, -10, 1, -10)}):Play()
				else
					ApplyTheme(toggleStroke, "Outlines", "Color")
					TS:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 0, 0)}):Play()
				end
				fireCallback()
				if Window.UpdateKeybinds then Window.UpdateKeybinds() end
			end
			
			if isMobile and hasKeybind then
				mobileToggle, _, getMobileBtn = createMobileToggle(container, function(enabled, removeBtn, saveBtn)
					if enabled then
						saveBtn(createMobileBindButton(getShortKey(bind), function()
							state = not state
							updateToggle()
						end))
					else
						removeBtn()
					end
				end)
				updateStyle(THEME.ElementStyle)
			end

			table.insert(Window._connections, fullBarBtn.MouseButton1Click:Connect(function()
				state = not state
				updateToggle()
			end))
			
			if hasKeybind then
				local isBinding = false
				table.insert(Window._connections, kbBtn.MouseButton1Click:Connect(function() 
					isBinding = true
					kbBtn.Text = "..."
					ApplyTheme(kbBtn, "Accent", "TextColor3") 
				end))
				
				table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if isBinding then
						if input.UserInputType == Enum.UserInputType.Keyboard then
							bind = input.KeyCode
							kbBtn.Text = getShortKey(bind)
							ApplyTheme(kbBtn, "TextMuted", "TextColor3")
							isBinding = false
							fireCallback()
							if Window.UpdateKeybinds then Window.UpdateKeybinds() end
						end
					else
						if bind and bind ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind then
							state = not state
							updateToggle()
						end
					end
				end))
			end
			
			RegisterElement(tglName, container)
			
			local api = {}
			function api:Set(newState)
				if state == newState then return end
				state = newState
				if state then
					ApplyTheme(toggleStroke, "Accent", "Color")
					fill.Size = UDim2.new(1, -10, 1, -10)
				else
					ApplyTheme(toggleStroke, "Outlines", "Color")
					fill.Size = UDim2.new(0, 0, 0, 0)
				end
				fireCallback()
				if Window.UpdateKeybinds then Window.UpdateKeybinds() end
			end
			function api:SetColor(newColor)
				if not hasColorpicker then return end
				currentColor = newColor
				if updateColors then 
					updateColors:SetColor(newColor)
				end
			end
			function api:SetColor2(newColor)
				if not hasColorpicker2 then return end
				currentColor2 = newColor
				if updateColors2 then 
					updateColors2:SetColor(newColor)
				end
			end
			function api:SetKeybind(newKey)
				if not hasKeybind then return end
				bind = newKey
				kbBtn.Text = getShortKey(bind)
				local mb = getMobileBtn and getMobileBtn()
				if mb then mb.Text = getShortKey(bind) end
			end
			function api:Save()
				return {
					State = state,
					Color = hasColorpicker and {currentColor.R, currentColor.G, currentColor.B} or nil,
					Color2 = hasColorpicker2 and {currentColor2.R, currentColor2.G, currentColor2.B} or nil,
					Bind = hasKeybind and (bind and bind.Name) or nil
				}
			end
			function api:Load(val)
				if val.State ~= nil then api:Set(val.State) end
				if hasColorpicker and val.Color then api:SetColor(Color3.new(unpack(val.Color))) end
				if hasColorpicker2 and val.Color2 then api:SetColor2(Color3.new(unpack(val.Color2))) end
				if hasKeybind and val.Bind then api:SetKeybind(Enum.KeyCode[val.Bind]) end
			end
			RegisterElementAPI("Toggle", tglName, api)

			if state then
				task.spawn(fireCallback)
			end

			return api
		end

		function BlockObj:CreateInput(inpConfig)
			local inpName = inpConfig.Name or "Input"
			local placeholder = inpConfig.Placeholder or "..."
			local defaultText = inpConfig.Default or ""
			local callback = inpConfig.Callback or function() end

			local container = CreateElementBase(38)

			local label = Instance.new("TextLabel")
			label.Name = "InputLabel"
			label.Size = UDim2.new(0.52, -15, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = inpName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local inputBox = Instance.new("Frame")
			inputBox.Name = "InputBox"
			inputBox.Size = UDim2.new(0.44, 0, 0, 28)
			inputBox.AnchorPoint = Vector2.new(1, 0.5)
			inputBox.Position = UDim2.new(1, -7, 0.5, 0)
			inputBox.BorderSizePixel = 0
			inputBox.ClipsDescendants = true
			inputBox.Parent = container
			ApplyTheme(inputBox, "Input", "BackgroundColor3")
			ApplyTheme(inputBox, "InputTrans", "BackgroundTransparency")
			
			local inputBoxCorner = Instance.new("UICorner")
			inputBoxCorner.CornerRadius = GLOBAL_CORNER
			inputBoxCorner.Parent = inputBox
			CS:AddTag(inputBoxCorner, "ElementCorner")
			
			attachStroke(inputBox, "ElementStroke")

			local textBox = Instance.new("TextBox")
			textBox.Name = "TextBox"
			textBox.Size = UDim2.new(1, 0, 1, 0)
			textBox.Position = UDim2.new(0, 0, 0, 0)
			textBox.BackgroundTransparency = 1
			textBox.BorderSizePixel = 0
			textBox.TextSize = 12
			textBox.PlaceholderText = placeholder
			textBox.Text = defaultText
			textBox.TextXAlignment = Enum.TextXAlignment.Center
			textBox.TextTruncate = Enum.TextTruncate.AtEnd
			textBox.Font = Enum.Font.Gotham
			textBox.Parent = inputBox
			ApplyTheme(textBox, "Text", "TextColor3")
			ApplyTheme(textBox, "TextMuted", "PlaceholderColor3")
			ApplyTheme(textBox, "TextFont", "Font")
			
			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					inputBox.Size = UDim2.new(0.44, 0, 0, 28)
					inputBox.AnchorPoint = Vector2.new(1, 0.5)
					inputBox.Position = UDim2.new(1, -7, 0.5, 0)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 56)
					label.Size = UDim2.new(1, -24, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					inputBox.Size = UDim2.new(1, -16, 0, 26) 
					inputBox.AnchorPoint = Vector2.new(0, 0)
					inputBox.Position = UDim2.new(0, 8, 0, 22) 
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.52, -15, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					inputBox.Size = UDim2.new(0.44, 0, 0, 22)
					inputBox.AnchorPoint = Vector2.new(1, 0.5)
					inputBox.Position = UDim2.new(1, -5, 0.5, 0)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 46)
					label.Size = UDim2.new(1, -24, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					inputBox.Size = UDim2.new(1, -12, 0, 22) 
					inputBox.AnchorPoint = Vector2.new(0, 0)
					inputBox.Position = UDim2.new(0, 6, 0, 18) 
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			table.insert(Window._connections, textBox.FocusLost:Connect(function()
				callback(textBox.Text)
			end))
			RegisterElement(inpName, container)
			
			local api = {}
			function api:SetText(txt)
				textBox.Text = txt
				callback(txt)
			end
			function api:Save()
				return { Text = textBox.Text }
			end
			function api:Load(val)
				if val.Text ~= nil then
					api:SetText(val.Text)
				end
			end
			RegisterElementAPI("Input", inpName, api)
			return api
		end

		function BlockObj:CreateDropdown(dropConfig)
			local isMulti = dropConfig.Multi or false
			local isSearch = dropConfig.Search or false
			return CreateAdvancedDropdown(dropConfig, isMulti, isSearch)
		end

		function BlockObj:CreateSlider(slConfig)
			local slName = slConfig.Name or "Slider"
			local min = slConfig.Min or 0
			local max = slConfig.Max or 100
			local rawStep = slConfig.Step or 1
			local step = (type(rawStep) == "number" and rawStep > 0) and rawStep or 1

			local stepStr = tostring(step)
			local decimals = 0
			local exp = stepStr:match("[eE]%-(%d+)")
			if exp then
				local mantissa = stepStr:match("^(.-)[eE]")
				local mantissaDecs = (mantissa and mantissa:find("%.")) and #mantissa:split(".")[2] or 0
				decimals = tonumber(exp) + mantissaDecs
			elseif stepStr:find("%.") then
				decimals = #stepStr:split(".")[2]
			end
			decimals = math.clamp(decimals, 0, 14)

			local function roundVal(val)
				val = math.clamp(val, min, max)
				local snapped = math.round(val / step) * step
				return tonumber(string.format("%." .. decimals .. "f", snapped)) or snapped
			end

			local function formatVal(val)
				return string.format("%." .. decimals .. "f", val)
			end

			local default = roundVal(slConfig.Default or min)
			local callback = slConfig.Callback or function() end
			local currentValue = default

			local container = CreateElementBase(38) 

			local label = Instance.new("TextLabel")
			label.Name = "SliderLabel"
			label.Size = UDim2.new(0.35, 0, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = slName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local valueBox = Instance.new("Frame")
			valueBox.Name = "ValueBox"
			valueBox.Size = UDim2.new(0, 52, 0, 24)
			valueBox.AnchorPoint = Vector2.new(1, 0.5)
			valueBox.Position = UDim2.new(1, -7, 0.5, 0)
			valueBox.BorderSizePixel = 0
			valueBox.Parent = container
			ApplyTheme(valueBox, "Input", "BackgroundColor3")
			ApplyTheme(valueBox, "InputTrans", "BackgroundTransparency")
			
			local valueBoxCorner = Instance.new("UICorner")
			valueBoxCorner.CornerRadius = GLOBAL_CORNER
			valueBoxCorner.Parent = valueBox
			CS:AddTag(valueBoxCorner, "ElementCorner")
			
			attachStroke(valueBox, "ElementStroke")

			local valueInput = Instance.new("TextBox")
			valueInput.Name = "ValueInput"
			valueInput.Size = UDim2.new(1, 0, 1, 0)
			valueInput.BackgroundTransparency = 1
			valueInput.BorderSizePixel = 0
			valueInput.TextSize = 12
			valueInput.Text = formatVal(default)
			valueInput.TextTruncate = Enum.TextTruncate.AtEnd
			valueInput.Font = Enum.Font.Gotham
			valueInput.Parent = valueBox
			ApplyTheme(valueInput, "Text", "TextColor3")
			ApplyTheme(valueInput, "TextFont", "Font")

			local track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(0.52, -64, 0, 6) 
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -64, 0.5, 0)
			track.BorderSizePixel = 0
			track.Parent = container
			ApplyTheme(track, "Input", "BackgroundColor3")
			ApplyTheme(track, "InputTrans", "BackgroundTransparency")
			
			local trackCorner = Instance.new("UICorner")
			trackCorner.CornerRadius = UDim.new(1, 0)
			trackCorner.Parent = track
			attachStroke(track, "ElementStroke")

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0)
			fill.BorderSizePixel = 0
			fill.Parent = track
			ApplyTheme(fill, "Accent", "BackgroundColor3")
			
			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = UDim.new(1, 0)
			fillCorner.Parent = fill

			local knob = Instance.new("Frame")
			knob.Name = "SliderKnob"
			knob.Size = UDim2.new(0, 12, 0, 12)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.Position = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 0.5, 0)
			knob.BorderSizePixel = 0
			knob.ZIndex = 3
			knob.Parent = track
			ApplyTheme(knob, "Accent", "BackgroundColor3")

			local knobCorner = Instance.new("UICorner")
			knobCorner.CornerRadius = UDim.new(1, 0)
			knobCorner.Parent = knob

			local knobStroke = Instance.new("UIStroke")
			knobStroke.Thickness = 1.5
			knobStroke.Color = Color3.fromRGB(255, 255, 255)
			knobStroke.Parent = knob

			local function updateStyle(style)
				if style == 1 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.35, 0, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 13
					valueBox.Size = UDim2.new(0, 52, 0, 24)
					valueBox.AnchorPoint = Vector2.new(1, 0.5)
					valueBox.Position = UDim2.new(1, -7, 0.5, 0)
					track.Size = UDim2.new(0.52, -64, 0, 6)
					track.AnchorPoint = Vector2.new(1, 0.5)
					track.Position = UDim2.new(1, -64, 0.5, 0)
					knob.Size = UDim2.new(0, 12, 0, 12)
				elseif style == 2 then
					container.Size = UDim2.new(1, 0, 0, 44)
					label.Size = UDim2.new(0.5, 0, 0, 16)
					label.Position = UDim2.new(0, 12, 0, 6)
					label.TextSize = 13
					valueBox.Size = UDim2.new(0, 52, 0, 20)
					valueBox.AnchorPoint = Vector2.new(1, 0)
					valueBox.Position = UDim2.new(1, -12, 0, 4)
					track.Size = UDim2.new(1, -24, 0, 6)
					track.AnchorPoint = Vector2.new(0.5, 0)
					track.Position = UDim2.new(0.5, 0, 0, 28)
					knob.Size = UDim2.new(0, 12, 0, 12)
				elseif style == 3 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.Size = UDim2.new(0.35, 0, 1, 0)
					label.Position = UDim2.new(0, 15, 0, 0)
					label.TextSize = 12
					valueBox.Size = UDim2.new(0, 52, 0, 20)
					valueBox.AnchorPoint = Vector2.new(1, 0.5)
					valueBox.Position = UDim2.new(1, -5, 0.5, 0)
					track.Size = UDim2.new(0.52, -64, 0, 4)
					track.AnchorPoint = Vector2.new(1, 0.5)
					track.Position = UDim2.new(1, -61, 0.5, 0)
					knob.Size = UDim2.new(0, 10, 0, 10)
				elseif style == 4 then
					container.Size = UDim2.new(1, 0, 0, 38)
					label.Size = UDim2.new(0.5, 0, 0, 14)
					label.Position = UDim2.new(0, 12, 0, 4)
					label.TextSize = 12
					valueBox.Size = UDim2.new(0, 52, 0, 18)
					valueBox.AnchorPoint = Vector2.new(1, 0)
					valueBox.Position = UDim2.new(1, -12, 0, 3)
					track.Size = UDim2.new(1, -24, 0, 4)
					track.AnchorPoint = Vector2.new(0.5, 0)
					track.Position = UDim2.new(0.5, 0, 0, 24)
					knob.Size = UDim2.new(0, 10, 0, 10)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local draggingSlider = false
			local function updateSlider(inputPos)
				local relative = math.clamp((inputPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				local rawValue = min + ((max - min) * relative)
				local steppedValue = roundVal(rawValue)
				currentValue = steppedValue
				valueInput.Text = formatVal(steppedValue)
				local alpha = math.clamp((steppedValue - min) / (max - min), 0, 1)
				TS:Create(fill, TweenInfo.new(0.1), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
				TS:Create(knob, TweenInfo.new(0.1), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
				callback(steppedValue)
			end

			table.insert(Window._connections, track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSlider = true
					updateSlider(input.Position.X)
				end
			end))

			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateSlider(input.Position.X)
				end
			end))

			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSlider = false
				end
			end))

			table.insert(Window._connections, valueInput.FocusLost:Connect(function()
				local num = tonumber(valueInput.Text)
				if num then
					local steppedValue = roundVal(num)
					currentValue = steppedValue
					valueInput.Text = formatVal(steppedValue)
					local alpha = math.clamp((steppedValue - min) / (max - min), 0, 1)
					TS:Create(fill, TweenInfo.new(0.2), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
					TS:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
					callback(steppedValue)
				else
					currentValue = min
					valueInput.Text = formatVal(min)
					fill.Size = UDim2.new(0, 0, 1, 0)
					knob.Position = UDim2.new(0, 0, 0.5, 0)
					callback(min)
				end
			end))
			RegisterElement(slName, container)
			
			local api = {}
			function api:Set(newVal)
				local steppedValue = roundVal(newVal)
				if currentValue == steppedValue then return end
				currentValue = steppedValue
				valueInput.Text = formatVal(steppedValue)
				local alpha = math.clamp((steppedValue - min) / (max - min), 0, 1)
				fill.Size = UDim2.new(alpha, 0, 1, 0)
				knob.Position = UDim2.new(alpha, 0, 0.5, 0)
				callback(steppedValue)
			end
			function api:Save()
				return { Value = currentValue }
			end
			function api:Load(val)
				if val.Value ~= nil then
					api:Set(val.Value)
				end
			end
			RegisterElementAPI("Slider", slName, api)
			return api
		end
		
		function BlockObj:CreateRangeSlider(cfg)
			cfg = cfg or {}
			local name = cfg.Name or cfg.Title or "Range Slider"
			local min = tonumber(cfg.Min) or 0
			local max = tonumber(cfg.Max) or 100
			if max <= min then max = min + 1 end
			local step = math.max(tonumber(cfg.Step) or 1, 0.000001)
			local defaults = cfg.Default or {min, max}
			local callback = cfg.Callback or function() end
			local low, high = min, max
			local container = CreateElementBase(54)
			local title = Instance.new("TextLabel")
			title.Name = "RangeLabel"
			title.BackgroundTransparency = 1
			title.Size = UDim2.new(0.58, 0, 0, 22)
			title.Position = UDim2.fromOffset(12, 2)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextSize = 12
			title.Text = name
			title.Parent = container
			ApplyTheme(title, "Text", "TextColor3")
			ApplyTheme(title, "TextFont", "Font")
			local valueLabel = Instance.new("TextLabel")
			valueLabel.Name = "RangeValues"
			valueLabel.BackgroundTransparency = 1
			valueLabel.Size = UDim2.new(0.42, -12, 0, 22)
			valueLabel.Position = UDim2.new(0.58, 0, 0, 2)
			valueLabel.TextXAlignment = Enum.TextXAlignment.Right
			valueLabel.TextSize = 12
			valueLabel.Parent = container
			ApplyTheme(valueLabel, "TextMuted", "TextColor3")
			local track = Instance.new("Frame")
			track.Name = "RangeTrack"
			track.Size = UDim2.new(1, -26, 0, 6)
			track.Position = UDim2.new(0, 13, 0, 36)
			track.BorderSizePixel = 0
			track.Parent = container
			ApplyTheme(track, "Input", "BackgroundColor3")
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(1, 0)
			tc.Parent = track
			attachStroke(track, "ElementStroke")
			local fill = Instance.new("Frame")
			fill.Name = "SelectedRange"
			fill.BorderSizePixel = 0
			fill.Parent = track
			ApplyTheme(fill, "Accent", "BackgroundColor3")
			local fc = Instance.new("UICorner")
			fc.CornerRadius = UDim.new(1, 0)
			fc.Parent = fill
			local knobs = {}
			for i = 1, 2 do
				local knob = Instance.new("TextButton")
				knob.Name = i == 1 and "MinHandle" or "MaxHandle"
				knob.Text = ""
				knob.Size = UDim2.fromOffset(14, 14)
				knob.AnchorPoint = Vector2.new(0.5, 0.5)
				knob.ZIndex = 5 + i
				knob.Parent = track
				ApplyTheme(knob, "Accent", "BackgroundColor3")
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = knob
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 1.5
				stroke.Color = Color3.new(1, 1, 1)
				stroke.Parent = knob
				knobs[i] = knob
			end
			local function snap(value)
				return math.clamp(min + math.round((math.clamp(tonumber(value) or min, min, max) - min) / step) * step, min, max)
			end
			local function redraw(animate)
				local a = (low - min) / (max - min)
				local b = (high - min) / (max - min)
				local targets = {UDim2.new(a, 0, 0.5, 0), UDim2.new(b, 0, 0.5, 0)}
				local fillPos = UDim2.new(a, 0, 0, 0)
				local fillSize = UDim2.new(b - a, 0, 1, 0)
				if animate then
					for i, knob in ipairs(knobs) do TS:Create(knob, TweenInfo.new(0.09), {Position = targets[i]}):Play() end
					TS:Create(fill, TweenInfo.new(0.09), {Position = fillPos, Size = fillSize}):Play()
				else
					for i, knob in ipairs(knobs) do knob.Position = targets[i] end
					fill.Position = fillPos
					fill.Size = fillSize
				end
				valueLabel.Text = tostring(low) .. " - " .. tostring(high)
			end
			local api = {}
			function api:Set(a, b)
				if type(a) == "table" then b = a[2] or a.Max; a = a[1] or a.Min end
				local newLow = snap(a or low)
				local newHigh = snap(b or high)
				if newLow > newHigh then newLow, newHigh = newHigh, newLow end
				if low == newLow and high == newHigh then return end
				low, high = newLow, newHigh
				redraw(true)
				callback(low, high)
			end
			function api:Get() return low, high end
			function api:Save() return {Min = low, Max = high} end
			function api:Load(data)
				if type(data) == "table" then self:Set(data.Min or data[1], data.Max or data[2]) end
			end
			local active = nil
			local function move(x)
				if not active or track.AbsoluteSize.X <= 0 then return end
				local value = snap(min + math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (max - min))
				if active == 1 then api:Set(math.min(value, high), high) else api:Set(low, math.max(value, low)) end
			end
			for i, knob in ipairs(knobs) do
				table.insert(Window._connections, knob.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then active = i; move(input.Position.X) end
				end))
			end
			table.insert(Window._connections, track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local value = min + math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1) * (max - min)
					active = math.abs(value - low) <= math.abs(value - high) and 1 or 2
					move(input.Position.X)
				end
			end))
			table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
				if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then move(input.Position.X) end
			end))
			table.insert(Window._connections, UIS.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then active = nil end
			end))
			low, high = snap(defaults[1] or defaults.Min or min), snap(defaults[2] or defaults.Max or max)
			if low > high then low, high = high, low end
			redraw(false)
			RegisterElement(name, container)
			RegisterElementAPI("RangeSlider", name, api)
			return api
		end

		function BlockObj:CreateColorpicker(cpConfig)
			local cpName = cpConfig.Name or "Colorpicker"
			local defaultColor = cpConfig.Default or Color3.fromRGB(255, 255, 255)
			local callback = cpConfig.Callback or function() end
			local currentColor = defaultColor
			
			local container = CreateElementBase(38)

			local label = Instance.new("TextLabel")
			label.Name = "ColorpickerLabel"
			label.Size = UDim2.new(1, -60, 1, 0)
			label.Position = UDim2.new(0, 15, 0, 0)
			label.BackgroundTransparency = 1
			label.TextSize = 13
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = cpName
			label.Font = Enum.Font.Gotham
			label.Parent = container
			ApplyTheme(label, "Text", "TextColor3")
			ApplyTheme(label, "TextFont", "Font")

			local previewBox = Instance.new("TextButton")
			previewBox.Name = "PreviewBox"
			previewBox.Size = UDim2.new(0, 24, 0, 24)
			previewBox.AnchorPoint = Vector2.new(1, 0.5)
			previewBox.Position = UDim2.new(1, -7, 0.5, 0) 
			previewBox.BackgroundColor3 = defaultColor
			previewBox.BorderSizePixel = 0
			previewBox.Text = ""
			previewBox.Parent = container
			
			local previewBoxCorner = Instance.new("UICorner")
			previewBoxCorner.CornerRadius = GLOBAL_CORNER
			previewBoxCorner.Parent = previewBox
			CS:AddTag(previewBoxCorner, "ElementCorner")

			local stroke = Instance.new("UIStroke")
			stroke.Name = "PreviewStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = 2
			stroke.Parent = previewBox
			ApplyTheme(stroke, "Outlines", "Color")

			local function updateStyle(style)
				if style == 3 or style == 4 then
					container.Size = UDim2.new(1, 0, 0, 30)
					label.TextSize = 12
					previewBox.Size = UDim2.new(0, 18, 0, 18)
					previewBox.Position = UDim2.new(1, -5, 0.5, 0)
				else
					container.Size = UDim2.new(1, 0, 0, 38)
					label.TextSize = 13
					previewBox.Size = UDim2.new(0, 24, 0, 24)
					previewBox.Position = UDim2.new(1, -7, 0.5, 0)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local innerAPI = AttachColorPicker(previewBox, defaultColor, function(c)
				currentColor = c
				callback(c)
			end)
			RegisterElement(cpName, container)
			
			local api = {}
			function api:SetColor(c)
				currentColor = c
				innerAPI:SetColor(c)
			end
			function api:Save()
				return { Color = {currentColor.R, currentColor.G, currentColor.B} }
			end
			function api:Load(val)
				if val.Color then
					api:SetColor(Color3.new(unpack(val.Color)))
				end
			end
			RegisterElementAPI("Colorpicker", cpName, api)
			return api
		end
		
		function BlockObj:CreateLabel(text)
			local lbl = Instance.new("TextLabel")
			lbl.Name = "BlockLabel"
			lbl.Size = UDim2.new(1, 0, 0, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.Y
			lbl.BackgroundTransparency = 1
			lbl.BorderSizePixel = 0
			lbl.TextSize = 13
			lbl.Text = text
			lbl.TextWrapped = true
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.LayoutOrder = 2
			lbl.Font = Enum.Font.Gotham
			lbl.Parent = blockContainer
			ApplyTheme(lbl, "TextMuted", "TextColor3")
			ApplyTheme(lbl, "SubtextFont", "Font")

			local function updateStyle(style)
				if style == 3 or style == 4 then
					lbl.TextSize = 12
				else
					lbl.TextSize = 13
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)
			RegisterElement(text, lbl)
			
			local api = {}
			function api:SetText(txt)
				lbl.Text = txt
			end
			return api
		end

		function BlockObj:CreateSection(text)
			local hasText = type(text) == "string" and text ~= ""

			local container = Instance.new("Frame")
			container.Name = "SectionContainer"
			container.Size = UDim2.new(1, 0, 0, 24)
			container.BackgroundTransparency = 1
			container.BorderSizePixel = 0
			container.ClipsDescendants = true
			container.LayoutOrder = 2
			container.Parent = blockContainer

			local function updateStyle(style)
				if style == 3 or style == 4 then
					container.Size = UDim2.new(1, 0, 0, 16)
				else
					container.Size = UDim2.new(1, 0, 0, 24)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)

			local label, leftLine, rightLine
			local function updateLines()
				if not label or not container then return end
				local totalW = container.AbsoluteSize.X
				if totalW <= 0 then return end

				local textWidth = label.AbsoluteSize.X
				local gap = 8
				local sidePad = 4
				local lineW = math.max(0, (totalW / 2) - (textWidth / 2) - gap - sidePad)

				if leftLine then
					leftLine.Size = UDim2.new(0, lineW, 0, 1)
					leftLine.Position = UDim2.new(0.5, -((textWidth / 2) + gap), 0.5, 0)
				end
				if rightLine then
					rightLine.Size = UDim2.new(0, lineW, 0, 1)
					rightLine.Position = UDim2.new(0.5, ((textWidth / 2) + gap), 0.5, 0)
				end
			end

			if not hasText then
				local line = Instance.new("Frame")
				line.Name = "SectionLine"
				line.Size = UDim2.new(1, -8, 0, 1)
				line.Position = UDim2.new(0.5, 0, 0.5, 0)
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.BorderSizePixel = 0
				line.Parent = container
				ApplyTheme(line, "Outlines", "BackgroundColor3")
			else
				label = Instance.new("TextLabel")
				label.Name = "SectionLabel"
				label.AutomaticSize = Enum.AutomaticSize.X
				label.Size = UDim2.new(0, 0, 1, 0)
				label.Position = UDim2.new(0.5, 0, 0.5, 0)
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.BackgroundTransparency = 1
				label.BorderSizePixel = 0
				label.TextSize = 11
				label.Text = text
				label.ZIndex = 2
				label.Parent = container
				
				ApplyTheme(label, "TextMuted", "TextColor3")
				ApplyTheme(label, "SubtextFont", "Font")

				leftLine = Instance.new("Frame")
				leftLine.Name = "LeftLine"
				leftLine.AnchorPoint = Vector2.new(1, 0.5)
				leftLine.BorderSizePixel = 0
				leftLine.Parent = container
				ApplyTheme(leftLine, "Outlines", "BackgroundColor3")

				rightLine = Instance.new("Frame")
				rightLine.Name = "RightLine"
				rightLine.AnchorPoint = Vector2.new(0, 0.5)
				rightLine.BorderSizePixel = 0
				rightLine.Parent = container
				ApplyTheme(rightLine, "Outlines", "BackgroundColor3")
				
				table.insert(Window._connections, label:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLines))
				table.insert(Window._connections, container:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLines))
				task.spawn(function()
					task.wait()
					updateLines()
				end)
			end
			RegisterElement(text or "Section", container)
			
			local api = {}
			function api:SetText(txt)
				if label then 
					label.Text = txt
					task.spawn(updateLines)
				end
			end
			return api
		end

		function BlockObj:CreateKeybind(cfg)
			local el = CreateElementBase(38)
			
			local bind = cfg.Default
			
			local lbl = Instance.new("TextLabel")
			lbl.Name = "KeybindLabel"
			lbl.Size = UDim2.new(1, -120, 1, 0)
			lbl.Position = UDim2.new(0, 15, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.TextSize = 13
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = cfg.Name
			lbl.Font = Enum.Font.Gotham
			lbl.Parent = el
			ApplyTheme(lbl, "Text", "TextColor3")
			ApplyTheme(lbl, "TextFont", "Font")
			
			local box = Instance.new("Frame")
			box.Name = "KeybindBox"
			box.Size = UDim2.new(0, 30, 0, 24)
			box.AutomaticSize = Enum.AutomaticSize.X
			box.AnchorPoint = Vector2.new(1, 0.5)
			box.Position = UDim2.new(1, -7, 0.5, 0)
			box.Parent = el
			ApplyTheme(box, "Input", "BackgroundColor3")
			ApplyTheme(box, "InputTrans", "BackgroundTransparency")
			
			local boxCorner = Instance.new("UICorner")
			boxCorner.CornerRadius = GLOBAL_CORNER
			boxCorner.Parent = box
			CS:AddTag(boxCorner, "ElementCorner")
			
			attachStroke(box, "ElementStroke")
			
			local bBtn = Instance.new("TextButton")
			bBtn.Name = "KeybindButton"
			bBtn.Size = UDim2.new(1,0,1,0)
			bBtn.BackgroundTransparency = 1
			bBtn.TextSize = 12
			bBtn.Text = getShortKey(bind)
			bBtn.Font = Enum.Font.Gotham
			bBtn.Parent = box
			ApplyTheme(bBtn, "TextMuted", "TextColor3")
			ApplyTheme(bBtn, "TextFont", "Font")
			
			local mobileToggle, getMobileBtn
			if isMobile then
				mobileToggle, _, getMobileBtn = createMobileToggle(el, function(enabled, removeBtn, saveBtn)
					if enabled then
						saveBtn(createMobileBindButton(getShortKey(bind), function()
							if cfg.Callback then pcall(function() cfg.Callback(bind) end) end
						end))
					else
						removeBtn()
					end
				end)
			end

			local p = Instance.new("UIPadding")
			p.Name = "KeybindPadding"
			p.PaddingLeft = UDim.new(0,6)
			p.PaddingRight = UDim.new(0,6)
			p.Parent = bBtn

			local function updateStyle(style)
				local edge = (style == 3 or style == 4) and 5 or 7
				if style == 3 or style == 4 then
					el.Size = UDim2.new(1, 0, 0, 30)
					lbl.TextSize = 12
					box.Size = UDim2.new(0, 30, 0, 20)
					bBtn.TextSize = 11
				else
					el.Size = UDim2.new(1, 0, 0, 38)
					lbl.TextSize = 13
					box.Size = UDim2.new(0, 30, 0, 24)
					bBtn.TextSize = 12
				end

				box.AnchorPoint = Vector2.new(1, 0.5)
				box.Position = UDim2.new(1, -edge, 0.5, 0)
				lbl.Position = UDim2.new(0, mobileToggle and 38 or 15, 0, 0)
				lbl.Size = UDim2.new(1, -(120 + (mobileToggle and 30 or 0)), 1, 0)
				if mobileToggle then
					mobileToggle.AnchorPoint = Vector2.new(0, 0.5)
					mobileToggle.Position = UDim2.new(0, 12, 0.5, 0)
					mobileToggle.Size = UDim2.new(0, 20, 0, 20)
				end
			end
			table.insert(Window._styleCallbacks, updateStyle)
			updateStyle(THEME.ElementStyle)
	
			local isBinding = false
			
			table.insert(Window._connections, bBtn.MouseButton1Click:Connect(function() 
				isBinding = true
				if isSettings and cfg.Name == "Open GUI Keybind" then Window._capturingOpenKeybind = true end
				bBtn.Text = "..."
				ApplyTheme(bBtn, "Accent", "TextColor3") 
			end))
			
			table.insert(Window._connections, UIS.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed and not isBinding then return end
				
				if isBinding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						bind = input.KeyCode
						bBtn.Text = getShortKey(bind)
						ApplyTheme(bBtn, "TextMuted", "TextColor3")
						isBinding = false
						if isSettings and cfg.Name == "Open GUI Keybind" then Window._capturingOpenKeybind = false end
						
						if cfg.Callback then 
							pcall(function() cfg.Callback(bind) end)
						end
						if Window.UpdateKeybinds then Window.UpdateKeybinds() end
					end
				else
					if bind and bind ~= Enum.KeyCode.Unknown and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind then
						if cfg.Callback then 
							pcall(function() cfg.Callback(bind) end)
						end
					end
				end
			end))
			RegisterElement(cfg.Name, el)
			
			local api = {}
			function api:SetKeybind(k)
				bind = k
				bBtn.Text = getShortKey(k)
				local mb = getMobileBtn and getMobileBtn()
				if mb then mb.Text = getShortKey(bind) end
			end
			function api:Save()
				return { Bind = bind and bind.Name or nil }
			end
			function api:Load(val)
				if val.Bind then
					local resolved = resolveKeycode(val.Bind)
					if resolved then
						api:SetKeybind(resolved)
						if isSettings and cfg.Name == "Open GUI Keybind" then
							Window:SetOpenKeybind(resolved)
						end
					end
				end
			end
			RegisterElementAPI("Keybind", cfg.Name, api)
			return api
		end
		
		return BlockObj
	end
	
	function Window:CreateTab(tabConfig, legacyIcon, legacyIsSettings)
		local name, icon, isSettings
		if type(tabConfig) == "table" then
			name = tabConfig.Name or "Tab"
			icon = tabConfig.Icon
			isSettings = tabConfig.IsSettings or false
		else
			name = tostring(tabConfig or "Tab")
			icon = legacyIcon
			isSettings = legacyIsSettings or false
		end
	
		local tabData = {Name = name, IsSettings = isSettings}
		local iconAsset = parseAsset(icon)
		local hasIcon = (iconAsset and iconAsset ~= "")
		local isCollapsed = (currentSidebarWidth < 115)
		
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "TabButton_" .. name
		tabButton.Size = isCollapsed and UDim2.new(0, 36, 0, 36) or UDim2.new(1, -4, 0, 38)
		tabButton.AutoButtonColor = false
		tabButton.Text = ""
		tabButton.BackgroundTransparency = 1
		tabButton.BorderSizePixel = 0
		tabButton.LayoutOrder = isSettings and 9999 or (#Window.Tabs + 1)
		tabButton.Parent = tabList
		
		local tabStroke = Instance.new("UIStroke")
		tabStroke.Name = "TabStroke"
		tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		tabStroke.Thickness = 1
		tabStroke.Transparency = 1
		tabStroke.Parent = tabButton
		ApplyTheme(tabStroke, "Outlines", "Color")
	
		local tabButtonCorner = Instance.new("UICorner")
		tabButtonCorner.CornerRadius = GLOBAL_CORNER
		tabButtonCorner.Parent = tabButton
		CS:AddTag(tabButtonCorner, "ElementCorner")
	
		local tabBtnPadding = Instance.new("UIPadding")
		tabBtnPadding.Name = "TabBtnPadding"
		tabBtnPadding.PaddingLeft = isCollapsed and UDim.new(0, 0) or UDim.new(0, 15) 
		tabBtnPadding.PaddingRight = isCollapsed and UDim.new(0, 0) or UDim.new(0, 15)
		tabBtnPadding.Parent = tabButton
	
		local tabLayout = Instance.new("UIListLayout")
		tabLayout.Name = "TabLayout"
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		tabLayout.HorizontalAlignment = isCollapsed and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Padding = UDim.new(0, 10)
		tabLayout.Parent = tabButton
	
		local tabIconLabel
		if hasIcon then
			tabIconLabel = Instance.new("ImageLabel")
			tabIconLabel.Name = "TabIcon"
			tabIconLabel.Size = isCollapsed and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 26, 0, 26)
			tabIconLabel.BackgroundTransparency = 1
			tabIconLabel.Image = iconAsset
			tabIconLabel.LayoutOrder = 1
			tabIconLabel.Parent = tabButton
			ApplyTheme(tabIconLabel, "TextMuted", "ImageColor3")
		end
	
		local tabLetterLabel
		if not hasIcon then
			tabLetterLabel = Instance.new("TextLabel")
			tabLetterLabel.Name = "TabLetter"
			tabLetterLabel.Size = isCollapsed and UDim2.new(0, 30, 0, 30) or UDim2.new(0, 26, 0, 26)
			tabLetterLabel.BackgroundTransparency = 1
			tabLetterLabel.TextSize = isCollapsed and 24 or 18
			tabLetterLabel.TextXAlignment = Enum.TextXAlignment.Center
			tabLetterLabel.TextYAlignment = Enum.TextYAlignment.Center
			tabLetterLabel.Text = getFirstChar(name)
			tabLetterLabel.LayoutOrder = 1
			tabLetterLabel.Visible = isCollapsed
			tabLetterLabel.Parent = tabButton
			ApplyTheme(tabLetterLabel, "TextMuted", "TextColor3")
			ApplyTheme(tabLetterLabel, "TextFont", "Font")
		end
	
		local tabBtnTitle = Instance.new("TextLabel")
		tabBtnTitle.Name = "TabTitle"
		tabBtnTitle.AutomaticSize = Enum.AutomaticSize.X
		tabBtnTitle.Size = UDim2.new(0, 0, 1, 0)
		tabBtnTitle.BackgroundTransparency = 1
		tabBtnTitle.TextSize = 13
		tabBtnTitle.TextXAlignment = Enum.TextXAlignment.Left
		tabBtnTitle.Text = name
		tabBtnTitle.TextTruncate = Enum.TextTruncate.AtEnd
		tabBtnTitle.Visible = not isCollapsed
		tabBtnTitle.LayoutOrder = 2
		tabBtnTitle.Parent = tabButton
		ApplyTheme(tabBtnTitle, "TextMuted", "TextColor3")
		ApplyTheme(tabBtnTitle, "TextFont", "Font")
	
		local page = Instance.new("CanvasGroup")
		page.GroupTransparency = 1
		page.Name = "Page_" .. name
		page.Size = UDim2.new(1, 0, 1, 0)
		page.Position = UDim2.new(0, 0, 0, 0)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = pagesFolder
	
		local pageContent = Instance.new("ScrollingFrame")
		pageContent.Name = "PageContent"
		pageContent.Size = UDim2.new(1, 0, 1, 0)
		pageContent.Position = UDim2.new(0, 0, 0, 0)
		pageContent.BackgroundTransparency = 1
		pageContent.ScrollBarThickness = 0
		pageContent.CanvasSize = UDim2.new(0, 0, 0, 0)
		pageContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
		pageContent.Parent = page
		
		local pagePadding = Instance.new("UIPadding")
		pagePadding.Name = "PagePadding"
		pagePadding.PaddingTop = UDim.new(0, 14)
		pagePadding.PaddingBottom = UDim.new(0, 14)
		pagePadding.PaddingLeft = UDim.new(0, 14)
		pagePadding.PaddingRight = UDim.new(0, 14)
		pagePadding.Parent = pageContent
	
		local columnsLayout = Instance.new("UIListLayout")
		columnsLayout.Name = "ColumnsLayout"
		columnsLayout.FillDirection = Enum.FillDirection.Horizontal
		columnsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		columnsLayout.Padding = UDim.new(0, 14)
		columnsLayout.Parent = pageContent
	
		local leftColumn = Instance.new("Frame")
		leftColumn.Name = "LeftColumn"
		leftColumn.Size = UDim2.new(0.5, -7, 0, 0)
		leftColumn.AutomaticSize = Enum.AutomaticSize.Y
		leftColumn.BackgroundTransparency = 1
		leftColumn.Parent = pageContent
		
		local leftColLayout = Instance.new("UIListLayout")
		leftColLayout.Name = "LeftColLayout"
		leftColLayout.FillDirection = Enum.FillDirection.Vertical
		leftColLayout.SortOrder = Enum.SortOrder.LayoutOrder
		leftColLayout.Padding = UDim.new(0, 14)
		leftColLayout.Parent = leftColumn
	
		local rightColumn = Instance.new("Frame")
		rightColumn.Name = "RightColumn"
		rightColumn.Size = UDim2.new(0.5, -7, 0, 0)
		rightColumn.AutomaticSize = Enum.AutomaticSize.Y
		rightColumn.BackgroundTransparency = 1
		rightColumn.Parent = pageContent
		
		local rightColLayout = Instance.new("UIListLayout")
		rightColLayout.Name = "RightColLayout"
		rightColLayout.FillDirection = Enum.FillDirection.Vertical
		rightColLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rightColLayout.Padding = UDim.new(0, 14)
		rightColLayout.Parent = rightColumn
	
		local function updateTabStyle(style)
			if style == 3 or style == 4 then
				leftColumn.Size = UDim2.new(0.5, -4, 0, 0)
				rightColumn.Size = UDim2.new(0.5, -4, 0, 0)
				pagePadding.PaddingTop = UDim.new(0, 8)
				pagePadding.PaddingBottom = UDim.new(0, 8)
				pagePadding.PaddingLeft = UDim.new(0, 8)
				pagePadding.PaddingRight = UDim.new(0, 8)
				columnsLayout.Padding = UDim.new(0, 8)
				leftColLayout.Padding = UDim.new(0, 8)
				rightColLayout.Padding = UDim.new(0, 8)
			else
				leftColumn.Size = UDim2.new(0.5, -7, 0, 0)
				rightColumn.Size = UDim2.new(0.5, -7, 0, 0)
				pagePadding.PaddingTop = UDim.new(0, 14)
				pagePadding.PaddingBottom = UDim.new(0, 14)
				pagePadding.PaddingLeft = UDim.new(0, 14)
				pagePadding.PaddingRight = UDim.new(0, 14)
				columnsLayout.Padding = UDim.new(0, 14)
				leftColLayout.Padding = UDim.new(0, 14)
				rightColLayout.Padding = UDim.new(0, 14)
			end
		end
		table.insert(Window._styleCallbacks, updateTabStyle)
		updateTabStyle(THEME.ElementStyle)
	
		tabData.Button = tabButton
		tabData.Stroke = tabStroke
		tabData.Label = tabBtnTitle
		tabData.Icon = tabIconLabel
		tabData.LetterLabel = tabLetterLabel
		tabData.Page = page
		tabData.Padding = tabBtnPadding
		tabData.Layout = tabLayout
		
		function tabData:SetTitle(newTitle)
			tabBtnTitle.Text = newTitle
			if tabLetterLabel then
				tabLetterLabel.Text = getFirstChar(newTitle)
			end
		end
	
		local function activateTab()
			if Window.CurrentTab == tabData then return end
	
			if searchInput and searchInput.Text ~= "" then
				searchInput.Text = "" 
			end
	
			local prevTab = Window.CurrentTab
			Window.CurrentTab = tabData
			local isTopOrBottom = (SIDEBAR_STATE.Position == "Top" or SIDEBAR_STATE.Position == "Bottom")
			local collapsedNow = (currentSidebarWidth < 115)
	
			if prevTab then
				prevTab.Page.ZIndex = 6
				TS:Create(prevTab.Stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
				ApplyTheme(prevTab.Stroke, "Outlines", "Color")
				
				ApplyTheme(prevTab.Label, "TextMuted", "TextColor3")
				if prevTab.Icon then ApplyTheme(prevTab.Icon, "TextMuted", "ImageColor3") end
				if prevTab.LetterLabel then ApplyTheme(prevTab.LetterLabel, "TextMuted", "TextColor3") end
				
				if not isTopOrBottom and not collapsedNow then 
					TS:Create(prevTab.Padding, TweenInfo.new(0.3), {PaddingLeft = UDim.new(0, 15)}):Play() 
				else
					TS:Create(prevTab.Padding, TweenInfo.new(0.3), {PaddingLeft = UDim.new(0, 0)}):Play()
				end
	
				if motionConfig then
					local oldPage = prevTab.Page
					local fade = TS:Create(oldPage, TweenInfo.new(motionDuration * 0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 1})
					fade:Play()
					fade.Completed:Once(function()
						if Window.CurrentTab ~= prevTab then oldPage.Visible = false end
					end)
				else
					prevTab.Page.Visible = false
				end
			end
	
			TS:Create(tabStroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
			ApplyTheme(tabStroke, "Accent", "Color")
			
			ApplyTheme(tabBtnTitle, "Text", "TextColor3")
			if tabIconLabel then ApplyTheme(tabIconLabel, "Accent", "ImageColor3") end
			if tabLetterLabel then ApplyTheme(tabLetterLabel, "Accent", "TextColor3") end
			
			if not isTopOrBottom and not collapsedNow then 
				TS:Create(tabBtnPadding, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {PaddingLeft = UDim.new(0, 22)}):Play() 
			else
				TS:Create(tabBtnPadding, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {PaddingLeft = UDim.new(0, 0)}):Play() 
			end
	
			page.Position = UDim2.new(0, 0, 0, motionConfig and 14 or 0)
			page.ZIndex = 7
			page.GroupTransparency = motionConfig and 1 or 0
			page.Visible = true
			if motionConfig then
				TS:Create(page, TweenInfo.new(motionDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0
				}):Play()
			end
		end
		
		table.insert(Window._connections, tabButton.MouseButton1Click:Connect(activateTab))
	
		function tabData:CreateBlock(blockConfig, overrideParent)
			local bName = blockConfig.Name or "Block"
			local bSide = blockConfig.Side or "Left"
			local bIcon = parseAsset(blockConfig.Icon)
			local variants = blockConfig.Variants

			local originalParent = overrideParent or ((bSide == "Right") and rightColumn or leftColumn)

			local blockAnchor = Instance.new("Frame")
			blockAnchor.Name = bName .. "_Anchor"
			blockAnchor.Size = UDim2.new(1, 0, 0, 0)
			blockAnchor.AutomaticSize = Enum.AutomaticSize.Y
			blockAnchor.BackgroundTransparency = 1
			blockAnchor.Parent = originalParent

			local dummyCard = Instance.new("Frame")
			dummyCard.Name = "DummyCard"
			dummyCard.Size = UDim2.new(1, 0, 0, 38)
			dummyCard.BackgroundTransparency = 1
			dummyCard.Visible = false
			dummyCard.Parent = blockAnchor
			ApplyTheme(dummyCard, "Card", "BackgroundColor3")
			ApplyTheme(dummyCard, "CardTrans", "BackgroundTransparency")

			local dummyCorner = Instance.new("UICorner")
			dummyCorner.CornerRadius = GLOBAL_CORNER
			dummyCorner.Parent = dummyCard
			CS:AddTag(dummyCorner, "ElementCorner")

			local dummyStroke = Instance.new("UIStroke")
			dummyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			dummyStroke.Thickness = 1
			dummyStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
			dummyStroke.Parent = dummyCard
			ApplyTheme(dummyStroke, "Outlines", "Color")
			CS:AddTag(dummyStroke, "BlockStroke")

			local dummyTitle = Instance.new("TextLabel")
			dummyTitle.Size = UDim2.new(1, -40, 1, 0)
			dummyTitle.Position = UDim2.new(0, 16, 0, 0)
			dummyTitle.BackgroundTransparency = 1
			dummyTitle.Text = bName
			dummyTitle.TextSize = 13
			dummyTitle.TextXAlignment = Enum.TextXAlignment.Left
			dummyTitle.Parent = dummyCard
			ApplyTheme(dummyTitle, "TextMuted", "TextColor3")
			ApplyTheme(dummyTitle, "TextFont", "Font")

			local dummyReturnBtn = Instance.new("ImageButton")
			dummyReturnBtn.Size = UDim2.new(0, 24, 0, 24) 
			dummyReturnBtn.AnchorPoint = Vector2.new(1, 0.5)
			dummyReturnBtn.Position = UDim2.new(1, -12, 0.5, 0)
			dummyReturnBtn.BackgroundTransparency = 1
			dummyReturnBtn.Image = "rbxassetid://10709790948"
			dummyReturnBtn.Rotation = 90 
			dummyReturnBtn.Parent = dummyCard
			ApplyTheme(dummyReturnBtn, "TextMuted", "ImageColor3")

			local blockContainer = Instance.new("Frame")
			blockContainer.Name = bName .. "_Block"
			blockContainer.Size = UDim2.new(1, 0, 0, 0)
			blockContainer.AutomaticSize = Enum.AutomaticSize.Y
			blockContainer.ZIndex = 100
			blockContainer.Active = true
			blockContainer.Parent = blockAnchor
			ApplyTheme(blockContainer, "Card", "BackgroundColor3")
			ApplyTheme(blockContainer, "CardTrans", "BackgroundTransparency")
			
			local blockContainerCorner = Instance.new("UICorner")
			blockContainerCorner.CornerRadius = GLOBAL_CORNER
			blockContainerCorner.Parent = blockContainer
			CS:AddTag(blockContainerCorner, "ElementCorner")

			local blockStroke = Instance.new("UIStroke")
			blockStroke.Name = "BlockStroke"
			blockStroke.Enabled = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
			blockStroke.Thickness = 1
			blockStroke.Parent = blockContainer
			ApplyTheme(blockStroke, "Outlines", "Color")
			CS:AddTag(blockStroke, "BlockStroke")

			local blockPadding = Instance.new("UIPadding")
			blockPadding.Name = "BlockPadding"
			blockPadding.PaddingTop = UDim.new(0, 12)
			blockPadding.PaddingBottom = UDim.new(0, 12)
			blockPadding.PaddingLeft = UDim.new(0, 12)
			blockPadding.PaddingRight = UDim.new(0, 12)
			blockPadding.Parent = blockContainer

			local blockLayout = Instance.new("UIListLayout")
			blockLayout.Name = "BlockLayout"
			blockLayout.FillDirection = Enum.FillDirection.Vertical
			blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
			blockLayout.Padding = UDim.new(0, 6)
			blockLayout.Parent = blockContainer

			local detachBtn = Instance.new("ImageButton")
			detachBtn.Size = UDim2.new(0, 24, 0, 24)
			detachBtn.AnchorPoint = Vector2.new(1, 0.5)
			detachBtn.Position = UDim2.new(1, 0, 0.5, 0)
			detachBtn.BackgroundTransparency = 1
			detachBtn.Image = "rbxassetid://10709790948"
			detachBtn.Rotation = -90 
			ApplyTheme(detachBtn, "Text", "ImageColor3")

			local isDetached = false
			local detachedPosition = nil
			local dragTriggers = {}
			local activeDragConns = {}

			local function ToggleDetach()
				isDetached = not isDetached
				if isDetached then
					local absPos = blockContainer.AbsolutePosition
					local absSize = blockContainer.AbsoluteSize
					
					blockContainer.Size = UDim2.new(0, absSize.X, 0, 0)
					blockContainer.Position = detachedPosition or UDim2.new(0, absPos.X, 0, absPos.Y + 15)
					blockContainer.Parent = screenGui

					ApplyTheme(blockContainer, "Background", "BackgroundColor3")
					ApplyTheme(blockContainer, "HUDTransparency", "BackgroundTransparency")
					
					dummyCard.Visible = true
					ApplyTheme(detachBtn, "TextMuted", "ImageColor3")
					detachBtn.Rotation = 90
					
					local dragging = false
					local dragStart, startPos
					
					for _, trigger in ipairs(dragTriggers) do
						local conn1 = trigger.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								dragging = true
								dragStart = input.Position
								startPos = blockContainer.Position
							end
						end)
						table.insert(activeDragConns, conn1)
					end
					
					local conn2 = UIS.InputChanged:Connect(function(input)
						if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							local delta = input.Position - dragStart
							blockContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
							detachedPosition = blockContainer.Position
						end
					end)
					table.insert(activeDragConns, conn2)
					
					local conn3 = UIS.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							dragging = false
						end
					end)
					table.insert(activeDragConns, conn3)
					
				else
					for _, c in ipairs(activeDragConns) do c:Disconnect() end
					activeDragConns = {}
					
					blockContainer.Size = UDim2.new(1, 0, 0, 0)
					blockContainer.Position = UDim2.new(0, 0, 0, 0)
					blockContainer.Parent = blockAnchor
					
					ApplyTheme(blockContainer, "Card", "BackgroundColor3")
					ApplyTheme(blockContainer, "CardTrans", "BackgroundTransparency")
					
					dummyCard.Visible = false
					ApplyTheme(detachBtn, "Text", "ImageColor3")
					detachBtn.Rotation = -90
				end
			end

			Window._configElements["__AxiomDetached~" .. tostring(tabData.Name or "Tab") .. "~" .. bSide .. "~" .. bName] = {
				Type = "DetachedBlock",
				API = {
					Save = function()
						local pos = isDetached and blockContainer.Position or detachedPosition
						return {Detached = isDetached, Position = pos and {pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset} or nil}
					end,
					Load = function(_, data)
						if type(data) ~= "table" then return end
						if type(data.Position) == "table" and #data.Position == 4 then
							detachedPosition = UDim2.new(unpack(data.Position))
						end
						if type(data.Detached) == "boolean" and data.Detached ~= isDetached then ToggleDetach() end
						if isDetached and detachedPosition then blockContainer.Position = detachedPosition end
					end
				}
			}
			detachBtn.MouseButton1Click:Connect(ToggleDetach)
			dummyReturnBtn.MouseButton1Click:Connect(ToggleDetach)

			if variants and type(variants) == "table" and #variants > 1 then
				local headerWrapper = Instance.new("Frame")
				headerWrapper.Name = "VariantsHeaderWrapper"
				headerWrapper.Size = UDim2.new(1, 0, 0, 26)
				headerWrapper.BackgroundTransparency = 1
				headerWrapper.LayoutOrder = 0
				headerWrapper.Parent = blockContainer

				table.insert(dragTriggers, headerWrapper)
				detachBtn.Parent = headerWrapper

				local tabsContainer = Instance.new("Frame")
				tabsContainer.Name = "TabsContainer"
				tabsContainer.Size = UDim2.new(1, -32, 1, 0) 
				tabsContainer.BackgroundTransparency = 1
				tabsContainer.Parent = headerWrapper

				local gap = 4
				local totalGaps = gap * (#variants - 1)

				local headerLayout = Instance.new("UIListLayout")
				headerLayout.FillDirection = Enum.FillDirection.Horizontal
				headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
				headerLayout.Padding = UDim.new(0, gap)
				headerLayout.Parent = tabsContainer

				local blockDivider = Instance.new("Frame")
				blockDivider.Name = "BlockDivider"
				blockDivider.Size = UDim2.new(1, 0, 0, 1)
				blockDivider.BorderSizePixel = 0
				blockDivider.LayoutOrder = 1
				blockDivider.Parent = blockContainer
				ApplyTheme(blockDivider, "Outlines", "BackgroundColor3")

				local activeIndex = 1
				local contentContainers = {}
				local apis = {}
				local tabs = {}

				local function updateVariantTabTexts()
					for _, tData in ipairs(tabs) do
						local padX = 14
						local maxW = tData.Btn.AbsoluteSize.X - (tData.HasIcon and 24 or 8) - padX
						local font = Enum.Font[THEME.TextFont] or Enum.Font.Gotham
						tData.Label.Text = truncateTwoDots(tData.RawName, font, tData.Label.TextSize, math.max(0, maxW))
					end
				end

				for i, vData in ipairs(variants) do
					local vName = vData.Name or ("Tab " .. i)
					local vIcon = parseAsset(vData.Icon)

					local tabBtn = Instance.new("TextButton")
					tabBtn.Name = "Tab_" .. vName
					tabBtn.Size = UDim2.new(1 / #variants, -(totalGaps / #variants), 1, 0)
					tabBtn.BackgroundTransparency = 1
					tabBtn.AutoButtonColor = false
					tabBtn.Text = ""
					tabBtn.LayoutOrder = i
					tabBtn.Parent = tabsContainer
					
					table.insert(dragTriggers, tabBtn)

					local tabBtnCorner = Instance.new("UICorner")
					tabBtnCorner.CornerRadius = GLOBAL_CORNER
					tabBtnCorner.Parent = tabBtn
					CS:AddTag(tabBtnCorner, "ElementCorner")

					local tabStroke = Instance.new("UIStroke")
					tabStroke.Name = "TabStroke"
					tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					tabStroke.Thickness = 1
					tabStroke.Transparency = (i == 1) and 0 or 1
					tabStroke.Parent = tabBtn
					ApplyTheme(tabStroke, "Outlines", "Color")

					local tabPad = Instance.new("UIPadding")
					tabPad.Name = "TabPadding"
					tabPad.PaddingLeft = UDim.new(0, 6)
					tabPad.PaddingRight = UDim.new(0, 6)
					tabPad.Parent = tabBtn

					local btnLayout = Instance.new("UIListLayout")
					btnLayout.FillDirection = Enum.FillDirection.Horizontal
					btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
					btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
					btnLayout.Padding = UDim.new(0, 6)
					btnLayout.Parent = tabBtn

					local tIcon
					if vIcon and vIcon ~= "" then
						tIcon = Instance.new("ImageLabel")
						tIcon.Size = UDim2.new(0, 16, 0, 16)
						tIcon.BackgroundTransparency = 1
						tIcon.Image = vIcon
						tIcon.Parent = tabBtn
						ApplyTheme(tIcon, i == 1 and "Text" or "TextMuted", "ImageColor3")
					end

					local tLabel = Instance.new("TextLabel")
					tLabel.AutomaticSize = Enum.AutomaticSize.X
					tLabel.Size = UDim2.new(0, 0, 1, 0)
					tLabel.BackgroundTransparency = 1
					tLabel.TextSize = 12
					tLabel.TextTruncate = Enum.TextTruncate.AtEnd
					tLabel.TextXAlignment = Enum.TextXAlignment.Center
					tLabel.Text = vName
					tLabel.Parent = tabBtn
					ApplyTheme(tLabel, i == 1 and "Text" or "TextMuted", "TextColor3")
					ApplyTheme(tLabel, i == 1 and "TextFont" or "SubtextFont", "Font")
					
					tabs[i] = {
						Btn = tabBtn,
						Stroke = tabStroke,
						Label = tLabel,
						RawName = vName,
						HasIcon = (vIcon and vIcon ~= "")
					}

					local contentFrame = Instance.new("CanvasGroup")
					contentFrame.GroupTransparency = i == 1 and 0 or 1
					contentFrame.Name = "Content_" .. vName
					contentFrame.Size = UDim2.new(1, 0, 0, 0)
					contentFrame.AutomaticSize = Enum.AutomaticSize.Y
					contentFrame.BackgroundTransparency = 1
					contentFrame.Visible = (i == 1)
					contentFrame.LayoutOrder = 2
					contentFrame.Parent = blockContainer
					contentFrame:SetAttribute("AxiomVariantIndex", i)
					contentContainers[i] = contentFrame

					local cLayout = Instance.new("UIListLayout")
					cLayout.FillDirection = Enum.FillDirection.Vertical
					cLayout.SortOrder = Enum.SortOrder.LayoutOrder
					cLayout.Padding = UDim.new(0, 6)
					cLayout.Parent = contentFrame
					
					local cPadding = Instance.new("UIPadding")
					cPadding.PaddingTop = UDim.new(0, 6)
					cPadding.Parent = contentFrame

					tabBtn.MouseButton1Click:Connect(function()
						if activeIndex == i then return end
						
						local oldTab = tabs[activeIndex]
						if oldTab then
							if oldTab.Stroke then
								TS:Create(oldTab.Stroke, TweenInfo.new(0.25), {Transparency = 1}):Play()
							end
							for _, child in ipairs(oldTab.Btn:GetChildren()) do
								if child:IsA("ImageLabel") then ApplyTheme(child, "TextMuted", "ImageColor3") end
								if child:IsA("TextLabel") then 
									ApplyTheme(child, "TextMuted", "TextColor3") 
									ApplyTheme(child, "SubtextFont", "Font")
								end
							end
						end
						local previousContent = contentContainers[activeIndex]
						previousContent.Visible = false
						previousContent.GroupTransparency = 1
						activeIndex = i
						local newTab = tabs[i]
						if newTab then
							if newTab.Stroke then
								TS:Create(newTab.Stroke, TweenInfo.new(0.25), {Transparency = 0}):Play()
							end
							for _, child in ipairs(newTab.Btn:GetChildren()) do
								if child:IsA("ImageLabel") then ApplyTheme(child, "Text", "ImageColor3") end
								if child:IsA("TextLabel") then 
									ApplyTheme(child, "Text", "TextColor3") 
									ApplyTheme(child, "TextFont", "Font")
								end
							end
						end
						local nextContent = contentContainers[activeIndex]
						nextContent.GroupTransparency = motionConfig and 1 or 0
						nextContent.Visible = true
						if motionConfig then
							local original = nextContent.Position
							nextContent.Position = original + UDim2.fromOffset(0, 8)
							TS:Create(nextContent, TweenInfo.new(motionDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = original, GroupTransparency = 0}):Play()
						end
					end)

					local bObj = BuildElementAPI(contentFrame, vName, vIcon, bSide, name, tabData.IsSettings)
					
					function bObj:SetTitle(newTitle)
						tabs[i].RawName = newTitle
						updateVariantTabTexts()
					end

					apis[i] = bObj
				end
				
				table.insert(Window._connections, tabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateVariantTabTexts))

				task.spawn(function()
					task.wait()
					updateVariantTabTexts()
				end)

				local function updateBlockStyle(style)
					updateVariantTabTexts()

					if style == 3 or style == 4 then
						blockPadding.PaddingTop = UDim.new(0, 8)
						blockPadding.PaddingBottom = UDim.new(0, 8)
						blockPadding.PaddingLeft = UDim.new(0, 8)
						blockPadding.PaddingRight = UDim.new(0, 8)
						blockLayout.Padding = UDim.new(0, 4)
						headerWrapper.Size = UDim2.new(1, 0, 0, 22)
						dummyCard.Size = UDim2.new(1, 0, 0, 30)
						dummyTitle.TextSize = 12
						for _, c in pairs(contentContainers) do
							c.UIListLayout.Padding = UDim.new(0, 4)
							c.UIPadding.PaddingTop = UDim.new(0, 4)
						end
					else
						blockPadding.PaddingTop = UDim.new(0, 12)
						blockPadding.PaddingBottom = UDim.new(0, 12)
						blockPadding.PaddingLeft = UDim.new(0, 12)
						blockPadding.PaddingRight = UDim.new(0, 12)
						blockLayout.Padding = UDim.new(0, 6)
						headerWrapper.Size = UDim2.new(1, 0, 0, 26)
						dummyCard.Size = UDim2.new(1, 0, 0, 38)
						dummyTitle.TextSize = 13
						for _, c in pairs(contentContainers) do
							c.UIListLayout.Padding = UDim.new(0, 6)
							c.UIPadding.PaddingTop = UDim.new(0, 6)
						end
					end
				end
				table.insert(Window._styleCallbacks, updateBlockStyle)
				updateBlockStyle(THEME.ElementStyle)

				return unpack(apis)
			else
				local bName = blockConfig.Name or "Block"
				local bIcon = parseAsset(blockConfig.Icon)

				local header = Instance.new("Frame")
				header.Name = "Header"
				header.Size = UDim2.new(1, 0, 0, 20)
				header.BackgroundTransparency = 1
				header.LayoutOrder = 0
				header.Parent = blockContainer

				table.insert(dragTriggers, header)
				detachBtn.Parent = header

				local titleContainer = Instance.new("Frame")
				titleContainer.Name = "TitleContainer"
				titleContainer.Size = UDim2.new(1, -22, 1, 0)
				titleContainer.BackgroundTransparency = 1
				titleContainer.Parent = header

				local headerLayout = Instance.new("UIListLayout")
				headerLayout.Name = "HeaderLayout"
				headerLayout.FillDirection = Enum.FillDirection.Horizontal
				headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
				headerLayout.Padding = UDim.new(0, 8)
				headerLayout.Parent = titleContainer

				local blockIconLabel
				if bIcon and bIcon ~= "" then
					blockIconLabel = Instance.new("ImageLabel")
					blockIconLabel.Name = "BlockIcon"
					blockIconLabel.Size = UDim2.new(0, 26, 0, 26)
					blockIconLabel.BackgroundTransparency = 1
					blockIconLabel.Image = bIcon
					blockIconLabel.Parent = titleContainer
					ApplyTheme(blockIconLabel, "Text", "ImageColor3")
				end

				local blockTitle = Instance.new("TextLabel")
				blockTitle.Name = "BlockTitle"
				blockTitle.AutomaticSize = Enum.AutomaticSize.X
				blockTitle.Size = UDim2.new(0, 0, 1, 0)
				blockTitle.BackgroundTransparency = 1
				blockTitle.TextSize = 13
				blockTitle.TextTruncate = Enum.TextTruncate.AtEnd
				blockTitle.Text = bName
				blockTitle.Parent = titleContainer
				ApplyTheme(blockTitle, "Text", "TextColor3")
				ApplyTheme(blockTitle, "TextFont", "Font")

				local blockDivider = Instance.new("Frame")
				blockDivider.Name = "BlockDivider"
				blockDivider.Size = UDim2.new(1, 0, 0, 1)
				blockDivider.BorderSizePixel = 0
				blockDivider.LayoutOrder = 1
				blockDivider.Parent = blockContainer
				ApplyTheme(blockDivider, "Outlines", "BackgroundColor3")

				local function updateBlockStyle(style)
					if style == 3 or style == 4 then
						blockPadding.PaddingTop = UDim.new(0, 8)
						blockPadding.PaddingBottom = UDim.new(0, 8)
						blockPadding.PaddingLeft = UDim.new(0, 8)
						blockPadding.PaddingRight = UDim.new(0, 8)
						blockLayout.Padding = UDim.new(0, 4)
						header.Size = UDim2.new(1, 0, 0, 22)
						dummyCard.Size = UDim2.new(1, 0, 0, 30)
						dummyTitle.TextSize = 12
						if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 22, 0, 22) end
					else
						blockPadding.PaddingTop = UDim.new(0, 12)
						blockPadding.PaddingBottom = UDim.new(0, 12)
						blockPadding.PaddingLeft = UDim.new(0, 12)
						blockPadding.PaddingRight = UDim.new(0, 12)
						blockLayout.Padding = UDim.new(0, 6)
						header.Size = UDim2.new(1, 0, 0, 26)
						dummyCard.Size = UDim2.new(1, 0, 0, 38)
						dummyTitle.TextSize = 13
						if blockIconLabel then blockIconLabel.Size = UDim2.new(0, 26, 0, 26) end
					end
				end
				table.insert(Window._styleCallbacks, updateBlockStyle)
				updateBlockStyle(THEME.ElementStyle)

				local bObj
				if tabData.IsSettings then
					bObj = BuildElementAPI(blockContainer, bName, bIcon, bSide, name, true)
				else
					bObj = BuildElementAPI(blockContainer, bName, bIcon, bSide, name, false)
				end
				
				function bObj:SetTitle(newTitle)
					blockTitle.Text = newTitle
				end
				
				return bObj
			end
		end
	
		if not isSettings and not Window.CurrentTab then task.spawn(activateTab) end
		table.insert(Window.Tabs, tabData)
		FullUpdateLayout()
	
		return tabData
	end
	
	local watermarkHolder = Instance.new("Frame")
	watermarkHolder.Name = "WatermarkHolder"
	watermarkHolder.AnchorPoint = Vector2.new(0.5, 0)
	watermarkHolder.Position = isMobile and UDim2.new(0.5, 0, 0, 8) or UDim2.new(0.5, 0, 0, 20)
	watermarkHolder.Size = UDim2.new(0, 0, 0, isMobile and 34 or 40)
	watermarkHolder.AutomaticSize = Enum.AutomaticSize.X
	watermarkHolder.BackgroundTransparency = 1
	watermarkHolder.Active = true
	watermarkHolder.ZIndex = 99999
	watermarkHolder.Visible = watermarkEnabled
	watermarkHolder.Parent = screenGui

	local wmShadowFolder = Instance.new("Frame")
	wmShadowFolder.Name = "WatermarkShadows"
	wmShadowFolder.Size = UDim2.new(0, 0, 1, 0)
	wmShadowFolder.Position = UDim2.new(0, 0, 0, 0)
	wmShadowFolder.BackgroundTransparency = 1
	wmShadowFolder.Visible = SIDEBAR_STATE.ShadowsEnabled
	wmShadowFolder.ZIndex = 0
	wmShadowFolder.Parent = watermarkHolder

	local wmShadowStrokes = {}
	for i = 1, shadowLayers do
		local trans = 0.8 + (i * 0.02)
		local wmShadow = Instance.new("Frame")
		wmShadow.Name = "WMShadowLayer" .. i
		wmShadow.BackgroundTransparency = 1
		wmShadow.AnchorPoint = Vector2.new(0, 0)
		wmShadow.Position = UDim2.new(0, 0, 0, 0)
		wmShadow.Size = UDim2.new(1, 0, 1, 0)
		wmShadow.BorderSizePixel = 0
		wmShadow.ZIndex = 0
		wmShadow.Parent = wmShadowFolder

		local wmShadowCorner = Instance.new("UICorner")
		wmShadowCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		wmShadowCorner.Parent = wmShadow
		CS:AddTag(wmShadowCorner, "HUDCorner")

		local wmShadowStroke = Instance.new("UIStroke")
		wmShadowStroke.Color = Color3.fromRGB(0, 0, 0)
		wmShadowStroke.Transparency = trans
		wmShadowStroke:SetAttribute("TargetTransparency", trans)
		wmShadowStroke.Thickness = i * 2
		wmShadowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		wmShadowStroke.Enabled = SIDEBAR_STATE.ShadowsEnabled
		wmShadowStroke.Parent = wmShadow
		table.insert(wmShadowStrokes, wmShadowStroke)
	end

	local function setLayeredShadows(enabled)
		enabled = enabled == true
		SIDEBAR_STATE.ShadowsEnabled = enabled
		shadowFolder.Visible = enabled
		sidebarShadowFolder.Visible = enabled and SIDEBAR_STATE.Detached
		wmShadowFolder.Visible = enabled
		for _, layer in ipairs(shadowFolder:GetChildren()) do
			local stroke = layer:FindFirstChild("ShadowStroke")
			if stroke then
				stroke.Enabled = enabled
				if enabled then stroke.Transparency = stroke:GetAttribute("TargetTransparency") or 0.85 end
			end
		end
		for _, layer in ipairs(sidebarShadowFolder:GetChildren()) do
			local stroke = layer:FindFirstChild("ShadowStroke")
			if stroke then
				stroke.Enabled = enabled and SIDEBAR_STATE.Detached
				if enabled then stroke.Transparency = stroke:GetAttribute("TargetTransparency") or 0.85 end
			end
		end
		for _, stroke in ipairs(wmShadowStrokes) do
			stroke.Enabled = enabled
			if enabled then stroke.Transparency = stroke:GetAttribute("TargetTransparency") or 0.85 end
		end
	end

	local wmBar = Instance.new("Frame")
	wmBar.Name = "WatermarkBar"
	wmBar.Size = UDim2.new(0, 0, 1, 0)
	wmBar.AutomaticSize = Enum.AutomaticSize.X
	wmBar.BorderSizePixel = 0
	wmBar.ZIndex = 2
	wmBar.Parent = watermarkHolder
	ApplyTheme(wmBar, "Background", "BackgroundColor3")
	ApplyTheme(wmBar, "HUDTransparency", "BackgroundTransparency")

	local wmCorner = Instance.new("UICorner")
	wmCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
	wmCorner.Parent = wmBar
	CS:AddTag(wmCorner, "HUDCorner")

	local wmStroke = Instance.new("UIStroke")
	wmStroke.Name = "WatermarkStroke"
	wmStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	wmStroke.Thickness = 1
	wmStroke.Enabled = THEME.MainOutlineEnabled
	wmStroke.Parent = wmBar
	ApplyTheme(wmStroke, "Outlines", "Color")
	CS:AddTag(wmStroke, "WatermarkStrokeBind")

	local wmPadding = Instance.new("UIPadding")
	wmPadding.PaddingLeft = UDim.new(0, isMobile and 9 or 14)
	wmPadding.PaddingRight = UDim.new(0, isMobile and 10 or 16)
	wmPadding.Parent = wmBar

	local wmLayout = Instance.new("UIListLayout")
	wmLayout.FillDirection = Enum.FillDirection.Horizontal
	wmLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	wmLayout.SortOrder = Enum.SortOrder.LayoutOrder
	wmLayout.Padding = UDim.new(0, isMobile and 7 or 10)
	wmLayout.Parent = wmBar

	local wmLogo = Instance.new("ImageLabel")
	wmLogo.Name = "WMLogo"
	wmLogo.Size = UDim2.new(0, isMobile and 18 or 22, 0, isMobile and 18 or 22)
	wmLogo.BackgroundTransparency = 1
	wmLogo.Image = (logoIconId and logoIconId ~= "") and logoIconId or SEARCH_ICON_ID
	wmLogo.LayoutOrder = 1
	wmLogo.Parent = wmBar
	ApplyTheme(wmLogo, "Accent", "ImageColor3")

	local function createWMDivider(order)
		local div = Instance.new("Frame")
		div.Name = "WMDivider"
		div.Size = UDim2.new(0, 1, 0, isMobile and 14 or 18)
		div.BorderSizePixel = 0
		div.LayoutOrder = order
		div.Parent = wmBar
		ApplyTheme(div, "Outlines", "BackgroundColor3")
		return div
	end

	createWMDivider(2)

	local wmFps = Instance.new("TextLabel")
	wmFps.Name = "WMFps"
	wmFps.AutomaticSize = Enum.AutomaticSize.X
	wmFps.Size = UDim2.new(0, 0, 1, 0)
	wmFps.BackgroundTransparency = 1
	wmFps.TextSize = isMobile and 11 or 14
	wmFps.Text = "60 fps"
	wmFps.LayoutOrder = 3
	wmFps.Parent = wmBar
	ApplyTheme(wmFps, "Text", "TextColor3")
	ApplyTheme(wmFps, "TextFont", "Font")

	createWMDivider(4)

	local wmPing = Instance.new("TextLabel")
	wmPing.Name = "WMPing"
	wmPing.AutomaticSize = Enum.AutomaticSize.X
	wmPing.Size = UDim2.new(0, 0, 1, 0)
	wmPing.BackgroundTransparency = 1
	wmPing.TextSize = isMobile and 11 or 14
	wmPing.Text = "0 ms"
	wmPing.LayoutOrder = 5
	wmPing.Parent = wmBar
	ApplyTheme(wmPing, "Text", "TextColor3")
	ApplyTheme(wmPing, "TextFont", "Font")

	createWMDivider(6)

	local wmUser = Instance.new("TextLabel")
	wmUser.Name = "WMUser"
	wmUser.AutomaticSize = Enum.AutomaticSize.X
	wmUser.Size = UDim2.new(0, 0, 1, 0)
	wmUser.BackgroundTransparency = 1
	wmUser.TextSize = isMobile and 11 or 14
	wmUser.Text = LP.DisplayName
	wmUser.LayoutOrder = 7
	wmUser.Parent = wmBar
	ApplyTheme(wmUser, "Text", "TextColor3")
	ApplyTheme(wmUser, "TextFont", "Font")

	local function updateWMShadowSize()
		local w = wmBar.AbsoluteSize.X
		if w > 0 then
			wmShadowFolder.Size = UDim2.new(0, w, 1, 0)
		end
	end
	table.insert(Window._connections, wmBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateWMShadowSize))
	task.spawn(function()
		task.wait(0.1)
		updateWMShadowSize()
	end)

	local wmDragging, wmDragInput, wmDragStart, wmStartPos
	local wmTargetPos = watermarkHolder.Position
	local wmDragConn = nil

	local function startWMLoop()
		if wmDragConn then return end
		wmDragConn = RS.RenderStepped:Connect(function(dt)
			if not watermarkHolder.Parent then
				if wmDragConn then wmDragConn:Disconnect(); wmDragConn = nil end
				return
			end
			local diffX = math.abs(watermarkHolder.Position.X.Offset - wmTargetPos.X.Offset)
			local diffY = math.abs(watermarkHolder.Position.Y.Offset - wmTargetPos.Y.Offset)
			if diffX > 0.1 or diffY > 0.1 then
				watermarkHolder.Position = watermarkHolder.Position:Lerp(wmTargetPos, 1 - math.exp(-28 * dt))
			else
				watermarkHolder.Position = wmTargetPos
				if not wmDragging then
					wmDragConn:Disconnect()
					wmDragConn = nil
				end
			end
		end)
		table.insert(Window._connections, wmDragConn)
	end

	table.insert(Window._connections, watermarkHolder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			wmDragging = true
			wmDragStart = input.Position
			wmStartPos = wmTargetPos
			startWMLoop()
			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					wmDragging = false
					endConn:Disconnect()
				end
			end)
			table.insert(Window._connections, endConn)
		end
	end))

	table.insert(Window._connections, watermarkHolder.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			wmDragInput = input
		end
	end))

	table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
		if input == wmDragInput and wmDragging then
			local delta = input.Position - wmDragStart
			wmTargetPos = UDim2.new(wmStartPos.X.Scale, wmStartPos.X.Offset + delta.X, wmStartPos.Y.Scale, wmStartPos.Y.Offset + delta.Y)
			startWMLoop()
		end
	end))

	local fpsFrames = 0
	local fpsElapsed = 0
	table.insert(Window._connections, RS.RenderStepped:Connect(function(dt)
		if not watermarkHolder.Visible then
			fpsFrames = 0
			fpsElapsed = 0
			return
		end
		fpsFrames = fpsFrames + 1
		fpsElapsed = fpsElapsed + dt
		if fpsElapsed >= 0.5 then
			wmFps.Text = tostring(math.round(fpsFrames / fpsElapsed)) .. " fps"
			fpsFrames = 0
			fpsElapsed = 0
		end
	end))

	task.spawn(function()
		while watermarkHolder.Parent do
			task.wait(2.0)
			if not watermarkHolder.Parent then break end
			if watermarkHolder.Visible then
				local pingVal = 0
				pcall(function()
					local netStats = StatsService:FindFirstChild("Network")
					if netStats and netStats:FindFirstChild("ServerStatsItem") then
						local pingItem = netStats.ServerStatsItem:FindFirstChild("Data Ping")
						if pingItem then
							pingVal = math.round(pingItem:GetValue())
						end
					end

					if pingVal == 0 then
						local perf = StatsService:FindFirstChild("PerformanceStats")
						if perf and perf:FindFirstChild("Ping") then
							pingVal = math.round(perf.Ping:GetValue())
						end
					end

					if pingVal == 0 then
						local rawPing = LP:GetNetworkPing()
						if rawPing and rawPing > 0 then
							pingVal = math.round(rawPing * 2000)
						end
					end
				end)
				wmPing.Text = tostring(pingVal) .. " ms"
			end
		end
	end)

	Window.Watermark = {
		SetVisible = function(self, state)
			watermarkHolder.Visible = state
			local control = Window._themeControls["Layout & Styles~Show Watermark"]
			if control then control.API:Set(state == true) end
		end,
		SetLogo = function(self, id)
			wmLogo.Image = parseAsset(id)
		end
	}

	local function SetupKeybindsHUD()
		local kbDockSide = "Right"
		local kbIsOpen = false
		local kbOffsetY = 0
		local KB_WIDTH = 195
		local VISIBLE_EDGE = 14

		local kbEnabled = keybindsEnabled

		local kbHolder = Instance.new("Frame")
		kbHolder.Name = "KeybindsHUD"
		kbHolder.Size = UDim2.new(0, KB_WIDTH, 0, 0)
		kbHolder.AutomaticSize = Enum.AutomaticSize.Y
		kbHolder.AnchorPoint = Vector2.new(0, 0.5)
		kbHolder.BackgroundTransparency = 1
		kbHolder.ZIndex = 9000
		kbHolder.Visible = kbEnabled
		kbHolder.Parent = screenGui

		Window.Keybinds = {
			SetVisible = function(self, state)
				kbHolder.Visible = state
				local control = Window._themeControls["Layout & Styles~Show Keybinds HUD"]
				if control then control.API:Set(state == true) end
			end
		}

		local kbMain = Instance.new("Frame")
		kbMain.Name = "MainCard"
		kbMain.Size = UDim2.new(1, 0, 0, 0)
		kbMain.AutomaticSize = Enum.AutomaticSize.Y
		kbMain.BorderSizePixel = 0
		kbMain.ZIndex = 9001
		kbMain.Parent = kbHolder
		ApplyTheme(kbMain, "Background", "BackgroundColor3")
		ApplyTheme(kbMain, "HUDTransparency", "BackgroundTransparency")

		local kbCorner = Instance.new("UICorner")
		kbCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
		kbCorner.Parent = kbMain
		CS:AddTag(kbCorner, "HUDCorner")

		local kbStroke = Instance.new("UIStroke")
		kbStroke.Name = "KeybindStroke"
		kbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		kbStroke.Thickness = 1
		kbStroke.Enabled = THEME.MainOutlineEnabled
		kbStroke.Parent = kbMain
		ApplyTheme(kbStroke, "Outlines", "Color")

		table.insert(Window._connections, mainOutlineStroke:GetPropertyChangedSignal("Enabled"):Connect(function()
			kbStroke.Enabled = mainOutlineStroke.Enabled
		end))

		local kbBar = Instance.new("Frame")
		kbBar.Name = "AccentStrip"
		kbBar.Size = UDim2.new(0, 3, 0, 44)
		kbBar.BorderSizePixel = 0
		kbBar.ZIndex = 9003
		kbBar.Parent = kbMain
		ApplyTheme(kbBar, "Accent", "BackgroundColor3")

		local kbBarCorner = Instance.new("UICorner")
		kbBarCorner.CornerRadius = UDim.new(1, 0)
		kbBarCorner.Parent = kbBar

		local kbEdgeBtn = Instance.new("TextButton")
		kbEdgeBtn.Name = "EdgeTrigger"
		kbEdgeBtn.BackgroundTransparency = 1
		kbEdgeBtn.Text = ""
		kbEdgeBtn.ZIndex = 9004
		kbEdgeBtn.Parent = kbMain

		local kbHeader = Instance.new("TextButton")
		kbHeader.Name = "Header"
		kbHeader.Size = UDim2.new(1, 0, 0, 28)
		kbHeader.BackgroundTransparency = 1
		kbHeader.Text = ""
		kbHeader.Parent = kbMain

		local kbTitle = Instance.new("TextLabel")
		kbTitle.Name = "Title"
		kbTitle.Size = UDim2.new(1, -20, 1, 0)
		kbTitle.Position = UDim2.new(0, 16, 0, 0)
		kbTitle.BackgroundTransparency = 1
		kbTitle.Text = "Keybinds"
		kbTitle.TextSize = 12
		kbTitle.TextXAlignment = Enum.TextXAlignment.Left
		kbTitle.Parent = kbHeader
		ApplyTheme(kbTitle, "Text", "TextColor3")
		ApplyTheme(kbTitle, "TextFont", "Font")

		local kbDivider = Instance.new("Frame")
		kbDivider.Name = "Divider"
		kbDivider.Size = UDim2.new(1, -20, 0, 1)
		kbDivider.Position = UDim2.new(0.5, 0, 1, -1)
		kbDivider.AnchorPoint = Vector2.new(0.5, 1)
		kbDivider.BorderSizePixel = 0
		kbDivider.Parent = kbHeader
		ApplyTheme(kbDivider, "Outlines", "BackgroundColor3")

		local kbEntries = Instance.new("ScrollingFrame")
		kbEntries.Name = "Entries"
		kbEntries.Size = UDim2.new(1, 0, 0, 0)
		kbEntries.Position = UDim2.new(0, 0, 0, 29)
		kbEntries.BackgroundTransparency = 1
		kbEntries.BorderSizePixel = 0
		kbEntries.ScrollBarThickness = 2
		kbEntries.CanvasSize = UDim2.new(0, 0, 0, 0)
		kbEntries.AutomaticCanvasSize = Enum.AutomaticSize.Y
		kbEntries.Parent = kbMain
		ApplyTheme(kbEntries, "Outlines", "ScrollBarImageColor3")

		local kbLayout = Instance.new("UIListLayout")
		kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
		kbLayout.Padding = UDim.new(0, 4)
		kbLayout.Parent = kbEntries

		local kbPad = Instance.new("UIPadding")
		kbPad.PaddingTop = UDim.new(0, 6)
		kbPad.PaddingBottom = UDim.new(0, 8)
		kbPad.PaddingLeft = UDim.new(0, 14)
		kbPad.PaddingRight = UDim.new(0, 8)
		kbPad.Parent = kbEntries

		local kbTargetPos = UDim2.new(1, -VISIBLE_EDGE, 0.5, kbOffsetY)

		local function UpdateKBDocking()
			if kbDockSide == "Right" then
				kbBar.AnchorPoint = Vector2.new(0, 0.5)
				kbBar.Position = UDim2.new(0, 5, 0.5, 0)

				kbEdgeBtn.AnchorPoint = Vector2.new(0, 0)
				kbEdgeBtn.Position = UDim2.new(0, 0, 0, 0)
				kbEdgeBtn.Size = UDim2.new(0, VISIBLE_EDGE + 6, 1, 0)

				kbTitle.Position = UDim2.new(0, 16, 0, 0)
				kbPad.PaddingLeft = UDim.new(0, 15)
				kbPad.PaddingRight = UDim.new(0, 8)

				if kbIsOpen then
					kbTargetPos = UDim2.new(1, -KB_WIDTH - 8, 0.5, kbOffsetY)
				else
					kbTargetPos = UDim2.new(1, -VISIBLE_EDGE, 0.5, kbOffsetY)
				end
			else
				kbBar.AnchorPoint = Vector2.new(1, 0.5)
				kbBar.Position = UDim2.new(1, -5, 0.5, 0)

				kbEdgeBtn.AnchorPoint = Vector2.new(1, 0)
				kbEdgeBtn.Position = UDim2.new(1, 0, 0, 0)
				kbEdgeBtn.Size = UDim2.new(0, VISIBLE_EDGE + 6, 1, 0)

				kbTitle.Position = UDim2.new(0, 10, 0, 0)
				kbPad.PaddingLeft = UDim.new(0, 8)
				kbPad.PaddingRight = UDim.new(0, 15)

				if kbIsOpen then
					kbTargetPos = UDim2.new(0, 8, 0.5, kbOffsetY)
				else
					kbTargetPos = UDim2.new(0, -KB_WIDTH + VISIBLE_EDGE, 0.5, kbOffsetY)
				end
			end
		end

		local kbStepConn = nil
		local function startKBLoop()
			if kbStepConn then return end
			kbStepConn = RS.RenderStepped:Connect(function(dt)
				if not kbHolder.Parent then
					if kbStepConn then kbStepConn:Disconnect(); kbStepConn = nil end
					return
				end
				local diffX = math.abs(kbHolder.Position.X.Offset - kbTargetPos.X.Offset)
				local diffY = math.abs(kbHolder.Position.Y.Offset - kbTargetPos.Y.Offset)
				if diffX > 0.1 or diffY > 0.1 then
					kbHolder.Position = kbHolder.Position:Lerp(kbTargetPos, 1 - math.exp(-26 * dt))
				else
					kbHolder.Position = kbTargetPos
					if not kbDragging then
						kbStepConn:Disconnect()
						kbStepConn = nil
					end
				end
			end)
			table.insert(Window._connections, kbStepConn)
		end

		UpdateKBDocking()
		kbHolder.Position = kbTargetPos

		table.insert(Window._connections, kbEdgeBtn.MouseButton1Click:Connect(function()
			kbIsOpen = not kbIsOpen
			UpdateKBDocking()
			startKBLoop()
		end))

		local kbDragging = false
		local kbStartMouseX, kbStartMouseY
		local kbStartPosX, kbStartPosY

		local function StartDrag(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				kbDragging = true
				kbStartMouseX = input.Position.X
				kbStartMouseY = input.Position.Y
				kbStartPosX = kbHolder.Position.X.Offset
				kbStartPosY = kbHolder.Position.Y.Offset
				startKBLoop()

				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						kbDragging = false
						endConn:Disconnect()

						local screenW = screenGui.AbsoluteSize.X
						local screenH = screenGui.AbsoluteSize.Y

						if input.Position.X < screenW / 2 then
							kbDockSide = "Left"
						else
							kbDockSide = "Right"
						end

						kbOffsetY = math.clamp(kbTargetPos.Y.Offset, -screenH / 2 + 60, screenH / 2 - 60)
						UpdateKBDocking()
						startKBLoop()
					end
				end)
				table.insert(Window._connections, endConn)
			end
		end

		table.insert(Window._connections, kbHeader.InputBegan:Connect(StartDrag))

		table.insert(Window._connections, UIS.InputChanged:Connect(function(input)
			if kbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local deltaX = input.Position.X - kbStartMouseX
				local deltaY = input.Position.Y - kbStartMouseY
				kbTargetPos = UDim2.new(kbHolder.Position.X.Scale, kbStartPosX + deltaX, 0.5, kbStartPosY + deltaY)
				startKBLoop()
			end
		end))

		local function UpdateKeybindList()
			for _, child in ipairs(kbEntries:GetChildren()) do
				if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
			end

			local count = 0
			for uniqueId, element in pairs(Window._configElements) do
				local success, data = pcall(function() return element.API:Save() end)
				if success and type(data) == "table" and data.Bind and data.Bind ~= "" and data.Bind ~= "Unknown" and data.Bind ~= "None" then
					local shortKeyTxt = shortKeys[data.Bind] or tostring(data.Bind)
					if shortKeyTxt ~= "None" and shortKeyTxt ~= "Unknown" and shortKeyTxt ~= "" then
						count = count + 1
						local itemName = uniqueId:match("~[^~]+~([^~]+)$") or uniqueId
						local isToggle = (element.Type == "Toggle")
						local isActive = (data.State == true)

						local row = Instance.new("Frame")
						row.Name = "Row_" .. tostring(itemName)
						row.Size = UDim2.new(1, 0, 0, 22)
						row.BackgroundTransparency = 1
						row.Parent = kbEntries

						local rowTitle = Instance.new("TextLabel")
						rowTitle.Size = UDim2.new(1, -40, 1, 0)
						rowTitle.Position = UDim2.new(0, 0, 0, 0)
						rowTitle.BackgroundTransparency = 1
						rowTitle.TextSize = 12
						rowTitle.Text = tostring(itemName)
						rowTitle.TextXAlignment = Enum.TextXAlignment.Left
						rowTitle.TextTruncate = Enum.TextTruncate.AtEnd
						rowTitle.Parent = row
						ApplyTheme(rowTitle, "Text", "TextColor3")
						ApplyTheme(rowTitle, "TextFont", "Font")

						local badge = Instance.new("Frame")
						badge.Size = UDim2.new(0, 26, 0, 18)
						badge.AnchorPoint = Vector2.new(1, 0.5)
						badge.Position = UDim2.new(1, 0, 0.5, 0)
						badge.AutomaticSize = Enum.AutomaticSize.X
						badge.BorderSizePixel = 0
						badge.Parent = row
						ApplyTheme(badge, "Input", "BackgroundColor3")
						ApplyTheme(badge, "InputTrans", "BackgroundTransparency")

						local badgeCorner = Instance.new("UICorner")
						badgeCorner.CornerRadius = UDim.new(0, hudCornerRadiusNum)
						badgeCorner.Parent = badge
						CS:AddTag(badgeCorner, "HUDCorner")

						local badgeStroke = Instance.new("UIStroke")
						badgeStroke.Thickness = 1
						badgeStroke.Parent = badge

						if isToggle and isActive then
							ApplyTheme(badgeStroke, "Accent", "Color")
						else
							ApplyTheme(badgeStroke, "Outlines", "Color")
						end

						local badgeTxt = Instance.new("TextLabel")
						badgeTxt.Size = UDim2.new(1, 0, 1, 0)
						badgeTxt.BackgroundTransparency = 1
						badgeTxt.TextSize = 11
						badgeTxt.Text = shortKeyTxt
						badgeTxt.Parent = badge
						ApplyTheme(badgeTxt, "SubtextFont", "Font")

						if isToggle and isActive then
							ApplyTheme(badgeTxt, "Accent", "TextColor3")
						else
							ApplyTheme(badgeTxt, "TextMuted", "TextColor3")
						end

						local badgePad = Instance.new("UIPadding")
						badgePad.PaddingLeft = UDim.new(0, 5)
						badgePad.PaddingRight = UDim.new(0, 5)
						badgePad.Parent = badgeTxt
					end
				end
			end

			if count == 0 then
				local emptyLbl = Instance.new("TextLabel")
				emptyLbl.Name = "EmptyLabel"
				emptyLbl.Size = UDim2.new(1, 0, 0, 18)
				emptyLbl.BackgroundTransparency = 1
				emptyLbl.TextSize = 11
				emptyLbl.Text = "No active binds"
				emptyLbl.Parent = kbEntries
				ApplyTheme(emptyLbl, "TextMuted", "TextColor3")
				ApplyTheme(emptyLbl, "SubtextFont", "Font")
				kbEntries.Size = UDim2.new(1, 0, 0, 32)
			else
				local visibleCount = math.min(count, 10)
				local targetHeight = 14 + (visibleCount * 22) + ((visibleCount - 1) * 4)
				kbEntries.Size = UDim2.new(1, 0, 0, targetHeight)
			end
		end

		local isUpdatingKB = false
		local function RequestKBUpdate()
			if isUpdatingKB then return end
			isUpdatingKB = true
			task.delay(0.1, function()
				isUpdatingKB = false
				UpdateKeybindList()
			end)
		end

		Window.UpdateKeybinds = RequestKBUpdate

		task.spawn(function()
			task.wait(1.5)
			UpdateKeybindList()
		end)
	end
	SetupKeybindsHUD()
	
	Window.SettingsTab = Window:CreateTab({
		Name = "UI Settings",
		Icon = SETTINGS_ICON_ID,
		IsSettings = true
	})
	
	local MainSettingsBlock = Window.SettingsTab:CreateBlock({
		Name = "UI Configuration",
		Side = "Left"
	})
	
	editModeToggleAPI = MainSettingsBlock:CreateToggle({
		Name = "GUI Edit",
		Default = false,
		Callback = function(state)
			Window.ToggleEditMode(state)
		end
	})
	
	MainSettingsBlock:CreateLabel("Enable GUI Edit to visually customize the menu without game interference. The mouse will be forced to stay unlocked.")
	local visualBlock = Window.SettingsTab:CreateBlock({Name = "Visual Effects", Side = "Right"})
	visualBlock:CreateDropdown({
		Name = "Animated Background",
		Options = {"None", "Constellation", "DotMatrix", "PulseGrid", "Aurora", "Comets"},
		Default = backgroundMode,
		Callback = function(mode) Window:SetAnimatedBackground(mode) end
	})
	visualBlock:CreateSlider({
		Name = "Background Intensity", Min = 0, Max = 1, Step = 0.05,
		Default = backgroundIntensity,
		Callback = function(value) Window:SetAnimatedBackground(backgroundMode, value) end
	})
	visualBlock:CreateToggle({
		Name = "Glass Mode", Default = glassConfig,
		Callback = function(value) Window:SetGlassMode(value) end
	})
	visualBlock:CreateSlider({
		Name = "Glass Strength", Min = 0, Max = 1, Step = 0.05,
		Default = glassStrength,
		Callback = function(value) Window:SetGlassMode(glassConfig, value) end
	})
	visualBlock:CreateDropdown({
		Name = "Glass Quality", Options = {"Low", "Balanced", "High"}, Default = glassResolution <= 90 and "Low" or glassResolution >= 192 and "High" or "Balanced",
		Callback = function(level) Window:SetGlassQuality(level) end
	})
	visualBlock:CreateToggle({
		Name = "Smooth Motion", Default = motionConfig,
		Callback = function(value) Window:SetMotion(value) end
	})
	visualBlock:CreateSlider({
		Name = "Motion Duration", Min = 0.1, Max = 0.6, Step = 0.05, Default = motionDuration,
		Callback = function(value) Window:SetMotion(motionConfig, value) end
	})

	local ThemeSaveBlock = Window.SettingsTab:CreateBlock({
		Name = "Theme Management",
		Side = "Left"
	})

	safeMakeFolder(Window.ThemeFolder)

	local function getThemes()
		local list = {}
		safeMakeFolder(Window.ThemeFolder)
		for _, file in pairs(safeListFiles(Window.ThemeFolder)) do
			local clean = tostring(file):gsub("[%z\r\n%s]+$", "")
			if clean:lower():match("%.json$") then
				local name = clean:match("([^/\\]+)%.[jJ][sS][oO][nN]$")
				if name and name ~= "" then 
					table.insert(list, name) 
				end
			end
		end
		return list
	end

	local themeAutoLoadPath = Window.ThemeFolder .. "/autoload_theme.txt"
	local currentThemeAutoLoad = safeReadFile(themeAutoLoadPath)
	currentThemeAutoLoad = currentThemeAutoLoad and currentThemeAutoLoad:match("^%s*(.-)%s*$") or ""

	local themeNameInput = ThemeSaveBlock:CreateInput({
		Name = "Theme Name",
		Placeholder = "Enter theme name..."
	})

	local themeDropdown = ThemeSaveBlock:CreateDropdown({
		Name = "Select Theme",
		Options = getThemes(),
		Default = (currentThemeAutoLoad ~= "" and currentThemeAutoLoad or nil)
	})

	ThemeSaveBlock:CreateButton({
		Name = "Load Theme",
		Callback = function()
			local tName = themeDropdown:Save().Selected
			if tName and tName ~= "" then
				local path = Window.ThemeFolder .. "/" .. tName .. ".json"
				local raw = safeReadFile(path)
				if raw and raw ~= "" then
					local success, res = pcall(function() return HttpService:JSONDecode(raw) end)
					if success and type(res) == "table" then
						for id, val in pairs(res) do
							if id == "SidebarWidth" then
								updateSidebarWidth(val)
							elseif Window._themeElements[id] then
								Window._themeElements[id].API:Load(val)
							end
						end
						Window:Notify({
							Title = "Theme System",
							Description = "Loaded theme: " .. tName,
							Duration = 3,
							Icon = SETTINGS_ICON_ID
						})
					end
				end
			end
		end
	})

	ThemeSaveBlock:CreateButton({
		Name = "Save Theme",
		Callback = function()
			local tName = themeNameInput:Save().Text
			if not tName or tName == "" then
				tName = themeDropdown:Save().Selected
			end
			if tName and tName ~= "" then
				local data = {}
				for id, el in pairs(Window._themeElements) do
					if not string.find(id, "~Configuration~") and not string.find(id, "~Theme Management~") and not string.find(id, "~UI Configuration~") then
						local savedData = el.API:Save()
						if savedData then
							data[id] = savedData
						end
					end
				end
				data["SidebarWidth"] = currentSidebarWidth
			
				safeMakeFolder(Window.ThemeFolder)
				local path = Window.ThemeFolder .. "/" .. tName .. ".json"
				safeWriteFile(path, HttpService:JSONEncode(data))
				themeDropdown:SetOptions(getThemes())
				themeDropdown:Set(tName)
				Window:Notify({
					Title = "Theme System",
					Description = "Saved theme: " .. tName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			else
				Window:Notify({Title = "Theme Error", Description = "Enter a theme name first.", Duration = 3})
			end
		end
	})

	ThemeSaveBlock:CreateButton({
		Name = "Refresh List",
		Callback = function()
			themeDropdown:SetOptions(getThemes())
			Window:Notify({Title = "Theme System", Description = "Theme list refreshed.", Duration = 2})
		end
	})

	ThemeSaveBlock:CreateButton({
		Name = "Delete Theme",
		Callback = function()
			local tName = themeDropdown:Save().Selected
			if tName and tName ~= "" then
				local path = Window.ThemeFolder .. "/" .. tName .. ".json"
				safeDelFile(path)
				themeDropdown:SetOptions(getThemes())
				themeDropdown:Set(nil)
				Window:Notify({
					Title = "Theme System",
					Description = "Deleted theme: " .. tName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			end
		end
	})

	local isInitThemeAutoLoad = true
	ThemeSaveBlock:CreateToggle({
		Name = "Auto-Load Selected Theme",
		Default = (currentThemeAutoLoad ~= ""),
		Callback = function(state)
			if isInitThemeAutoLoad then return end
			if state then
				local tName = themeDropdown:Save().Selected
				if tName and tName ~= "" then
					safeWriteFile(themeAutoLoadPath, tName)
				else
					Window:Notify({Title = "Error", Description = "Please select a theme first to auto-load.", Duration = 3})
				end
			else
				safeDelFile(themeAutoLoadPath)
			end
		end
	})
	isInitThemeAutoLoad = false

	local function CreateThemeEditorBlock(name, sideName)
		local blockContainer = Instance.new("Frame")
		blockContainer.Name = name .. "_ThemeBlock"
		blockContainer.Size = UDim2.new(1, 0, 0, 0)
		blockContainer.AutomaticSize = Enum.AutomaticSize.Y
		blockContainer.Parent = sideName == "Right" and themeEditorRight or themeEditorLeft
		ApplyTheme(blockContainer, "Background", "BackgroundColor3")
		ApplyTheme(blockContainer, "BackgroundTrans", "BackgroundTransparency")
	
		local corner = Instance.new("UICorner")
		corner.CornerRadius = GLOBAL_CORNER
		corner.Parent = blockContainer
		CS:AddTag(corner, "ElementCorner")

		local blockStroke = Instance.new("UIStroke")
		blockStroke.Name = "EditorOutlineStroke"
		blockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		blockStroke.Thickness = 1
		blockStroke.Enabled = THEME.MainOutlineEnabled
		blockStroke.Parent = blockContainer
		ApplyTheme(blockStroke, "Outlines", "Color")
		CS:AddTag(blockStroke, "EditorLeftOutlineBind")

		local blockPadding = Instance.new("UIPadding")
		blockPadding.PaddingTop = UDim.new(0, 12)
		blockPadding.PaddingBottom = UDim.new(0, 12)
		blockPadding.PaddingLeft = UDim.new(0, 12)
		blockPadding.PaddingRight = UDim.new(0, 12)
		blockPadding.Parent = blockContainer

		local blockLayout = Instance.new("UIListLayout")
		blockLayout.FillDirection = Enum.FillDirection.Vertical
		blockLayout.SortOrder = Enum.SortOrder.LayoutOrder
		blockLayout.Padding = UDim.new(0, 6)
		blockLayout.Parent = blockContainer
	
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 20)
		title.BackgroundTransparency = 1
		title.TextSize = 13
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = name
		title.Parent = blockContainer
		ApplyTheme(title, "Text", "TextColor3")
		ApplyTheme(title, "TextFont", "Font")
	
		local div = Instance.new("Frame")
		div.Size = UDim2.new(1, 0, 0, 1)
		div.BorderSizePixel = 0
		div.Parent = blockContainer
		ApplyTheme(div, "Outlines", "BackgroundColor3")

		local function updateThemeBlockStyle(style)
			if style == 3 or style == 4 then
				blockPadding.PaddingTop = UDim.new(0, 8)
				blockPadding.PaddingBottom = UDim.new(0, 8)
				blockPadding.PaddingLeft = UDim.new(0, 8)
				blockPadding.PaddingRight = UDim.new(0, 8)
				blockLayout.Padding = UDim.new(0, 4)
				title.Size = UDim2.new(1, 0, 0, 16)
			else
				blockPadding.PaddingTop = UDim.new(0, 12)
				blockPadding.PaddingBottom = UDim.new(0, 12)
				blockPadding.PaddingLeft = UDim.new(0, 12)
				blockPadding.PaddingRight = UDim.new(0, 12)
				blockLayout.Padding = UDim.new(0, 6)
				title.Size = UDim2.new(1, 0, 0, 20)
			end
		end
		table.insert(Window._styleCallbacks, updateThemeBlockStyle)
		updateThemeBlockStyle(THEME.ElementStyle)

		return BuildElementAPI(blockContainer, name, "", sideName, "SettingsTab", true)
	end

	local colorsBlock = CreateThemeEditorBlock("Colors", "Left")
	colorsBlock:CreateColorpicker({
		Name = "Accent Color",
		Default = THEME.Accent,
		Callback = function(c) UpdateTheme("Accent", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Background",
		Default = THEME.Background,
		Callback = function(c) UpdateTheme("Background", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Sidebar",
		Default = THEME.Sidebar,
		Callback = function(c) UpdateTheme("Sidebar", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Cards & Panels",
		Default = THEME.Card,
		Callback = function(c) UpdateTheme("Card", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Elements",
		Default = THEME.Element,
		Callback = function(c) UpdateTheme("Element", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Inputs & Highlights",
		Default = THEME.Input,
		Callback = function(c) UpdateTheme("Input", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Outlines & Borders",
		Default = THEME.Outlines,
		Callback = function(c) UpdateTheme("Outlines", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Main Text",
		Default = THEME.Text,
		Callback = function(c) UpdateTheme("Text", c) end
	})
	colorsBlock:CreateColorpicker({
		Name = "Subtext",
		Default = THEME.TextMuted,
		Callback = function(c) UpdateTheme("TextMuted", c) end
	})

	local transBlock = CreateThemeEditorBlock("Transparency", "Left")
	transBlock:CreateSlider({
		Name = "Background",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.BackgroundTrans * 100),
		Callback = function(v) UpdateTheme("BackgroundTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Bg Image",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.BgImageTrans * 100),
		Callback = function(v) UpdateTheme("BgImageTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Cards & Panels",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.CardTrans * 100),
		Callback = function(v) UpdateTheme("CardTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Elements",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.ElementTrans * 100),
		Callback = function(v) UpdateTheme("ElementTrans", v/100) end
	})
	transBlock:CreateSlider({
		Name = "Inputs",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.InputTrans * 100),
		Callback = function(v) UpdateTheme("InputTrans", v/100) end
	})

	transBlock:CreateSlider({
		Name = "HUD",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.round(THEME.HUDTransparency * 100),
		Callback = function(v) UpdateTheme("HUDTransparency", v / 100) end
	})

	local miscBlock = CreateThemeEditorBlock("Fonts & Extras", "Left")
	miscBlock:CreateInput({
		Name = "Bg Image ID",
		Placeholder = "rbxassetid://...",
		Default = THEME.BackgroundImage or "",
		Callback = function(t) UpdateTheme("BackgroundImage", t) end
	})
	miscBlock:CreateDropdown({
		Name = "Primary Font",
		Options = FontsList,
		Default = THEME.TextFont,
		Callback = function(v) UpdateTheme("TextFont", v) end
	})
	miscBlock:CreateDropdown({
		Name = "Subtext Font",
		Options = FontsList,
		Default = THEME.SubtextFont,
		Callback = function(v) UpdateTheme("SubtextFont", v) end
	})

	local layoutBlock = CreateThemeEditorBlock("Layout & Styles", "Right")
	layoutBlock:CreateSlider({
		Name = "Sidebar Width",
		Min = MIN_SIDEBAR_WIDTH,
		Max = MAX_SIDEBAR_WIDTH,
		Step = 1,
		Default = math.clamp(currentSidebarWidth, MIN_SIDEBAR_WIDTH, MAX_SIDEBAR_WIDTH),
		Callback = function(width) updateSidebarWidth(width) end
	})
	layoutBlock:CreateKeybind({
		Name = "Open GUI Keybind",
		Default = openKeybind,
		Callback = function(key) Window:SetOpenKeybind(key) end
	})
	layoutBlock:CreateToggle({
		Name = "Main GUI Outline",
		Default = THEME.MainOutlineEnabled,
		Callback = function(s)
			THEME.MainOutlineEnabled = s
			mainOutlineStroke.Enabled = s 
			sidebarOutlineStroke.Enabled = (s and SIDEBAR_STATE.Detached)
			sidebarOutlineStroke.Transparency = 0
			mainOutlineStroke.Transparency = 0
			for _, ns in ipairs(CS:GetTagged("NotificationStrokeBind")) do
				ns.Enabled = s
			end
			for _, ws in ipairs(CS:GetTagged("WatermarkStrokeBind")) do
				ws.Enabled = s
			end
			for _, ls in ipairs(CS:GetTagged("EditorLeftOutlineBind")) do
				ls.Enabled = s
			end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Internal Outlines",
		Options = {"Off", "Only Blocks", "Only Elements", "All"},
		Default = THEME.InternalOutlines,
		Callback = function(opt)
			THEME.InternalOutlines = opt
			local showBlocks = (opt == "Only Blocks" or opt == "All")
			local showElems = (opt == "Only Elements" or opt == "All")
			for _, stroke in ipairs(CS:GetTagged("BlockStroke")) do stroke.Enabled = showBlocks end
			for _, stroke in ipairs(CS:GetTagged("ElementStroke")) do stroke.Enabled = showElems end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "GUI Style",
		Options = {"Style 1", "Style 2", "Style 3", "Style 4"},
		Default = "Style " .. tostring(THEME.ElementStyle or 1),
		Callback = function(opt)
			THEME.ElementStyle = tonumber(opt:match("%d+")) or 1
			for _, cb in ipairs(Window._styleCallbacks) do
				cb(THEME.ElementStyle)
			end
			FullUpdateLayout()
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Close Animation",
		Options = {"Fade Slide Down", "Fade Slide Up", "Zoom Fade", "Slide Right"},
		Default = (THEME.CloseAnimation == 2 and "Fade Slide Up") or (THEME.CloseAnimation == 3 and "Zoom Fade") or (THEME.CloseAnimation == 4 and "Slide Right") or "Fade Slide Down",
		Callback = function(opt)
			if opt == "Fade Slide Up" then
				THEME.CloseAnimation = 2
			elseif opt == "Zoom Fade" then
				THEME.CloseAnimation = 3
			elseif opt == "Slide Right" then
				THEME.CloseAnimation = 4
			else
				THEME.CloseAnimation = 1
			end
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Watermark",
		Default = watermarkEnabled,
		Callback = function(s)
			watermarkHolder.Visible = s
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Keybinds HUD",
		Default = keybindsEnabled,
		Callback = function(s)
			if Window.Keybinds then
				Window.Keybinds:SetVisible(s)
			end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Topbar Elements Pos",
		Options = {"Right", "Left"},
		Default = THEME.TopbarAlign or "Right",
		Callback = function(opt)
			UpdateTopbarAlign(opt)
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Search Bar",
		Default = showSearchBar,
		Callback = function(s)
			searchContainer.Visible = s 
		end
	})
	layoutBlock:CreateToggle({
		Name = "Show Profile",
		Default = showProfile,
		Callback = function(s)
			profileBlock.Visible = s 
		end
	})
	layoutBlock:CreateToggle({
		Name = "Drop Shadows",
		Default = SIDEBAR_STATE.ShadowsEnabled,
		Callback = function(s)
			setLayeredShadows(s)
		end
	})
	setLayeredShadows(SIDEBAR_STATE.ShadowsEnabled)
	layoutBlock:CreateSlider({
		Name = "Main Corner Radius",
		Min = 0,
		Max = 30,
		Step = 1,
		Default = cornerRadiusNum,
		Callback = function(v)
			cornerRadiusNum = v
			MAIN_CORNER = UDim.new(0, v)
			for _, corner in ipairs(CS:GetTagged("MainCorner")) do corner.CornerRadius = MAIN_CORNER end
			FullUpdateLayout()
		end
	})
	layoutBlock:CreateSlider({
		Name = "Elements Corner Radius",
		Min = 0,
		Max = 30,
		Step = 1,
		Default = elCornerRadiusNum,
		Callback = function(v)
			UpdateElementCorners(v)
		end
	})
	layoutBlock:CreateSlider({
		Name = "HUD Corner Radius",
		Min = 0,
		Max = 30,
		Step = 1,
		Default = hudCornerRadiusNum,
		Callback = function(v)
			hudCornerRadiusNum = v
			for _, corner in ipairs(CS:GetTagged("HUDCorner")) do corner.CornerRadius = UDim.new(0, v) end
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Sidebar Position",
		Options = {"Left", "Right", "Top", "Bottom"},
		Default = SIDEBAR_STATE.Position or "Left",
		Callback = function(opt)
			SIDEBAR_STATE.Position = opt
			FullUpdateLayout()
		end
	})
	layoutBlock:CreateToggle({
		Name = "Detached Sidebar",
		Default = SIDEBAR_STATE.Detached or false,
		Callback = function(s)
			SIDEBAR_STATE.Detached = s
			FullUpdateLayout()
			setLayeredShadows(SIDEBAR_STATE.ShadowsEnabled)
		end
	})
	layoutBlock:CreateDropdown({
		Name = "Toggle Checkbox Pos",
		Options = {"Right", "Left"},
		Default = THEME.TogglePosition or "Right",
		Callback = function(opt)
			UpdateTogglePosition(opt)
		end
	})
	
	local configBlock = Window.SettingsTab:CreateBlock({
		Name = "Configuration",
		Side = "Right"
	})
	
	safeMakeFolder(Window.ConfigFolder)
	
	local function getConfigs()
		local list = {}
		safeMakeFolder(Window.ConfigFolder)
		for _, file in pairs(safeListFiles(Window.ConfigFolder)) do
			local clean = tostring(file):gsub("[%z\r\n%s]+$", "")
			if clean:lower():match("%.json$") then
				local name = clean:match("([^/\\]+)%.[jJ][sS][oO][nN]$")
				if name and name ~= "" then 
					table.insert(list, name) 
				end
			end
		end
		return list
	end
	
	local autoLoadPath = Window.ConfigFolder .. "/autoload.txt"
	local currentAutoLoad = safeReadFile(autoLoadPath)
	currentAutoLoad = currentAutoLoad and currentAutoLoad:match("^%s*(.-)%s*$") or ""

	local configNameInput = configBlock:CreateInput({
		Name = "Config Name",
		Placeholder = "Enter name..."
	})
	
	local configDropdown = configBlock:CreateDropdown({
		Name = "Select Config",
		Options = getConfigs(),
		Default = (currentAutoLoad ~= "" and currentAutoLoad or nil)
	})
	
	configBlock:CreateButton({
		Name = "Load Config",
		Callback = function()
			local cfgName = configDropdown:Save().Selected
			if not cfgName or cfgName == "" then
				Window:Notify({Title = "Config Error", Description = "No config selected.", Duration = 3})
				return
			end
			
			local path = Window.ConfigFolder .. "/" .. cfgName .. ".json"
			local raw = safeReadFile(path)
			if not raw or raw == "" then
				Window:Notify({Title = "Config Error", Description = "File is empty or cannot be read.", Duration = 3})
				return
			end

			local success, res = pcall(function() return HttpService:JSONDecode(raw) end)
			if success and type(res) == "table" then
				for id, val in pairs(res) do
					if Window._configElements[id] then
						pcall(function() Window._configElements[id].API:Load(val) end)
					end
				end
				Window:Notify({
					Title = "Config System",
					Description = "Loaded config: " .. cfgName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			else
				Window:Notify({Title = "Config Error", Description = "Failed to parse JSON file.", Duration = 3})
			end
		end
	})
	
	configBlock:CreateButton({
		Name = "Save Config",
		Callback = function()
			local cfgName = configNameInput:Save().Text
			if not cfgName or cfgName == "" then
				cfgName = configDropdown:Save().Selected
			end
			
			if not cfgName or cfgName == "" then
				Window:Notify({Title = "Config Error", Description = "Enter a config name first.", Duration = 3})
				return
			end
			
			safeMakeFolder(Window.ConfigFolder)
			
			local data = {}
			for id, el in pairs(Window._configElements) do
				local s, savedData = pcall(function() return el.API:Save() end)
				if s and savedData ~= nil then
					data[id] = savedData
				end
			end
			
			local sEncode, json = pcall(function() return HttpService:JSONEncode(data) end)
			if not sEncode then
				Window:Notify({Title = "Config Error", Description = "JSON serialization failed.", Duration = 3})
				return
			end

			local path = Window.ConfigFolder .. "/" .. cfgName .. ".json"
			local sWrite, err = safeWriteFile(path, json)
			if sWrite then
				configDropdown:SetOptions(getConfigs())
				configDropdown:Set(cfgName)
				Window:Notify({
					Title = "Config System",
					Description = "Saved config: " .. cfgName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			else
				Window:Notify({Title = "Config Error", Description = "Executor blocked writing file: " .. tostring(err), Duration = 4})
			end
		end
	})

	configBlock:CreateButton({
		Name = "Refresh List",
		Callback = function()
			configDropdown:SetOptions(getConfigs())
			Window:Notify({Title = "Config System", Description = "Config list refreshed.", Duration = 2})
		end
	})
	
	configBlock:CreateButton({
		Name = "Delete Config",
		Callback = function()
			local cfgName = configDropdown:Save().Selected
			if cfgName and cfgName ~= "" then
				local path = Window.ConfigFolder .. "/" .. cfgName .. ".json"
				safeDelFile(path)
				configDropdown:SetOptions(getConfigs())
				configDropdown:Set(nil)
				Window:Notify({
					Title = "Config System",
					Description = "Deleted config: " .. cfgName,
					Duration = 3,
					Icon = SETTINGS_ICON_ID
				})
			end
		end
	})
	
	local isInitConfigAutoLoad = true
	configBlock:CreateToggle({
		Name = "Auto-Load Selected Config",
		Default = (currentAutoLoad ~= ""),
		Callback = function(state)
			if isInitConfigAutoLoad then return end
			if state then
				local cfgName = configDropdown:Save().Selected
				if cfgName and cfgName ~= "" then
					safeWriteFile(autoLoadPath, cfgName)
				else
					Window:Notify({Title = "Error", Description = "Please select a config first to auto-load.", Duration = 3})
				end
			else
				safeDelFile(autoLoadPath)
			end
		end
	})
	isInitConfigAutoLoad = false
	
	function Window:SetOpenKeybind(key)
		local resolved = resolveKeycode(key)
		if not resolved then return false end
		openKeybind = resolved
		local control = self._themeControls["Layout & Styles~Open GUI Keybind"]
		if control then control.API:SetKeybind(resolved) end
		return true
	end

	function Window:GetOpenKeybind()
		return openKeybind
	end

	local controlBindings = {
		Accent = {"Colors~Accent Color", "Colorpicker"},
		Background = {"Colors~Background", "Colorpicker"},
		Sidebar = {"Colors~Sidebar", "Colorpicker"},
		Card = {"Colors~Cards & Panels", "Colorpicker"},
		Element = {"Colors~Elements", "Colorpicker"},
		Input = {"Colors~Inputs & Highlights", "Colorpicker"},
		Outlines = {"Colors~Outlines & Borders", "Colorpicker"},
		Text = {"Colors~Main Text", "Colorpicker"},
		TextMuted = {"Colors~Subtext", "Colorpicker"},
		BackgroundTrans = {"Transparency~Background", "Percent"},
		HUDTransparency = {"Transparency~HUD", "Percent"},
		BgImageTrans = {"Transparency~Bg Image", "Percent"},
		CardTrans = {"Transparency~Cards & Panels", "Percent"},
		ElementTrans = {"Transparency~Elements", "Percent"},
		InputTrans = {"Transparency~Inputs", "Percent"},
		BackgroundImage = {"Fonts & Extras~Bg Image ID", "Text"},
		TextFont = {"Fonts & Extras~Primary Font", "Dropdown"},
		SubtextFont = {"Fonts & Extras~Subtext Font", "Dropdown"},
		MainOutlineEnabled = {"Layout & Styles~Main GUI Outline", "Toggle"},
		InternalOutlines = {"Layout & Styles~Internal Outlines", "Dropdown"},
		ElementStyle = {"Layout & Styles~GUI Style", "Style"},
		CloseAnimation = {"Layout & Styles~Close Animation", "Animation"},
		ShowWatermark = {"Layout & Styles~Show Watermark", "Toggle"},
		ShowKeybindsHUD = {"Layout & Styles~Show Keybinds HUD", "Toggle"},
		TopbarAlign = {"Layout & Styles~Topbar Elements Pos", "Dropdown"},
		ShowSearchBar = {"Layout & Styles~Show Search Bar", "Toggle"},
		ShowProfile = {"Layout & Styles~Show Profile", "Toggle"},
		DropShadows = {"Layout & Styles~Drop Shadows", "Toggle"},
		SidebarWidth = {"Layout & Styles~Sidebar Width", "Slider"},
		CornerRadius = {"Layout & Styles~Main Corner Radius", "Slider"},
		ElementsCornerRadius = {"Layout & Styles~Elements Corner Radius", "Slider"},
		HUDCornerRadius = {"Layout & Styles~HUD Corner Radius", "Slider"},
		SidebarPosition = {"Layout & Styles~Sidebar Position", "Dropdown"},
		DetachedSidebar = {"Layout & Styles~Detached Sidebar", "Toggle"},
		TogglePosition = {"Layout & Styles~Toggle Checkbox Pos", "Dropdown"}
	}

	function Window:SetThemeOption(key, value)
		if key == "OpenKeybind" then return self:SetOpenKeybind(value) end
		local binding = controlBindings[key]
		if not binding then
			if THEME[key] ~= nil then
				UpdateTheme(key, value)
				return true
			end
			return false
		end
		local entry = self._themeControls[binding[1]]
		if not entry then return false end
		local kind = binding[2]
		if kind == "Percent" then
			if tonumber(value) == nil then return false end
			value = math.round(math.clamp(tonumber(value), 0, 1) * 100) / 100
			if THEME[key] ~= value then UpdateTheme(key, value) end
			entry.API:Set(math.round(value * 100))
		elseif kind == "Colorpicker" then
			if typeof(value) ~= "Color3" then return false end
			entry.API:SetColor(value)
		elseif kind == "Text" then
			entry.API:SetText(tostring(value))
		elseif kind == "Style" then
			local n = tonumber(value)
			if not n or n < 1 or n > 4 then return false end
			entry.API:Set("Style " .. tostring(math.floor(n)))
		elseif kind == "Animation" then
			if type(value) == "number" then
				value = ({"Fade Slide Down", "Fade Slide Up", "Zoom Fade", "Slide Right"})[value]
			end
			if not value then return false end
			entry.API:Set(value)
		elseif kind == "Toggle" then
			entry.API:Set(value == true)
		else
			entry.API:Set(value)
		end
		return true
	end

	function Window:SetTheme(options)
		if type(options) ~= "table" then return false end
		local allApplied = true
		for key, value in pairs(options) do
			if not self:SetThemeOption(key, value) then allApplied = false end
		end
		return allApplied
	end

	function Window:SetHUDTransparency(value)
		return self:SetThemeOption("HUDTransparency", value)
	end

	searchContainer.Visible = showSearchBar
	profileBlock.Visible = showProfile
	setGlass(glassConfig)
	UpdateElementCorners(elCornerRadiusNum)

	UpdateTopbarAlign(THEME.TopbarAlign)
	UpdateTogglePosition(THEME.TogglePosition)

	mainOutlineStroke.Enabled = THEME.MainOutlineEnabled
	mainOutlineStroke.Transparency = 0
	sidebarOutlineStroke.Enabled = (THEME.MainOutlineEnabled and SIDEBAR_STATE.Detached)
	sidebarOutlineStroke.Transparency = 0
	for _, ns in ipairs(CS:GetTagged("NotificationStrokeBind")) do
		ns.Enabled = THEME.MainOutlineEnabled
	end
	for _, ws in ipairs(CS:GetTagged("WatermarkStrokeBind")) do
		ws.Enabled = THEME.MainOutlineEnabled
	end
	for _, ls in ipairs(CS:GetTagged("EditorLeftOutlineBind")) do
		ls.Enabled = THEME.MainOutlineEnabled
	end

	local showBlocks = (THEME.InternalOutlines == "Only Blocks" or THEME.InternalOutlines == "All")
	local showElems = (THEME.InternalOutlines == "Only Elements" or THEME.InternalOutlines == "All")
	for _, stroke in ipairs(CS:GetTagged("BlockStroke")) do stroke.Enabled = showBlocks end
	for _, stroke in ipairs(CS:GetTagged("ElementStroke")) do stroke.Enabled = showElems end

	updateSidebarWidth(currentSidebarWidth)

	task.spawn(function()
		task.wait(1.5)
	
		local tAutoName = safeReadFile(themeAutoLoadPath)
		if tAutoName and tAutoName ~= "" then
			tAutoName = tAutoName:match("^%s*(.-)%s*$")
			local tPath = Window.ThemeFolder .. "/" .. tAutoName .. ".json"
			local rawTheme = safeReadFile(tPath)
			if rawTheme and rawTheme ~= "" then
				local ts2, tRes = pcall(function() return HttpService:JSONDecode(rawTheme) end)
				if ts2 and type(tRes) == "table" then
					for id, val in pairs(tRes) do
						if id == "SidebarWidth" then
							updateSidebarWidth(val)
						elseif Window._themeElements[id] then
							Window._themeElements[id].API:Load(val)
						end
					end
					themeDropdown:Set(tAutoName)
					Window:Notify({
						Title = "Theme System",
						Description = "Auto-loaded theme: " .. tAutoName,
						Duration = 3,
						Icon = SETTINGS_ICON_ID
					})
				end
			end
		end

		task.wait(0.5)

		local autoName = safeReadFile(autoLoadPath)
		if autoName and autoName ~= "" then
			autoName = autoName:match("^%s*(.-)%s*$")
			local path = Window.ConfigFolder .. "/" .. autoName .. ".json"
			local rawJson = safeReadFile(path)
			if rawJson and rawJson ~= "" then
				local s2, res = pcall(function() return HttpService:JSONDecode(rawJson) end)
				if s2 and type(res) == "table" then
					for id, val in pairs(res) do
						if Window._configElements[id] then
							pcall(function() Window._configElements[id].API:Load(val) end)
						end
					end
					configDropdown:Set(autoName)
					Window:Notify({
						Title = "Config System",
						Description = "Auto-loaded config: " .. autoName,
						Duration = 3,
						Icon = SETTINGS_ICON_ID
					})
				end
			end
		end
	end)

	return Window
end

return Library
