-- CCASP Statusbar Component
-- Shows CCASP status in the statusline with Nerd Font icons

local M = {}
local nf = require("ccasp.ui.icons")

-- Get short status string for statusline
function M.get()
  local ccasp = require("ccasp")
  local status = ccasp.get_status()

  local sync_icon = status.sync_status == "synced" and nf.sync_ok or nf.sync_warn

  local parts = {
    nf.ccasp .. " CCASP",
    "v" .. status.version,
    nf.perm_mode(status.permissions_mode) .. " " .. status.permissions_mode,
    nf.update_mode(status.update_mode) .. " " .. status.update_mode,
    nf.shield .. " " .. status.protected_count,
    sync_icon,
  }

  return table.concat(parts, " " .. nf.pipe .. " ")
end

-- Get full status line for sidebar footer
function M.get_full()
  local ccasp = require("ccasp")
  local status = ccasp.get_status()

  local perm_icon = nf.perm_mode(status.permissions_mode)
  local update_icon = nf.update_mode(status.update_mode)
  local sync_icon = status.sync_status == "synced" and nf.sync_ok or nf.sync_warn

  return string.format(
    "CCASP v%s %s %s %s %s %s %s %s %d %s %s",
    status.version,
    nf.pipe,
    perm_icon .. " " .. status.permissions_mode:sub(1, 1):upper() .. status.permissions_mode:sub(2),
    nf.pipe,
    update_icon .. " " .. status.update_mode:sub(1, 1):upper() .. status.update_mode:sub(2),
    nf.pipe,
    nf.shield,
    status.protected_count,
    nf.pipe,
    sync_icon
  )
end

-- Get minimal status (for narrow displays)
function M.get_minimal()
  local ccasp = require("ccasp")
  local status = ccasp.get_status()

  local perm_char = status.permissions_mode:sub(1, 1):upper()
  local update_char = status.update_mode:sub(1, 1):upper()
  local sync_icon = status.sync_status == "synced" and nf.sync_ok or nf.sync_warn

  return string.format("[%s%s%s%s%d%s%s]", perm_char, nf.pipe, update_char, nf.pipe, status.protected_count, nf.pipe, sync_icon)
end

-- Update statusbar (trigger redraw)
function M.update()
  vim.cmd("redrawstatus")
end

-- Get lualine component
function M.lualine()
  return {
    function()
      return M.get()
    end,
    cond = function()
      -- Only show when CCASP is open
      local ccasp = require("ccasp")
      return ccasp.state.sidebar_open
    end,
  }
end

-- Get lualine component (minimal version)
function M.lualine_mini()
  return {
    function()
      return M.get_minimal()
    end,
    cond = function()
      local ccasp = require("ccasp")
      return ccasp.state.sidebar_open
    end,
  }
end

-- Render status bar line for sidebar bottom
function M.render_line(width)
  local status = M.get_full()

  -- Truncate or pad to fit width
  if #status > width then
    status = status:sub(1, width - 3) .. "..."
  elseif #status < width then
    status = status .. string.rep(" ", width - #status)
  end

  return status
end

-- Get health check status
function M.health_check()
  local checks = {}
  local runtime = require("ccasp.runtime")
  local cwd = vim.fn.getcwd()

  -- Check each agent CLI. A missing non-default runtime is informational, not
  -- a failure, so an unused runtime never shows the bar as unhealthy.
  local active = runtime.default()
  for _, name in ipairs(runtime.order) do
    local spec = runtime.specs[name]
    local found = runtime.is_available(name)
    table.insert(checks, {
      name = spec.label .. " CLI",
      status = found or name ~= active,
      message = found and "Available" or "Not found in PATH",
    })
  end

  -- Check the active runtime's project directory
  local runtime_dir = cwd .. "/" .. runtime.spec(active).root
  local dir_check = vim.fn.isdirectory(runtime_dir) == 1
  table.insert(checks, {
    name = runtime.spec(active).root .. " directory",
    status = dir_check,
    message = dir_check and "Found" or "Not found - run ccasp init",
  })

  -- Check the active runtime's prompt directory
  local cmd_dir = runtime.prompts_dir(cwd, active)
  local cmd_check = vim.fn.isdirectory(cmd_dir) == 1
  table.insert(checks, {
    name = "Commands directory",
    status = cmd_check,
    message = cmd_check and "Found" or "Not found",
  })

  -- Check nui.nvim
  local nui_ok, _ = pcall(require, "nui.popup")
  table.insert(checks, {
    name = "nui.nvim",
    status = nui_ok,
    message = nui_ok and "Loaded" or "Not installed",
  })

  -- Check telescope
  local telescope_ok, _ = pcall(require, "telescope")
  table.insert(checks, {
    name = "telescope.nvim",
    status = telescope_ok,
    message = telescope_ok and "Loaded" or "Not installed (optional)",
  })

  -- Check toggleterm
  local toggleterm_ok, _ = pcall(require, "toggleterm")
  table.insert(checks, {
    name = "toggleterm.nvim",
    status = toggleterm_ok,
    message = toggleterm_ok and "Loaded" or "Not installed (optional)",
  })

  return checks
end

-- Format health check for display
function M.format_health_check()
  local checks = M.health_check()
  local lines = {
    "",
    "Health Check",
    string.rep("─", 38),
    "",
  }

  for _, check in ipairs(checks) do
    local icon = check.status and "✓" or "✗"
    table.insert(lines, string.format("  %s %s", icon, check.name))
    table.insert(lines, string.format("      %s", check.message))
  end

  return lines
end

return M
