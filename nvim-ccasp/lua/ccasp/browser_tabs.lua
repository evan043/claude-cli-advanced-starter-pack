-- ccasp/browser_tabs.lua - Browser-like tab bar for Claude CLI sessions
-- Provides a fixed tab bar above the terminal with right-click context menus
-- v1.4.0 - Refactored with unified popup factory and improved organization

local M = {}
local picker_popup = require("ccasp.ui.picker_popup")

-- Configuration
M.config = {
  height = 1, -- Tab bar height in lines
  position = "top", -- Position relative to terminal
  max_tabs = 10, -- Maximum number of tabs
  icons = {
    main = "",
    worktree = "",
    branch = "",
    close = "",
    add = "+",
    active = "●",
    inactive = "○",
    pinned = "",
    modified = "●",
    group = "◆",
  },
  colors = {
    active_bg = "TabLineSel",
    inactive_bg = "TabLine",
    bar_bg = "TabLineFill",
    pinned = "DiagnosticInfo",
    modified = "DiagnosticWarn",
    group_1 = "DiagnosticHint",
    group_2 = "DiagnosticOk",
    group_3 = "DiagnosticWarn",
    group_4 = "DiagnosticError",
  },
  -- Session persistence
  persist = {
    enabled = true,
    file = ".claude/cache/browser-tabs.json",
  },
  -- Tab groups
  groups = {
    enabled = true,
    colors = { "DiagnosticHint", "DiagnosticOk", "DiagnosticWarn", "DiagnosticError" },
  },
}

-- State
M.state = {
  tabs = {}, -- { id, name, type, path, winid, bufnr, active, job_id, pinned, group, modified, created_at }
  active_tab = nil,
  bar_winid = nil,
  bar_bufnr = nil,
  next_id = 1,
  -- Drag state
  dragging = false,
  drag_tab_id = nil,
  drag_start_col = nil,
  -- Recent sessions
  recent = {}, -- { name, type, path, branch, closed_at }
  max_recent = 10,
  -- Tab groups
  groups = {}, -- { id, name, color_index }
  next_group_id = 1,
}

-- Setup with user config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Load persisted state if enabled
  if M.config.persist.enabled then
    M.load_state()
  end
end

-- Generate unique tab ID
local function generate_id()
  local id = M.state.next_id
  M.state.next_id = M.state.next_id + 1
  return "tab_" .. id
end

-- Generate unique group ID
local function generate_group_id()
  local id = M.state.next_group_id
  M.state.next_group_id = M.state.next_group_id + 1
  return "group_" .. id
end

-- Get git worktrees
function M.get_worktrees()
  local worktrees = {}
  local handle = io.popen("git worktree list --porcelain 2>/dev/null")
  if not handle then
    return worktrees
  end

  local output = handle:read("*a")
  handle:close()

  local current_wt = {}
  for line in output:gmatch("[^\n]+") do
    if line:match("^worktree ") then
      current_wt = { path = line:gsub("^worktree ", "") }
    elseif line:match("^HEAD ") then
      current_wt.head = line:gsub("^HEAD ", "")
    elseif line:match("^branch ") then
      current_wt.branch = line:gsub("^branch refs/heads/", "")
      table.insert(worktrees, current_wt)
      current_wt = {}
    elseif line:match("^detached") then
      current_wt.branch = "(detached)"
      table.insert(worktrees, current_wt)
      current_wt = {}
    end
  end

  return worktrees
end

-- Get git branches
function M.get_branches()
  local branches = {}
  local handle = io.popen("git branch --format='%(refname:short)' 2>/dev/null")
  if not handle then
    return branches
  end

  local output = handle:read("*a")
  handle:close()

  for branch in output:gmatch("[^\n]+") do
    table.insert(branches, branch)
  end

  return branches
end

-- Get current branch
function M.get_current_branch()
  local handle = io.popen("git branch --show-current 2>/dev/null")
  if not handle then
    return nil
  end
  local branch = handle:read("*l")
  handle:close()
  return branch
end

