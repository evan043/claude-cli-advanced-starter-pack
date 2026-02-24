-- CCASP Session Title Bar
-- Uses winbar (window-local statusline at top) for session titles
-- Much simpler and more reliable than floating windows

local M = {}
local nf = require("ccasp.ui.icons")

-- Debounce timer for autocmd updates
local _update_timer = nil

-- Available colors for title bars (dark blue/teal/steel palette)
M.colors = {
  { name = "Blue", fg = "#61afef", bg = "#1e3a5f" },
  { name = "Green", fg = "#98c379", bg = "#1e3a2a" },
  { name = "Teal", fg = "#56b6c2", bg = "#1e4a5f" },
  { name = "Steel", fg = "#5fafff", bg = "#1a2a4a" },
  { name = "Slate", fg = "#8899aa", bg = "#2a3040" },
  { name = "Ice", fg = "#7ec8e3", bg = "#1e3a4f" },
  { name = "Navy", fg = "#4a8fcf", bg = "#0d1a2f" },
  { name = "Mint", fg = "#6fcf97", bg = "#1a3a2a" },
  { name = "Gold", fg = "#e5c07b", bg = "#3a2f1a" },
}

-- Named color index constants
M.COLOR_GOLD = 9

-- Session color assignments
local session_colors = {} -- { session_id = color_idx }

-- Minimized sessions storage
local minimized = {} -- { session_id = { name, color_idx, bufnr, minimized_at } }
local minimized_counter = 0 -- tracks order of minimization for display sorting

-- Active session border color (steel blue for visibility)
local ACTIVE_BORDER_COLOR = "#3a7fcf"
local INACTIVE_BORDER_COLOR = "#1e2a3a"

-- Create single highlight group set
local function create_highlight_group(name, fg, bg, bold)
  vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg, bold = bold or false })
end

-- Create highlight groups for each color
local function setup_highlights()
  for i, color in ipairs(M.colors) do
    create_highlight_group("CcaspWinbar" .. i, color.fg, color.bg, true)
    create_highlight_group("CcaspWinbarBtn" .. i, "#56b6c2", color.bg, true)
    create_highlight_group("CcaspWinbarActive" .. i, "#ffffff", color.bg, true)
    -- Dimmed variant: muted grey fg, same per-color bg (used when Claude is streaming)
    create_highlight_group("CcaspWinbarDim" .. i, "#5c6370", color.bg, false)
  end

  create_highlight_group("CcaspWinbarDefault", "#8899aa", "#1e2a3a", true)
  create_highlight_group("CcaspActiveBorder", ACTIVE_BORDER_COLOR, nil, true)
  create_highlight_group("CcaspInactiveBorder", INACTIVE_BORDER_COLOR, nil)
end

-- Get or assign color for session
local function get_color_idx(session_id)
  if session_colors[session_id] then
    return session_colors[session_id]
  end
  -- Assign next available color
  local used = {}
  for _, idx in pairs(session_colors) do
    used[idx] = true
  end
  for i = 1, #M.colors do
    if not used[i] then
      session_colors[session_id] = i
      return i
    end
  end
  -- All colors used, cycle
  session_colors[session_id] = 1
  return 1
end

-- Lookup current session from window (used by winbar click handlers)
local function get_current_session()
  local sessions = require("ccasp.sessions")
  local win = vim.api.nvim_get_current_win()
  return sessions.get_by_window(win)
end

-- Helper: exit terminal mode before opening a modal dialog
local function exit_terminal_and_run(fn)
  vim.schedule(function()
    local mode = vim.api.nvim_get_mode().mode
    if mode == "t" then
      local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
      vim.api.nvim_feedkeys(esc, "n", false)
      vim.schedule(fn)
    else
      fn()
    end
  end)
end

