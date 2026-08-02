-- ccasp.nvim - Neovim integration for Claude CLI Advanced Starter Pack
-- A terminal-based AI command center for managing multiple Claude sessions
-- Supports both "classic" (sidebar+terminal) and "modern" (floating panels) layouts

local M = {}

-- Plugin version
M.version = "1.5.0"

-- Helper: Check if classic layout is active
function M.is_classic()
  return M.config.layout == "classic"
end

-- Helper: Check if appshell layout is active
function M.is_appshell()
  return M.config.layout == "appshell"
end

-- Demo mode helpers: mask paths and names for marketing screenshots
function M.is_demo_mode()
  return M.config.demo_mode == true
end

local demo_name_counter = 0
local demo_name_cache = {} -- original_name → masked_name

function M.mask_path(path)
  if not M.is_demo_mode() then return path end
  return "~/projects/my-project"
end

function M.mask_name(name)
  if not M.is_demo_mode() then return name end
  if not name or name == "" then return "Project" end
  if demo_name_cache[name] then return demo_name_cache[name] end
  demo_name_counter = demo_name_counter + 1
  local masked = "Project " .. demo_name_counter
  demo_name_cache[name] = masked
  return masked
end

-- Demo mode: get a clean working directory so Claude CLI doesn't show real paths.
-- Creates a temp directory with a generic name and a minimal .claude/ folder.
local demo_dir_cache = nil
function M.get_demo_dir()
  if demo_dir_cache then return demo_dir_cache end
  local base = vim.fn.has("win32") == 1
    and (os.getenv("TEMP") or "C:\\Temp")
    or "/tmp"
  local dir = base:gsub("\\", "/") .. "/ccasp-demo/my-project"
  -- Create directory tree if missing
  vim.fn.mkdir(dir .. "/.claude", "p")
  -- Write a minimal settings.json so Claude CLI recognizes the project
  local settings_path = dir .. "/.claude/settings.json"
  if vim.fn.filereadable(settings_path) == 0 then
    vim.fn.writefile({ '{"permissions":{"allow":[]},"enabledTools":[]}' }, settings_path)
  end
  -- Write a minimal CLAUDE.md so Claude CLI shows a generic project name
  local claude_md_path = dir .. "/CLAUDE.md"
  if vim.fn.filereadable(claude_md_path) == 0 then
    vim.fn.writefile({ "# My Project", "", "Demo project workspace." }, claude_md_path)
  end
  demo_dir_cache = dir
  return dir
end

-- Helper: Conditionally setup module with config
local function setup_module(name, module_ref, config)
  if module_ref then
    module_ref.setup(config)
  end
end

-- Health check helpers
local function check_executable(health, name, cmd)
  if vim.fn.executable(cmd) == 1 then
    health.ok(name .. " found")
    return true
  else
    return false
  end
end

local function check_directory(health, name, path)
  if vim.fn.isdirectory(path) == 1 then
    health.ok(name .. " exists")
    return true
  else
    return false
  end
end

local function check_module(health, name, mod_name)
  local ok, _ = pcall(require, mod_name)
  if ok then
    health.ok(name .. " found")
    return true
  else
    return false
  end
end

