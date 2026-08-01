-- ccasp/appshell/flyout.lua - Collapsible Sidebar Panel
-- Opens as floating overlay from icon rail. Reuses existing sidebar renderers.

local M = {}
local icons = require("ccasp.ui.icons")

local state = {
  win = nil,
  buf = nil,
  current_section = nil,
  item_lines = {}, -- line -> action mapping
  expanded_command = nil, -- name of currently expanded command (commands section)
  commands_search_query = "", -- active filter for commands section
}

-- Word-wrap text to max_width, returning up to max_lines lines
local function word_wrap(text, max_width, max_lines)
  if not text or text == "" then return {} end
  max_lines = max_lines or 3

  local result = {}
  local remaining = text

  while #result < max_lines and #remaining > 0 do
    if #remaining <= max_width then
      table.insert(result, remaining)
      break
    end

    -- Find last space within max_width
    local cut = max_width
    local space_pos = remaining:sub(1, max_width):match(".*()%s")
    if space_pos and space_pos > 1 then
      cut = space_pos
    end

    table.insert(result, (remaining:sub(1, cut):gsub("%s+$", "")))
    remaining = remaining:sub(cut + 1):gsub("^%s+", "")
  end

  return result
end

-- Panel header metadata per section key
local panel_headers = {
  commands      = { icon = icons.commands,  name = "Slash Commands" },
  terminal      = { icon = icons.terminal,  name = "Sessions" },
  repos         = { icon = icons.repo,      name = "Repositories" },
  panels        = { icon = icons.dashboard, name = "Panels" },
  agents        = { icon = icons.agents,    name = "Agents" },
  browse        = { icon = icons.search,    name = "Browse" },
  orchestration = { icon = icons.reload,    name = "Orchestration" },
  system        = { icon = icons.settings,  name = "System" },
  features      = { icon = icons.features,  name = "Features" },
  deploy        = { icon = icons.deploy,    name = "Deploy Configuration" },
  project       = { icon = icons.config,    name = "Project" },
}

-- Render a prominent panel header box at the top of each flyout section
local function render_panel_header(lines, section_key)
  local info = panel_headers[section_key]
  if not info then return end

  local w = 30
  local text = "  " .. info.icon .. "  " .. info.name
  local text_w = vim.fn.strdisplaywidth(text)
  local pad = math.max(0, w - text_w)

  table.insert(lines, "")
  table.insert(lines, " ┏" .. string.rep("━", w) .. "┓")
  table.insert(lines, " ┃" .. text .. string.rep(" ", pad) .. "┃")
  table.insert(lines, " ┗" .. string.rep("━", w) .. "┛")
  table.insert(lines, "")
end