-- Render tab bar content
function M.render()
  local icons = M.config.icons
  local parts = {}

  -- Add button
  table.insert(parts, " " .. icons.add .. " ")

  -- Sort tabs: pinned first, then by position
  local sorted_tabs = {}
  for _, tab in ipairs(M.state.tabs) do
    table.insert(sorted_tabs, tab)
  end
  table.sort(sorted_tabs, function(a, b)
    if a.pinned and not b.pinned then return true end
    if not a.pinned and b.pinned then return false end
    return false -- Keep original order otherwise
  end)

  -- Render each tab
  for _, tab in ipairs(sorted_tabs) do
    local icon = icons[tab.type] or icons.main
    local indicator = tab.id == M.state.active_tab and icons.active or icons.inactive
    local pinned_icon = tab.pinned and (icons.pinned .. " ") or ""
    local modified_icon = tab.modified and (icons.modified .. " ") or ""
    local group_icon = ""
    if tab.group then
      local group = M.get_group(tab.group)
      if group then
        group_icon = icons.group .. " "
      end
    end
    local close = tab.pinned and "" or (" " .. icons.close)

    local tab_text = string.format(" %s%s%s%s %s%s ", indicator, pinned_icon, group_icon, icon, tab.name, close)
    table.insert(parts, tab_text)
  end

  -- Fill remaining space
  local line = table.concat(parts, "│")

  return { line }
end

