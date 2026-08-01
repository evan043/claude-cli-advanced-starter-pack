-- Runtime picker for :CcaspRuntime
-- Switches which agent CLI the active session drives, and keeps the command
-- palette pointed at that runtime's prompt directory.

local runtime = require("ccasp.runtime")

local M = {}

local function notify(msg, level)
  vim.notify("CCASP: " .. msg, level or vim.log.levels.INFO)
end

-- Repoint the command palette after a runtime change.
local function refresh_commands()
  local ok, commands = pcall(require, "ccasp.core.commands")
  if ok and commands.reload then pcall(commands.reload) end
end

-- Apply a runtime to the active session, falling back to the global default
-- when no session is live yet.
function M.switch(name)
  local key = runtime.normalize(name)
  if not key then
    notify("Unknown runtime: " .. tostring(name), vim.log.levels.ERROR)
    return false
  end

  if not runtime.is_available(key) then
    notify(runtime.label(key) .. " CLI not found in PATH", vim.log.levels.ERROR)
    return false
  end

  runtime.set_default(key)

  local ccasp_ok, ccasp = pcall(require, "ccasp")
  if ccasp_ok and ccasp.config then
    ccasp.config.runtime = key
    ccasp.config.terminal.shell = runtime.command(key)
    ccasp.config.claude.command = runtime.command(key)
  end

  local sessions_ok, sessions = pcall(require, "ccasp.sessions")
  local switched_session = false
  if sessions_ok then
    local active = sessions.get_active()
    if active and sessions.set_runtime then
      switched_session = sessions.set_runtime(active.id, key)
    end
  end

  refresh_commands()

  if switched_session then
    notify(("switched to %s -- restart the session to launch it (<leader>cR)")
      :format(runtime.label(key)))
  else
    notify("default runtime set to " .. runtime.label(key))
  end
  return true
end

-- Current runtime plus availability, for display.
function M.status()
  local lines = {}
  local active = runtime.default()
  for _, name in ipairs(runtime.order) do
    table.insert(lines, ("%s %-7s %s"):format(
      name == active and "*" or " ",
      runtime.label(name),
      runtime.is_available(name) and "available" or "not in PATH"
    ))
  end
  return lines
end

-- Entry point for :CcaspRuntime [name]
function M.pick(arg)
  if arg and arg ~= "" then
    return M.switch(arg)
  end

  local available = runtime.available()
  if #available == 0 then
    notify("no agent CLI found in PATH (install claude or codex)", vim.log.levels.ERROR)
    return false
  end

  local active = runtime.default()
  local choices = {}
  for _, name in ipairs(runtime.order) do
    table.insert(choices, {
      name = name,
      label = ("%s%s%s"):format(
        runtime.label(name),
        name == active and "  (current)" or "",
        runtime.is_available(name) and "" or "  -- not installed"
      ),
    })
  end

  vim.ui.select(choices, {
    prompt = "CCASP runtime:",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then M.switch(choice.name) end
  end)
  return true
end

return M
