-- CCASP runtime resolver
-- Resolves which agent CLI a session drives (Claude Code or Codex) and where
-- that runtime keeps its slash-command prompts.
--
-- Default runtime resolution order:
--   1. .ccasp/runtime/state.json -- emitted by `ccasp init`, authoritative
--   2. .ccasp/config.yaml        -- flat `key: value`, parsed directly
--   3. whichever CLI is on PATH  -- claude wins a tie
--
-- Sessions carry their own runtime, so this module never assumes a single
-- global answer; callers pass a name when they have one.

local M = {}

M.specs = {
  claude = {
    name = "claude",
    label = "Claude",
    command = "claude",
    root = ".claude",
    prompts_subdir = "commands",
    -- npm/installer shims mean the bare name is not always what is on PATH.
    candidates = { "claude", "claude.cmd", "claude.exe" },
    -- Subcommand that selects this runtime under the Happy wrapper. Bare
    -- `happy` already starts Claude, so it needs none.
    happy_args = nil,
    -- Single-key shortcut in the session-type picker.
    key = "c",
    short = "CL",
  },
  codex = {
    name = "codex",
    label = "Codex",
    command = "codex",
    root = ".codex",
    prompts_subdir = "prompts",
    candidates = { "codex", "codex.cmd", "codex.exe" },
    happy_args = "codex",
    key = "x",
    short = "CX",
  },
}

-- Happy (happy.engineering) wraps an agent CLI to add mobile control.
local HAPPY = "happy"
local HAPPY_CANDIDATES = { "happy", "happy.cmd", "happy.exe" }

-- Stable display/pick order.
M.order = { "claude", "codex" }

M.FALLBACK = "claude"

local detect_cache = {}
local resolved_default = nil
local config_cache = nil

local function project_root()
  local ok, ccasp = pcall(require, "ccasp")
  if ok and ccasp.config and ccasp.config.project_root then
    return ccasp.config.project_root
  end
  return vim.fn.getcwd()
end

local function join(root, rel)
  return ((root or "") .. "/" .. rel):gsub("\\", "/"):gsub("//+", "/")
end

-- Normalize anything caller-supplied into a known runtime name.
function M.normalize(name)
  if type(name) == "table" and name.name then name = name.name end
  if type(name) ~= "string" then return nil end
  name = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
  return M.specs[name] and name or nil
end

function M.spec(name)
  return M.specs[M.normalize(name) or M.FALLBACK]
end

-- True when any candidate binary for this runtime is on PATH.
function M.is_available(name)
  local key = M.normalize(name)
  if not key then return false end
  if detect_cache[key] ~= nil then return detect_cache[key] end

  local found = false
  for _, candidate in ipairs(M.specs[key].candidates) do
    if vim.fn.executable(candidate) == 1 then
      found = true
      break
    end
  end
  detect_cache[key] = found
  return found
end

-- Names of every runtime whose CLI is actually installed.
function M.available()
  local out = {}
  for _, name in ipairs(M.order) do
    if M.is_available(name) then table.insert(out, name) end
  end
  return out
end

-- Read .ccasp/runtime/state.json, else .ccasp/config.yaml. Returns a table with
-- `default_runtime` and `dual_runtime` when either source supplies them.
local function read_project_config(root)
  if config_cache then return config_cache end
  local cfg = {}

  local state_path = join(root, ".ccasp/runtime/state.json")
  if vim.fn.filereadable(state_path) == 1 then
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(state_path), "\n"))
    if ok and type(decoded) == "table" then
      cfg.default_runtime = M.normalize(decoded.default_runtime)
      cfg.dual_runtime = decoded.dual_runtime
    end
  end

  -- config.yaml is a flat `key: value` document; a line match is sufficient and
  -- avoids pulling a YAML parser into Neovim.
  if cfg.default_runtime == nil or cfg.dual_runtime == nil then
    local yaml_path = join(root, ".ccasp/config.yaml")
    if vim.fn.filereadable(yaml_path) == 1 then
      for _, line in ipairs(vim.fn.readfile(yaml_path)) do
        local key, value = line:match("^%s*([%w_]+)%s*:%s*(%S+)")
        if key == "default_runtime" and cfg.default_runtime == nil then
          cfg.default_runtime = M.normalize(value)
        elseif key == "dual_runtime" and cfg.dual_runtime == nil then
          cfg.dual_runtime = (value == "true")
        end
      end
    end
  end

  config_cache = cfg
  return cfg