-- Default configuration
M.config = {
  -- Layout mode: "classic" (sidebar+terminal), "modern" (floating panels), or "appshell" (icon rail + flyout)
  layout = "classic",

  -- Appshell layout settings (icon rail + flyout + header + content + footer)
  appshell = {
    icon_rail = { width = 5, visible = true },
    flyout = { width = 35, visible = false },
    header = { height = 1, visible = true },
    footer = { height = 2, visible = true },
    right_panel = { width = 40, visible = false },
  },

  -- Classic layout settings (sidebar on left, terminal on right)
  sidebar = {
    width = 40,
    position = "left",
    auto_open = true,
  },
  terminal = {
    shell = "claude",
    size = 60, -- percentage of window
    direction = "vertical",
  },

  -- Classic layout paths (for backwards compatibility with core modules)
  ccasp_root = ".claude",
  settings_file = ".claude/settings.json",
  protected_file = ".claude/protected.json",

  -- Grid layout settings (for modern layout)
  grid = {
    rows = 3,
    cols = 2,
    -- Agent definitions for each cell
    agents = {
      { name = "planner", role = "Architecture & Planning", model = "opus" },
      { name = "implementer", role = "Code Implementation", model = "sonnet" },
      { name = "tester", role = "Test Generation", model = "sonnet" },
      { name = "reviewer", role = "Code Review", model = "sonnet" },
      { name = "debugger", role = "Debugging & Fixes", model = "sonnet" },
      { name = "docs", role = "Documentation", model = "haiku" },
    },
  },
  -- Control panel settings (for modern layout)
  control_panel = {
    width = 45,
    height = 30, -- Increased for Prompt Injector section
    position = "right", -- "right", "left", "float"
    border = "rounded",
  },
  -- Prompt Injector settings (NEW in v1.1.0)
  prompt_injector = {
    enabled = false,
    auto_enhance = false,
    openai = {
      model = "gpt-5.2",
      max_tokens = 1000,
      temperature = 0.3,
    },
  },
  -- CCASP paths (relative to project root)
  paths = {
    settings = ".claude/config/settings.json",
    tech_stack = ".claude/config/tech-stack.json",
    state = ".claude/config/ccasp-state.json",
    hooks_dir = ".claude/hooks/tools",
    commands_dir = ".claude/commands",
    skills_dir = ".claude/skills",
    cache_dir = ".claude/hooks/cache",
    deploy_config = ".claude/config/deploy-config.json",
  },
  -- Default Claude CLI options
  claude = {
    command = "claude",
    default_model = "sonnet",
    auto_commit = false,
    write_files = true,
    run_tests = true,
  },
  -- Onboarding / Getting Started
  onboarding = {
    auto_open = true,       -- Open welcome on first launch
    show_on_update = false, -- Show welcome on version update
  },

  -- Demo mode: hides all file/folder paths from UI (for marketing screenshots)
  demo_mode = false,

  -- Neovide GUI settings (applied only when running inside Neovide)
  neovide = {
    font = "JetBrainsMono Nerd Font Mono:h12",
    padding = 4,
  },

  -- Keymaps
  keys = {
    prefix = "<leader>c",
    grid = "g",
    control = "p",
    features = "f",
    hooks = "h",
    commands = "c",
    skills = "s",
    dashboard = "d",
    restart_all = "R",
    kill_all = "K",
    -- Prompt Injector keymaps
    prompt_injector = "i",
    quick_enhance = "e",
    -- Taskbar keymaps (NEW in v1.2.0)
    taskbar = "T",
    -- Browser tabs / Sessions (NEW in v1.3.0)
    new_session = "n",
  },
  -- Browser tabs settings (NEW in v1.3.0)
  browser_tabs = {
    enabled = true,
    height = 1,
    icons = {
      main = "",
      worktree = "",
      branch = "",
      close = "",
      add = "+",
    },
  },
  -- Window manager settings (NEW in v1.2.0)
  window_manager = {
    enabled = true,
    move_step = 5,
    resize_step = 2,
    drag_enabled = true,
    taskbar = {
      enabled = true,
      max_items = 9,
      show_icons = true,
    },
  },
}

-- State tracking
M.state = {
  agents = {}, -- { bufnr, winid, job_id, name, status }
  control_panel = nil, -- { bufnr, winid }
  dashboard = nil,
  initialized = false,
  -- Classic layout state
  sidebar_open = false,
  active_tab = 1, -- 1=Commands, 2=Settings, 3=Protected, 4=Status, 5=Keys, 6=Assets, 7=Shortcuts
  selected_command = nil,
  selected_asset = nil,
  selected_asset_type = nil,
  selected_shortcut = nil,
  search_query = "",
  expanded_sections = {},
  expanded_asset_sections = { agents = true, hooks = false, skills = false },
  commands_cache = nil,
  assets_cache = nil,
  last_command = nil,
}

