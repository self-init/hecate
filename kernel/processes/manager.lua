---@class ProcessManager
---@field process_id number
---@field processes table<number, Process>
---@field active_process Process
---@field queues table<number, Process[]>
---@field meta table<number, { queue_level: number, ticks_used: number }>
---@field tick_count number
ProcessManager = {}

-- MLFQ configuration
local NUM_QUEUES     = 3
local QUANTA         = {2, 4, 8}  -- yields per queue before demotion
local BOOST_INTERVAL = 50         -- steps between starvation-prevention boosts

function ProcessManager:new(arch)
    local procman = {
        process_id     = 0,
        processes      = {},
        active_process = nil,
        -- queues[1] = highest priority, queues[NUM_QUEUES] = lowest
        queues         = {{}, {}, {}},
        -- pid -> { queue_level (0-based), ticks_used }
        meta           = {},
        tick_count     = 0,
    }
    setmetatable(procman, self)
    self.__index = self
    return procman
end

function ProcessManager:add_process(process)
    process.pid     = self.process_id
    self.process_id = self.process_id + 1
    self.processes[process.pid] = process

    self.meta[process.pid] = {
        queue_level = 0,
        ticks_used  = 0,
    }
    table.insert(self.queues[1], process)
end

function ProcessManager:remove_process(pid)
    if self.processes[pid] then
        self.processes[pid].dead = true
    end
    self.processes[pid] = nil
    self.meta[pid]      = nil
end

-- Dequeue the next runnable process from the highest non-empty queue.
function ProcessManager:_next_process()
    for level = 1, NUM_QUEUES do
        local queue = self.queues[level]
        while #queue > 0 do
            local proc = table.remove(queue, 1)
            if not proc.dead then
                return proc, level - 1  -- 0-based level
            end
        end
    end
    return nil, nil
end

-- Move all processes into queue 0 to prevent starvation.
function ProcessManager:_boost_all()
    for level = 2, NUM_QUEUES do
        for _, proc in ipairs(self.queues[level]) do
            if not proc.dead then
                local m = self.meta[proc.pid]
                if m then
                    m.queue_level = 0
                    m.ticks_used  = 0
                end
                table.insert(self.queues[1], proc)
            end
        end
        self.queues[level] = {}
    end
end

-- Run one scheduler step: resume the next highest-priority process.
-- Returns true if a process was run, false if all queues are empty.
function ProcessManager:step()
    self.tick_count = self.tick_count + 1

    if self.tick_count % BOOST_INTERVAL == 0 then
        self:_boost_all()
    end

    local proc, level = self:_next_process()
    if not proc then return false end

    self.active_process = proc
    local m = self.meta[proc.pid]

    local ok = coroutine.resume(proc.coroutine)

    self.active_process = nil

    if not ok then
        proc.dead      = true
        proc.exit_code = -1
        self.meta[proc.pid] = nil
        return true
    end
    if coroutine.status(proc.coroutine) == "dead" then
        proc.dead      = true
        proc.exit_code = proc.exit_code or 0
        self.meta[proc.pid] = nil
        return true
    end

    if not m then return true end  -- process removed itself during execution
    m.ticks_used = m.ticks_used + 1

    if m.ticks_used >= QUANTA[level + 1] then
        -- Exhausted quantum, demote to next queue.
        m.ticks_used  = 0
        local new_level = math.min(level + 1, NUM_QUEUES - 1)
        m.queue_level = new_level
        table.insert(self.queues[new_level + 1], proc)
    else
        -- Remaining ticks in quantum; re-enqueue at same level.
        table.insert(self.queues[level + 1], proc)
    end

    return true
end