-- Setup global click handlers for winbar icon buttons
-- Uses %@v:lua.FuncName@text%X statusline click syntax
local function setup_click_handlers()
  _G.CcaspTitlebar_cycle = function(_, _, button, _)
    if button ~= "l" then return end
    vim.schedule(function()
      require("ccasp.sessions").focus_next()
    end)
  end

  _G.CcaspTitlebar_rename = function(_, _, button, _)
    if button ~= "l" then return end
    exit_terminal_and_run(function()
      local session = get_current_session()
      if session then M.rename(session.id) end
    end)
  end

  _G.CcaspTitlebar_color = function(_, _, button, _)
    if button ~= "l" then return end
    exit_terminal_and_run(function()
      local session = get_current_session()
      if session then M.change_color(session.id) end
    end)
  end

  _G.CcaspTitlebar_minimize = function(_, _, button, _)
    if button ~= "l" then return end
    vim.schedule(function()
      local session = get_current_session()
      if session then M.minimize(session.id) end
    end)
  end

  _G.CcaspTitlebar_close = function(_, _, button, _)
    if button ~= "l" then return end
    exit_terminal_and_run(function()
      local session = get_current_session()
      if session then M.close_session(session.id) end
    end)
  end

  _G.CcaspTitlebar_save_note = function(_, _, button, _)
    if button ~= "l" then return end
    exit_terminal_and_run(function()
      local session = get_current_session()
      if session then
        require("ccasp.saved_notes").save_note(session.id)
      end
    end)
  end

  _G.CcaspTitlebar_screenshot_browse = function(_, _, button, _)
    if button ~= "l" then return end
    exit_terminal_and_run(function()
      local session = get_current_session()
      if session then
        require("ccasp.panels.screenshot_browser").open(session.id)
      end
    end)
  end

  _G.CcaspTitlebar_todo = function(_, _, button, _)
    if button ~= "l" then return end
    exit_terminal_and_run(function()
      require("ccasp.panels.todos").toggle()
    end)
  end

  _G.CcaspTitlebar_screenshot = function(_, _, button, _)
    if button ~= "l" then return end
    vim.schedule(function()
      local session = get_current_session()
      if not session then return end

      -- Find the most recent file in Snipping Tool directory
      local snip_dir = vim.fn.expand("~/OneDrive/Pictures/Snipping Tool")
      local files = vim.fn.glob(snip_dir .. "/*", false, true)
      if #files == 0 then
        vim.notify("No screenshots found in Snipping Tool folder", vim.log.levels.WARN)
        return
      end

      -- Sort by modification time (newest first)
      table.sort(files, function(a, b)
        return vim.fn.getftime(a) > vim.fn.getftime(b)
      end)

      local newest = files[1]

      -- Send the file path directly to the pty channel.
      -- chansend() bypasses Neovim's modal state entirely, so calling it while
      -- Neovim is in normal mode (after the winbar click exited terminal mode)
      -- works correctly — Claude CLI receives the bytes and inserts them at its
      -- chatbox cursor, regardless of Neovim's current mode.
      -- Do NOT call sessions.focus() first: its normal!G scroll + startinsert
      -- run BEFORE chansend, and re-entering terminal mode can send terminal
      -- focus events (\x1b[I) that cause Claude CLI to reset cursor position,
      -- making the paste land in the wrong spot when the chatbox was active.
      if session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr) then
        local chan = vim.bo[session.bufnr].channel
        if chan and chan > 0 then
          vim.fn.chansend(chan, newest)
          vim.notify("Pasted: " .. vim.fn.fnamemodify(newest, ":t"), vim.log.levels.INFO)
        end
        -- Re-enter terminal mode AFTER the paste so the user can resume typing
        -- immediately without needing to click back into the chatbox.
        vim.schedule(function()
          local win = session.winid
          if win and vim.api.nvim_win_is_valid(win)
              and vim.api.nvim_get_current_win() == win then
            local mode = vim.api.nvim_get_mode().mode
            if mode ~= "t" then
              vim.cmd("startinsert")
            end
          end
        end)
      end
    end)
  end
end

-- Build winbar string for a session
local function build_winbar(session_id, name, is_primary, claude_running, is_active, activity)
  local color_idx = get_color_idx(session_id)
  local hl
  if is_active then
    hl = "CcaspWinbarActive" .. color_idx
  elseif activity == "working" then
    hl = "CcaspWinbarDim" .. color_idx
  else
    hl = "CcaspWinbar" .. color_idx
  end
  local btn_hl = "CcaspWinbarBtn" .. color_idx

  local status = claude_running and "●" or "○"
  local primary_marker = is_primary and " ★" or ""
  local active_marker = is_active and " ▶▶ ACTIVE ◀◀" or ""

  -- Clickable icon buttons using %@v:lua.FuncName@icon%X winbar click syntax
  -- Uses Material Design Nerd Font icons for cross-platform rendering
  -- Color matches title text (hl) instead of separate btn_hl
  local winbar = string.format(
    "%%#%s# %s %s%s%s %%=%%#%s#"
    .. " %%@v:lua.CcaspTitlebar_screenshot@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_screenshot_browse@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_cycle@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_rename@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_color@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_save_note@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_todo@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_minimize@  %s  %%X"
    .. "│%%@v:lua.CcaspTitlebar_close@  %s  %%X"
    .. " %%#%s# ",
    hl, status, name, primary_marker, active_marker,
    hl,
    nf.win_screenshot, nf.win_screenshot_browse, nf.win_cycle, nf.win_rename, nf.palette, nf.win_save_note, nf.win_todo, nf.win_minimize, nf.win_close,
    hl
  )

  return winbar
end

-- Apply winbar to a session's window
function M.create(session_id)
  local sessions = require("ccasp.sessions")
  local session = sessions.get(session_id)

  if not session or not session.winid or not vim.api.nvim_win_is_valid(session.winid) then
    return
  end

  -- Assign color if not already
  get_color_idx(session_id)

  -- Update winbar
  M.update(session_id)
end