-- Detect project root by walking up from cwd looking for .claude/ directory.
-- Returns the detected root or falls back to the starting directory.
local function detect_project_root()
  local cwd = vim.fn.getcwd():gsub("\\", "/")
  local dir = cwd
  while true do
    if vim.fn.isdirectory(dir .. "/.claude") == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h"):gsub("\\", "/")
    if parent == dir then break end -- reached filesystem root
    dir = parent
  end
  return cwd -- fallback: use original cwd
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Detect and store project root (used by commands scanner, config paths, etc.)
  M.config.project_root = detect_project_root()

  -- Resolve which agent CLI this project drives. The built-in defaults name
  -- Claude; when the user has not pinned a command explicitly we follow the
  -- project's configured runtime, so a Codex project launches Codex.
  local runtime = require("ccasp.runtime")
  runtime.reset()
  M.config.runtime = runtime.default(M.config.project_root)
  local resolved_cli = runtime.command(M.config.runtime)

  if not (opts and opts.terminal and opts.terminal.shell) then
    M.config.terminal.shell = resolved_cli
  end
  if not (opts and opts.claude and opts.claude.command) then
    M.config.claude.command = resolved_cli
  end

  -- Protected module loader: logs warning on failure instead of crashing
  local function safe_require(mod)
    local ok, result = pcall(require, mod)
    if not ok then
      vim.notify("ccasp: failed to load " .. mod .. ": " .. tostring(result), vim.log.levels.WARN)
      return nil
    end
    return result
  end

  -- Load shared modules
  M.utils = safe_require("ccasp.config")
  M.telescope = safe_require("ccasp.telescope")
  M.statusline = safe_require("ccasp.statusline")

  -- Load ALL modules (both layouts available)
  -- Classic layout modules: sidebar + terminal
  M.core = safe_require("ccasp.core")
  M.ui = safe_require("ccasp.ui")
  M.terminal = safe_require("ccasp.terminal")

  -- Initialize state from saved settings
  if M.core and M.core.settings then
    M.core.settings.load()
  end

  -- Modern layout modules: floating panels
  M.panels = {
    control = safe_require("ccasp.panels.control"),
    features = safe_require("ccasp.panels.features"),
    hooks = safe_require("ccasp.panels.hooks"),
    dashboard = safe_require("ccasp.panels.dashboard"),
    commands = safe_require("ccasp.panels.commands"),
    prompt_editor = safe_require("ccasp.panels.prompt_editor"),
    site_intel = safe_require("ccasp.panels.site_intel"),
  }
  M.agents = safe_require("ccasp.agents")

  -- Load Prompt Injector modules (available in both layouts)
  M.openai = safe_require("ccasp.openai")
  M.prompt_injector = safe_require("ccasp.prompt_injector")

  -- Initialize Prompt Injector with config
  setup_module("prompt_injector", M.prompt_injector, {
    enabled = M.config.prompt_injector.enabled,
    auto_enhance = M.config.prompt_injector.auto_enhance,
    openai = M.config.prompt_injector.openai,
  })

  -- Load Window Manager modules (available in both layouts)
  M.window_manager = safe_require("ccasp.window_manager")
  M.taskbar = safe_require("ccasp.taskbar")
  M.drag = safe_require("ccasp.drag")

  -- Initialize Window Manager with config
  setup_module("window_manager", M.window_manager, {
    enabled = M.config.window_manager.enabled,
    move_step = M.config.window_manager.move_step,
    resize_step = M.config.window_manager.resize_step,
  })

  -- Initialize Taskbar with config
  local taskbar_cfg = M.config.window_manager and M.config.window_manager.taskbar
  if taskbar_cfg then
    setup_module("taskbar", M.taskbar, {
      enabled = taskbar_cfg.enabled,
      max_items = taskbar_cfg.max_items,
      show_icons = taskbar_cfg.show_icons,
    })
  end

  -- Initialize Drag with config
  setup_module("drag", M.drag, {
    enabled = M.config.window_manager and M.config.window_manager.drag_enabled,
  })

  -- Load Browser Tabs module
  M.browser_tabs = safe_require("ccasp.browser_tabs")

  -- Initialize Browser Tabs with config
  setup_module("browser_tabs", M.browser_tabs, {
    enabled = M.config.browser_tabs.enabled,
    height = M.config.browser_tabs.height,
    icons = M.config.browser_tabs.icons,
  })

  -- Load Appshell modules (if appshell layout)
  if M.config.layout == "appshell" then
    M.appshell = safe_require("ccasp.appshell")
    if M.appshell then
      M.appshell.setup(M.config.appshell or {})
    end
  end

  -- Register :CcaspProjectConfig command
  vim.api.nvim_create_user_command("CcaspProjectConfig", function()
    require("ccasp.project_config").open()
  end, { desc = "Open CCASP Project Configuration panel" })

  -- Neovide-specific configuration (font, padding, quit keybinds)
  local neovide = safe_require("ccasp.neovide")
  if neovide then
    neovide.setup(M.config.neovide or {})
  end

  -- Load Multi-Session Terminal Manager
  M.sessions = safe_require("ccasp.sessions")

  -- Load Session Titlebar module
  M.session_titlebar = safe_require("ccasp.session_titlebar")
  setup_module("session_titlebar", M.session_titlebar, {})

  -- Initialize modern UI modules (highlights, topbar, logo)
  if M.ui then
    -- Apply all highlight groups
    if M.ui.highlights then
      M.ui.highlights.setup()
    end

    -- Initialize topbar (horizontal command strip) - skip for appshell (uses its own header)
    if M.ui.topbar and not M.is_appshell() then
      M.ui.topbar.setup()
      -- Enable tabline display
      vim.o.showtabline = 2
    end

    -- Initialize logo module
    if M.ui.logo then
      M.ui.logo.setup()
    end
  end

  -- Setup keymaps
  M.setup_keymaps()

  -- Setup autocommands
  M.setup_autocmds()

  -- Hide chrome that wastes vertical space in appshell mode
  if M.is_appshell() then
    vim.o.showmode = false    -- hides "-- TERMINAL --" etc.
    vim.o.laststatus = 0      -- hides statuslines between splits
    vim.o.cmdheight = 0       -- auto-shows only for errors/messages

    -- Make any uncovered area (base window, message area) match the dark appshell background.
    -- With cmdheight=0, the message area overlays on the last row and can show stale content
    -- like "C:\...\cmd.exe" from :terminal. These highlights make it invisible.
    vim.api.nvim_set_hl(0, "Normal", { bg = "#0d1117" })
    vim.api.nvim_set_hl(0, "MsgArea", { fg = "#0d1117", bg = "#0d1117" })
    vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = "#0d1117", bg = "#0d1117" })
  end

  M.state.initialized = true

  -- Only notify in non-appshell layouts; appshell uses cmdheight=0
  -- which turns any message into a "Press ENTER" prompt
  if not M.is_appshell() then
    vim.notify("CCASP.nvim v" .. M.version .. " loaded (" .. M.config.layout .. " layout)", vim.log.levels.INFO)
  end

  -- Check for first-launch onboarding (deferred to let UI settle)
  if M.config.onboarding and M.config.onboarding.auto_open then
    vim.defer_fn(function()
      local ob_ok, onboarding_state = pcall(require, "ccasp.onboarding.state")
      if ob_ok and onboarding_state.check_first_launch() then
        local ob_init_ok, onboarding = pcall(require, "ccasp.onboarding")
        if ob_init_ok and onboarding.open_welcome then
          onboarding.open_welcome()
        end
      end
    end, 500)
  end