-- Section content renderers
local section_renderers = {
  commands = function(lines, item_lines)
    local commands_ok, commands_mod = pcall(require, "ccasp.core.commands")
    if not commands_ok then
      table.insert(lines, "  Commands module not available")
      return
    end

    commands_mod.load_all()
    local sections = commands_mod.get_sections()
    local all_cmds = commands_mod.get_all()

    -- Active search indicator
    local query = state.commands_search_query:lower()
    if query ~= "" then
      table.insert(lines, string.format("  %s Filter: %s", icons.search, state.commands_search_query))
      table.insert(lines, "")
    end

    -- Flyout width for wrapping (approximate)
    local wrap_width = 28

    local total_count = 0
    local shown_count = 0

    for _, section in ipairs(sections) do
      -- Collect commands matching the search query
      local section_cmds = {}
      for _, cmd_name in ipairs(section.commands) do
        local cmd = all_cmds[cmd_name]
        if cmd then
          total_count = total_count + 1
          if query == ""
              or cmd_name:lower():find(query, 1, true)
              or (cmd.description or ""):lower():find(query, 1, true) then
            table.insert(section_cmds, cmd)
            shown_count = shown_count + 1
          end
        end
      end

      if #section_cmds > 0 then
        -- Section header with box-drawing
        table.insert(lines, "  ╭" .. string.rep("─", 30) .. "╮")
        table.insert(lines, "  │  " .. section.name .. string.rep(" ", math.max(0, 26 - vim.fn.strdisplaywidth(section.name))) .. "  │")
        table.insert(lines, "  ╰" .. string.rep("─", 30) .. "╯")

        -- Command entries (name only; description shown on expand)
        for _, cmd in ipairs(section_cmds) do
          local desc = cmd.description or ""

          table.insert(lines, "    /" .. cmd.name)
          item_lines[#lines] = { action = "cmd_toggle_preview", name = cmd.name, path = cmd.path, description = desc }

          -- Expanded description (inline preview)
          if state.expanded_command == cmd.name and desc ~= "" then
            local wrapped = word_wrap(desc, wrap_width, 3)
            for _, wline in ipairs(wrapped) do
              table.insert(lines, "      ┊ " .. wline)
              -- Description lines are NOT actionable (nav skips them)
            end
          end
        end
        table.insert(lines, "")
      end
    end

    -- Footer counter
    table.insert(lines, "  " .. string.rep("─", 30))
    if query ~= "" then
      table.insert(lines, string.format("  %d / %d commands", shown_count, total_count))
    else
      table.insert(lines, string.format("  %d commands", total_count))
    end
    table.insert(lines, "")
    table.insert(lines, "  [Enter]run [p]preview [y]copy [e]edit [/]filter")
  end,

  terminal = function(lines, item_lines)
    -- ── Layers Section ──
    local layers_ok, layers = pcall(require, "ccasp.layers")
    if layers_ok and layers.is_initialized() then
      table.insert(lines, "  " .. icons.dashboard .. " Layers")
      table.insert(lines, "  " .. string.rep("─", 30))
      table.insert(lines, "")

      local all_layers = layers.list()
      for _, layer in ipairs(all_layers) do
        local marker = layer.is_active and icons.arrow_right or " "
        local line = string.format("  %s %s (%d)", marker, layer.name, layer.session_count)
        table.insert(lines, line)
        item_lines[#lines] = { action = "switch_layer", layer_num = layer.num }
      end

      table.insert(lines, "")

      -- Layer actions
      local layer_actions = {
        { icon = icons.maximize, label = "New Layer", action = "layer_new" },
        { icon = icons.edit,     label = "Rename Layer", action = "layer_rename" },
        { icon = icons.close,    label = "Close Layer", action = "layer_close" },
      }
      for _, a in ipairs(layer_actions) do
        table.insert(lines, "  " .. a.icon .. " " .. a.label)
        item_lines[#lines] = { action = a.action }
      end

      table.insert(lines, "")
    end

    -- ── Layout Templates Section ──
    local tmpl_ok, tmpl = pcall(require, "ccasp.layout_templates")
    if tmpl_ok then
      table.insert(lines, "  " .. icons.layout .. " Layout Templates")
      table.insert(lines, "  " .. string.rep("─", 30))
      table.insert(lines, "")

      local all_templates = tmpl.list()
      if #all_templates > 0 then
        for _, t in ipairs(all_templates) do
          local marker = t.is_default and icons.star_filled or " "
          local line = string.format("  %s %s (%dL/%dS)", marker, t.name, t.layer_count, t.session_count)
          table.insert(lines, line)
          item_lines[#lines] = { action = "load_template", template_name = t.name }
        end
      else
        table.insert(lines, "    (no saved templates)")
      end
      table.insert(lines, "")

      local tmpl_actions = {
        { icon = icons.save,        label = "Save Current Layout",  action = "save_template" },
        { icon = icons.edit,         label = "Rename Template",      action = "rename_template" },
        { icon = icons.star_filled,  label = "Set Default Template", action = "set_default_template" },
        { icon = icons.delete,       label = "Delete Template",      action = "delete_template" },
      }
      for _, a in ipairs(tmpl_actions) do
        table.insert(lines, "  " .. a.icon .. " " .. a.label)
        item_lines[#lines] = { action = a.action }
      end

      table.insert(lines, "")
    end

    -- ── Terminal Sessions Section ──
    table.insert(lines, "  " .. icons.terminal .. " Terminal Sessions")
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")

    local sessions_ok, sessions = pcall(require, "ccasp.sessions")
    if sessions_ok then
      local all = sessions.list()
      local count = #all

      table.insert(lines, "  Sessions: " .. count .. "/" .. 8)
      table.insert(lines, "  Layout: " .. sessions.get_layout())
      table.insert(lines, "")

      -- List active sessions
      for i, session in ipairs(all) do
        local status_icon = session.claude_running and icons.claude_on or icons.claude_off
        local primary = session.is_primary and (" " .. icons.primary) or ""
        local line = string.format("  %s %s%s", status_icon, session.name, primary)
        table.insert(lines, line)
        item_lines[#lines] = { action = "focus_session", id = session.id }
      end

      table.insert(lines, "")
    end

    -- Session actions
    table.insert(lines, "  " .. string.rep("─", 30))

    -- New Session action
    table.insert(lines, "  " .. icons.maximize .. " New Session")
    item_lines[#lines] = { action = "new_session" }

    -- Recent repos (indented under New Session for quick-launch)
    local repo_ok, repo_storage = pcall(require, "ccasp.repo_launcher.storage")
    if repo_ok then
      local ccasp_main = require("ccasp")
      local recent = repo_storage.get_recent(5)
      if #recent > 0 then
        table.insert(lines, "    Recent repos:")
        for _, repo in ipairs(recent) do
          table.insert(lines, "      " .. icons.repo .. " " .. ccasp_main.mask_name(repo.name))
          item_lines[#lines] = { action = "new_session_at_repo", path = repo.path, name = repo.name }
        end
      end
    end

    -- New session at custom path (opens path input dialog)
    table.insert(lines, "  " .. icons.repo .. " New Claude Repository Session")
    item_lines[#lines] = { action = "open_path_dialog" }

    -- New Happy session (opens repo picker, launches Happy instead of Claude)
    table.insert(lines, "  " .. icons.terminal .. " New Happy Repository Session")
    item_lines[#lines] = { action = "new_happy_session" }

    -- Saved Notes
    table.insert(lines, "")
    table.insert(lines, "  " .. icons.save .. " Saved Notes")
    item_lines[#lines] = { action = "open_saved_notes" }

    local remaining_actions = {
      { icon = icons.edit,     label = "Rename Current Session", action = "session_rename" },
      { icon = icons.reorder,  label = "Reorder Sessions", action = "session_reorder" },
      { icon = icons.minimize, label = "Minimize Current", action = "session_minimize" },
      { icon = icons.reload,   label = "Restore Minimized", action = "session_restore" },
      { icon = icons.layout,   label = "Resize All Panels", action = "session_rebuild_layout" },
      { icon = icons.close,    label = "Close All Sessions", action = "session_close_all" },
    }
    for _, a in ipairs(remaining_actions) do
      table.insert(lines, "  " .. a.icon .. " " .. a.label)
      item_lines[#lines] = { action = a.action }
    end
  end,

  repos = function(lines, item_lines)
    local storage_ok, storage = pcall(require, "ccasp.repo_launcher.storage")
    if not storage_ok then
      table.insert(lines, "  Repo launcher not available")
      return
    end

    local nf_ok, nf = pcall(require, "ccasp.ui.icons")
    local pin_icon = nf_ok and nf.pin or "*"
    local repo_icon = nf_ok and nf.repo or ">"
    local clock_icon = nf_ok and nf.clock or "@"
    local ccasp_main = require("ccasp")

    -- Pinned repos
    local pinned = storage.get_pinned()
    if #pinned > 0 then
      table.insert(lines, "  " .. pin_icon .. " Pinned")
      for _, repo in ipairs(pinned) do
        table.insert(lines, "    " .. ccasp_main.mask_name(repo.name))
        item_lines[#lines] = { action = "open_repo", path = repo.path, name = repo.name }
      end
      table.insert(lines, "")
    end

    -- Recent repos (top 5, excluding pinned)
    local recent = storage.get_recent(10)
    local shown = 0
    table.insert(lines, "  " .. clock_icon .. " Recent")
    for _, repo in ipairs(recent) do
      if not repo.pinned and shown < 5 then
        table.insert(lines, "    " .. ccasp_main.mask_name(repo.name))
        item_lines[#lines] = { action = "open_repo", path = repo.path, name = repo.name }
        shown = shown + 1
      end
    end

    if shown == 0 then
      table.insert(lines, "    (no recent repos)")
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", 30))

    -- Action items
    table.insert(lines, "  Open new path...")
    item_lines[#lines] = { action = "open_path_dialog" }

    table.insert(lines, "  Browse all repos...")
    item_lines[#lines] = { action = "open_browser" }
  end,

  panels = function(lines, item_lines)
    local panels = {
      { icon = icons.dashboard, label = "Dashboard", action = "dashboard" },
      { icon = icons.settings,  label = "Control Panel", action = "control" },
      { icon = icons.todo,      label = "Todo List", action = "todos" },
      { icon = icons.hooks,     label = "Hook Manager", action = "hooks" },
      { icon = icons.minimize,  label = "Taskbar", action = "taskbar" },
      { icon = icons.search,    label = "Site Intelligence", action = "site_intel" },
    }
    for _, p in ipairs(panels) do
      table.insert(lines, "  " .. p.icon .. " " .. p.label)
      item_lines[#lines] = { action = p.action }
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "  " .. icons.globe .. " Open in Browser")
    table.insert(lines, "")

    local browser_actions = {
      { icon = icons.globe, label = "Feature Audit", action = "browser_feature_audit" },
      { icon = icons.globe, label = "Dev Scan", action = "browser_dev_scan" },
      { icon = icons.globe, label = "Full Dashboard", action = "browser_dashboard" },
    }
    for _, b in ipairs(browser_actions) do
      table.insert(lines, "  " .. b.icon .. " " .. b.label)
      item_lines[#lines] = { action = b.action }
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "  " .. icons.help .. " Prompt Injector")
    table.insert(lines, "")

    local pi_actions = {
      { icon = icons.enabled,  label = "Toggle Prompt Injector", action = "prompt_injector" },
      { icon = icons.ai,       label = "Quick Enhance", action = "quick_enhance" },
      { icon = icons.reload,   label = "Toggle Auto-Enhance", action = "auto_enhance" },
    }
    for _, a in ipairs(pi_actions) do
      table.insert(lines, "  " .. a.icon .. " " .. a.label)
      item_lines[#lines] = { action = a.action }
    end
  end,

  agents = function(lines, item_lines)
    local actions = {
      { icon = icons.agents,  label = "Open Agent Grid", action = "grid" },
      { icon = icons.reload,  label = "Restart All Agents", action = "restart_all" },
      { icon = icons.close,   label = "Kill All Agents", action = "kill_all" },
    }
    for _, a in ipairs(actions) do
      table.insert(lines, "  " .. a.icon .. " " .. a.label)
      item_lines[#lines] = { action = a.action }
    end
  end,

  browse = function(lines, item_lines)
    local actions = {
      { icon = icons.commands, label = "Commands (Telescope)", action = "commands" },
      { icon = icons.assets,   label = "Skills (Telescope)", action = "skills" },
      { icon = icons.todo,     label = "Todos (Telescope)", action = "todos_telescope" },
    }
    for _, a in ipairs(actions) do
      table.insert(lines, "  " .. a.icon .. " " .. a.label)
      item_lines[#lines] = { action = a.action }
    end
  end,

  orchestration = function(lines, item_lines)
    -- Read current settings from tech-stack.json
    local config_ok, config = pcall(require, "ccasp.config")
    local orch = {}
    if config_ok then
      local ts = config.load_tech_stack()
      if ts then orch = ts.orchestration or {} end
    end
    local parallel = orch.parallel or {}
    local compacting = orch.compacting or {}

    table.insert(lines, "  Parallel Agents")
    table.insert(lines, "    Tasks/phase:   " .. (parallel.maxTasks or 2))
    table.insert(lines, "    Plans/roadmap:  " .. (parallel.maxPlans or 2))
    table.insert(lines, "    Roadmaps/epic:  " .. (parallel.maxRoadmaps or 2))
    table.insert(lines, "")
    table.insert(lines, "  Context Compacting")
    table.insert(lines, "    Compact at:     " .. (compacting.remainingThreshold or 40) .. "% remaining")
    table.insert(lines, "    Poll interval:  " .. (compacting.pollIntervalSec or 120) .. "s")
    table.insert(lines, "    After launch:   " .. (compacting.compactAfterLaunch ~= false and "Yes" or "No"))
    table.insert(lines, "    After poll:     " .. (compacting.compactAfterPoll ~= false and "Yes" or "No"))
    table.insert(lines, "")

    table.insert(lines, "  " .. string.rep("─", 30))
    local actions = {
      { icon = icons.settings, label = "Open Settings (CLI)", action = "orchestration_settings" },
      { icon = icons.reload,   label = "Refresh", action = "refresh" },
    }
    for _, a in ipairs(actions) do
      table.insert(lines, "  " .. a.icon .. " " .. a.label)
      item_lines[#lines] = { action = a.action }
    end
  end,

  system = function(lines, item_lines)
    local actions = {
      { icon = icons.save,    label = "Save Settings", action = "save_settings" },
      { icon = icons.reload,  label = "Detect Tech Stack", action = "detect_stack" },
      { icon = icons.reload,  label = "Refresh", action = "refresh" },
    }
    for _, a in ipairs(actions) do
      table.insert(lines, "  " .. a.icon .. " " .. a.label)
      item_lines[#lines] = { action = a.action }
    end
  end,

  features = function(lines, item_lines)
    -- Load current tech stack for toggle states
    local config_ok, config = pcall(require, "ccasp.config")
    local tech_stack = {}
    if config_ok then
      tech_stack = config.load_tech_stack() or {}
    end

    local categories = {
      {
        name = "Core Features",
        items = {
          { label = "Token Management", path = "tokenManagement.enabled" },
          { label = "Happy Mode", path = "happyMode.enabled" },
          { label = "Phased Development", path = "phasedDevelopment.enabled" },
          { label = "Agents", path = "agents.enabled" },
        },
      },
      {
        name = "Hooks & Automation",
        items = {
          { label = "Hooks Enabled", path = "hooks.enabled" },
          { label = "Auto Commit", path = "hooks.autoCommit" },
          { label = "Git Tracking", path = "hooks.gitTracking" },
          { label = "Decision Logging", path = "hooks.decisionLogging" },
        },
      },
      {
        name = "Integrations",
        items = {
          { label = "Template Sync", path = "sync.enabled" },
          { label = "GitHub Sync", path = "versionControl.autoSync" },
          { label = "Deployment", path = "deployment.enabled" },
        },
      },
    }

    for _, cat in ipairs(categories) do
      table.insert(lines, "  " .. cat.name)
      for _, feat in ipairs(cat.items) do
        local enabled = config_ok and config.get_nested(tech_stack, feat.path)
        local toggle_icon = enabled and icons.enabled or icons.disabled
        local status = enabled and "ON" or "OFF"
        table.insert(lines, "  " .. toggle_icon .. " " .. feat.label .. "  " .. status)
        item_lines[#lines] = { action = "toggle_feature", path = feat.path, name = feat.label }
      end
      table.insert(lines, "")
    end

    -- Template Sync status indicator
    local sync_cfg = config_ok and config.get_nested(tech_stack, "sync") or {}
    if sync_cfg and type(sync_cfg) == "table" then
      table.insert(lines, "  Template Sync Status")
      local sync_version = sync_cfg.ccaspVersionAtSync or "unknown"
      local sync_method = sync_cfg.method or "symlink"
      local last_sync = sync_cfg.lastSyncAt
      local sync_time = "never"
      if last_sync and type(last_sync) == "string" then
        -- Extract time portion from ISO string
        local t = last_sync:match("T(%d+:%d+)")
        if t then sync_time = t end
      end
      local status_icon = sync_cfg.enabled and icons.sync_ok or icons.sync_warn
      table.insert(lines, "  " .. (status_icon or "~") .. " v" .. sync_version .. " at " .. sync_time .. " (" .. sync_method .. ")")
      table.insert(lines, "")
      table.insert(lines, "  " .. (icons.reload or "R") .. " Recompile Templates")
      item_lines[#lines] = { action = "recompile_templates" }
      table.insert(lines, "")
    end

    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "  " .. icons.check .. " Enable All")
    item_lines[#lines] = { action = "features_enable_all" }
    table.insert(lines, "  " .. icons.close .. " Disable All")
    item_lines[#lines] = { action = "features_disable_all" }
  end,

  project = function(lines, item_lines)
    local storage_ok, proj_storage = pcall(require, "ccasp.project_config.storage")
    if storage_ok then
      local cfg = proj_storage.load()
      local mode_labels = {
        commercial_saas = "Commercial SaaS",
        commercial_single = "Single-Tenant",
        personal = "Personal",
      }
      table.insert(lines, "  Mode: " .. (mode_labels[cfg.app_mode] or "Unknown"))

      local total, enabled = 0, 0
      for _, v in pairs(cfg.features) do
        total = total + 1
        if v then enabled = enabled + 1 end
      end
      table.insert(lines, "  Features: " .. enabled .. "/" .. total .. " enabled")

      table.insert(lines, "")

      if cfg.app_mode == "personal" then
        table.insert(lines, "  Disabled: skipped entirely")
      else
        table.insert(lines, "  Disabled: stubbed (CCASP:STUB)")
      end
    else
      table.insert(lines, "  (config module not available)")
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. icons.settings .. " Open Configuration Panel")
    item_lines[#lines] = { action = "project_config" }
  end,

  -- Deploy configuration panel
  deploy = function(lines, item_lines)
    local config = require("ccasp.config")
    local data = config.load_deploy_config()

    -- Helper to render a toggle line
    local function toggle_line(label, path, shortcut, indent)
      indent = indent or "  "
      local val = config.get_nested(data, path)
      local icon = val and icons.enabled or icons.disabled
      local status = val and "[ON ]" or "[OFF]"
      local pad = string.rep(" ", math.max(1, 20 - #label))
      table.insert(lines, indent .. icon .. " " .. label .. pad .. status .. "  (" .. shortcut .. ")")
      item_lines[#lines] = { action = "deploy_toggle", path = path, label = label }
    end

    -- Frontend section
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "  " .. icons.deploy .. "  Frontend (Cloudflare)")
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")
    toggle_line("Clean dist/", "frontend.cleanDist", "d")
    toggle_line("Full rebuild", "frontend.fullRebuild", "r")
    toggle_line("Cache busting", "frontend.cacheBusting", "c")
    toggle_line("Verbose output", "frontend.verbose", "v")
    table.insert(lines, "")

    -- Backend section
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "  " .. icons.settings .. "  Backend (Railway)")
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")
    toggle_line("Git status check", "backend.preDeployGitCheck", "g")

    -- Health check URL (non-toggle, display only)
    local hc_url = config.get_nested(data, "backend.healthCheckUrl") or "not set"
    table.insert(lines, "  " .. icons.config .. " Health URL: " .. hc_url)
    table.insert(lines, "")

    -- Verification section
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "  " .. icons.search .. "  Verification")
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")
    toggle_line("SHA verify", "verification.shaVerification", "s")
    toggle_line("Notifications", "notifications.enabled", "n")
    toggle_line("Auto-rollback", "rollback.autoRollbackOnShaFailure", "a")
    table.insert(lines, "")

    -- Production URL display
    local prod_url = config.get_nested(data, "verification.productionUrl") or "not set"
    table.insert(lines, "  " .. icons.config .. " Prod URL: " .. prod_url)
    local delay = config.get_nested(data, "verification.propagationDelay") or 15
    table.insert(lines, "  " .. icons.config .. " CDN delay: " .. delay .. "s")
    table.insert(lines, "")

    -- Actions
    table.insert(lines, "  " .. string.rep("─", 30))
    table.insert(lines, "")
    table.insert(lines, "  " .. icons.commands .. " [E] Edit config file")
    item_lines[#lines] = { action = "deploy_edit" }
    table.insert(lines, "  " .. icons.deploy .. " [D] Deploy now")
    item_lines[#lines] = { action = "deploy_now" }
    table.insert(lines, "  " .. icons.search .. " [P] Preview command")
    item_lines[#lines] = { action = "deploy_preview" }
    table.insert(lines, "  " .. icons.reload .. " [R] Reset defaults")
    item_lines[#lines] = { action = "deploy_reset" }
  end,
}

-- Render flyout content for current section
local function render()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  local lines = {}
  state.item_lines = {}

  -- Prominent panel header
  render_panel_header(lines, state.current_section)

  local renderer = section_renderers[state.current_section]
  if renderer then
    renderer(lines, state.item_lines)
  else
    table.insert(lines, "  Unknown section: " .. tostring(state.current_section))
  end

  local ns = vim.api.nvim_create_namespace("ccasp_flyout")

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  -- Highlights
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for i, line in ipairs(lines) do
    if line:match("^ ┏") or line:match("^ ┗") then
      -- Panel header border (heavy box)
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "CcaspFlyoutPanelBorder", i - 1, 0, -1)
    elseif line:match("^ ┃") then
      -- Panel header name (heavy box)
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "CcaspFlyoutPanelName", i - 1, 0, -1)
    elseif line:match("^  [─]+$") then
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "CcaspSeparator", i - 1, 0, -1)
    elseif line:match("^  ╭") or line:match("^  ╰") then
      -- Box-drawing borders (commands section)
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "Comment", i - 1, 0, -1)
    elseif line:match("^  │") then
      -- Section name inside box (commands section)
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "CcaspFlyoutTitle", i - 1, 0, -1)
    elseif line:match("^      ┊") then
      -- Expanded description line (commands section)
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "Comment", i - 1, 0, -1)
    elseif line:match("^    Recent repos:") then
      -- Recent repos sub-header (terminal section)
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "Comment", i - 1, 0, -1)
    elseif line:match("^    /") then
      -- Command name line (commands section) - highlight name vs description
      local dash_pos = line:find(" %- ")
      local name_end = dash_pos and (dash_pos - 1) or #line
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "CcaspFlyoutItem", i - 1, 4, name_end)
      if dash_pos then
        pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "Comment", i - 1, dash_pos + 2, -1)
      end
    elseif line:match("Filter:") then
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "DiagnosticInfo", i - 1, 0, -1)
    elseif line:match("commands$") then
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "Comment", i - 1, 0, -1)
    elseif line:match("^  %[") then
      -- Keybinding hint footer
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "Comment", i - 1, 0, -1)
    elseif state.item_lines[i] then
      pcall(vim.api.nvim_buf_add_highlight, state.buf, ns, "CcaspFlyoutItem", i - 1, 0, -1)
    end
  end
end

-- Execute action at cursor line
local function execute_action_at_cursor()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end

  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local item = state.item_lines[cursor[1]]
  if not item then return end

  M.execute_action(item)
end

-- Helper: close flyout, exit terminal mode if needed, then run a function.
-- Used for actions that open modals (rename, color picker, etc.) from the flyout.
-- The WinEnter handler auto-enters terminal mode when the flyout closes and focus
-- lands on a terminal window, so we must exit terminal mode before opening a modal.
-- NOTE: stopinsert only exits INSERT mode, NOT terminal mode ("t"). For terminal
-- mode we must use <C-\><C-n> via feedkeys. Since feedkeys is async, we schedule
-- fn() on the NEXT tick so the mode change takes effect first.
local function close_and_run_modal(fn)
  M.close()
  vim.schedule(function()
    local mode = vim.api.nvim_get_mode().mode
    if mode == "t" then
      -- Exit terminal mode with <C-\><C-n>, then schedule fn on next tick
      local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
      vim.api.nvim_feedkeys(esc, "n", false)
      vim.schedule(fn)
    elseif mode == "i" then
      vim.cmd("stopinsert")
      fn()
    else
      fn()
    end
  end)
end

-- Execute a flyout action
function M.execute_action(item)
  local ccasp = require("ccasp")
  local sessions = require("ccasp.sessions")

  local action_handlers = {
    -- Commands section
    cmd_toggle_preview = function()
      if state.expanded_command == item.name then
        state.expanded_command = nil
      else
        state.expanded_command = item.name
      end
      render()
      -- Re-position cursor on the toggled command
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        for line_nr, line_item in pairs(state.item_lines) do
          if line_item.name == item.name then
            pcall(vim.api.nvim_win_set_cursor, state.win, { line_nr, 0 })
            break
          end
        end
      end
    end,
    cmd_inject = function()
      local cmd_name = item.name
      M.close()
      vim.schedule(function()
        local sess = require("ccasp.sessions")
        local active = sess.get_active()
        if active and active.bufnr and vim.api.nvim_buf_is_valid(active.bufnr) then
          -- Focus the session window and enter terminal mode
          if active.winid and vim.api.nvim_win_is_valid(active.winid) then
            vim.api.nvim_set_current_win(active.winid)
          end
          local job_id = vim.b[active.bufnr].terminal_job_id
          if job_id and job_id > 0 then
            -- Inject into prompt without \n so user can review/add args before submitting
            vim.fn.chansend(job_id, "/" .. cmd_name)
            vim.cmd("startinsert")
            return
          end
        end
        vim.notify("No active Claude session to send command", vim.log.levels.WARN)
      end)
    end,
    cmd_copy = function()
      vim.fn.setreg("+", "/" .. item.name)
      vim.notify("Copied: /" .. item.name, vim.log.levels.INFO)
    end,
    cmd_edit = function()
      local path = item.path
      M.close()
      vim.schedule(function()
        vim.cmd("edit " .. vim.fn.fnameescape(path))
      end)
    end,

    -- Terminal sessions
    new_session = function()
      -- Don't close flyout — it's a float that doesn't interfere with splits.
      -- Closing it would leave the wide left spacer visible as a blank area.
      -- The user can keep interacting with the flyout; Tab goes to the new session.
      vim.schedule(function()
        require("ccasp.runtime_picker").open({
          prompt = "New session type",
          on_select = function(runtime_name)
            sessions.spawn(nil, runtime_name)
            -- Re-render and re-focus flyout after spawn settles
            vim.defer_fn(function()
              if state.win and vim.api.nvim_win_is_valid(state.win) then
                render()
                vim.api.nvim_set_current_win(state.win)
              end
            end, 1000)
          end,
        })
      end)
    end,
    new_session_at_repo = function()
      -- Launch a new session at the selected repo path, asking which agent
      local repo_path = item.path
      M.close()
      vim.schedule(function()
        require("ccasp.repo_launcher").open_repo_pick(repo_path)
      end)
    end,
    new_repo_session = function()
      -- Close flyout, exit terminal mode, prompt for path inline, then spawn.
      -- Avoids the complex float-within-float flow that causes focus/race issues.
      M.close()
      vim.schedule(function()
        local mode = vim.api.nvim_get_mode().mode
        if mode == "t" or mode == "i" then
          vim.cmd("stopinsert")
        end
        vim.ui.input({ prompt = "Repository path: " }, function(input)
          if not input or input == "" then return end
          local path = vim.fn.expand(input)
          if vim.fn.isdirectory(path) == 0 then
            vim.notify("Not a valid directory: " .. require("ccasp").mask_path(path), vim.log.levels.ERROR)
            return
          end
          vim.schedule(function()
            local m = vim.api.nvim_get_mode().mode
            if m == "t" or m == "i" then
              vim.cmd("stopinsert")
            end
            require("ccasp.repo_launcher").open_repo_pick(path)
          end)
        end)
      end)
    end,
    new_happy_session = function()
      -- Close flyout, open the Happy repo picker
      close_and_run_modal(function()
        require("ccasp.repo_launcher").open_happy_picker()
      end)
    end,
    focus_session = function()
      M.close()
      vim.schedule(function() sessions.focus(item.id) end)
    end,
    session_rename = function()
      local primary = sessions.get_primary()
      if not primary then return end
      close_and_run_modal(function()
        sessions.rename(primary.id)
      end)
    end,
    session_minimize = function()
      local primary = sessions.get_primary()
      if not primary then return end
      M.close()
      vim.schedule(function() sessions.minimize(primary.id) end)
    end,
    session_restore = function()
      M.close()
      vim.schedule(function() sessions.restore_all() end)
    end,
    session_reorder = function()
      close_and_run_modal(function()
        sessions.show_reorder_modal()
      end)
    end,
    session_rebuild_layout = function()
      M.close()
      vim.schedule(function() sessions.rebuild() end)
    end,
    session_close_all = function()
      M.close()
      vim.schedule(function() sessions.close_all() end)
    end,

    -- Layer management
    switch_layer = function()
      -- Close flyout FIRST so layer switch reattaches windows into the
      -- content area, not the narrow flyout float.
      M.close()
      vim.schedule(function()
        local layers_ok, layers = pcall(require, "ccasp.layers")
        if layers_ok then
          layers.switch_to(item.layer_num)
        end
      end)
    end,
    layer_new = function()
      close_and_run_modal(function()
        local layers_ok, layers = pcall(require, "ccasp.layers")
        if layers_ok then layers.show_new_modal() end
      end)
    end,
    layer_rename = function()
      close_and_run_modal(function()
        local layers_ok, layers = pcall(require, "ccasp.layers")
        if layers_ok then layers.show_rename_modal() end
      end)
    end,
    layer_close = function()
      close_and_run_modal(function()
        local layers_ok, layers = pcall(require, "ccasp.layers")
        if layers_ok then layers.show_close_modal() end
      end)
    end,

    -- Layout templates
    save_template = function()
      close_and_run_modal(function()
        require("ccasp.layout_templates").show_save_modal()
      end)
    end,
    load_template = function()
      close_and_run_modal(function()
        require("ccasp.layout_templates").apply(item.template_name)
      end)
    end,
    rename_template = function()
      close_and_run_modal(function()
        require("ccasp.layout_templates").show_rename_modal()
      end)
    end,
    set_default_template = function()
      close_and_run_modal(function()
        require("ccasp.layout_templates").show_set_default_modal()
      end)
    end,
    delete_template = function()
      close_and_run_modal(function()
        require("ccasp.layout_templates").show_delete_modal()
      end)
    end,

    -- Repo launcher
    open_repo = function()
      close_and_run_modal(function()
        require("ccasp.repo_launcher").open_repo_pick(item.path)
      end)
    end,
    open_path_dialog = function()
      close_and_run_modal(function()
        require("ccasp.repo_launcher").open_launcher()
      end)
    end,
    open_browser = function()
      close_and_run_modal(function()
        require("ccasp.repo_launcher").open_browser()
      end)
    end,

    -- Saved Notes
    open_saved_notes = function()
      close_and_run_modal(function()
        require("ccasp.saved_notes").open_browser()
      end)
    end,

    -- Panels
    dashboard = function()
      if ccasp.panels and ccasp.panels.dashboard then ccasp.panels.dashboard.open() end
    end,
    control = function()
      if ccasp.panels and ccasp.panels.control then ccasp.panels.control.toggle() end
    end,
    hooks = function()
      if ccasp.panels and ccasp.panels.hooks then ccasp.panels.hooks.open() end
    end,
    taskbar = function()
      if ccasp.taskbar then ccasp.taskbar.show_picker() end
    end,
    site_intel = function()
      if ccasp.panels and ccasp.panels.site_intel then ccasp.panels.site_intel.toggle() end
    end,
    todos = function()
      close_and_run_modal(function()
        local ok, todos_panel = pcall(require, "ccasp.panels.todos")
        if ok and todos_panel then
          todos_panel.open()
        else
          vim.notify("CCASP: failed to load todo panel: " .. tostring(todos_panel), vim.log.levels.ERROR)
        end
      end)
    end,

    -- Prompt Injector
    prompt_injector = function()
      if ccasp.prompt_injector then ccasp.prompt_injector.toggle() end
    end,
    quick_enhance = function()
      if ccasp.prompt_injector then ccasp.prompt_injector.quick_enhance() end
    end,
    auto_enhance = function()
      if ccasp.prompt_injector and ccasp.prompt_injector.toggle_auto_enhance then
        ccasp.prompt_injector.toggle_auto_enhance()
      end
    end,

    -- Agents
    grid = function()
      if ccasp.agents then ccasp.agents.open_grid() end
    end,
    restart_all = function()
      if ccasp.agents then ccasp.agents.restart_all() end
    end,
    kill_all = function()
      if ccasp.agents then ccasp.agents.kill_all() end
    end,

    -- Browser (Site Intel Dashboard)
    browser_feature_audit = function()
      require("ccasp.browser").open_dashboard("feature-audit")
    end,
    browser_dev_scan = function()
      require("ccasp.browser").open_dashboard("dev-scan")
    end,
    browser_dashboard = function()
      require("ccasp.browser").open_dashboard()
    end,

    -- Browse
    commands = function()
      M.close()
      if ccasp.panels and ccasp.panels.commands then
        ccasp.panels.commands.toggle()
      elseif ccasp.telescope then
        ccasp.telescope.commands()
      end
    end,
    skills = function()
      M.close()
      if ccasp.telescope then ccasp.telescope.skills() end
    end,
    todos_telescope = function()
      M.close()
      vim.schedule(function()
        require("ccasp.todos_telescope").pick()
      end)
    end,

    -- Orchestration
    orchestration_settings = function()
      M.close()
      vim.fn.termopen("ccasp settings orchestration", { cwd = vim.fn.getcwd() })
    end,

    -- System
    save_settings = function()
      if ccasp.core and ccasp.core.settings then
        ccasp.core.settings.save()
        vim.notify("Settings saved", vim.log.levels.INFO)
      end
    end,
    detect_stack = function()
      vim.cmd("!ccasp detect-stack")
    end,
    refresh = function()
      render()
      vim.notify("Refreshed", vim.log.levels.INFO)
    end,

    -- Template sync recompile
    recompile_templates = function()
      vim.notify("CCASP: Recompiling templates...", vim.log.levels.INFO)
      vim.fn.jobstart("ccasp template-sync --recompile", {
        on_exit = function(_, code)
          if code == 0 then
            vim.schedule(function()
              vim.notify("CCASP: Templates recompiled", vim.log.levels.INFO)
              render()
            end)
          else
            vim.schedule(function()
              vim.notify("CCASP: Recompile failed (exit " .. code .. ")", vim.log.levels.ERROR)
            end)
          end
        end,
      })
    end,

    -- Feature toggles
    toggle_feature = function()
      local config_ok, config = pcall(require, "ccasp.config")
      if not config_ok then return end
      local tech_stack = config.load_tech_stack()
      local new_value = config.toggle_nested(tech_stack, item.path)
      config.save_tech_stack(tech_stack)
      vim.notify(
        string.format("CCASP: %s %s", item.name, new_value and "enabled" or "disabled"),
        vim.log.levels.INFO
      )
    end,
    features_enable_all = function()
      local config_ok, config = pcall(require, "ccasp.config")
      if not config_ok then return end
      local features = require("ccasp.panels.features")
      features.set_all(true)
    end,
    features_disable_all = function()
      local config_ok, config = pcall(require, "ccasp.config")
      if not config_ok then return end
      local features = require("ccasp.panels.features")
      features.set_all(false)
    end,

    -- Project configuration
    project_config = function()
      close_and_run_modal(function()
        require("ccasp.project_config").open()
      end)
    end,

    -- Deploy: toggle a boolean config option
    deploy_toggle = function()
      local config = require("ccasp.config")
      local data = config.load_deploy_config()
      config.toggle_nested(data, item.path)
      config.save_deploy_config(data)
      render()
    end,

    -- Deploy: open config file in editor
    deploy_edit = function()
      local config = require("ccasp.config")
      local path = config.get_path("deploy_config")
      if path then
        M.close()
        vim.schedule(function()
          vim.cmd("edit " .. vim.fn.fnameescape(path))
        end)
      end
    end,

    -- Deploy: inject /deploy-full into active session
    deploy_now = function()
      M.close()
      vim.schedule(function()
        local sess = require("ccasp.sessions")
        local active = sess.get_active()
        if active and active.bufnr and vim.api.nvim_buf_is_valid(active.bufnr) then
          local chan = vim.api.nvim_buf_get_var(active.bufnr, "terminal_job_id")
          if chan then
            vim.api.nvim_chan_send(chan, "/deploy-full\n")
          end
        end
      end)
    end,

    -- Deploy: show what the deploy command would do
    deploy_preview = function()
      local config = require("ccasp.config")
      local data = config.load_deploy_config()
      local preview = { "", "  Deploy Preview:", "  " .. string.rep("─", 28), "" }

      local function step(enabled, label)
        local icon_str = enabled and icons.enabled or icons.disabled
        table.insert(preview, "  " .. icon_str .. " " .. label)
      end

      step(config.get_nested(data, "frontend.cleanDist"), "rm -rf dist/")
      step(config.get_nested(data, "frontend.fullRebuild"), "rm -rf node_modules/ && npm install")
      step(true, config.get_nested(data, "frontend.buildCommand") or "npm run build")
      step(config.get_nested(data, "frontend.cacheBusting"), "Cache-busting headers")
      step(config.get_nested(data, "frontend.verbose"), "Verbose output")
      step(config.get_nested(data, "backend.preDeployGitCheck"), "Pre-deploy git check")
      step(config.get_nested(data, "verification.shaVerification"), "SHA verification")
      step(config.get_nested(data, "notifications.enabled"), "Notifications")
      step(config.get_nested(data, "rollback.autoRollbackOnShaFailure"), "Auto-rollback on SHA fail")

      table.insert(preview, "")
      table.insert(preview, "  Project: " .. (config.get_nested(data, "frontend.project") or "eroland-me"))
      table.insert(preview, "  Output:  " .. (config.get_nested(data, "frontend.outputDir") or "dist"))
      table.insert(preview, "")

      -- Show in a temporary float
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, preview)
      vim.bo[buf].modifiable = false
      vim.bo[buf].bufhidden = "wipe"

      local width = 40
      local height = #preview
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = " Deploy Preview ",
        title_pos = "center",
      })

      vim.keymap.set("n", "q", function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end, { buffer = buf, nowait = true })
      vim.keymap.set("n", "<Esc>", function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end, { buffer = buf, nowait = true })
    end,

    -- Deploy: reset config to defaults
    deploy_reset = function()
      local config = require("ccasp.config")
      local defaults = config.get_deploy_defaults()
      config.save_deploy_config(defaults)
      render()
    end,
  }

  local handler = action_handlers[item.action]
  if handler then
    handler()
    -- Re-render after action (session list may have changed)
    -- Skip for commands actions that already call render() themselves
    local skip_rerender = item.action == "cmd_toggle_preview"
        or item.action == "cmd_inject"
        or item.action == "cmd_copy"
        or item.action == "cmd_edit"
        or item.action == "new_session"
        or item.action == "focus_session"
        or item.action == "session_rename"
        or item.action == "session_reorder"
        or item.action == "session_minimize"
        or item.action == "session_restore"
        or item.action == "session_rebuild_layout"
        or item.action == "session_close_all"
        or item.action == "new_session_at_repo"
        or item.action == "new_repo_session"
        or item.action == "new_happy_session"
        or item.action == "open_repo"
        or item.action == "open_path_dialog"
        or item.action == "open_browser"
        or item.action == "switch_layer"
        or item.action == "layer_new"
        or item.action == "layer_rename"
        or item.action == "layer_close"
        or item.action == "save_template"
        or item.action == "load_template"
        or item.action == "rename_template"
        or item.action == "set_default_template"
        or item.action == "delete_template"
        or item.action == "project_config"
        or item.action == "deploy_toggle"
        or item.action == "deploy_edit"
        or item.action == "deploy_now"
        or item.action == "deploy_preview"
        or item.action == "deploy_reset"
    if not skip_rerender then
      vim.defer_fn(function() render() end, 500)
    end
  end
end

-- Setup keymaps
local function setup_keymaps()
  if not state.buf then return end
  local opts = { buffer = state.buf, nowait = true, silent = true }

  vim.keymap.set("n", "<CR>", function()
    -- In commands section, Enter injects the command into the active session
    if state.current_section == "commands" then
      if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
      local cursor = vim.api.nvim_win_get_cursor(state.win)
      local cmd_item = state.item_lines[cursor[1]]
      if cmd_item and cmd_item.action == "cmd_toggle_preview" then
        M.execute_action({ action = "cmd_inject", name = cmd_item.name, path = cmd_item.path })
        return
      end
    end
    execute_action_at_cursor()
  end, opts)
  vim.keymap.set("n", "l", execute_action_at_cursor, opts)

  -- Mouse click → execute action at clicked line
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local line = mouse.line
    if line < 1 then return end
    -- Move cursor to clicked line
    pcall(vim.api.nvim_win_set_cursor, state.win, { line, 0 })
    -- Execute if actionable
    local item = state.item_lines[line]
    if item then
      M.execute_action(item)
    end
  end, opts)

  vim.keymap.set("n", "q", function() M.close() end, opts)
  vim.keymap.set("n", "<Esc>", function()
    -- In commands section, first Esc clears filter; second Esc closes
    if state.current_section == "commands" and state.commands_search_query ~= "" then
      state.commands_search_query = ""
      state.expanded_command = nil
      render()
      return
    end
    M.close()
  end, opts)
  vim.keymap.set("n", "h", function() M.close() end, opts)

  -- j/k/Down/Up navigation (skip non-item lines)
  local function nav_down()
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local total = vim.api.nvim_buf_line_count(state.buf)
    for line = cursor[1] + 1, total do
      if state.item_lines[line] then
        vim.api.nvim_win_set_cursor(state.win, { line, 0 })
        return
      end
    end
  end

  local function nav_up()
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    for line = cursor[1] - 1, 1, -1 do
      if state.item_lines[line] then
        vim.api.nvim_win_set_cursor(state.win, { line, 0 })
        return
      end
    end
  end

  vim.keymap.set("n", "j", nav_down, opts)
  vim.keymap.set("n", "k", nav_up, opts)
  vim.keymap.set("n", "<Down>", nav_down, opts)
  vim.keymap.set("n", "<Up>", nav_up, opts)

  -- Left arrow / Shift-Tab → focus back to icon rail
  local function focus_icon_rail()
    local icon_rail = require("ccasp.appshell.icon_rail")
    local rail_win = icon_rail.get_win()
    if rail_win and vim.api.nvim_win_is_valid(rail_win) then
      vim.api.nvim_set_current_win(rail_win)
    end
  end

  vim.keymap.set("n", "<Left>", focus_icon_rail, opts)
  vim.keymap.set("n", "<S-Tab>", focus_icon_rail, opts)

  -- Tab → close flyout and return to the most recently active session
  vim.keymap.set("n", "<Tab>", function()
    M.close() -- handles flyout.visible, icon rail, and content resize
    -- Focus the last active session (most recently created or clicked)
    vim.schedule(function()
      local sessions = require("ccasp.sessions")
      local target = sessions.get_active()
      if target and target.winid and vim.api.nvim_win_is_valid(target.winid) then
        vim.api.nvim_set_current_win(target.winid)
        vim.cmd("startinsert")
      end
    end)
  end, opts)

  -- Commands-section-specific keymaps (guarded by current section check)
  -- x: inject command into Claude session
  vim.keymap.set("n", "x", function()
    if state.current_section ~= "commands" then return end
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local cmd_item = state.item_lines[cursor[1]]
    if cmd_item and cmd_item.action == "cmd_toggle_preview" then
      M.execute_action({ action = "cmd_inject", name = cmd_item.name, path = cmd_item.path })
    end
  end, opts)

  -- y: copy command name to clipboard
  vim.keymap.set("n", "y", function()
    if state.current_section ~= "commands" then return end
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local cmd_item = state.item_lines[cursor[1]]
    if cmd_item and cmd_item.action == "cmd_toggle_preview" then
      M.execute_action({ action = "cmd_copy", name = cmd_item.name })
    end
  end, opts)

  -- e: open command file in editor
  vim.keymap.set("n", "e", function()
    if state.current_section ~= "commands" then return end
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local cmd_item = state.item_lines[cursor[1]]
    if cmd_item and cmd_item.action == "cmd_toggle_preview" then
      M.execute_action({ action = "cmd_edit", name = cmd_item.name, path = cmd_item.path })
    end
  end, opts)

  -- p: toggle preview/expand description (commands section)
  vim.keymap.set("n", "p", function()
    if state.current_section ~= "commands" then return end
    execute_action_at_cursor() -- triggers cmd_toggle_preview stored on item
  end, opts)

  -- /: search/filter commands
  vim.keymap.set("n", "/", function()
    if state.current_section ~= "commands" then return end
    vim.ui.input({ prompt = icons.search .. " Filter: " }, function(input)
      if input ~= nil then
        state.commands_search_query = input
        state.expanded_command = nil
        render()
        -- Move cursor to first actionable item after re-render
        if state.win and vim.api.nvim_win_is_valid(state.win) and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
          for line_nr = 1, vim.api.nvim_buf_line_count(state.buf) do
            if state.item_lines[line_nr] then
              pcall(vim.api.nvim_win_set_cursor, state.win, { line_nr, 0 })
              break
            end
          end
        end
      end
    end)
  end, opts)

  -- Deploy-section-specific keymaps (guarded by section check)
  local deploy_toggles = {
    d = "frontend.cleanDist",
    r = "frontend.fullRebuild",
    c = "frontend.cacheBusting",
    v = "frontend.verbose",
    g = "backend.preDeployGitCheck",
    s = "verification.shaVerification",
    n = "notifications.enabled",
    a = "rollback.autoRollbackOnShaFailure",
  }

  for key, path in pairs(deploy_toggles) do
    vim.keymap.set("n", key, function()
      if state.current_section ~= "deploy" then return end
      M.execute_action({ action = "deploy_toggle", path = path })
    end, opts)
  end

  -- E: edit config (deploy section)
  vim.keymap.set("n", "E", function()
    if state.current_section ~= "deploy" then return end
    M.execute_action({ action = "deploy_edit" })
  end, opts)

  -- D: deploy now (deploy section)
  vim.keymap.set("n", "D", function()
    if state.current_section ~= "deploy" then return end
    M.execute_action({ action = "deploy_now" })
  end, opts)

  -- P: preview command (deploy section)
  vim.keymap.set("n", "P", function()
    if state.current_section ~= "deploy" then return end
    M.execute_action({ action = "deploy_preview" })
  end, opts)

  -- R: reset defaults (deploy section)
  vim.keymap.set("n", "R", function()
    if state.current_section ~= "deploy" then return end
    M.execute_action({ action = "deploy_reset" })
  end, opts)
end

-- Open flyout for a section
function M.open(bounds, section)
  -- Reset commands-specific state when switching away
  if state.current_section ~= section then
    state.expanded_command = nil
    state.commands_search_query = ""
  end
  state.current_section = section

  -- If window already exists, just re-render with new section
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    render()
    return
  end

  -- Create buffer
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false

  -- Create floating window
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    row = bounds.row,
    col = bounds.col,
    width = bounds.width,
    height = bounds.height,
    style = "minimal",
    focusable = true,
    zindex = 60,
    border = { "", "", "", "│", "", "", "", "│" },
  })

  vim.wo[state.win].winhighlight = "Normal:CcaspFlyoutBg,EndOfBuffer:CcaspFlyoutBg,FloatBorder:CcaspFlyoutBorder"
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].wrap = false

  -- Sandbox buffer to prevent Neovim errors on unmapped keys
  local helpers_ok, helpers = pcall(require, "ccasp.panels.helpers")
  if helpers_ok then
    helpers.sandbox_buffer(state.buf)
  end

  setup_keymaps()
  render()

  -- Move cursor to first actionable item
  for line = 1, vim.api.nvim_buf_line_count(state.buf) do
    if state.item_lines[line] then
      vim.api.nvim_win_set_cursor(state.win, { line, 0 })
      break
    end
  end
end

-- Close flyout
function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.current_section = nil
  state.expanded_command = nil
  state.commands_search_query = ""

  -- Notify appshell that flyout is closed
  local appshell = require("ccasp.appshell")
  appshell.config.flyout.visible = false
  appshell.state.active_section = nil

  local icon_rail = require("ccasp.appshell.icon_rail")
  icon_rail.set_active(nil)

  -- Resize content area to reclaim flyout space (shrink left spacer back to rail-only width).
  -- Without this, the wide spacer stays visible as a blank area after the flyout float closes.
  appshell.calculate_zones()
  local content_ok, content = pcall(require, "ccasp.appshell.content")
  if content_ok and appshell.state and appshell.state.zones then
    content.resize(appshell.state.zones.content)
  end
end

-- Switch section without closing
function M.switch_section(section)
  -- Reset commands-specific state when leaving commands section
  if state.current_section == "commands" and section ~= "commands" then
    state.expanded_command = nil
    state.commands_search_query = ""
  end
  state.current_section = section
  render()
end

-- Resize flyout
function M.resize(bounds)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, {
      relative = "editor",
      row = bounds.row,
      col = bounds.col,
      width = bounds.width,
      height = bounds.height,
    })
    render()
  end
end

-- Check if flyout is open
function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Get flyout window ID
function M.get_win()
  return state.win
end

-- Focus flyout and move cursor to first actionable item
function M.focus()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    -- Move cursor to first actionable item
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      for line = 1, vim.api.nvim_buf_line_count(state.buf) do
        if state.item_lines[line] then
          vim.api.nvim_win_set_cursor(state.win, { line, 0 })
          break
        end
      end
    end
  end
end

-- Refresh commands section when the active terminal session changes.
-- Each session may be in a different project with different .claude/commands/.
vim.api.nvim_create_autocmd("User", {
  pattern = "CcaspActiveSessionChanged",
  callback = function()
    if state.current_section == "commands" and state.win and vim.api.nvim_win_is_valid(state.win) then
      local commands_ok, commands_mod = pcall(require, "ccasp.core.commands")
      if commands_ok then
        commands_mod.reload()
      end
      render()
    end
  end,
})

return M