-- Update tab bar display
function M.refresh()
  if not M.state.bar_bufnr or not vim.api.nvim_buf_is_valid(M.state.bar_bufnr) then
    return
  end

  local lines = M.render()
  vim.bo[M.state.bar_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(M.state.bar_bufnr, 0, -1, false, lines)
  vim.bo[M.state.bar_bufnr].modifiable = false

  M.apply_highlights()

  -- Persist state if enabled
  if M.config.persist.enabled then
    M.save_state()
  end
end

-- Apply syntax highlighting to tab bar
function M.apply_highlights()
  if not M.state.bar_bufnr or not vim.api.nvim_buf_is_valid(M.state.bar_bufnr) then
    return
  end

  local ns = vim.api.nvim_create_namespace("ccasp_browser_tabs")
  vim.api.nvim_buf_clear_namespace(M.state.bar_bufnr, ns, 0, -1)

  -- Full line background
  vim.api.nvim_buf_add_highlight(M.state.bar_bufnr, ns, M.config.colors.bar_bg, 0, 0, -1)

  local line = vim.api.nvim_buf_get_lines(M.state.bar_bufnr, 0, 1, false)[1] or ""

  -- Find and highlight the active tab
  for match_start, match_end in line:gmatch("()●.-()│") do
    vim.api.nvim_buf_add_highlight(M.state.bar_bufnr, ns, M.config.colors.active_bg, 0, match_start - 1, match_end - 1)
  end

  -- Highlight pinned tabs
  local icons = M.config.icons
  local pin_pattern = icons.pinned:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  for match_start in line:gmatch("()" .. pin_pattern) do
    vim.api.nvim_buf_add_highlight(M.state.bar_bufnr, ns, M.config.colors.pinned, 0, match_start - 1, match_start + #icons.pinned - 1)
  end

  -- Highlight group indicators with their colors
  for _, tab in ipairs(M.state.tabs) do
    if tab.group then
      local group = M.get_group(tab.group)
      if group then
        local color = M.config.colors["group_" .. tostring(group.color_index)] or M.config.colors.group_1
        -- Find the group icon for this tab and highlight it
        -- (simplified - in practice would need exact position)
      end
    end
  end
end

-- Show context menu at mouse position
function M.show_context_menu(menu_type, context)
  local items = {}

  if menu_type == "new_session" then
    items = {
      { label = " New Main Session", action = "new_main" },
      { label = " New Worktree Session", action = "new_worktree" },
      { label = " New Branch Session", action = "new_branch" },
      { label = "───────────────────", action = nil },
      { label = " Recent Sessions", action = "show_recent" },
      { label = "───────────────────", action = nil },
      { label = " Close All Sessions", action = "close_all" },
      { label = " Close All But Pinned", action = "close_unpinned" },
    }
  elseif menu_type == "tab" then
    local tab = context and M.get_tab(context.tab_id)
    local pin_label = (tab and tab.pinned) and " Unpin Tab" or " Pin Tab"

    items = {
      { label = pin_label, action = "toggle_pin", context = context },
      { label = " Rename Tab", action = "rename", context = context },
      { label = " Duplicate Session", action = "duplicate", context = context },
      { label = "───────────────────", action = nil },
      { label = "◆ Add to Group", action = "add_to_group", context = context },
      { label = "◇ Remove from Group", action = "remove_from_group", context = context },
      { label = "───────────────────", action = nil },
      { label = " Move Left", action = "move_left", context = context },
      { label = " Move Right", action = "move_right", context = context },
      { label = "───────────────────", action = nil },
      { label = " Close Tab", action = "close", context = context },
      { label = " Close Others", action = "close_others", context = context },
      { label = " Close Tabs to Right", action = "close_right", context = context },
    }
  end

  M.show_menu_popup(items)
end

-- Show menu popup window (context menu at mouse position)
function M.show_menu_popup(items)
  picker_popup.show({
    items = items,
    centered = false, -- Use mouse position
    on_select = function(item)
      if item and item.action then
        M.execute_action(item.action, item.context)
      end
    end,
  })
end

-- Execute menu action (dispatch table pattern)
function M.execute_action(action, context)
  local actions = {
    new_main = function()
      require("ccasp.runtime_picker").open({
        prompt = "New session type",
        on_select = function(name) M.new_session("main", nil, nil, name) end,
      })
    end,
    new_worktree = function() M.show_worktree_picker() end,
    new_branch = function() M.show_branch_picker() end,
    show_recent = function() M.show_recent_sessions() end,
    close = function() if context then M.close_tab(context.tab_id) end end,
    close_all = function() M.close_all_tabs() end,
    close_unpinned = function() M.close_unpinned_tabs() end,
    close_others = function() if context then M.close_other_tabs(context.tab_id) end end,
    close_right = function() if context then M.close_tabs_to_right(context.tab_id) end end,
    rename = function() if context then M.rename_tab(context.tab_id) end end,
    duplicate = function() if context then M.duplicate_tab(context.tab_id) end end,
    toggle_pin = function() if context then M.toggle_pin(context.tab_id) end end,
    move_left = function() if context then M.move_tab_left(context.tab_id) end end,
    move_right = function() if context then M.move_tab_right(context.tab_id) end end,
    add_to_group = function() if context then M.show_group_picker(context.tab_id) end end,
    remove_from_group = function() if context then M.remove_from_group(context.tab_id) end end,
  }

  local handler = actions[action]
  if handler then
    handler()
  end
end

-- Show recent sessions picker
function M.show_recent_sessions()
  if #M.state.recent == 0 then
    vim.notify("No recent sessions", vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, session in ipairs(M.state.recent) do
    local icon = M.config.icons[session.type] or M.config.icons.main
    local time_ago = M.format_time_ago(session.closed_at)
    local label = string.format(" %s %s (%s)", icon, session.name, time_ago)
    table.insert(items, {
      label = label,
      action = "restore_recent",
      context = { index = i },
    })
  end

  table.insert(items, { label = "───────────────────", action = nil })
  table.insert(items, { label = " Clear History", action = "clear_recent" })

  M.show_picker_window("Recent Sessions", items, function(item)
    if item.action == "restore_recent" then
      M.restore_recent_session(item.context.index)
    elseif item.action == "clear_recent" then
      M.state.recent = {}
      vim.notify("Recent sessions cleared", vim.log.levels.INFO)
    end
  end)
end

-- Format time ago
function M.format_time_ago(timestamp)
  if not timestamp then return "unknown" end
  local diff = os.time() - timestamp
  if diff < 60 then return "just now" end
  if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
  if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
  return math.floor(diff / 86400) .. "d ago"
end

-- Restore a recent session
function M.restore_recent_session(index)
  local session = M.state.recent[index]
  if not session then return end

  M.new_session(session.type, session.path, session.branch)

  -- Remove from recent
  table.remove(M.state.recent, index)
end

-- Show worktree picker popup
function M.show_worktree_picker()
  local worktrees = M.get_worktrees()

  if #worktrees == 0 then
    vim.notify("No git worktrees found", vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, wt in ipairs(worktrees) do
    local label = string.format(" %s (%s)", wt.branch or "unknown", wt.path)
    table.insert(items, {
      label = label,
      action = "select_worktree",
      context = { path = wt.path, branch = wt.branch },
    })
  end

  table.insert(items, { label = "───────────────────", action = nil })
  table.insert(items, { label = " Create New Worktree", action = "create_worktree" })

  M.show_picker_window("Select Worktree", items, function(item)
    if item.action == "select_worktree" then
      M.new_session("worktree", item.context.path, item.context.branch)
    elseif item.action == "create_worktree" then
      M.create_worktree_dialog()
    end
  end)
end

-- Show branch picker popup
function M.show_branch_picker()
  local branches = M.get_branches()

  if #branches == 0 then
    vim.notify("No git branches found", vim.log.levels.WARN)
    return
  end

  local current = M.get_current_branch()
  local items = {}

  for _, branch in ipairs(branches) do
    local icon = branch == current and "●" or "○"
    local label = string.format(" %s %s", icon, branch)
    table.insert(items, {
      label = label,
      action = "select_branch",
      context = { branch = branch },
    })
  end

  table.insert(items, { label = "───────────────────", action = nil })
  table.insert(items, { label = " Create New Branch", action = "create_branch" })

  M.show_picker_window("Select Branch", items, function(item)
    if item.action == "select_branch" then
      M.new_session("branch", nil, item.context.branch)
    elseif item.action == "create_branch" then
      M.create_branch_dialog()
    end
  end)
end

-- Show group picker
function M.show_group_picker(tab_id)
  local items = {}

  -- Existing groups
  for _, group in ipairs(M.state.groups) do
    local color_name = "Color " .. group.color_index
    local label = string.format("◆ %s (%s)", group.name, color_name)
    table.insert(items, {
      label = label,
      action = "select_group",
      context = { tab_id = tab_id, group_id = group.id },
    })
  end

  if #M.state.groups > 0 then
    table.insert(items, { label = "───────────────────", action = nil })
  end

  table.insert(items, { label = "+ Create New Group", action = "create_group", context = { tab_id = tab_id } })

  M.show_picker_window("Add to Group", items, function(item)
    if item.action == "select_group" then
      M.add_to_group(item.context.tab_id, item.context.group_id)
    elseif item.action == "create_group" then
      M.create_group_dialog(item.context.tab_id)
    end
  end)
end

-- Create group dialog
function M.create_group_dialog(tab_id)
  vim.ui.input({ prompt = "Group name: " }, function(name)
    if not name or name == "" then return end

    local group_id = generate_group_id()
    local color_index = (#M.state.groups % 4) + 1

    table.insert(M.state.groups, {
      id = group_id,
      name = name,
      color_index = color_index,
    })

    if tab_id then
      M.add_to_group(tab_id, group_id)
    end

    vim.notify("Created group: " .. name, vim.log.levels.INFO)
  end)
end

-- Add tab to group
function M.add_to_group(tab_id, group_id)
  local tab = M.get_tab(tab_id)
  if tab then
    tab.group = group_id
    M.refresh()
  end
end

-- Remove tab from group
function M.remove_from_group(tab_id)
  local tab = M.get_tab(tab_id)
  if tab then
    tab.group = nil
    M.refresh()
  end
end

-- Get group by ID
function M.get_group(group_id)
  for _, group in ipairs(M.state.groups) do
    if group.id == group_id then
      return group
    end
  end
  return nil
end

-- Show generic picker window (centered on screen)
function M.show_picker_window(title, items, on_select)
  picker_popup.show({
    items = items,
    title = title,
    centered = true, -- Center on screen
    on_select = function(item)
      if item and item.action and on_select then
        on_select(item)
      end
    end,
  })
end

-- Create new session
-- runtime_name picks which agent CLI the tab drives; defaults to the
-- configured runtime.
function M.new_session(session_type, path, branch, runtime_name)
  -- Check max tabs
  if #M.state.tabs >= M.config.max_tabs then
    vim.notify("Maximum tabs reached (" .. M.config.max_tabs .. ")", vim.log.levels.WARN)
    return
  end

  local terminal = require("ccasp.terminal")

  -- Determine working directory
  local cwd = path or vim.fn.getcwd()
  local name = branch or vim.fn.fnamemodify(cwd, ":t")

  if session_type == "branch" and branch then
    name = branch
  elseif session_type == "worktree" and branch then
    name = branch
  else
    name = "main"
  end

  -- Create tab entry
  local tab_id = generate_id()
  local tab = {
    id = tab_id,
    name = name,
    type = session_type,
    path = cwd,
    branch = branch,
    winid = nil,
    bufnr = nil,
    job_id = nil,
    active = false,
    pinned = false,
    group = nil,
    modified = false,
    runtime = require("ccasp.runtime").normalize(runtime_name),
    created_at = os.time(),
  }

  table.insert(M.state.tabs, tab)

  -- Create terminal for this session
  M.create_terminal_for_tab(tab_id, cwd, tab.runtime)

  -- Set as active
  M.activate_tab(tab_id)

  M.refresh()

  vim.notify(string.format("Created %s session: %s", session_type, name), vim.log.levels.INFO)

  return tab_id
end

-- Create terminal for a tab
function M.create_terminal_for_tab(tab_id, cwd, runtime_name)
  local tab = M.get_tab(tab_id)
  if not tab then
    return
  end

  -- Create a new terminal buffer
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[term_buf].bufhidden = "hide"

  -- Unlike sessions.lua this execs the CLI directly rather than typing it into
  -- a shell, so the runtime has to be resolved up front.
  local runtime = require("ccasp.runtime")
  local resolved = runtime.normalize(runtime_name) or runtime.normalize(tab.runtime) or runtime.default()

  -- Start terminal job
  vim.api.nvim_buf_call(term_buf, function()
    vim.fn.termopen(runtime.command(resolved), {
      cwd = cwd,
      on_exit = function(_, exit_code)
        tab.job_id = nil
        M.refresh()
      end,
    })
  end)

  tab.bufnr = term_buf
  tab.job_id = vim.b[term_buf].terminal_job_id
end

-- Get tab by ID
function M.get_tab(tab_id)
  for _, tab in ipairs(M.state.tabs) do
    if tab.id == tab_id then
      return tab
    end
  end
  return nil
end

-- Get tab index
function M.get_tab_index(tab_id)
  for i, tab in ipairs(M.state.tabs) do
    if tab.id == tab_id then
      return i
    end
  end
  return nil
end

-- Activate a tab (show its terminal)
function M.activate_tab(tab_id)
  local tab = M.get_tab(tab_id)
  if not tab then
    return
  end

  -- Deactivate all tabs
  for _, t in ipairs(M.state.tabs) do
    t.active = false
  end

  -- Activate this tab
  tab.active = true
  M.state.active_tab = tab_id

  -- Show the tab's terminal buffer
  if tab.bufnr and vim.api.nvim_buf_is_valid(tab.bufnr) then
    local terminal = require("ccasp.terminal")
    -- If terminal is open, switch to this buffer
    if terminal.is_open() then
      local term_win = vim.fn.win_findbuf(tab.bufnr)
      if #term_win == 0 then
        -- Buffer not displayed, need to display it
        -- Find terminal window and switch buffer
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].buftype == "terminal" then
            vim.api.nvim_win_set_buf(win, tab.bufnr)
            break
          end
        end
      end
    end
  end

  M.refresh()
end

-- Toggle pin status
function M.toggle_pin(tab_id)
  local tab = M.get_tab(tab_id)
  if tab then
    tab.pinned = not tab.pinned
    M.refresh()
    vim.notify(tab.pinned and "Tab pinned" or "Tab unpinned", vim.log.levels.INFO)
  end
end

-- Move tab left
function M.move_tab_left(tab_id)
  local index = M.get_tab_index(tab_id)
  if not index or index <= 1 then return end

  -- Don't move past pinned tabs
  local prev_tab = M.state.tabs[index - 1]
  if prev_tab.pinned and not M.get_tab(tab_id).pinned then
    return
  end

  M.state.tabs[index], M.state.tabs[index - 1] = M.state.tabs[index - 1], M.state.tabs[index]
  M.refresh()
end

-- Move tab right
function M.move_tab_right(tab_id)
  local index = M.get_tab_index(tab_id)
  if not index or index >= #M.state.tabs then return end

  -- Don't move pinned tabs past unpinned
  local tab = M.get_tab(tab_id)
  local next_tab = M.state.tabs[index + 1]
  if tab.pinned and not next_tab.pinned then
    return
  end

  M.state.tabs[index], M.state.tabs[index + 1] = M.state.tabs[index + 1], M.state.tabs[index]
  M.refresh()
end

-- Close tabs matching a filter function
-- @param filter_fn function(tab, index) -> boolean - return true to close the tab
local function close_tabs_filtered(filter_fn)
  local ids = {}
  for i, tab in ipairs(M.state.tabs) do
    if filter_fn(tab, i) then
      table.insert(ids, tab.id)
    end
  end

  for _, id in ipairs(ids) do
    M.close_tab(id)
  end
end

-- Close a tab
function M.close_tab(tab_id)
  local tab = M.get_tab(tab_id)
  if not tab then
    return
  end

  -- Add to recent sessions
  M.add_to_recent(tab)

  -- Kill terminal job if running
  if tab.job_id then
    vim.fn.jobstop(tab.job_id)
  end

  -- Delete buffer
  if tab.bufnr and vim.api.nvim_buf_is_valid(tab.bufnr) then
    vim.api.nvim_buf_delete(tab.bufnr, { force = true })
  end

  -- Remove from tabs
  for i, t in ipairs(M.state.tabs) do
    if t.id == tab_id then
      table.remove(M.state.tabs, i)
      break
    end
  end

  -- If closed active tab, activate another
  if M.state.active_tab == tab_id then
    M.state.active_tab = nil
    if #M.state.tabs > 0 then
      M.activate_tab(M.state.tabs[1].id)
    end
  end

  M.refresh()
end

-- Add tab to recent sessions
function M.add_to_recent(tab)
  table.insert(M.state.recent, 1, {
    name = tab.name,
    type = tab.type,
    path = tab.path,
    branch = tab.branch,
    closed_at = os.time(),
  })

  -- Trim to max
  while #M.state.recent > M.state.max_recent do
    table.remove(M.state.recent)
  end
end

-- Close all tabs
function M.close_all_tabs()
  close_tabs_filtered(function() return true end)
end

-- Close all unpinned tabs
function M.close_unpinned_tabs()
  close_tabs_filtered(function(tab) return not tab.pinned end)
end

-- Close other tabs (keep one)
function M.close_other_tabs(keep_tab_id)
  close_tabs_filtered(function(tab) return tab.id ~= keep_tab_id and not tab.pinned end)
end

-- Close tabs to the right
function M.close_tabs_to_right(tab_id)
  local ref_index = M.get_tab_index(tab_id)
  if not ref_index then return end
  close_tabs_filtered(function(tab, i) return i > ref_index and not tab.pinned end)
end

-- Rename tab dialog
function M.rename_tab(tab_id)
  local tab = M.get_tab(tab_id)
  if not tab then
    return
  end

  vim.ui.input({ prompt = "New name: ", default = tab.name }, function(input)
    if input and input ~= "" then
      tab.name = input
      M.refresh()
    end
  end)
end

-- Duplicate tab
function M.duplicate_tab(tab_id)
  local tab = M.get_tab(tab_id)
  if not tab then
    return
  end

  M.new_session(tab.type, tab.path, tab.branch)
end

-- Create worktree dialog
function M.create_worktree_dialog()
  vim.ui.input({ prompt = "Branch name for new worktree: " }, function(branch)
    if not branch or branch == "" then
      return
    end

    vim.ui.input({ prompt = "Worktree path: ", default = "../" .. branch }, function(path)
      if not path or path == "" then
        return
      end

      -- Create worktree
      local cmd = string.format("git worktree add %s -b %s 2>&1", vim.fn.shellescape(path), vim.fn.shellescape(branch))
      local output = vim.fn.system(cmd)

      if vim.v.shell_error == 0 then
        vim.notify("Created worktree: " .. path, vim.log.levels.INFO)
        M.new_session("worktree", path, branch)
      else
        vim.notify("Failed to create worktree: " .. output, vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Create branch dialog
function M.create_branch_dialog()
  vim.ui.input({ prompt = "New branch name: " }, function(branch)
    if not branch or branch == "" then
      return
    end

    -- Create and checkout branch
    local cmd = string.format("git checkout -b %s 2>&1", vim.fn.shellescape(branch))
    local output = vim.fn.system(cmd)

    if vim.v.shell_error == 0 then
      vim.notify("Created branch: " .. branch, vim.log.levels.INFO)
      M.new_session("branch", nil, branch)
    else
      vim.notify("Failed to create branch: " .. output, vim.log.levels.ERROR)
    end
  end)
end

-- Create the tab bar window
function M.create_bar(terminal_winid)
  if M.state.bar_winid and vim.api.nvim_win_is_valid(M.state.bar_winid) then
    return -- Already exists
  end

  -- Create buffer
  M.state.bar_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[M.state.bar_bufnr].buftype = "nofile"
  vim.bo[M.state.bar_bufnr].bufhidden = "wipe"
  vim.bo[M.state.bar_bufnr].swapfile = false

  -- Get terminal window position
  local term_config = vim.api.nvim_win_get_config(terminal_winid)
  local term_pos = vim.api.nvim_win_get_position(terminal_winid)
  local term_width = vim.api.nvim_win_get_width(terminal_winid)

  -- Create tab bar above terminal
  local bar_row = term_pos[1] - M.config.height - 1
  if bar_row < 0 then
    bar_row = 0
  end

  M.state.bar_winid = vim.api.nvim_open_win(M.state.bar_bufnr, false, {
    relative = "editor",
    row = bar_row,
    col = term_pos[2],
    width = term_width,
    height = M.config.height,
    style = "minimal",
    focusable = true,
    zindex = 100,
  })

  -- Set window options
  vim.wo[M.state.bar_winid].wrap = false
  vim.wo[M.state.bar_winid].cursorline = false

  -- Setup keymaps
  M.setup_bar_keymaps()

  -- Initial render
  M.refresh()
end

-- Setup mouse handlers for tab bar
local function setup_mouse_handlers(opts)
  -- Right-click shows context menu
  vim.keymap.set("n", "<RightMouse>", function()
    local mouse_pos = vim.fn.getmousepos()
    local col = mouse_pos.column

    -- Check if click is near the + button (beginning of line)
    if col <= 4 then
      M.show_context_menu("new_session")
    else
      -- Find which tab was clicked
      local clicked_tab = M.get_tab_at_column(col)
      if clicked_tab then
        M.show_context_menu("tab", { tab_id = clicked_tab.id })
      else
        M.show_context_menu("new_session")
      end
    end
  end, opts)

  -- Left-click on tab activates it or closes it
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse_pos = vim.fn.getmousepos()
    local col = mouse_pos.column

    -- Check if click is on + button
    if col <= 4 then
      M.show_context_menu("new_session")
      return
    end

    -- Check if click is on a tab
    local clicked_tab = M.get_tab_at_column(col)
    if clicked_tab then
      -- Check if click is on close button (last few chars of tab, unless pinned)
      if not clicked_tab.pinned then
        local tab_end = M.get_tab_end_column(clicked_tab.id)
        if tab_end and col >= tab_end - 3 then
          M.close_tab(clicked_tab.id)
          return
        end
      end
      M.activate_tab(clicked_tab.id)
    end
  end, opts)

  -- Middle-click closes tab
  vim.keymap.set("n", "<MiddleMouse>", function()
    local mouse_pos = vim.fn.getmousepos()
    local col = mouse_pos.column

    local clicked_tab = M.get_tab_at_column(col)
    if clicked_tab and not clicked_tab.pinned then
      M.close_tab(clicked_tab.id)
    end
  end, opts)

  -- Double-click pins/unpins
  vim.keymap.set("n", "<2-LeftMouse>", function()
    local mouse_pos = vim.fn.getmousepos()
    local col = mouse_pos.column

    local clicked_tab = M.get_tab_at_column(col)
    if clicked_tab then
      M.toggle_pin(clicked_tab.id)
    end
  end, opts)

  -- Drag support for reordering
  vim.keymap.set("n", "<LeftDrag>", function()
    if not M.state.dragging then
      local mouse_pos = vim.fn.getmousepos()
      local col = mouse_pos.column
      local clicked_tab = M.get_tab_at_column(col)
      if clicked_tab then
        M.state.dragging = true
        M.state.drag_tab_id = clicked_tab.id
        M.state.drag_start_col = col
      end
    end
  end, opts)

  vim.keymap.set("n", "<LeftRelease>", function()
    if M.state.dragging and M.state.drag_tab_id then
      local mouse_pos = vim.fn.getmousepos()
      local col = mouse_pos.column
      local target_tab = M.get_tab_at_column(col)

      if target_tab and target_tab.id ~= M.state.drag_tab_id then
        M.reorder_tabs(M.state.drag_tab_id, target_tab.id)
      end
    end

    M.state.dragging = false
    M.state.drag_tab_id = nil
    M.state.drag_start_col = nil
  end, opts)
end

-- Setup keyboard navigation for tab bar
local function setup_keyboard_nav(opts)
  -- Arrow keys and h/l for navigation
  vim.keymap.set("n", "h", function() M.navigate_tabs(-1) end, opts)
  vim.keymap.set("n", "l", function() M.navigate_tabs(1) end, opts)
  vim.keymap.set("n", "<Left>", function() M.navigate_tabs(-1) end, opts)
  vim.keymap.set("n", "<Right>", function() M.navigate_tabs(1) end, opts)
  vim.keymap.set("n", "<Tab>", function() M.navigate_tabs(1) end, opts)
  vim.keymap.set("n", "<S-Tab>", function() M.navigate_tabs(-1) end, opts)

  -- Close and pin current tab
  vim.keymap.set("n", "x", function()
    if M.state.active_tab then
      local tab = M.get_tab(M.state.active_tab)
      if tab and not tab.pinned then
        M.close_tab(M.state.active_tab)
      end
    end
  end, opts)

  vim.keymap.set("n", "p", function()
    if M.state.active_tab then
      M.toggle_pin(M.state.active_tab)
    end
  end, opts)
end

-- Setup tab number keys (1-9 to switch to tab)
local function setup_tab_number_keys(opts)
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      if M.state.tabs[i] then
        M.activate_tab(M.state.tabs[i].id)
      end
    end, opts)
  end
end

-- Setup keymaps for tab bar
function M.setup_bar_keymaps()
  if not M.state.bar_bufnr then
    return
  end

  local opts = { buffer = M.state.bar_bufnr, nowait = true, silent = true }

  setup_mouse_handlers(opts)
  setup_keyboard_nav(opts)
  setup_tab_number_keys(opts)
end

-- Navigate tabs with keyboard
function M.navigate_tabs(direction)
  if #M.state.tabs == 0 then return end

  local current_index = 1
  if M.state.active_tab then
    current_index = M.get_tab_index(M.state.active_tab) or 1
  end

  local new_index = current_index + direction
  if new_index < 1 then new_index = #M.state.tabs end
  if new_index > #M.state.tabs then new_index = 1 end

  M.activate_tab(M.state.tabs[new_index].id)
end

-- Reorder tabs via drag
function M.reorder_tabs(source_id, target_id)
  local source_index = M.get_tab_index(source_id)
  local target_index = M.get_tab_index(target_id)

  if not source_index or not target_index then return end

  local source_tab = M.state.tabs[source_index]
  local target_tab = M.state.tabs[target_index]

  -- Don't allow moving unpinned before pinned
  if not source_tab.pinned and target_tab.pinned then
    return
  end

  -- Don't allow moving pinned after unpinned
  if source_tab.pinned and not target_tab.pinned and target_index > source_index then
    return
  end

  -- Remove and insert
  table.remove(M.state.tabs, source_index)
  table.insert(M.state.tabs, target_index, source_tab)

  M.refresh()
end

-- Get tab at column position
function M.get_tab_at_column(col)
  local pos = 5 -- After the + button

  for _, tab in ipairs(M.state.tabs) do
    local tab_width = #tab.name + 8 -- icon + indicators + spacing
    if tab.pinned then
      tab_width = tab_width + 2 -- pin icon
    end
    if col >= pos and col < pos + tab_width then
      return tab
    end
    pos = pos + tab_width + 1 -- +1 for separator
  end

  return nil
end

-- Get end column of a tab
function M.get_tab_end_column(tab_id)
  local pos = 5

  for _, tab in ipairs(M.state.tabs) do
    local tab_width = #tab.name + 8
    if tab.pinned then
      tab_width = tab_width + 2
    end
    if tab.id == tab_id then
      return pos + tab_width
    end
    pos = pos + tab_width + 1
  end

  return nil
end

-- Close tab bar
function M.close_bar()
  if M.state.bar_winid and vim.api.nvim_win_is_valid(M.state.bar_winid) then
    vim.api.nvim_win_close(M.state.bar_winid, true)
  end
  M.state.bar_winid = nil
  M.state.bar_bufnr = nil
end

-- Save state to file
function M.save_state()
  local persist_path = vim.fn.getcwd() .. "/" .. M.config.persist.file

  -- Create directory if needed
  local dir = vim.fn.fnamemodify(persist_path, ":h")
  vim.fn.mkdir(dir, "p")

  -- Build save data (exclude bufnr, job_id, winid as they won't be valid)
  local save_data = {
    tabs = {},
    groups = M.state.groups,
    recent = M.state.recent,
    next_id = M.state.next_id,
    next_group_id = M.state.next_group_id,
  }

  for _, tab in ipairs(M.state.tabs) do
    table.insert(save_data.tabs, {
      id = tab.id,
      name = tab.name,
      type = tab.type,
      path = tab.path,
      branch = tab.branch,
      pinned = tab.pinned,
      group = tab.group,
      created_at = tab.created_at,
    })
  end

  -- Write file
  local json = vim.fn.json_encode(save_data)
  local file = io.open(persist_path, "w")
  if file then
    file:write(json)
    file:close()
  end
end

-- Load state from file
function M.load_state()
  local persist_path = vim.fn.getcwd() .. "/" .. M.config.persist.file

  local file = io.open(persist_path, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    return
  end

  -- Restore state
  M.state.groups = data.groups or {}
  M.state.recent = data.recent or {}
  M.state.next_id = data.next_id or 1
  M.state.next_group_id = data.next_group_id or 1

  -- Note: tabs need to be recreated (terminals aren't persisted)
  -- Just load the metadata for reference
  if data.tabs and #data.tabs > 0 then
    vim.notify(string.format("CCASP: %d previous sessions available. Use Recent Sessions to restore.", #data.tabs), vim.log.levels.INFO)

    -- Add to recent so they can be restored
    for _, tab in ipairs(data.tabs) do
      table.insert(M.state.recent, 1, {
        name = tab.name,
        type = tab.type,
        path = tab.path,
        branch = tab.branch,
        closed_at = os.time(),
      })
    end

    -- Trim recent to max
    while #M.state.recent > M.state.max_recent do
      table.remove(M.state.recent)
    end
  end
end

-- Get tab count
function M.count()
  return #M.state.tabs
end

-- Check if has tabs
function M.has_tabs()
  return #M.state.tabs > 0
end

return M