end

-- Open CCASP (classic layout: sidebar + terminal, appshell: full chrome)
function M.open()
  if M.is_appshell() then
    if M.appshell then
      M.appshell.open()
    end
  elseif M.is_classic() then
    M.ui.sidebar.open()
    M.state.sidebar_open = true
    -- Show animated logo
    if M.ui.logo then
      M.ui.logo.show()
    end
    -- Refresh topbar
    if M.ui.topbar then
      M.ui.topbar.refresh()
    end
  else
    M.panels.dashboard.open()
  end
end

-- Close CCASP
function M.close()
  if M.is_appshell() then
    if M.appshell then
      M.appshell.close()
    end
  elseif M.is_classic() then
    M.ui.sidebar.close()
    M.terminal.close()
    M.state.sidebar_open = false
    -- Hide logo
    if M.ui.logo then
      M.ui.logo.hide()
    end
  else
    -- Close any open panels
    if M.panels.dashboard.is_open then
      M.panels.dashboard.close()
    end
  end
end

-- Toggle sidebar (classic), control panel (modern), or icon rail (appshell)
function M.toggle_sidebar()
  if M.is_appshell() then
    if M.appshell then
      M.appshell.toggle_rail()
    end
  elseif M.is_classic() then
    if M.state.sidebar_open then
      M.ui.sidebar.close()
      M.state.sidebar_open = false
    else
      M.ui.sidebar.open()
      M.state.sidebar_open = true
    end
  else
    M.panels.control.toggle()
  end
end