-- Update winbar for a session
function M.update(session_id)
  -- Skip minimized sessions (their winid is nil or stale)
  if minimized[session_id] then return end

  local sessions = require("ccasp.sessions")
  local session = sessions.get(session_id)

  if not session or not session.winid or not vim.api.nvim_win_is_valid(session.winid) then
    return
  end

  local primary = sessions.get_primary()
  local is_primary = primary and primary.id == session_id

  -- Check if this session's window is the current/active window
  local current_win = vim.api.nvim_get_current_win()
  local is_active = session.winid == current_win

  -- Get activity state (working/done/idle) for dimmed winbar styling
  local activity = "idle"
  if sessions.get_activity then
    activity = sessions.get_activity(session_id) or "idle"
  end

  local winbar = build_winbar(
    session_id,
    session.name,
    is_primary,
    session.claude_running,
    is_active,
    activity
  )

  -- Set winbar for this window
  vim.wo[session.winid].winbar = winbar

  -- Set window border highlight based on active state
  local color_idx_val = session_colors[session_id] or 1
  if is_active then
    vim.wo[session.winid].winhighlight = "Normal:CcaspTerminalBg,NormalFloat:CcaspTerminalBg,EndOfBuffer:CcaspTerminalBg,WinBar:CcaspWinbarActive" .. color_idx_val .. ",WinBarNC:CcaspWinbar" .. color_idx_val .. ",WinSeparator:CcaspBorderActive"
  else
    vim.wo[session.winid].winhighlight = "Normal:CcaspTerminalBg,NormalFloat:CcaspTerminalBg,EndOfBuffer:CcaspTerminalBg,WinBar:CcaspWinbar" .. color_idx_val .. ",WinBarNC:CcaspWinbar" .. color_idx_val .. ",WinSeparator:CcaspBorderInactive"
  end

  -- Setup keymaps for this buffer
  M.setup_keymaps(session.bufnr, session_id)
end

-- Remove winbar (called on close)
function M.destroy(session_id)
  session_colors[session_id] = nil
  -- Winbar is automatically removed when window closes
end

-- Set session color directly (used by layout templates)
function M.set_color(session_id, color_idx)
  session_colors[session_id] = color_idx
  M.update(session_id)
end

-- Pre-assign color before titlebar creation (no update call)
function M.pre_assign_color(session_id, color_idx)
  session_colors[session_id] = color_idx
end

-- Update all session winbars
function M.update_all()
  local sessions = require("ccasp.sessions")
  local all_sessions = sessions.list()

  for _, session in ipairs(all_sessions) do
    M.update(session.id)
  end
end

-- Rename session via floating input modal
function M.rename(session_id)
  local helpers = require("ccasp.panels.helpers")
  local sessions = require("ccasp.sessions")
  local session = sessions.get(session_id)
  if not session then return end

  local width = 40
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { session.name })

  local pos = helpers.calculate_position({ width = width, height = 1 })
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = pos.width,
    height = 1,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. nf.win_rename .. "  Rename Session ",
    title_pos = "center",
    footer = " Enter: Apply │ Esc: Cancel ",
    footer_pos = "center",
    style = "minimal",
  })

  -- Enter insert mode at end of text
  vim.cmd("startinsert!")

  local function close_modal()
    vim.cmd("stopinsert")
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    helpers.restore_terminal_focus()
  end

  local function confirm()
    local new_name = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
    vim.cmd("stopinsert")
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if new_name ~= "" then
      session.name = new_name
      M.update(session_id)
      vim.notify("Session renamed to: " .. new_name, vim.log.levels.INFO)
    end
    helpers.restore_terminal_focus()
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("i", "<CR>", confirm, opts)
  vim.keymap.set("n", "<CR>", confirm, opts)
  vim.keymap.set("i", "<Esc>", close_modal, opts)
  vim.keymap.set("n", "<Esc>", close_modal, opts)
  vim.keymap.set("n", "q", close_modal, opts)
end