end

-- Whether the project wants both runtimes offered side by side.
function M.dual_enabled(root)
  local cfg = read_project_config(root or project_root())
  if cfg.dual_runtime ~= nil then return cfg.dual_runtime end
  -- Not configured: offer a choice whenever both CLIs are actually installed.
  return #M.available() > 1
end

-- The runtime new sessions should use when the caller has no preference.
function M.default(root)
  if resolved_default then return resolved_default end

  local cfg = read_project_config(root or project_root())
  local configured = cfg.default_runtime

  -- Honor the configured runtime, but not when its CLI is missing -- falling
  -- back beats spawning a terminal that immediately errors.
  if configured and M.is_available(configured) then
    resolved_default = configured
    return resolved_default
  end

  local available = M.available()
  resolved_default = configured or available[1] or M.FALLBACK
  if configured and #available > 0 and not M.is_available(configured) then
    resolved_default = available[1]
  end
  return resolved_default
end

-- Shell string typed into a session terminal.
function M.command(name)
  return M.spec(name).command
end

function M.label(name)
  return M.spec(name).label
end

-- Directory holding this runtime's slash-command prompts.
function M.prompts_dir(root, name)
  local spec = M.spec(name)
  return join(root or project_root(), spec.root .. "/" .. spec.prompts_subdir)
end

-- Command that launches this runtime under Happy, for mobile control.
function M.happy_command(name)
  local spec = M.spec(name)
  return spec.happy_args and (HAPPY .. " " .. spec.happy_args) or HAPPY
end

-- Whether the Happy wrapper itself is installed.
function M.happy_available()
  if detect_cache[HAPPY] ~= nil then return detect_cache[HAPPY] end
  local found = false
  for _, candidate in ipairs(HAPPY_CANDIDATES) do
    if vim.fn.executable(candidate) == 1 then
      found = true
      break
    end
  end
  detect_cache[HAPPY] = found
  return found
end

-- Best guess at the runtime a command string refers to, so sessions and saved
-- layout templates that stored a bare binary name still resolve correctly.
function M.from_command(command)
  if type(command) ~= "string" then return nil end
  local head, rest = command:match("^%s*([%w%.%-_]+)%s*(.*)$")
  if not head then return nil end
  head = head:lower():gsub("%.cmd$", ""):gsub("%.exe$", "")

  -- Happy wraps a runtime rather than being one: bare `happy` starts Claude,
  -- `happy codex` starts Codex. Unwrap so the session tags the real runtime
  -- and the command palette follows it.
  if head == HAPPY then
    local sub = (rest or ""):match("^([%w%-_]+)")
    return M.normalize(sub) or M.FALLBACK
  end

  return M.normalize(head)
end

-- True when the command string launches through the Happy wrapper.
function M.is_happy_command(command)
  if type(command) ~= "string" then return false end
  local head = command:match("^%s*([%w%.%-_]+)") or ""
  return head:lower():gsub("%.cmd$", ""):gsub("%.exe$", "") == HAPPY
end

-- Explicit override for the session; cleared by reset().
function M.set_default(name)
  local key = M.normalize(name)
  if not key then return false end
  resolved_default = key
  return true
end

-- Drop caches after an install, a config edit, or a project switch.
function M.reset()
  detect_cache = {}
  resolved_default = nil
  config_cache = nil
end

return M