-- Toggle focus between sidebar and terminal (classic), or rail and content (appshell)
function M.toggle_focus()
  if M.is_appshell() then
    -- Toggle between icon rail and terminal content
    local icon_rail = require("ccasp.appshell.icon_rail")
    local rail_win = icon_rail.get_win()
    if rail_win and vim.api.nvim_get_current_win() == rail_win then
      -- Focus terminal
      if M.sessions then M.sessions.focus_next() end
    else
      -- Focus icon rail
      if rail_win and vim.api.nvim_win_is_valid(rail_win) then
        vim.api.nvim_set_current_win(rail_win)
      end
    end
  elseif M.is_classic() then
    if M.ui.sidebar.is_focused() then
      M.terminal.focus()
    else
      M.ui.sidebar.focus()
    end
  end
end

-- Run a command
function M.run_command(cmd_name)
  if not cmd_name or cmd_name == "" then
    cmd_name = M.state.selected_command
  end

  if not cmd_name then
    vim.notify("No command selected", vim.log.levels.WARN)
    return
  end

  if M.is_classic() then
    -- Get command options
    local options = M.state.command_options and M.state.command_options[cmd_name] or {}

    -- Build command string
    local cmd_str = "/" .. cmd_name
    for key, value in pairs(options) do
      if value == true then
        cmd_str = cmd_str .. " --" .. key
      elseif value ~= false then
        cmd_str = cmd_str .. " --" .. key .. "=" .. tostring(value)
      end
    end

    -- Execute in terminal
    M.terminal.run_command(cmd_name, options)

    -- Record usage in topbar
    if M.ui and M.ui.topbar then
      M.ui.topbar.record_usage(cmd_name)
    end

    -- Save as last command
    M.state.last_command = cmd_name
  end
end

-- Run last command
function M.run_last_command()
  if M.state.last_command then
    M.run_command(M.state.last_command)
  else
    vim.notify("No previous command", vim.log.levels.INFO)
  end
end

-- Quick search commands
function M.quick_search()
  if M.is_classic() then
    M.ui.search.open()
  else
    M.panels.commands.toggle()
  end
end

-- Check for updates
function M.check_updates()
  if M.is_classic() then
    M.terminal.send("/update-check")
  end
end