-- Change title bar color via floating color picker modal
function M.change_color(session_id)
  local helpers = require("ccasp.panels.helpers")
  local current_idx = session_colors[session_id] or 1

  local width = 34
  local height = #M.colors + 4

  local buf = helpers.create_buffer("ccasp://color-picker")
  local pos = helpers.calculate_position({ width = width, height = height })
  local win = helpers.create_window(buf, {
    width = pos.width,
    height = pos.height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. nf.palette .. "  Session Color ",
    footer = " Enter: Select │ Esc: Cancel ",
    footer_pos = "center",
  })

  vim.wo[win].cursorline = true

  -- Build content
  local lines = {}
  local item_lines = {}

  table.insert(lines, "")
  table.insert(lines, "  Select a color:")
  table.insert(lines, "")

  for i, color in ipairs(M.colors) do
    local marker = (i == current_idx) and "  ●" or ""
    table.insert(lines, string.format("    %s%s", color.name, marker))
    item_lines[#lines] = { color_idx = i }
  end

  table.insert(lines, "")

  helpers.set_buffer_content(buf, lines)
  helpers.sandbox_buffer(buf)

  -- Highlights: color each swatch line with its actual fg color
  local ns = helpers.prepare_highlights("ccasp_color_picker", buf)
  for i, line_text in ipairs(lines) do
    if line_text:match("Select") then
      vim.api.nvim_buf_add_highlight(buf, ns, "Title", i - 1, 0, -1)
    end
    for ci, color in ipairs(M.colors) do
      if line_text:match("^    " .. color.name) then
        local hl_name = "CcaspSwatch" .. ci
        vim.api.nvim_set_hl(0, hl_name, { fg = color.fg, bold = true })
        vim.api.nvim_buf_add_highlight(buf, ns, hl_name, i - 1, 4, -1)
      end
    end
  end

  local panel = { bufnr = buf, winid = win }
  local function close_modal()
    helpers.close_panel(panel)
  end

  local function apply_at_cursor()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local item = item_lines[cursor[1]]
    if item and item.color_idx then
      session_colors[session_id] = item.color_idx
      M.update(session_id)
      close_modal()
      vim.notify("Color: " .. M.colors[item.color_idx].name, vim.log.levels.INFO)
    end
  end

  -- Keymaps
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", apply_at_cursor, opts)
  vim.keymap.set("n", "q", close_modal, opts)
  vim.keymap.set("n", "<Esc>", close_modal, opts)

  -- Navigation
  local function nav_down()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local total = vim.api.nvim_buf_line_count(buf)
    for line = cursor[1] + 1, total do
      if item_lines[line] then
        vim.api.nvim_win_set_cursor(win, { line, 0 })
        return
      end
    end
  end

  local function nav_up()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    for line = cursor[1] - 1, 1, -1 do
      if item_lines[line] then
        vim.api.nvim_win_set_cursor(win, { line, 0 })
        return
      end
    end
  end

  vim.keymap.set("n", "j", nav_down, opts)
  vim.keymap.set("n", "k", nav_up, opts)
  vim.keymap.set("n", "<Down>", nav_down, opts)
  vim.keymap.set("n", "<Up>", nav_up, opts)

  -- Mouse click
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local line = mouse.line
    if line < 1 then return end
    pcall(vim.api.nvim_win_set_cursor, win, { line, 0 })
    local item = item_lines[line]
    if item and item.color_idx then
      session_colors[session_id] = item.color_idx
      M.update(session_id)
      close_modal()
      vim.notify("Color: " .. M.colors[item.color_idx].name, vim.log.levels.INFO)
    end
  end, opts)

  -- Position cursor on current color
  for line = 1, #lines do
    if item_lines[line] and item_lines[line].color_idx == current_idx then
      vim.api.nvim_win_set_cursor(win, { line, 0 })
      break
    end
  end
end

-- Minimize session
function M.minimize(session_id)
  local sessions = require("ccasp.sessions")
  local session = sessions.get(session_id)

  if not session then return end

  -- Store minimized state (ordered by minimized_counter for display sorting)
  minimized_counter = minimized_counter + 1
  minimized[session_id] = {
    name = session.name,
    color_idx = session_colors[session_id] or 1,
    bufnr = session.bufnr,
    minimized_at = minimized_counter,
  }

  -- Check if there are other visible sessions
  local visible = sessions.list()
  local other_visible = 0
  for _, s in ipairs(visible) do
    if s.id ~= session_id then
      other_visible = other_visible + 1
    end
  end

  if other_visible == 0 and session.winid and vim.api.nvim_win_is_valid(session.winid) then
    -- Last visible session: show splash instead of hiding window
    local splash = require("ccasp.splash")
    splash.show(session.winid)
    -- Clear winbar so the session title doesn't persist on the splash window
    vim.wo[session.winid].winbar = ""
    -- Disconnect session from window so it's no longer "active" in sessions.list()
    session.winid = nil
  else
    -- Other sessions visible: hide window, focus next
    if session.winid and vim.api.nvim_win_is_valid(session.winid) then
      vim.api.nvim_win_hide(session.winid)
    end
    -- Disconnect session from window (buffer stays alive via bufhidden=hide)
    session.winid = nil
    -- Focus the next available session
    local remaining = sessions.list()
    if #remaining > 0 then
      sessions.focus(remaining[1].id)
    end
  end

  -- Refresh header and footer to show minimized state
  local header_ok, header = pcall(require, "ccasp.appshell.header")
  if header_ok then header.refresh() end
  local footer_ok, footer = pcall(require, "ccasp.appshell.footer")
  if footer_ok then footer.refresh() end

  vim.notify(session.name .. " minimized", vim.log.levels.INFO)
end

