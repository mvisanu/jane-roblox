--[[
Minimal Roblox engine mock used only by scripts/walkability_test.py.

It implements just enough of Vector3, CFrame, Instance, and the services that
WorldService touches so the real WorldService source can be executed outside of
Roblox Studio. Every BasePart that gets created is recorded in `WORLD_PARTS`
with its final world transform so an offline test can reason about collision.

This file is a test double. It is never synced into the game.
]]

local M = {}

-- Vector3 -------------------------------------------------------------------

local Vector3mt = {}
Vector3mt.__index = Vector3mt

local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3mt)
end

function Vector3mt.__add(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function Vector3mt.__sub(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function Vector3mt.__unm(a)
	return vec(-a.X, -a.Y, -a.Z)
end

function Vector3mt.__mul(a, b)
	if type(a) == "number" then
		return vec(a * b.X, a * b.Y, a * b.Z)
	end
	if type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

function Vector3mt.__div(a, b)
	if type(b) == "number" then
		return vec(a.X / b, a.Y / b, a.Z / b)
	end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end

function Vector3mt.__eq(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

Vector3mt.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return vec(0, 0, 0)
		end
		return vec(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(Vector3mt, key)
end

local Vector3 = { new = function(x, y, z) return vec(x, y, z) end }
Vector3.zero = vec(0, 0, 0)

local Vector2 = {
	new = function(x, y) return { X = x or 0, Y = y or 0 } end,
}
Vector2.zero = Vector2.new(0, 0)

local function cross(a, b)
	return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end

-- CFrame --------------------------------------------------------------------
-- Rotation is a 3x3 matrix stored column-wise: xa (right), ya (up), za (back).
-- Roblox LookVector is -za.

local CFramemt = {}

local function cf(position, xa, ya, za)
	return setmetatable({
		p = position,
		xa = xa or vec(1, 0, 0),
		ya = ya or vec(0, 1, 0),
		za = za or vec(0, 0, 1),
	}, CFramemt)
end

local function rotate(c, v)
	return vec(
		c.xa.X * v.X + c.ya.X * v.Y + c.za.X * v.Z,
		c.xa.Y * v.X + c.ya.Y * v.Y + c.za.Y * v.Z,
		c.xa.Z * v.X + c.ya.Z * v.Y + c.za.Z * v.Z
	)
end

CFramemt.__index = function(self, key)
	if key == "Position" then
		return self.p
	elseif key == "X" then
		return self.p.X
	elseif key == "Y" then
		return self.p.Y
	elseif key == "Z" then
		return self.p.Z
	elseif key == "LookVector" then
		return -self.za
	elseif key == "RightVector" then
		return self.xa
	elseif key == "UpVector" then
		return self.ya
	elseif key == "Lerp" then
		return function(a, b, alpha)
			return cf(a.p + (b.p - a.p) * alpha, b.xa, b.ya, b.za)
		end
	end
	return nil
end

CFramemt.__mul = function(a, b)
	if getmetatable(b) == Vector3mt then
		return a.p + rotate(a, b)
	end
	return cf(a.p + rotate(a, b.p), rotate(a, b.xa), rotate(a, b.ya), rotate(a, b.za))
end

CFramemt.__add = function(a, v)
	return cf(a.p + v, a.xa, a.ya, a.za)
end

CFramemt.__sub = function(a, v)
	return cf(a.p - v, a.xa, a.ya, a.za)
end

local CFrame = {}

function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cf(vec(x.X, x.Y, x.Z))
	end
	return cf(vec(x or 0, y or 0, z or 0))
end

function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	-- R = Rx * Ry * Rz, columns are the rotated basis vectors.
	local xa = vec(cy * cz, cx * sz + sx * sy * cz, sx * sz - cx * sy * cz)
	local ya = vec(-cy * sz, cx * cz - sx * sy * sz, sx * cz + cx * sy * sz)
	local za = vec(sy, -sx * cy, cx * cy)
	return cf(vec(0, 0, 0), xa, ya, za)
end

function CFrame.lookAt(origin, target, up)
	up = up or vec(0, 1, 0)
	local za = (origin - target).Unit
	if za.Magnitude == 0 then
		za = vec(0, 0, 1)
	end
	local xa = cross(up, za).Unit
	local ya = cross(za, xa)
	return cf(origin, xa, ya, za)
end

CFrame.identity = cf(vec(0, 0, 0))

-- Enum ----------------------------------------------------------------------

local function enumBranch(name)
	return setmetatable({}, {
		__index = function(branch, key)
			local value = { Name = key, Branch = name }
			rawset(branch, key, value)
			return value
		end,
	})
end

local Enum = setmetatable({}, {
	__index = function(self, key)
		local branch = enumBranch(key)
		rawset(self, key, branch)
		return branch
	end,
})

-- Color3 --------------------------------------------------------------------

local Color3 = {}
local Color3mt = { __index = {} }
function Color3mt.__index:Lerp(other, alpha)
	return Color3.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3mt)
end

function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

-- UDim / UDim2 ---------------------------------------------------------------

local function udim(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end

local UDim = { new = function(scale, offset) return udim(scale, offset) end }

-- UDim2.X is a UDim, not a number: WorldService reads label sizes as .X.Offset.
local UDim2 = {
	fromOffset = function(x, y) return { X = udim(0, x), Y = udim(0, y) } end,
	fromScale = function(x, y) return { X = udim(x, 0), Y = udim(y, 0) } end,
	new = function(xScale, xOffset, yScale, yOffset)
		return { X = udim(xScale, xOffset), Y = udim(yScale, yOffset) }
	end,
}

-- Instances -----------------------------------------------------------------

WORLD_PARTS = {}

local PART_CLASSES = {
	Part = true,
	SpawnLocation = true,
	MeshPart = true,
	WedgePart = true,
	TrussPart = true,
}

local Instancemt = {}
Instancemt.__index = function(self, key)
	local stored = rawget(self, "_props")[key]
	if stored ~= nil then
		return stored
	end
	return rawget(Instancemt, "_methods")[key]
end
Instancemt.__newindex = function(self, key, value)
	if key == "Parent" then
		local previous = rawget(self, "_props").Parent
		if previous then
			for index, child in ipairs(rawget(previous, "_children")) do
				if child == self then
					table.remove(rawget(previous, "_children"), index)
					break
				end
			end
		end
		rawget(self, "_props").Parent = value
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	rawget(self, "_props")[key] = value
end

local methods = {}
Instancemt._methods = methods

function methods:IsA(className)
	local class = rawget(self, "_props").ClassName
	if className == "BasePart" then
		return PART_CLASSES[class] == true
	end
	return class == className
end

function methods:FindFirstChild(name)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").Name == name then
			return child
		end
	end
	return nil
end

function methods:WaitForChild(name)
	return self:FindFirstChild(name)
end

function methods:FindFirstChildOfClass(className)
	for _, child in ipairs(rawget(self, "_children")) do
		if rawget(child, "_props").ClassName == className then
			return child
		end
	end
	return nil
end

function methods:GetChildren()
	local copy = {}
	for index, child in ipairs(rawget(self, "_children")) do
		copy[index] = child
	end
	return copy
end

function methods:GetDescendants()
	local list = {}
	local function walk(node)
		for _, child in ipairs(rawget(node, "_children")) do
			table.insert(list, child)
			walk(child)
		end
	end
	walk(self)
	return list
end

function methods:Destroy()
	local props = rawget(self, "_props")
	if props.Parent then
		self.Parent = nil
	end
	props.Destroyed = true
	for _, child in ipairs(self:GetDescendants()) do
		rawget(child, "_props").Destroyed = true
	end
end

function methods:ClearAllChildren()
	for _, child in ipairs(self:GetChildren()) do
		child:Destroy()
	end
end

function methods:SetAttribute(name, value)
	rawget(self, "_attributes")[name] = value
end

function methods:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end

function methods:GetPivot()
	local props = rawget(self, "_props")
	if props.CFrame then
		return props.CFrame
	end
	if props.PrimaryPart then
		return rawget(props.PrimaryPart, "_props").CFrame
	end
	return CFrame.new(0, 0, 0)
end

function methods:PivotTo(target)
	rawget(self, "_props").Pivot = target
end

local function signal()
	return { Connect = function() return { Disconnect = function() end } end }
end

local Instance = {}

function Instance.new(className)
	local object = setmetatable({
		_props = { ClassName = className, Name = className, Parent = nil },
		_children = {},
		_attributes = {},
	}, Instancemt)

	local props = rawget(object, "_props")
	if PART_CLASSES[className] then
		props.Size = vec(4, 1, 2)
		props.CFrame = CFrame.new(0, 0, 0)
		props.CanCollide = true
		props.Anchored = false
		props.Transparency = 0
		props.Shape = Enum.PartType.Block
		table.insert(WORLD_PARTS, object)
	elseif className == "ProximityPrompt" then
		props.Triggered = signal()
	end
	return object
end

-- Services ------------------------------------------------------------------

local workspaceFolder = Instance.new("Folder")
workspaceFolder.Name = "Workspace"

local ReplicatedStorage = Instance.new("Folder")
ReplicatedStorage.Name = "ReplicatedStorage"

local Shared = Instance.new("Folder")
Shared.Name = "Shared"
Shared.Parent = ReplicatedStorage

local tagged = {}

local lighting = Instance.new("Folder")
lighting.Name = "Lighting"

local services = {
	Workspace = workspaceFolder,
	ReplicatedStorage = ReplicatedStorage,
	Lighting = lighting,
	CollectionService = {
		AddTag = function(_, instance, tag)
			tagged[tag] = tagged[tag] or {}
			table.insert(tagged[tag], instance)
		end,
		GetTagged = function(_, tag)
			return tagged[tag] or {}
		end,
		HasTag = function(_, instance, tag)
			for _, entry in ipairs(tagged[tag] or {}) do
				if entry == instance then
					return true
				end
			end
			return false
		end,
		GetInstanceAddedSignal = function() return signal() end,
		GetInstanceRemovedSignal = function() return signal() end,
	},
	Debris = { AddItem = function() end },
	Players = { GetPlayers = function() return {} end, PlayerAdded = signal(), PlayerRemoving = signal() },
	RunService = {
		Heartbeat = signal(),
		Stepped = signal(),
		IsStudio = function() return true end,
		IsServer = function() return true end,
		IsClient = function() return false end,
	},
	--[[
		An in-memory DataStore.

		Tests that only care about geometry could get away with no store at all,
		but "does my furniture come back when I rejoin?" cannot be answered
		without one: it is precisely the save-then-load round trip, sanitiser and
		all, that has to be exercised. This keeps the data in a table and is
		otherwise faithful to the two calls DataService makes.
	]]
	DataStoreService = {
		GetDataStore = function()
			local saved = {}
			return {
				GetAsync = function(_, key)
					return saved[key]
				end,
				UpdateAsync = function(_, key, transform)
					saved[key] = transform(saved[key])
					return saved[key]
				end,
				SetAsync = function(_, key, value)
					saved[key] = value
					return value
				end,
			}
		end,
	},
	TweenService = { Create = function() return { Play = function() end } end },
	MarketplaceService = {
		PromptGamePassPurchaseFinished = signal(),
		UserOwnsGamePassAsync = function() return false end,
		PromptProductPurchase = function() end,
		PromptGamePassPurchase = function() end,
	},
}

local game = {
	GetService = function(_, name)
		return services[name] or Instance.new("Folder")
	end,
	BindToClose = function() end,
}

-- Module registry ------------------------------------------------------------

local modules = {}

local function registerModule(name, value)
	local holder = Instance.new("ModuleScript")
	holder.Name = name
	holder.Parent = Shared
	modules[holder] = value
	return holder
end

local function requireShim(target)
	if modules[target] ~= nil then
		return modules[target]
	end
	error("mock require: unknown module " .. tostring(target and target.Name or target))
end

-- Exported globals -----------------------------------------------------------

M.Vector3 = Vector3
M.Vector2 = Vector2
M.CFrame = CFrame
M.Color3 = Color3
M.Enum = Enum
M.UDim = UDim
M.UDim2 = UDim2
M.Instance = Instance
M.game = game
M.workspace = workspaceFolder
M.require = requireShim
M.registerModule = registerModule
M.Shared = Shared
M.isPart = function(object)
	return PART_CLASSES[rawget(object, "_props").ClassName] == true
end

function M.install(env)
	-- Luau standard library extras that plain Lua does not ship.
	if math.round == nil then
		math.round = function(x)
			return math.floor(x + 0.5)
		end
		math.clamp = function(x, low, high)
			return math.max(low, math.min(high, x))
		end
		math.sign = function(x)
			if x > 0 then
				return 1
			elseif x < 0 then
				return -1
			end
			return 0
		end
		-- Luau keeps math.atan2; Lua 5.3+ folded it into math.atan(y, x).
		math.atan2 = function(y, x)
			return math.atan(y, x)
		end
	end
	if table.freeze == nil then
		table.freeze = function(t) return t end
		table.clone = function(t)
			local copy = {}
			for key, value in pairs(t) do
				copy[key] = value
			end
			return copy
		end
		table.find = function(haystack, needle)
			for index, value in ipairs(haystack) do
				if value == needle then
					return index
				end
			end
			return nil
		end
	end

	env.Vector3 = Vector3
	env.Vector2 = Vector2
	env.CFrame = CFrame
	env.Color3 = Color3
	env.Enum = Enum
	env.UDim = UDim
	env.UDim2 = UDim2
	env.Instance = Instance
	env.game = game
	env.workspace = workspaceFolder
	env.require = requireShim
	env.task = {
		spawn = function(fn, ...) return fn(...) end,
		delay = function() end,
		wait = function() end,
		defer = function(fn, ...) return fn(...) end,
	}
	return env
end

-- Part export ----------------------------------------------------------------

local function fullName(object)
	local names = {}
	local node = object
	while node do
		local props = rawget(node, "_props")
		table.insert(names, 1, props.Name)
		node = props.Parent
	end
	return table.concat(names, ".")
end

--[[ Flattens every live BasePart into plain numbers for the Python checker. ]]
function M.exportParts()
	local rows = {}
	for _, object in ipairs(WORLD_PARTS) do
		local props = rawget(object, "_props")
		if not props.Destroyed and props.Parent ~= nil then
			local c = props.CFrame
			local size = props.Size
			local color = props.Color or { R = 0, G = 0, B = 0 }
			table.insert(rows, {
				path = fullName(object),
				name = props.Name,
				canCollide = props.CanCollide and 1 or 0,
				transparency = props.Transparency or 0,
				shape = (props.Shape and props.Shape.Name) or "Block",
				material = (props.Material and props.Material.Name) or "Plastic",
				r = math.floor(color.R * 255 + 0.5),
				g = math.floor(color.G * 255 + 0.5),
				b = math.floor(color.B * 255 + 0.5),
				sx = size.X, sy = size.Y, sz = size.Z,
				px = c.p.X, py = c.p.Y, pz = c.p.Z,
				xx = c.xa.X, xy = c.xa.Y, xz = c.xa.Z,
				yx = c.ya.X, yy = c.ya.Y, yz = c.ya.Z,
				zx = c.za.X, zy = c.za.Y, zz = c.za.Z,
			})
		end
	end
	return rows
end

-- Exposes the physical cottage signs and their rendered lettering to the
-- offline regression suite. This deliberately exports only the small public
-- contract the tests need instead of leaking the mock's internal object graph.
function M.exportHomeSigns()
	local rows = {}
	for _, object in ipairs(WORLD_PARTS) do
		local props = rawget(object, "_props")
		if not props.Destroyed and props.Parent ~= nil and props.Name == "HomeNameSignBoard" then
			local surface = object:FindFirstChild("HomeNameSurface")
			local owner = surface and surface:FindFirstChild("OwnerName")
			local subtitle = surface and surface:FindFirstChild("HomeSubtitle")
			local ownerColor = owner and owner.TextColor3 or Color3.new()
			local strokeColor = owner and owner.TextStrokeColor3 or Color3.new()
			table.insert(rows, {
				path = fullName(object),
				corner = object:GetAttribute("PlotCorner") or "",
				ownerText = owner and owner.Text or "",
				ownerFont = owner and owner.Font and owner.Font.Name or "",
				subtitleText = subtitle and subtitle.Text or "",
				subtitleFont = subtitle and subtitle.Font and subtitle.Font.Name or "",
				pixelsPerStud = surface and surface.PixelsPerStud or 0,
				lightInfluence = surface and surface.LightInfluence or 1,
				textR = math.floor(ownerColor.R * 255 + 0.5),
				textG = math.floor(ownerColor.G * 255 + 0.5),
				textB = math.floor(ownerColor.B * 255 + 0.5),
				strokeR = math.floor(strokeColor.R * 255 + 0.5),
				strokeG = math.floor(strokeColor.G * 255 + 0.5),
				strokeB = math.floor(strokeColor.B * 255 + 0.5),
			})
		end
	end
	return rows
end

return M