-- Toggle permissions mode
function M.toggle_permissions()
  if M.is_classic() then
    local settings = M.core.settings.get()
    local modes = { "auto", "plan", "ask" }
    local current_idx = 1

    for i, mode in ipairs(modes) do
      if mode == settings.permissions_mode then
        current_idx = i
        break
      end
    end

    local next_idx = (current_idx % #modes) + 1
    settings.permissions_mode = modes[next_idx]
    M.core.settings.set("permissions_mode", settings.permissions_mode)

    vim.notify("Permissions mode: " .. settings.permissions_mode, vim.log.levels.INFO)
    M.ui.statusbar.update()
  end
end

-- Reload commands cache
function M.reload_commands()
  M.state.commands_cache = nil
  if M.is_classic() then
    M.core.commands.load_all()
    M.ui.sidebar.refresh()
  end
end

-- Reload assets cache
function M.reload_assets()
  M.state.assets_cache = nil
  if M.is_classic() then
    M.core.assets.reload()
    M.ui.sidebar.refresh()
  end
end

-- Search commands
function M.search_commands(query)
  M.state.search_query = query or ""
  if M.is_classic() then
    M.ui.sidebar.filter(M.state.search_query)
  end
end

-- Get plugin status for statusbar
function M.get_status()
  local status = {
    version = M.version,
    permissions_mode = "auto",
    update_mode = "manual",
    protected_count = 0,
    sync_status = "unknown",
  }

  if M.is_classic() and M.core then
    local settings = M.core.settings.get()
    local protected = M.core.protected.list()

    status.permissions_mode = settings.permissions_mode or "auto"
    status.update_mode = settings.update_mode or "manual"
    status.protected_count = #protected
    status.sync_status = M.core.commands.get_sync_status()
  end

  return status
end

-- Setup classic layout keymaps
local function setup_classic_keymaps()
  local opts = { noremap = true, silent = true }
  local keybindings = M.config.keybindings or {
    toggle_sidebar = "<C-b>",
    toggle_focus = "<C-\\>",
    open_ccasp = "<leader>cc",
    run_last = "<leader>cr",
    quick_search = "<leader>cs",
    check_updates = "<leader>cu",
    toggle_perms = "<leader>cp",
  }

  vim.keymap.set("n", keybindings.toggle_sidebar, M.toggle_sidebar,
    vim.tbl_extend("force", opts, { desc = "Toggle CCASP sidebar" }))
  vim.keymap.set("n", keybindings.toggle_focus, M.toggle_focus,
    vim.tbl_extend("force", opts, { desc = "Toggle focus sidebar/terminal" }))
  vim.keymap.set("n", keybindings.open_ccasp, M.open,
    vim.tbl_extend("force", opts, { desc = "Open CCASP Control Center" }))
  vim.keymap.set("n", keybindings.run_last, M.run_last_command,
    vim.tbl_extend("force", opts, { desc = "Run last CCASP command" }))
  vim.keymap.set("n", keybindings.quick_search, M.quick_search,
    vim.tbl_extend("force", opts, { desc = "Quick search commands" }))
  vim.keymap.set("n", keybindings.check_updates, M.check_updates,
    vim.tbl_extend("force", opts, { desc = "Check for CCASP updates" }))
  vim.keymap.set("n", keybindings.toggle_perms, M.toggle_permissions,
    vim.tbl_extend("force", opts, { desc = "Toggle permissions mode" }))
end

-- Setup modern layout keymaps
local function setup_modern_keymaps()
  local default_keys = {
    grid = "g",
    control = "p",
    features = "f",
    hooks = "h",
    commands = "c",
    skills = "s",
    dashboard = "d",
    restart_all = "R",
    kill_all = "K",
    prompt_injector = "i",
    quick_enhance = "e",
    taskbar = "T",
    new_session = "n",
    browser = "o",
    project_config = "P",
  }
  local prefix = M.config.keys and M.config.keys.prefix or "<leader>c"
  local keys = vim.tbl_extend("keep", M.config.keys or {}, default_keys)

  -- Function lookup table for modern features
  local actions = {
    grid = function() M.agents.open_grid() end,
    control = function() M.panels.control.toggle() end,
    features = function() M.panels.features.open() end,
    hooks = function() M.panels.hooks.open() end,
    commands = function() M.panels.commands.toggle() end,
    skills = function() M.telescope.skills() end,
    dashboard = function() M.panels.dashboard.open() end,
    restart_all = function() M.agents.restart_all() end,
    kill_all = function() M.agents.kill_all() end,
    prompt_injector = function() M.prompt_injector.toggle() end,
    quick_enhance = function() M.prompt_injector.quick_enhance() end,
    taskbar = function() M.taskbar.show_picker() end,
    new_session = function() M.browser_tabs.show_context_menu("new_session") end,
    browser = function() require("ccasp.browser").open_dashboard() end,
    project_config = function() require("ccasp.project_config").toggle() end,
    -- Session management
    spawn_session = function()
      require("ccasp.runtime_picker").open({
        prompt = "New session type",
        on_select = function(name) M.sessions.spawn(nil, name) end,
      })
    end,
    session_picker = function() M.sessions.show_picker() end,
    session_next = function() M.sessions.focus_next() end,
    session_prev = function() M.sessions.focus_prev() end,
  }

  local mappings = {
    { keys.grid, actions.grid, "Open Agent Grid" },
    { keys.control, actions.control, "Control Panel (floating)" },
    { keys.features, actions.features, "Feature Toggles" },
    { keys.hooks, actions.hooks, "Hook Manager" },
    -- Note: keys.commands and keys.skills overlap with classic, skip duplicate
    { keys.dashboard, actions.dashboard, "Dashboard (floating)" },
    { keys.restart_all, actions.restart_all, "Restart All Agents" },
    { keys.kill_all, actions.kill_all, "Kill All Agents" },
    { keys.prompt_injector, actions.prompt_injector, "Toggle Prompt Injector" },
    { keys.quick_enhance, actions.quick_enhance, "Quick Enhance" },
    { keys.taskbar, actions.taskbar, "Show Taskbar" },
    { keys.new_session, actions.new_session, "New Session Menu" },
    { keys.browser, actions.browser, "Open Site Intel in Browser" },
    { keys.project_config, actions.project_config, "Project Configuration" },
  }

  -- Session management keymaps
  -- Ctrl+Shift+N: New session
  -- Ctrl+Tab / Ctrl+Shift+Tab: Cycle through sessions (works in terminal mode too!)
  -- Backtick (`): Quick toggle to next session (easy single key)
  vim.keymap.set("n", "<C-S-n>", actions.spawn_session, { desc = "CCASP: New Session" })
  vim.keymap.set("n", prefix .. "S", actions.session_picker, { desc = "CCASP: Session Picker" })
  vim.keymap.set("n", "<C-Tab>", actions.session_next, { desc = "CCASP: Next Session" })
  vim.keymap.set("n", "<C-S-Tab>", actions.session_prev, { desc = "CCASP: Previous Session" })

  -- Quick toggle with backtick (`) - single key to cycle sessions
  vim.keymap.set("n", "`", actions.session_next, { desc = "CCASP: Quick toggle session" })
  vim.keymap.set("n", "~", actions.session_prev, { desc = "CCASP: Quick toggle session (prev)" })

  -- Terminal mode quick toggle (Ctrl+` for next session while typing)
  vim.keymap.set("t", "<C-`>", function()
    vim.cmd([[<C-\><C-n>]])
    M.sessions.focus_next()
  end, { desc = "CCASP: Quick toggle session from terminal" })

  -- Standard prefix mappings (e.g., <leader>cg for agent grid)
  for _, map in ipairs(mappings) do
    vim.keymap.set("n", prefix .. map[1], map[2], { desc = "CCASP: " .. map[3] })
  end

  -- Extra keymaps from presets (e.g., <S-F1>, <Tab>p)
  if M.config.extra_keymaps then
    for _, map in ipairs(M.config.extra_keymaps) do
      local key, action_name, desc = map[1], map[2], map[3]
      if actions[action_name] then
        vim.keymap.set("n", key, actions[action_name], { desc = "CCASP: " .. desc })
      end
    end
  end

  -- Taskbar restore keymaps (1-9)
  if M.config.window_manager and M.config.window_manager.taskbar and M.config.window_manager.taskbar.enabled then
    for i = 1, 9 do
      vim.keymap.set("n", prefix .. tostring(i), function()
        M.taskbar.restore_by_index(i)
      end, { desc = "CCASP: Restore taskbar item " .. i })
    end
  end
end

-- Setup appshell-specific keymaps
local function setup_appshell_keymaps()
  local opts = { noremap = true, silent = true }

  -- Ctrl+B toggles icon rail (matches VS Code sidebar toggle)
  vim.keymap.set("n", "<C-b>", function()
    if M.appshell then M.appshell.toggle_rail() end
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle icon rail" }))

  -- Ctrl+Shift+B toggles flyout for last section
  vim.keymap.set("n", "<C-S-b>", function()
    if M.appshell then
      local section = M.appshell.state.active_section or "terminal"
      M.appshell.toggle_flyout(section)
    end
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle flyout" }))

  -- Ctrl+Shift+P toggles right panel
  vim.keymap.set("n", "<C-S-p>", function()
    if M.appshell then M.appshell.toggle_right_panel() end
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle right panel" }))

  -- Alt+1 through Alt+5 for quick section access
  for i = 1, 5 do
    vim.keymap.set("n", "<M-" .. i .. ">", function()
      if M.appshell then
        local icon_rail = require("ccasp.appshell.icon_rail")
        icon_rail.select(i)
      end
    end, vim.tbl_extend("force", opts, { desc = "CCASP: Section " .. i }))
  end

  -- Helper: exit terminal mode safely via feedkeys (vim.cmd cannot send key sequences)
  local function exit_terminal_mode()
    local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
    vim.api.nvim_feedkeys(esc, "n", false)
  end

  -- Terminal-mode shortcuts (exit terminal mode first, then act)
  vim.keymap.set("t", "<C-b>", function()
    exit_terminal_mode()
    vim.schedule(function()
      if M.appshell then M.appshell.toggle_rail() end
    end)
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle icon rail (terminal)" }))

  vim.keymap.set("t", "<C-S-b>", function()
    exit_terminal_mode()
    vim.schedule(function()
      if M.appshell then
        local section = M.appshell.state.active_section or "terminal"
        M.appshell.toggle_flyout(section)
      end
    end)
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle flyout (terminal)" }))

  -- Tab toggles command panel (flyout) from anywhere
  vim.keymap.set("n", "<Tab>", function()
    if M.appshell then
      local section = M.appshell.state.active_section or "terminal"
      M.appshell.toggle_flyout(section)
    end
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle command panel" }))

  vim.keymap.set("t", "<Tab>", function()
    exit_terminal_mode()
    vim.schedule(function()
      if M.appshell then
        local section = M.appshell.state.active_section or "terminal"
        M.appshell.toggle_flyout(section)
      end
    end)
  end, vim.tbl_extend("force", opts, { desc = "CCASP: Toggle command panel (terminal)" }))
end

-- Setup keybindings
function M.setup_keymaps()
  setup_classic_keymaps()
  setup_modern_keymaps()
  if M.is_appshell() then
    setup_appshell_keymaps()
  end

  -- Help & Onboarding keymaps (all layouts)
  local prefix = M.config.keys and M.config.keys.prefix or "<leader>c"
  vim.keymap.set("n", prefix .. "?", function()
    require("ccasp.help").toggle()
  end, { desc = "CCASP: Toggle Help panel" })

  vim.keymap.set("n", prefix .. "w", function()
    require("ccasp.onboarding").toggle_welcome()
  end, { desc = "CCASP: Toggle Getting Started" })
end

-- Setup autocommands
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("CCASP", { clear = true })

  -- Watch for config file changes
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/.claude/config/*.json",
    callback = function(args)
      local ok, err = pcall(function()
        local content = table.concat(vim.fn.readfile(args.file), "\n")
        vim.fn.json_decode(content)
      end)
      if not ok then
        vim.notify("CCASP: Invalid JSON - " .. tostring(err), vim.log.levels.ERROR)
      else
        vim.notify("CCASP: Config updated", vim.log.levels.INFO)
        vim.api.nvim_exec_autocmds("User", { pattern = "CcaspConfigReload" })
      end
    end,
  })

  -- Cleanup on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.agents.kill_all()
    end,
  })
end

-- Health check
function M.health()
  local health = vim.health or require("health")
  health.start("CCASP.nvim")

  -- Check executables. Both runtimes are probed; at least one must be present.
  local runtime = require("ccasp.runtime")
  local install_hint = {
    claude = "Install Claude CLI: npm install -g @anthropic-ai/claude-code",
    codex = "Install Codex CLI: npm install -g @openai/codex",
  }
  local available = runtime.available()
  for _, name in ipairs(runtime.order) do
    local spec = runtime.specs[name]
    if runtime.is_available(name) then
      health.ok(spec.label .. " CLI found")
    elseif #available == 0 then
      health.error(spec.label .. " CLI not found", { install_hint[name] })
    else
      health.info(spec.label .. " CLI not installed", { install_hint[name] })
    end
  end
  if #available > 0 then
    health.ok("Default runtime: " .. runtime.label(runtime.default()))
  end

  if not check_executable(health, "CCASP CLI", "ccasp") then
    health.warn("CCASP CLI not found", { "Install: npm install -g claude-cli-advanced-starter-pack" })
  end

  -- Check directories for the active runtime
  local health_root = M.config.project_root or vim.fn.getcwd()
  local runtime_dirname = runtime.spec(runtime.default(health_root)).root
  if not check_directory(health, runtime_dirname .. " directory", health_root .. "/" .. runtime_dirname) then
    health.warn(runtime_dirname .. " directory not found", { "Run: ccasp init" })
  end

  -- Check required dependencies
  if not check_module(health, "plenary.nvim", "plenary") then
    health.error("plenary.nvim not found", { "Required for async operations" })
  end

  if not check_module(health, "telescope.nvim", "telescope") then
    health.warn("telescope.nvim not found", { "Optional: enables command/skill browsing" })
  end

  -- Check Neovim version
  local version = vim.version()
  if version.major > 0 or (version.major == 0 and version.minor >= 10) then
    health.ok("Neovim version supports mouse drag (" .. tostring(version.major) .. "." .. tostring(version.minor) .. ")")
  else
    health.warn("Neovim < 0.10 - mouse drag disabled", { "Upgrade Neovim for drag support" })
  end

  -- Check optional modules
  if not check_module(health, "Window manager module", "ccasp.window_manager") then
    health.error("Window manager module failed to load")
  end

  if not check_module(health, "Taskbar module", "ccasp.taskbar") then
    health.error("Taskbar module failed to load")
  end

  if not check_module(health, "Browser tabs module", "ccasp.browser_tabs") then
    health.error("Browser tabs module failed to load")
  end
end

return M