-- Progressive split: create window in the right position based on visible count
-- Mirrors create_split_window() logic from sessions.lua
local function restore_split_window(visible_count, visible_list)
  if visible_count == 0 then
    -- Fullscreen: reuse current window
    return
  elseif visible_count == 1 then
    -- 1 → 2: side-by-side columns
    local target = visible_list[#visible_list]
    if target and target.winid and vim.api.nvim_win_is_valid(target.winid) then
      vim.api.nvim_set_current_win(target.winid)
    end
    vim.cmd("belowright vnew")
  elseif visible_count == 2 then
    -- 2 → 3: split first column vertically (start 2x2)
    local target = visible_list[1]
    if target and target.winid and vim.api.nvim_win_is_valid(target.winid) then
      vim.api.nvim_set_current_win(target.winid)
    end
    vim.cmd("belowright new")
  elseif visible_count == 3 then
    -- 3 → 4: split second column vertically (complete 2x2)
    local target = visible_list[2]
    if target and target.winid and vim.api.nvim_win_is_valid(target.winid) then
      vim.api.nvim_set_current_win(target.winid)
    end
    vim.cmd("belowright new")
  else
    -- 5+: alternate between column and row splits
    local target = visible_list[#visible_list]
    if target and target.winid and vim.api.nvim_win_is_valid(target.winid) then
      vim.api.nvim_set_current_win(target.winid)
    end
    vim.cmd(visible_count % 2 == 0 and "belowright vnew" or "belowright new")
  end
end

-- Restore minimized session
function M.restore(session_id)
  local min_session = minimized[session_id]
  if not min_session then return end

  local sessions = require("ccasp.sessions")
  local splash = require("ccasp.splash")

  local new_winid

  if splash.is_showing() then
    -- Splash is active: hide splash, reuse the window
    local splash_win = splash.get_win()
    splash.hide(splash_win, min_session.bufnr)
    new_winid = splash_win
  else
    -- Progressive split based on how many non-minimized sessions are visible
    local all_listed = sessions.list()
    local visible = {}
    for _, s in ipairs(all_listed) do
      if not minimized[s.id] then
        table.insert(visible, s)
      end
    end
    restore_split_window(#visible, visible)
    new_winid = vim.api.nvim_get_current_win()

    if min_session.bufnr and vim.api.nvim_buf_is_valid(min_session.bufnr) then
      vim.api.nvim_win_set_buf(new_winid, min_session.bufnr)
    end
  end

  -- Update session state
  local session = sessions.get(session_id)
  if session then
    session.winid = new_winid
  end

  -- Restore color
  session_colors[session_id] = min_session.color_idx

  -- Remove from minimized
  minimized[session_id] = nil

  -- Update winbar
  M.update(session_id)

  -- Equalize windows after restore
  vim.cmd("wincmd =")

  -- Focus the restored session
  if new_winid and vim.api.nvim_win_is_valid(new_winid) then
    vim.api.nvim_set_current_win(new_winid)
    -- Scroll to bottom and enter terminal mode
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= "t" and mode ~= "nt" then
      pcall(vim.cmd, "normal! G")
      vim.cmd("startinsert")
    end
  end

  -- Refresh header and footer
  local header_ok, header = pcall(require, "ccasp.appshell.header")
  if header_ok then header.refresh() end
  local footer_ok, footer = pcall(require, "ccasp.appshell.footer")
  if footer_ok then footer.refresh() end

  vim.notify(min_session.name .. " restored", vim.log.levels.INFO)
end

-- Check if a session is minimized
function M.is_minimized(session_id)
  return minimized[session_id] ~= nil
end

-- Get minimized sessions list (sorted by minimization order)
function M.get_minimized()
  local result = {}
  for id, data in pairs(minimized) do
    table.insert(result, {
      id = id,
      name = data.name,
      color_idx = data.color_idx,
      minimized_at = data.minimized_at or 0,
    })
  end
  -- Sort by minimization order (first minimized appears first/leftmost)
  table.sort(result, function(a, b) return a.minimized_at < b.minimized_at end)
  return result
end

-- Restore all minimized sessions at once
function M.restore_all()
  local min_sessions = M.get_minimized()

  if #min_sessions == 0 then
    vim.notify("No minimized sessions", vim.log.levels.INFO)
    return
  end

  local sessions_mod = require("ccasp.sessions")
  local splash = require("ccasp.splash")
  local count = #min_sessions
  local last_winid

  -- Build running list of all visible sessions for progressive split targeting
  -- (minimized sessions have winid=nil so they won't appear in list())
  local all_listed = sessions_mod.list()
  local visible = {}
  for _, s in ipairs(all_listed) do
    if not minimized[s.id] then
      table.insert(visible, s)
    end
  end
  local restored = {}

  for _, ms in ipairs(min_sessions) do
    local min_session = minimized[ms.id]
    if not min_session then goto continue end

    local new_winid
    local current_total = #visible + #restored

    if current_total == 0 and splash.is_showing() then
      -- No visible sessions, splash showing: reuse splash window
      local splash_win = splash.get_win()
      splash.hide(splash_win, min_session.bufnr)
      new_winid = splash_win
      vim.api.nvim_set_current_win(new_winid)
    elseif current_total == 0 then
      -- No visible sessions, no splash: reuse current window
      new_winid = vim.api.nvim_get_current_win()
      if min_session.bufnr and vim.api.nvim_buf_is_valid(min_session.bufnr) then
        vim.api.nvim_win_set_buf(new_winid, min_session.bufnr)
      end
    else
      -- Progressive split: combine visible + already-restored for targeting
      local all_visible = {}
      for _, v in ipairs(visible) do table.insert(all_visible, v) end
      for _, r in ipairs(restored) do table.insert(all_visible, r) end

      restore_split_window(current_total, all_visible)
      new_winid = vim.api.nvim_get_current_win()

      if min_session.bufnr and vim.api.nvim_buf_is_valid(min_session.bufnr) then
        vim.api.nvim_win_set_buf(new_winid, min_session.bufnr)
      end
    end

    -- Update session state
    local session = sessions_mod.get(ms.id)
    if session then
      session.winid = new_winid
    end

    -- Restore color
    session_colors[ms.id] = min_session.color_idx

    -- Remove from minimized
    minimized[ms.id] = nil

    -- Update winbar
    M.update(ms.id)

    -- Track this restored session for progressive split targeting
    table.insert(restored, { id = ms.id, winid = new_winid })
    last_winid = new_winid

    ::continue::
  end

  -- Full grid rebuild to ensure proper layout after restoring multiple sessions.
  -- Incremental splits can produce asymmetric trees; rebuild corrects them.
  sessions_mod.rebuild()

  -- Focus the last restored session
  if last_winid then
    -- rebuild() may have moved the session to a different window; look up fresh winid
    local last_session = sessions_mod.get(min_sessions[#min_sessions].id)
    local focus_win = (last_session and last_session.winid) or last_winid
    if focus_win and vim.api.nvim_win_is_valid(focus_win) then
      vim.api.nvim_set_current_win(focus_win)
      local mode = vim.api.nvim_get_mode().mode
      if mode ~= "t" and mode ~= "nt" then
        pcall(vim.cmd, "normal! G")
        vim.cmd("startinsert")
      end
    end
  end

  -- Refresh header once (footer + equalization already handled by rebuild)
  local header_ok, header = pcall(require, "ccasp.appshell.header")
  if header_ok then header.refresh() end

  vim.notify(count .. " session(s) restored", vim.log.levels.INFO)
end

-- Show minimized sessions picker (single select)
function M.show_minimized_picker()
  local min_sessions = M.get_minimized()

  if #min_sessions == 0 then
    vim.notify("No minimized sessions", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, session in ipairs(min_sessions) do
    local color = M.colors[session.color_idx] or { name = "Default" }
    table.insert(items, string.format("[%s] %s", color.name, session.name))
  end

  vim.ui.select(items, {
    prompt = "Restore minimized session:",
  }, function(_, idx)
    if idx then
      M.restore(min_sessions[idx].id)
    end
  end)
end

-- Close session with floating confirmation modal
function M.close_session(session_id)
  local helpers = require("ccasp.panels.helpers")
  local sessions = require("ccasp.sessions")
  local session = sessions.get(session_id)
  if not session then return end

  local width = 36
  local height = 7

  local buf = helpers.create_buffer("ccasp://close-confirm")
  local pos = helpers.calculate_position({ width = width, height = height })
  local win = helpers.create_window(buf, {
    width = pos.width,
    height = pos.height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. nf.win_close .. "  Close Session ",
    footer = " y: Yes │ n/Esc: No ",
    footer_pos = "center",
  })

  vim.wo[win].cursorline = true

  -- Build content
  local lines = {}
  local item_lines = {}

  table.insert(lines, "")
  table.insert(lines, "  Close \"" .. session.name .. "\"?")
  table.insert(lines, "")
  table.insert(lines, "  " .. string.rep("─", width - 4))
  table.insert(lines, "    Yes - Close session")
  item_lines[#lines] = { action = "yes" }
  table.insert(lines, "    No  - Cancel")
  item_lines[#lines] = { action = "no" }
  table.insert(lines, "")

  helpers.set_buffer_content(buf, lines)
  helpers.sandbox_buffer(buf)

  -- Highlights
  local ns = helpers.prepare_highlights("ccasp_close_confirm", buf)
  for i, line_text in ipairs(lines) do
    if line_text:match("Close \"") then
      vim.api.nvim_buf_add_highlight(buf, ns, "WarningMsg", i - 1, 0, -1)
    elseif line_text:match("^  ─") then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", i - 1, 0, -1)
    elseif line_text:match("^    Yes") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticError", i - 1, 4, 7)
    elseif line_text:match("^    No") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", i - 1, 4, 6)
    end
  end

  local panel = { bufnr = buf, winid = win }
  local function close_modal()
    helpers.close_panel(panel)
  end

  local function do_close()
    close_modal()
    vim.schedule(function() sessions.close(session_id) end)
  end

  local function execute_at_cursor()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local item = item_lines[cursor[1]]
    if item then
      if item.action == "yes" then do_close()
      elseif item.action == "no" then close_modal() end
    end
  end

  -- Keymaps
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", execute_at_cursor, opts)
  vim.keymap.set("n", "y", do_close, opts)
  vim.keymap.set("n", "n", close_modal, opts)
  vim.keymap.set("n", "q", close_modal, opts)
  vim.keymap.set("n", "<Esc>", close_modal, opts)

  -- Navigation
  local function nav_down()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local total = vim.api.nvim_buf_line_count(buf)
    for line = cursor[1] + 1, total do
      if item_lines[line] then
        vim.api.nvim_win_set_cursor(win, { line, 0 })
        return
      end
    end
  end

  local function nav_up()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    for line = cursor[1] - 1, 1, -1 do
      if item_lines[line] then
        vim.api.nvim_win_set_cursor(win, { line, 0 })
        return
      end
    end
  end

  vim.keymap.set("n", "j", nav_down, opts)
  vim.keymap.set("n", "k", nav_up, opts)
  vim.keymap.set("n", "<Down>", nav_down, opts)
  vim.keymap.set("n", "<Up>", nav_up, opts)

  -- Mouse click
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local line = mouse.line
    if line < 1 then return end
    pcall(vim.api.nvim_win_set_cursor, win, { line, 0 })
    local item = item_lines[line]
    if item then
      if item.action == "yes" then do_close()
      elseif item.action == "no" then close_modal() end
    end
  end, opts)

  -- Default cursor on "No" (safe default)
  for line = #lines, 1, -1 do
    if item_lines[line] and item_lines[line].action == "no" then
      vim.api.nvim_win_set_cursor(win, { line, 0 })
      break
    end
  end
end

-- Create keymap with extended options
local function set_keymap(mode, key, fn, base_opts, desc)
  vim.keymap.set(mode, key, fn, vim.tbl_extend("force", base_opts, { desc = desc }))
end

-- Setup keymaps for terminal buffer
function M.setup_keymaps(bufnr, session_id)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  local sessions = require("ccasp.sessions")
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Session cycling (Ctrl-Tab only; plain Tab is reserved for flyout toggle)
  local function exit_terminal_mode()
    local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
    vim.api.nvim_feedkeys(esc, "n", false)
  end

  set_keymap("t", "<C-Tab>", function()
    exit_terminal_mode()
    vim.schedule(function() sessions.focus_next() end)
  end, opts, "Next Claude session")

  set_keymap("t", "<C-S-Tab>", function()
    exit_terminal_mode()
    vim.schedule(function() sessions.focus_prev() end)
  end, opts, "Previous Claude session")

  -- Normal mode session controls
  set_keymap("n", "r", function() M.rename(session_id) end, opts, "Rename session")
  set_keymap("n", "c", function() M.change_color(session_id) end, opts, "Change session color")
  set_keymap("n", "_", function() M.minimize(session_id) end, opts, "Minimize session")
  set_keymap("n", "x", function() M.close_session(session_id) end, opts, "Close session")

  -- Alt+1-9: Switch layers from terminal mode
  for i = 1, 9 do
    set_keymap("t", "<M-" .. i .. ">", function()
      exit_terminal_mode()
      vim.schedule(function()
        local layers_ok, layers = pcall(require, "ccasp.layers")
        if layers_ok and layers.is_initialized() then
          layers.switch_to(i)
        end
      end)
    end, opts, "Switch to layer " .. i)
  end

  -- Normal mode: clicking inside a terminal should enter terminal mode.
  -- Handles the case where WinEnter doesn't fire (clicking within the same window
  -- after exiting terminal mode with Ctrl+\, Ctrl+N). Without this, the user
  -- would be stuck in normal mode and get E21 when trying to type.
  -- Cross-window clicks are dispatched to the target (footer gets direct handling).
  -- Winbar clicks (line==0) are replayed with noremap so Neovim's native %@ handlers fire.
  set_keymap("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local current_win = vim.api.nvim_get_current_win()

    -- Winbar click: replay with noremap so native %@ handlers fire
    -- (cycle, rename, color, minimize, close buttons)
    if mouse.line == 0 then
      local key = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
      return
    end

    if mouse.winid ~= 0 and mouse.winid ~= current_win then
      -- Cross-window click: dispatch to footer or focus target window
      local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
      if ft_ok and footer.get_win and footer.get_win() == mouse.winid then
        footer.handle_click(mouse)
        return
      end
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(mouse.winid) then
          vim.api.nvim_set_current_win(mouse.winid)
        end
      end)
      return
    end

    -- Same window, buffer content: enter terminal mode
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].buftype == "terminal" then
        local mode = vim.api.nvim_get_mode().mode
        if mode ~= "t" then
          vim.cmd("startinsert")
        end
      end
    end)
  end, opts, "Click to activate terminal")

  -- Terminal mode: intercept mouse clicks for cross-window session switching.
  -- Terminal apps (Claude CLI) enable mouse tracking which consumes click events,
  -- preventing Neovim from switching windows on single click. This handler
  -- detects clicks targeting a different window, exits terminal mode, and
  -- switches to the target window. Same-window clicks pass through to the
  -- terminal app so Claude CLI input positioning still works.
  -- Footer clicks are dispatched directly (same pattern as Alt+1-9 layer switch)
  -- so layer/session tab clicks work with a single click from terminal mode.
  vim.keymap.set("t", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local current_win = vim.api.nvim_get_current_win()

    if mouse.winid ~= 0 and mouse.winid ~= current_win then
      -- Footer click: handle layer/session switching directly (single-click)
      local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
      if ft_ok and footer.get_win and footer.get_win() == mouse.winid then
        local saved_mouse = mouse
        exit_terminal_mode()
        vim.schedule(function()
          footer.handle_click(saved_mouse)
        end)
        return ""
      end

      -- Cross-window click: switch to target window
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(mouse.winid) then
          vim.api.nvim_set_current_win(mouse.winid)
          -- WinEnter autocmd will auto-enter terminal mode if target is a session
        end
      end)
      return ""  -- suppress the mouse event (don't send to terminal app)
    end

    -- Same window, winbar click: exit terminal mode and replay with noremap
    -- so Neovim's native %@ handlers fire (cycle, rename, color, minimize, close)
    if mouse.line == 0 then
      exit_terminal_mode()
      vim.schedule(function()
        local key = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
      end)
      return ""
    end

    -- Same window, buffer content: pass click through to terminal app (Claude CLI input)
    return vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
  end, { buffer = bufnr, noremap = true, silent = true, expr = true, desc = "Click to switch sessions" })

  -- Terminal mode: suppress double-click so the <2-LeftMouse> escape sequence
  -- doesn't leak into the terminal app as a stray 'ý' (0xFD) character.
  vim.keymap.set("t", "<2-LeftMouse>", function()
    return ""
  end, { buffer = bufnr, noremap = true, silent = true, expr = true, desc = "Suppress double-click in terminal" })
end

-- Show context menu
function M.show_context_menu(session_id)
  local sessions = require("ccasp.sessions")
  local session = sessions.get(session_id)

  if not session then return end

  vim.ui.select({
    "Rename",
    "Change Color",
    "Minimize",
    "Close",
  }, {
    prompt = session.name .. ":",
  }, function(choice)
    if choice == "Rename" then
      M.rename(session_id)
    elseif choice == "Change Color" then
      M.change_color(session_id)
    elseif choice == "Minimize" then
      M.minimize(session_id)
    elseif choice == "Close" then
      M.close_session(session_id)
    end
  end)
end

-- Debounced winbar title update (prevents rapid-fire redraws from WinEnter+BufEnter)
local function debounced_winbar_update()
  if _update_timer then
    vim.fn.timer_stop(_update_timer)
  end
  _update_timer = vim.fn.timer_start(50, function()
    _update_timer = nil
    vim.schedule(function()
      M.update_all()
    end)
  end)
end

-- ═══════════════════════════════════════════════════════════════════
-- Layer Manager Internal API (called only by layers.lua)
-- ═══════════════════════════════════════════════════════════════════

-- Deep copy utility
local function deep_copy(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = type(v) == "table" and deep_copy(v) or v
  end
  return copy
end

-- Export titlebar state for layer snapshot
function M._export_state()
  return {
    session_colors = deep_copy(session_colors),
    minimized = deep_copy(minimized),
    minimized_counter = minimized_counter,
  }
end

-- Import titlebar state from a layer snapshot
function M._import_state(data)
  data = data or {}
  session_colors = data.session_colors or {}
  minimized = data.minimized or {}
  minimized_counter = data.minimized_counter or 0
end

-- Initialize
function M.setup()
  setup_highlights()
  setup_click_handlers()

  local group = vim.api.nvim_create_augroup("CcaspSessionActive", { clear = true })

  -- IMMEDIATE: Auto-enter terminal mode when focusing a session window.
  -- Prevents E21 ("modifiable is off") which occurs when clicking a terminal
  -- window leaves the user in normal mode (terminal buffers are non-modifiable
  -- in normal mode). Uses vim.schedule so it runs after focus() completes its
  -- own setup without conflicting (e.g. sessions.focus calls normal! G first).
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()

      -- Spacer windows (header/rail/footer padding) should never hold focus.
      -- Redirect to the nearest visible terminal session immediately.
      local content_ok, content = pcall(require, "ccasp.appshell.content")
      if content_ok and content.is_spacer_win and content.is_spacer_win(win) then
        vim.schedule(function()
          local sessions = require("ccasp.sessions")
          local active = sessions.list()
          if #active > 0 then
            sessions.focus(active[1].id)
          end
        end)
        return
      end

      -- Terminal session windows: track as active and enter terminal mode.
      -- vim.schedule ensures this runs after any in-progress focus() call
      -- that may do normal! G before startinsert.
      local sessions_ok, sessions = pcall(require, "ccasp.sessions")
      if sessions_ok then
        local session = sessions.get_by_window(win)
        if session then
          sessions.set_active_by_window(win)
          vim.schedule(function()
            if not vim.api.nvim_win_is_valid(win) then return end
            if vim.api.nvim_get_current_win() ~= win then return end
            local bufnr = vim.api.nvim_win_get_buf(win)
            if vim.bo[bufnr].buftype == "terminal" then
              local mode = vim.api.nvim_get_mode().mode
              if mode ~= "t" then
                vim.cmd("startinsert")
              end
            end
          end)
        end
      end
    end,
  })

  -- DEBOUNCED: Update winbar titles (active/inactive styling)
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = group,
    callback = function()
      debounced_winbar_update()
    end,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      debounced_winbar_update()
    end,
  })
end

return M
