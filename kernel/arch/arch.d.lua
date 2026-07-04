---@meta

---Base class for kernel architectures
---@class Arch
local Arch = {}

---Called on kernel initialization, creates initial devices and filesystems
function Arch:init() end

---Called on each step of the process scheduler, performs some device upkeep
function Arch:step() end
