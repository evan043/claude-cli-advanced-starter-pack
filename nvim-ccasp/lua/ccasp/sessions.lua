-- CCASP Multi-Session Terminal Manager
-- Manages multiple agent CLI sessions with quadrant stacking layout
-- Layout progression: 1 → 1x2 → 2x2 → 2x3 → 2x4 (max 8 sessions)
--
-- Sessions may drive different runtimes (Claude Code or Codex); each session
-- stores both its command string and the resolved runtime name.

local M = {}

local runtime = require("ccasp.runtime")

-- Command string for new sessions when the caller has no preference.
local function default_command()
  return runtime.command(runtime.default())
end

-- Titlebar module (lazy-loaded to avoid circular dependency)
local titlebar = nil
local function get_titlebar()
  if not titlebar then
    titlebar = require("ccasp.session_titlebar")
  end
  return titlebar
end

-- Session state
local state = {
  sessions = {}, -- { id = { id, bufnr, winid, claude_running, name } }
  session_order = {}, -- ordered list of session IDs
  primary_session = nil,
  active_session = nil, -- most recently focused/created session
  max_sessions = 8,
  resizing = false, -- true during split/rearrange to suppress auto-scroll
  activity = {}, -- { session_id = "idle"|"working"|"done" }
  activity_timers = {}, -- { session_id = timer_handle } for 3s silence detection
  activity_burst = {}, -- { session_id = count } event counter for burst detection
  activity_burst_timers = {}, -- { session_id = timer_handle } burst window reset
  activity_suppress = {}, -- { session_id = true } suppress during startup
}

-- Global activity registry: persists across layer switches so footer can show
-- live status colors for ALL sessions regardless of which layer is active.
-- Separate from state.activity which gets swapped on _import_state().
local global_activity = {}               -- { session_id = "idle"|"working"|"done" }
local global_activity_timers = {}         -- { session_id = timer_handle }
local global_activity_burst = {}          -- { session_id = count }
local global_activity_burst_timers = {}   -- { session_id = timer_handle }
local global_activity_suppress = {}       -- { session_id = true }
local _suppress_cli_launch = false        -- true during template apply to prevent auto-launches

-- Refresh footer + titlebar for a session after activity state change
local function refresh_activity_chrome(id)
  local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
  if ft_ok then footer.refresh() end
  get_titlebar().update(id)
end

-- Attach on_lines auto-scroll to a terminal buffer so unfocused session
-- windows stay pinned to the bottom as new output arrives.
-- Also tracks activity state (working/done) for unfocused sessions.
-- Guarded by state.resizing to avoid SIGWINCH-triggered scroll displacement
-- when splits resize all terminal TUIs simultaneously.
--
-- Activity is tracked in TWO registries:
--   state.activity[id]  → per-layer (swapped on layer switch)
--   global_activity[id] → cross-layer (persists, used by footer for all layers)
-- The callback does NOT detach when the session moves to an inactive layer
-- (window invalid but buffer alive). It only detaches when the buffer is gone.
local function attach_auto_scroll(id, bufnr)
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf)
      -- Detach only if buffer is gone
      if not vim.api.nvim_buf_is_valid(buf) then
        global_activity[id] = nil
        return true -- detach
      end

      -- Skip during split/rearrange (SIGWINCH triggers bulk on_lines)
      if state.resizing then return end

      -- Check if session is in current layer (has valid window)
      local session = state.sessions[id]
      local winid = session and session.winid
      local has_window = winid and vim.api.nvim_win_is_valid(winid)
      local is_focused = has_window and (vim.api.nvim_get_current_win() == winid)

      -- Auto-scroll: only for unfocused sessions with valid windows
      if has_window and not is_focused then
        vim.schedule(function()
          if not vim.api.nvim_win_is_valid(winid) then return end
          if not vim.api.nvim_buf_is_valid(buf) then return end
          if state.resizing then return end
          local line_count = vim.api.nvim_buf_line_count(buf)
          pcall(vim.api.nvim_win_set_cursor, winid, { line_count, 0 })
        end)
      end

      -- Activity tracking: for ALL unfocused sessions (including inactive layers)
      if not is_focused and not global_activity_suppress[id] then
        if global_activity[id] == "working" then
          -- Already working: reset the 3s silence timer
          if global_activity_timers[id] then
            vim.fn.timer_stop(global_activity_timers[id])
          end
          global_activity_timers[id] = vim.fn.timer_start(3000, function()
            global_activity_timers[id] = nil
            if global_activity[id] == "working" then
              global_activity[id] = "done"
              -- Also update layer-local if session is in current layer
              if state.sessions[id] then
                state.activity[id] = "done"
              end
              vim.schedule(function() refresh_activity_chrome(id) end)
            end
          end)
          -- Sync layer-local
          if state.sessions[id] then
            state.activity[id] = "working"
          end
        else
          -- Not yet working: burst detection (5+ events in 1s = real streaming)
          global_activity_burst[id] = (global_activity_burst[id] or 0) + 1
          if global_activity_burst[id] >= 5 then
            -- Enough events: transition to working
            global_activity[id] = "working"
            global_activity_burst[id] = 0
            if global_activity_burst_timers[id] then
              vim.fn.timer_stop(global_activity_burst_timers[id])
              global_activity_burst_timers[id] = nil
            end
            -- Start 3s silence timer
            global_activity_timers[id] = vim.fn.timer_start(3000, function()
              global_activity_timers[id] = nil
              if global_activity[id] == "working" then
                global_activity[id] = "done"
                if state.sessions[id] then
                  state.activity[id] = "done"
                end
                vim.schedule(function() refresh_activity_chrome(id) end)
              end
            end)
            -- Sync layer-local
            if state.sessions[id] then
              state.activity[id] = "working"
            end
            vim.schedule(function() refresh_activity_chrome(id) end)
          else
            -- Not enough events yet: reset burst window after 1s of quiet
            if global_activity_burst_timers[id] then
              vim.fn.timer_stop(global_activity_burst_timers[id])
            end
            global_activity_burst_timers[id] = vim.fn.timer_start(1000, function()
              global_activity_burst[id] = 0
              global_activity_burst_timers[id] = nil
            end)
          end
        end
      end
    end,
  })
end

-- Generate unique session ID
local function generate_id()
  return "session_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Get count of active sessions
function M.count()
  local count = 0
  for _, id in ipairs(state.session_order) do
    local session = state.sessions[id]
    if session and session.winid and vim.api.nvim_win_is_valid(session.winid) then
      count = count + 1
    end
  end
  return count
end

-- Get all active sessions in order
function M.list()
  local sessions = {}
  for _, id in ipairs(state.session_order) do
    local session = state.sessions[id]
    if session and session.winid and vim.api.nvim_win_is_valid(session.winid) then
      table.insert(sessions, {
        id = id,
        name = session.name,
        bufnr = session.bufnr,
        winid = session.winid,
        claude_running = session.claude_running,
        is_primary = id == state.primary_session,
      })
    end
  end
  return sessions
end

-- Clean up invalid sessions from order list.
-- Keeps sessions alive if they have a valid buffer (minimized sessions have
-- bufhidden=hide so their buffers persist even after their window is closed).
local function cleanup_invalid()
  local new_order = {}
  for _, id in ipairs(state.session_order) do
    local session = state.sessions[id]
    if session then
      if (session.winid and vim.api.nvim_win_is_valid(session.winid))
          or (session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr)) then
        table.insert(new_order, id)
      else
        state.sessions[id] = nil
      end
    end
  end
  state.session_order = new_order
end

-- Get layout description based on count
function M.get_layout()
  local count = M.count()
  if count <= 1 then return "1"
  elseif count == 2 then return "1x2"
  elseif count <= 4 then return "2x2"
  elseif count <= 6 then return "2x3"
  else return "2x4"
  end
end

-- Equalize all session windows using Neovim's built-in equalization.
-- wincmd = understands the window tree hierarchy and respects
-- winfixwidth/winfixheight on spacer windows (icon rail, footer).
function M.rearrange()
  state.resizing = true
  cleanup_invalid()
  local sessions = M.list()
  if #sessions == 0 then
    state.resizing = false
    return
  end

  -- Update titlebars first (winbar height affects equalization)
  get_titlebar().update_all()

  vim.cmd("wincmd =")

  -- Refresh footer to reflect current session list
  local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
  if ft_ok then footer.refresh() end

  -- Clear resizing flag after TUI has settled (SIGWINCH fires on_lines synchronously)
  vim.defer_fn(function() state.resizing = false end, 300)
end

-- Focus window by session if valid
local function focus_session_window(session)
  if session and session.winid and vim.api.nvim_win_is_valid(session.winid) then
    vim.api.nvim_set_current_win(session.winid)
  end
end

-- Calculate grid dimensions for a given session count.
-- Layout progression: 1 → 1x2 → 2x2 → 2x3 → 2x4
local function grid_dimensions(count)
  if count <= 1 then return 1, 1
  elseif count <= 2 then return 2, 1
  elseif count <= 4 then return 2, 2
  elseif count <= 6 then return 3, 2
  else return 4, 2
  end
end

-- Apply standard terminal window options to a window
local function apply_terminal_win_opts(win)
  vim.wo[win].scrolloff = 0
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].statusline = " "
end

--- Rebuild all session windows into a proper cols×rows grid.
--- Closes existing windows (keeping terminal buffers alive via bufhidden=hide),
--- creates a fresh grid, and places session buffers in row-major order
--- (left→right, top→bottom). Terminal processes are NOT interrupted.
---
--- @param existing table[] Ordered list from M.list() — sessions to rearrange
--- @param include_new_cell boolean If true, leave one empty cell at the end
--- @param anchor_win number|nil Explicit anchor window (skip closing existing windows)
--- @return number|nil new_cell_win Window ID of the empty cell (if include_new_cell)
local function rebuild_to_grid(existing, include_new_cell, anchor_win)
  local total = #existing + (include_new_cell and 1 or 0)
  local cols, rows = grid_dimensions(total)

  -- Protect all terminal buffers from deletion when their windows close.
  -- The process keeps running inside the buffer.
  for _, s in ipairs(existing) do
    if s.bufnr and vim.api.nvim_buf_is_valid(s.bufnr) then
      vim.bo[s.bufnr].bufhidden = "hide"
    end
  end

  if anchor_win then
    -- Caller provided anchor (e.g. _reattach_windows) — sessions have no windows yet
  else
    -- Close all session windows except the first (Neovim needs at least one window).
    -- Terminal buffers stay alive (bufhidden=hide) so CLI processes are unaffected.
    anchor_win = existing[1].winid
    for i = #existing, 2, -1 do
      if existing[i].winid and vim.api.nvim_win_is_valid(existing[i].winid) then
        vim.api.nvim_win_close(existing[i].winid, true)
      end
    end
  end

  vim.api.nvim_set_current_win(anchor_win)

  -- Build columns: anchor is column 1, create cols 2..N with belowright vnew
  local col_wins = { anchor_win }
  for c = 2, cols do
    vim.cmd("belowright vnew")
    -- Mark temp buffer for auto-cleanup when replaced by session buffer
    vim.bo[vim.api.nvim_get_current_buf()].bufhidden = "wipe"
    col_wins[c] = vim.api.nvim_get_current_win()
  end

  -- Split each column into rows
  -- grid[col][row] = winid
  local grid = {}
  for c = 1, cols do
    grid[c] = { col_wins[c] }
    vim.api.nvim_set_current_win(col_wins[c])
    for r = 2, rows do
      local cell_num = (r - 1) * cols + c -- row-major cell index
      if cell_num <= total then
        vim.cmd("belowright new")
        vim.bo[vim.api.nvim_get_current_buf()].bufhidden = "wipe"
        grid[c][r] = vim.api.nvim_get_current_win()
      end
    end
  end

  -- Place existing session buffers into grid cells (row-major order).
  -- Session state (winid) is updated but the buffer/process is untouched.
  local session_idx = 0
  local new_cell_win = nil
  for r = 1, rows do
    for c = 1, cols do
      local win = grid[c] and grid[c][r]
      if not win then goto continue end
      session_idx = session_idx + 1

      if session_idx <= #existing then
        local s = existing[session_idx]
        vim.api.nvim_win_set_buf(win, s.bufnr)
        -- Update session state with new window reference
        if state.sessions[s.id] then
          state.sessions[s.id].winid = win
        end
        apply_terminal_win_opts(win)
      else
        -- This cell is for the new session (caller will run vim.cmd("terminal") here)
        new_cell_win = win
      end

      ::continue::
    end
  end

  -- Re-attach auto-scroll for relocated sessions (old callbacks detach on invalid winid)
  for _, s in ipairs(existing) do
    attach_auto_scroll(s.id, s.bufnr)
  end

  -- Focus the new cell window so the caller can create a terminal there
  if new_cell_win then
    vim.api.nvim_set_current_win(new_cell_win)
  end

  return new_cell_win
end

-- Create split window based on session count
-- Uses vnew/new (not vsplit/split) to avoid briefly duplicating the terminal
-- buffer of the focused session into the new window.
-- For 5+ sessions, uses rebuild_to_grid for proper 2x3/2x4 layouts.
local function create_split_window(count, sessions)
  if count == 0 then
    -- First session: reuse current window if it's a valid content window
    -- (layer switch focuses the anchor before calling spawn). Only vnew
    -- as fallback if current window is a float or spacer.
    local cur = vim.api.nvim_get_current_win()
    local cfg = vim.api.nvim_win_get_config(cur)
    if cfg.relative and cfg.relative ~= "" then
      vim.cmd("vnew")
    end
    -- else: stay in current window — vim.cmd("terminal") will replace its buffer
  elseif count == 1 then
    -- 1 → 2: side-by-side columns (new window to the right)
    focus_session_window(sessions[#sessions])
    vim.cmd("belowright vnew")
  elseif count == 2 then
    -- 2 → 3: split left column vertically (session 1 top, new below = bottom-left)
    focus_session_window(sessions[1])
    vim.cmd("belowright new")
  elseif count == 3 then
    -- 3 → 4: split right column vertically (session 2 top, new below = bottom-right)
    focus_session_window(sessions[2])
    vim.cmd("belowright new")
  elseif count == 4 then
    -- 4 → 5: transition from 2x2 to 2x3 (full grid rebuild, sessions stay alive)
    rebuild_to_grid(sessions, true)
  elseif count == 5 then
    -- 5 → 6: complete 2x3 by splitting 3rd column (sessions[3] is top-right, full height)
    focus_session_window(sessions[3])
    vim.cmd("belowright new")
  elseif count == 6 then
    -- 6 → 7: transition from 2x3 to 2x4 (full grid rebuild, sessions stay alive)
    rebuild_to_grid(sessions, true)
  elseif count == 7 then
    -- 7 → 8: complete 2x4 by splitting 4th column (sessions[4] is top-right, full height)
    focus_session_window(sessions[4])
    vim.cmd("belowright new")
  end
end

--- Fully rebuild the session window grid from scratch.
--- Closes all session windows (terminal buffers survive via bufhidden=hide),
--- recreates a proper cols×rows grid, and places sessions in row-major order.
--- Safe to call at any time — corrects any window tree corruption caused by
--- delete/add cycles leaving the window tree in an inconsistent state.
--- Acts as a "video-game unstuck" for the quadrant layout.
function M.rebuild()
  state.resizing = true
  cleanup_invalid()
  local sessions = M.list()
  if #sessions == 0 then
    state.resizing = false
    return
  end

  if #sessions == 1 then
    -- Single session: just ensure titlebar + equalize (no grid to rebuild)
    get_titlebar().update_all()
    vim.cmd("wincmd =")
  else
    -- Multiple sessions: full grid rebuild
    rebuild_to_grid(sessions, false)
    -- Rebuild titlebars for all sessions (windows are new after rebuild)
    for _, s in ipairs(sessions) do
      get_titlebar().create(s.id)
    end
    get_titlebar().update_all()
    vim.cmd("wincmd =")
  end

  -- Update terminal module with the rebuilt primary's new winid
  local primary = state.primary_session and state.sessions[state.primary_session]
  if primary and primary.winid and vim.api.nvim_win_is_valid(primary.winid) then
    require("ccasp.terminal")._set_state(primary.bufnr, primary.winid)
  end

  -- Focus the active session (or fallback)
  local active = M.get_active()
  if active and active.winid and vim.api.nvim_win_is_valid(active.winid) then
    vim.api.nvim_set_current_win(active.winid)
  end

  -- Refresh footer to reflect current session list
  local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
  if ft_ok then footer.refresh() end

  -- Clear resizing flag after TUI has settled
  vim.defer_fn(function() state.resizing = false end, 300)
end

-- Launch CLI in terminal buffer (defaults to the configured runtime's command,
-- pass command to override).
-- Reads session.command at fire time so template apply can override before the defer fires.
local function launch_claude_cli(id, bufnr, name, command)
  command = command or default_command()
  -- Template apply manages its own CLI launches; skip when suppressed.
  if _suppress_cli_launch then return end
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    -- Session may have been removed by a layer switch (e.g. template apply)
    if not state.sessions[id] then return end

    -- Use session's stored command if updated (e.g. by template apply before this fires)
    local session = state.sessions[id]
    local actual_command = session.command or command

    local job_id = vim.b[bufnr].terminal_job_id
    if job_id and job_id > 0 then
      vim.fn.chansend(job_id, actual_command .. "\r")
      state.sessions[id].claude_running = true

      if id == state.primary_session then
        require("ccasp.terminal")._set_claude_running(true)
      end

      -- Only enter insert mode if the terminal window still has focus.
      -- The flyout or another panel may be focused; blindly calling
      -- startinsert would put INSERT mode on the wrong buffer.
      local session = state.sessions[id]
      if session and session.winid and vim.api.nvim_win_is_valid(session.winid)
          and vim.api.nvim_get_current_win() == session.winid then
        vim.cmd("startinsert")
      end
    end
  end, 500)
end

-- Create a new agent CLI session.
-- Optional: pass a target_win to place the terminal in an existing window
-- instead of creating a split (used by layer switch for empty layers).
-- runtime_name picks which CLI to launch; defaults to the configured runtime.
function M.spawn(target_win, runtime_name)
  cleanup_invalid()

  local count = M.count()
  if count >= state.max_sessions then
    vim.notify("Maximum sessions reached (" .. state.max_sessions .. ")", vim.log.levels.WARN)
    return nil
  end

  local id = generate_id()
  local name = "Claude " .. (count + 1)

  -- Suppress auto-scroll during split (SIGWINCH fires on_lines for all terminals)
  state.resizing = true

  -- If splash is showing, reuse its window instead of creating a new split.
  -- This prevents an orphaned splash window sitting next to the new session.
  local splash = require("ccasp.splash")
  if not target_win and count == 0 and splash.is_showing() then
    local splash_win = splash.get_win()
    splash.hide(splash_win)
    target_win = splash_win
  end

  if target_win and vim.api.nvim_win_is_valid(target_win) then
    -- Layer switch or splash reuse: place terminal directly in the given window (no split)
    vim.api.nvim_set_current_win(target_win)
  else
    create_split_window(count, M.list())
  end

  -- In demo mode, launch in a clean temp directory so Claude CLI doesn't show real paths
  local ccasp = require("ccasp")
  local spawn_dir = ccasp.is_demo_mode() and ccasp.get_demo_dir() or vim.fn.getcwd()
  vim.cmd("lcd " .. vim.fn.fnameescape(spawn_dir))
  vim.cmd("terminal")

  local bufnr, winid = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()

  -- Keep terminal buffer alive when its window is closed (layer switching).
  -- Without this, Neovim deletes the buffer on window close, killing the process.
  vim.bo[bufnr].bufhidden = "hide"

  -- Apply terminal window options (winhighlight set later by titlebar.update)
  apply_terminal_win_opts(winid)

  local spawn_path = spawn_dir
  local spawn_runtime = runtime.normalize(runtime_name)
  local spawn_command = spawn_runtime and runtime.command(spawn_runtime) or default_command()
  state.sessions[id] = { id = id, name = name, bufnr = bufnr, winid = winid, claude_running = false, path = spawn_path, command = spawn_command, runtime = runtime.from_command(spawn_command) }
  table.insert(state.session_order, id)
  state.active_session = id -- newly created session is always active
  state.activity[id] = "idle"
  -- Suppress activity detection during startup (CLI banner output is not real work)
  state.activity_suppress[id] = true
  global_activity_suppress[id] = true
  vim.defer_fn(function()
    state.activity_suppress[id] = nil
    global_activity_suppress[id] = nil
  end, 5000)

  if count == 0 then
    state.primary_session = id
    require("ccasp.terminal")._set_state(bufnr, winid)
  end

  -- Auto-scroll: keep unfocused terminal windows pinned to bottom
  attach_auto_scroll(id, bufnr)

  -- Update all titlebars FIRST so every session has a winbar before equalization.
  -- wincmd = accounts for winbar height; running it before winbars are set causes
  -- misaligned quadrants (windows without winbars get 1 extra row).
  get_titlebar().update_all()

  -- Equalize windows AFTER winbars are consistent across all sessions
  vim.cmd("wincmd =")

  -- Refresh footer to show the new session tab
  local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
  if ft_ok then footer.refresh() end

  launch_claude_cli(id, bufnr, name)

  vim.defer_fn(function()
    get_titlebar().create(id)
    M.rearrange() -- includes wincmd = and footer.refresh() (also sets/clears resizing)
  end, 800)

  -- Notify listeners that a new session is active
  pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "CcaspActiveSessionChanged" })

  return id
end

-- Create a new CLI session at a specific directory path.
-- opts.command: CLI command to launch (default: configured runtime's command)
-- opts.runtime: runtime name ("claude"|"codex"); resolves opts.command when given
function M.spawn_at_path(path, opts)
  opts = opts or {}
  local cli_command = opts.command
    or (opts.runtime and runtime.command(opts.runtime))
    or default_command()
  local ccasp = require("ccasp")

  -- Ensure we're in normal mode before creating splits
  local mode = vim.api.nvim_get_mode().mode
  if mode == "t" or mode == "i" then
    vim.cmd("stopinsert")
  end

  -- Validate path is a directory
  if vim.fn.isdirectory(path) == 0 then
    vim.notify("Directory not found: " .. ccasp.mask_path(path), vim.log.levels.ERROR)
    return nil
  end

  cleanup_invalid()

  local count = M.count()
  if count >= state.max_sessions then
    vim.notify("Maximum sessions reached (" .. state.max_sessions .. ")", vim.log.levels.WARN)
    return nil
  end

  local id = generate_id()
  local raw_name = opts.name or vim.fn.fnamemodify(path, ":t")
  local name = ccasp.is_demo_mode() and ("Session " .. (count + 1)) or raw_name

  -- Suppress auto-scroll during split (SIGWINCH fires on_lines for all terminals)
  state.resizing = true

  create_split_window(count, M.list())

  -- Set the local directory (demo mode → use clean temp dir so Claude CLI hides real paths)
  local lcd_path = ccasp.is_demo_mode() and ccasp.get_demo_dir() or path
  vim.cmd("lcd " .. vim.fn.fnameescape(lcd_path))
  vim.cmd("terminal")

  local bufnr, winid = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()

  -- Keep terminal buffer alive when its window is closed (layer switching).
  vim.bo[bufnr].bufhidden = "hide"

  -- Apply terminal window options (winhighlight set later by titlebar.update)
  apply_terminal_win_opts(winid)

  state.sessions[id] = { id = id, name = name, bufnr = bufnr, winid = winid, claude_running = false, path = lcd_path, command = cli_command, runtime = runtime.from_command(cli_command) }
  table.insert(state.session_order, id)
  state.active_session = id -- newly created session is always active
  state.activity[id] = "idle"
  -- Suppress activity detection during startup (CLI banner output is not real work)
  state.activity_suppress[id] = true
  global_activity_suppress[id] = true
  vim.defer_fn(function()
    state.activity_suppress[id] = nil
    global_activity_suppress[id] = nil
  end, 5000)

  if count == 0 then
    state.primary_session = id
    require("ccasp.terminal")._set_state(bufnr, winid)
  end

  -- Pre-assign titlebar color before first update (so it renders immediately)
  if opts.color_idx then
    get_titlebar().pre_assign_color(id, opts.color_idx)
  end

  -- Auto-scroll: keep unfocused terminal windows pinned to bottom
  attach_auto_scroll(id, bufnr)

  -- Update all titlebars FIRST so every session has a winbar before equalization.
  -- wincmd = accounts for winbar height; running it before winbars are set causes
  -- misaligned quadrants (windows without winbars get 1 extra row).
  get_titlebar().update_all()

  -- Equalize windows AFTER winbars are consistent across all sessions
  vim.cmd("wincmd =")

  -- Refresh footer to show the new session tab
  local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
  if ft_ok then footer.refresh() end

  launch_claude_cli(id, bufnr, name, cli_command)

  vim.defer_fn(function()
    get_titlebar().create(id)
    M.rearrange() -- includes wincmd = and footer.refresh() (also sets/clears resizing)
  end, 800)

  return id
end

-- Remove session from order list
local function remove_from_order(id)
  for i, sid in ipairs(state.session_order) do
    if sid == id then
      table.remove(state.session_order, i)
      return
    end
  end
end

-- Reassign primary session if current primary is closed
local function reassign_primary_if_needed(closed_id)
  if closed_id ~= state.primary_session then return end

  local sessions = M.list()
  if #sessions > 0 then
    state.primary_session = sessions[1].id
    local terminal = require("ccasp.terminal")
    terminal._set_state(sessions[1].bufnr, sessions[1].winid)
    terminal._set_claude_running(sessions[1].claude_running)
  else
    state.primary_session = nil
  end
end

-- Close a specific session
function M.close(id)
  local session = state.sessions[id]
  if not session then return end

  -- Suppress auto-scroll during close (remaining windows resize)
  state.resizing = true

  get_titlebar().destroy(id)

  -- Check if this is the last visible session
  local visible = M.list()
  local other_visible = 0
  for _, s in ipairs(visible) do
    if s.id ~= id then
      other_visible = other_visible + 1
    end
  end

  if other_visible == 0 and session.winid and vim.api.nvim_win_is_valid(session.winid) then
    -- Last visible session: show splash instead of closing window.
    -- Keeps content area alive so user can Tab → flyout → New Session.
    -- Works whether there are minimized sessions or not.
    local splash = require("ccasp.splash")
    splash.show(session.winid)
  elseif session.winid and vim.api.nvim_win_is_valid(session.winid) then
    vim.api.nvim_win_close(session.winid, true)
  end

  -- Clean up activity tracking (layer-local)
  if state.activity_timers[id] then
    vim.fn.timer_stop(state.activity_timers[id])
    state.activity_timers[id] = nil
  end
  if state.activity_burst_timers[id] then
    vim.fn.timer_stop(state.activity_burst_timers[id])
    state.activity_burst_timers[id] = nil
  end
  state.activity[id] = nil
  state.activity_burst[id] = nil
  state.activity_suppress[id] = nil
  -- Clean up global activity tracking
  if global_activity_timers[id] then
    vim.fn.timer_stop(global_activity_timers[id])
    global_activity_timers[id] = nil
  end
  if global_activity_burst_timers[id] then
    vim.fn.timer_stop(global_activity_burst_timers[id])
    global_activity_burst_timers[id] = nil
  end
  global_activity[id] = nil
  global_activity_burst[id] = nil
  global_activity_suppress[id] = nil

  state.sessions[id] = nil
  remove_from_order(id)
  reassign_primary_if_needed(id)

  vim.defer_fn(M.rebuild, 100) -- full grid rebuild to maintain proper layout
end

-- Close all sessions
function M.close_all()
  -- Keep one window alive so the content area isn't destroyed.
  -- Without it the cursor lands in a spacer with no keybindings and the user
  -- cannot open the flyout, spawn a new session, or switch layers.
  local splash_win = nil
  for id, session in pairs(state.sessions) do
    get_titlebar().destroy(id)
    if not splash_win and session.winid and vim.api.nvim_win_is_valid(session.winid) then
      splash_win = session.winid
    elseif session.winid and vim.api.nvim_win_is_valid(session.winid) then
      vim.api.nvim_win_close(session.winid, true)
    end
  end

  -- Show splash in the surviving window (Tab → flyout → New Session)
  if splash_win and vim.api.nvim_win_is_valid(splash_win) then
    local splash = require("ccasp.splash")
    splash.show(splash_win)
  end

  state.sessions = {}
  state.session_order = {}
  state.primary_session = nil
  state.active_session = nil

  -- Clean up all activity timers (layer-local)
  for _, timer in pairs(state.activity_timers) do
    vim.fn.timer_stop(timer)
  end
  for _, timer in pairs(state.activity_burst_timers) do
    vim.fn.timer_stop(timer)
  end
  state.activity = {}
  state.activity_timers = {}
  state.activity_burst = {}
  state.activity_burst_timers = {}
  state.activity_suppress = {}
  -- Clean up all global activity timers
  for _, timer in pairs(global_activity_timers) do
    vim.fn.timer_stop(timer)
  end
  for _, timer in pairs(global_activity_burst_timers) do
    vim.fn.timer_stop(timer)
  end
  global_activity = {}
  global_activity_timers = {}
  global_activity_burst = {}
  global_activity_burst_timers = {}
  global_activity_suppress = {}

  local terminal = require("ccasp.terminal")
  terminal._set_state(nil, nil)
  terminal._set_claude_running(false)
end

-- Focus a specific session
function M.focus(id)
  local session = state.sessions[id]
  if session and session.winid and vim.api.nvim_win_is_valid(session.winid) then
    state.active_session = id
    vim.api.nvim_set_current_win(session.winid)
    -- Ensure the terminal buffer is still displayed in this window
    if session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr) then
      local current_buf = vim.api.nvim_win_get_buf(session.winid)
      if current_buf ~= session.bufnr then
        vim.api.nvim_win_set_buf(session.winid, session.bufnr)
      end
    end
    -- Scroll to bottom using native motion (respects terminal viewport, unlike buf_line_count)
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= "t" and mode ~= "nt" then
      vim.cmd("normal! G")
    end
    vim.cmd("startinsert")
  end
end

-- Focus next session
function M.focus_next()
  local sessions = M.list()
  if #sessions == 0 then return end

  local current_win = vim.api.nvim_get_current_win()
  local current_idx = 0

  for i, session in ipairs(sessions) do
    if session.winid == current_win then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #sessions) + 1
  M.focus(sessions[next_idx].id)
end

-- Focus previous session
function M.focus_prev()
  local sessions = M.list()
  if #sessions == 0 then return end

  local current_win = vim.api.nvim_get_current_win()
  local current_idx = 0

  for i, session in ipairs(sessions) do
    if session.winid == current_win then
      current_idx = i
      break
    end
  end

  local prev_idx = current_idx - 1
  if prev_idx < 1 then prev_idx = #sessions end
  M.focus(sessions[prev_idx].id)
end

-- Send command to a specific session
function M.send(cmd, id)
  local session
  if id then
    session = state.sessions[id]
  else
    local current_win = vim.api.nvim_get_current_win()
    for _, s in pairs(state.sessions) do
      if s.winid == current_win then
        session = s
        break
      end
    end
  end

  if not session or not session.bufnr then return end

  local job_id = vim.b[session.bufnr].terminal_job_id
  if job_id and job_id > 0 then
    vim.fn.chansend(job_id, cmd .. "\n")
  end
end

-- Get session by ID
function M.get(id)
  return state.sessions[id]
end

-- Set session name (used by layout templates)
function M.set_name(id, name)
  if state.sessions[id] then
    state.sessions[id].name = name
  end
end

-- Set session CLI command type (used by layout templates)
function M.set_command(id, command)
  if state.sessions[id] then
    state.sessions[id].command = command
    -- Keep the runtime tag in sync so the command palette follows the binary.
    state.sessions[id].runtime = runtime.from_command(command)
  end
end

-- Switch a session to a named runtime. Only affects the next launch; an
-- already-running CLI keeps going until the session is restarted.
function M.set_runtime(id, name)
  local key = runtime.normalize(name)
  if not key or not state.sessions[id] then return false end
  M.set_command(id, runtime.command(key))
  return true
end

-- Runtime driving a session, falling back to the configured default.
function M.get_runtime(id)
  local session = state.sessions[id or state.active_session]
  if not session then return runtime.default() end
  return session.runtime or runtime.from_command(session.command) or runtime.default()
end

-- Suppress/allow CLI auto-launch (used during template apply to prevent
-- race conditions with layer-switch state snapshots).
function M.suppress_cli_launch(val)
  _suppress_cli_launch = val
end

-- Get primary session
function M.get_primary()
  if state.primary_session then
    return state.sessions[state.primary_session]
  end
  return nil
end

-- Get the most recently active session (last focused or created)
function M.get_active()
  if state.active_session and state.sessions[state.active_session] then
    local s = state.sessions[state.active_session]
    if s.winid and vim.api.nvim_win_is_valid(s.winid) then
      return s
    end
  end
  -- Fallback to primary, then first available
  local primary = M.get_primary()
  if primary and primary.winid and vim.api.nvim_win_is_valid(primary.winid) then
    return primary
  end
  local all = M.list()
  return all[1] or nil
end

-- Get activity state for a session ("idle", "working", or "done")
function M.get_activity(id)
  return state.activity[id] or "idle"
end

-- Get global activity state (persists across layer switches)
-- Used by footer to show live status colors for ALL layers
function M.get_global_activity(id)
  return global_activity[id] or "idle"
end

-- Track active session from WinEnter (called by session_titlebar autocmd)
function M.set_active_by_window(winid)
  local prev_active = state.active_session
  for id, session in pairs(state.sessions) do
    if session.winid == winid then
      state.active_session = id

      -- Clear activity indicator when user focuses a done/working session
      if state.activity[id] == "done" or state.activity[id] == "working"
        or global_activity[id] == "done" or global_activity[id] == "working" then
        -- Stop any pending timers (layer-local)
        if state.activity_timers[id] then
          vim.fn.timer_stop(state.activity_timers[id])
          state.activity_timers[id] = nil
        end
        if state.activity_burst_timers[id] then
          vim.fn.timer_stop(state.activity_burst_timers[id])
          state.activity_burst_timers[id] = nil
        end
        state.activity_burst[id] = 0
        state.activity[id] = "idle"
        -- Also clear global activity
        if global_activity_timers[id] then
          vim.fn.timer_stop(global_activity_timers[id])
          global_activity_timers[id] = nil
        end
        if global_activity_burst_timers[id] then
          vim.fn.timer_stop(global_activity_burst_timers[id])
          global_activity_burst_timers[id] = nil
        end
        global_activity_burst[id] = 0
        global_activity[id] = "idle"
        vim.schedule(function() refresh_activity_chrome(id) end)
      end

      -- Notify listeners (flyout commands, panels) when session changes
      if prev_active ~= id then
        vim.schedule(function()
          pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "CcaspActiveSessionChanged" })
        end)
      end
      return
    end
  end
end

-- Register an existing session (called from sidebar)
function M.register_primary(bufnr, winid)
  local id = generate_id()
  local primary_command = default_command()
  local primary_runtime = runtime.from_command(primary_command)
  state.sessions[id] = {
    id = id,
    name = runtime.label(primary_runtime) .. " 1",
    bufnr = bufnr,
    winid = winid,
    claude_running = false,
    command = primary_command,
    runtime = primary_runtime,
  }
  table.insert(state.session_order, id)
  state.primary_session = id
  state.active_session = id
  state.activity[id] = "idle"
  -- Suppress activity detection during startup (CLI banner output is not real work)
  state.activity_suppress[id] = true
  global_activity_suppress[id] = true
  vim.defer_fn(function()
    state.activity_suppress[id] = nil
    global_activity_suppress[id] = nil
  end, 5000)

  -- Auto-scroll: keep unfocused terminal windows pinned to bottom
  attach_auto_scroll(id, bufnr)

  -- Create titlebar after short delay (allows terminal to initialize)
  vim.defer_fn(function()
    local ok, err = pcall(function()
      get_titlebar().create(id)
    end)
    if not ok then
      vim.schedule(function()
        vim.notify("Titlebar create error: " .. tostring(err), vim.log.levels.WARN)
      end)
    end
  end, 500)

  -- Initialize layer system on first session registration
  local layers_ok, layers = pcall(require, "ccasp.layers")
  if layers_ok then layers.init() end

  return id
end

-- Mark session as claude running
function M.set_claude_running(id, running)
  if state.sessions[id] then
    state.sessions[id].claude_running = running
    get_titlebar().update(id)
  end
end

-- Reorder sessions by providing a new ordered list of session IDs.
-- Rebuilds the grid so sessions physically move to their new positions.
-- Also updates the footer taskbar order.
function M.reorder(new_order)
  -- Validate all IDs exist in current sessions
  for _, id in ipairs(new_order) do
    if not state.sessions[id] then return false end
  end
  state.session_order = new_order
  -- Full grid rebuild to physically rearrange windows
  M.rebuild()
  return true
end

-- Get human-readable grid position label for a session index.
-- Maps 1-based index to grid location (e.g. "top-left", "bottom-right").
local function get_grid_position_label(index, total)
  local cols, rows = grid_dimensions(total)
  local r = math.ceil(index / cols)
  local c = ((index - 1) % cols) + 1

  if total == 1 then return "fullscreen" end

  if rows == 1 then
    if cols == 2 then
      return c == 1 and "left" or "right"
    end
    return "col " .. c
  end

  local row_label = r == 1 and "top" or "bottom"
  if cols == 1 then return row_label end
  if cols == 2 then
    local col_label = c == 1 and "left" or "right"
    return row_label .. "-" .. col_label
  end
  if cols == 3 then
    local col_labels = { "left", "center", "right" }
    return row_label .. "-" .. (col_labels[c] or ("col" .. c))
  end
  if cols == 4 then
    local col_labels = { "far-left", "left", "right", "far-right" }
    return row_label .. "-" .. (col_labels[c] or ("col" .. c))
  end
  return "pos " .. index
end

-- Show floating reorder modal for the active layer's sessions.
-- Users navigate with j/k and move items with K/J (Shift+k/j).
-- Enter applies the new order, Esc cancels.
function M.show_reorder_modal()
  local helpers = require("ccasp.panels.helpers")
  local icons = require("ccasp.ui.icons")

  cleanup_invalid()
  local sessions = M.list()

  if #sessions < 2 then
    vim.notify("Need 2+ sessions to reorder", vim.log.levels.INFO)
    return
  end

  -- Working copy of the order (will be mutated by move operations)
  local working_order = {}
  for _, s in ipairs(sessions) do
    table.insert(working_order, { id = s.id, name = s.name })
  end

  local width = 44
  local total = #working_order

  local buf = helpers.create_buffer("ccasp://reorder-sessions")

  local item_lines = {}
  local cursor_item = 1

  local function render_modal(win)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

    local lines = {}
    item_lines = {}

    table.insert(lines, "")
    table.insert(lines, "  Pos  Session              Grid")
    table.insert(lines, "  " .. string.rep("─", width - 4))

    for i, entry in ipairs(working_order) do
      local pos_label = get_grid_position_label(i, total)
      local name_pad = math.max(1, 21 - vim.fn.strdisplaywidth(entry.name))
      local line = string.format("   %d.  %s%s%s", i, entry.name, string.rep(" ", name_pad), pos_label)
      table.insert(lines, line)
      item_lines[#lines] = i
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", width - 4))
    table.insert(lines, "  K: Move up  J: Move down")
    table.insert(lines, "  Enter: Apply  Esc: Cancel")
    table.insert(lines, "")

    local ns = vim.api.nvim_create_namespace("ccasp_reorder")
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, line_text in ipairs(lines) do
      if line_text:match("^  Pos") then
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, "Title", i - 1, 0, -1)
      elseif line_text:match("^  ─") then
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, "Comment", i - 1, 0, -1)
      elseif line_text:match("^  K:") or line_text:match("^  Enter:") then
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, "Comment", i - 1, 0, -1)
      elseif item_lines[i] then
        local idx = item_lines[i]
        -- Highlight position number
        pcall(vim.api.nvim_buf_add_highlight, buf, ns, "Number", i - 1, 3, 5)
        -- Highlight grid label in grey (find it after the name gap)
        local grid_start = line_text:find("%s%s+%S", 10)
        if grid_start then
          local label_start = line_text:find("%S", grid_start + 1)
          if label_start then
            pcall(vim.api.nvim_buf_add_highlight, buf, ns, "Comment", i - 1, label_start - 1, -1)
          end
        end
        -- Highlight active item with accent
        if idx == cursor_item then
          pcall(vim.api.nvim_buf_add_highlight, buf, ns, "CursorLine", i - 1, 0, -1)
        end
      end
    end

    if win and vim.api.nvim_win_is_valid(win) then
      for line_nr, idx in pairs(item_lines) do
        if idx == cursor_item then
          pcall(vim.api.nvim_win_set_cursor, win, { line_nr, 0 })
          break
        end
      end
    end
  end

  local height = total + 8
  local pos = helpers.calculate_position({ width = width, height = height })
  local win = helpers.create_window(buf, {
    width = pos.width,
    height = pos.height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. icons.reorder .. "  Reorder Sessions ",
    title_pos = "center",
    footer = " K: Up  J: Down  Enter: Apply  Esc: Cancel ",
    footer_pos = "center",
  })

  vim.wo[win].cursorline = true
  helpers.sandbox_buffer(buf)
  render_modal(win)

  local panel = { bufnr = buf, winid = win }
  local function close_modal()
    helpers.close_panel(panel)
  end

  local function apply_order()
    local new_order = {}
    for _, entry in ipairs(working_order) do
      table.insert(new_order, entry.id)
    end
    close_modal()
    vim.schedule(function()
      M.reorder(new_order)
      vim.notify("Sessions reordered", vim.log.levels.INFO)
    end)
  end

  local function nav_down()
    if cursor_item < total then
      cursor_item = cursor_item + 1
      render_modal(win)
    end
  end

  local function nav_up()
    if cursor_item > 1 then
      cursor_item = cursor_item - 1
      render_modal(win)
    end
  end

  local function move_down()
    if cursor_item < total then
      working_order[cursor_item], working_order[cursor_item + 1] =
        working_order[cursor_item + 1], working_order[cursor_item]
      cursor_item = cursor_item + 1
      render_modal(win)
    end
  end

  local function move_up()
    if cursor_item > 1 then
      working_order[cursor_item], working_order[cursor_item - 1] =
        working_order[cursor_item - 1], working_order[cursor_item]
      cursor_item = cursor_item - 1
      render_modal(win)
    end
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", apply_order, opts)
  vim.keymap.set("n", "<Esc>", close_modal, opts)
  vim.keymap.set("n", "q", close_modal, opts)

  vim.keymap.set("n", "j", nav_down, opts)
  vim.keymap.set("n", "k", nav_up, opts)
  vim.keymap.set("n", "<Down>", nav_down, opts)
  vim.keymap.set("n", "<Up>", nav_up, opts)

  vim.keymap.set("n", "J", move_down, opts)
  vim.keymap.set("n", "K", move_up, opts)
  vim.keymap.set("n", "<S-Down>", move_down, opts)
  vim.keymap.set("n", "<S-Up>", move_up, opts)

  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    local line = mouse.line
    if line < 1 then return end
    local idx = item_lines[line]
    if idx then
      cursor_item = idx
      render_modal(win)
    end
  end, opts)
end

-- Show session picker
function M.show_picker()
  local sessions = M.list()

  if #sessions == 0 then
    vim.notify("No active Claude sessions", vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, session in ipairs(sessions) do
    local status = session.claude_running and "●" or "○"
    local primary = session.is_primary and " ★" or ""
    table.insert(items, string.format("[%d] %s %s%s", i, status, session.name, primary))
  end

  vim.ui.select(items, {
    prompt = "Select Claude Session:",
  }, function(_, idx)
    if idx then
      M.focus(sessions[idx].id)
    end
  end)
end

-- Rename a session
function M.rename(id)
  get_titlebar().rename(id)
end

-- Change session title bar color
function M.change_color(id)
  get_titlebar().change_color(id)
end

-- Minimize a session
function M.minimize(id)
  get_titlebar().minimize(id)
end

-- Restore a minimized session
function M.restore(id)
  get_titlebar().restore(id)
end

-- Get minimized sessions
function M.get_minimized()
  return get_titlebar().get_minimized()
end

-- Restore all minimized sessions at once
function M.restore_all()
  get_titlebar().restore_all()
end

-- Show minimized sessions picker
function M.show_minimized_picker()
  get_titlebar().show_minimized_picker()
end

-- Get session by current window
function M.get_by_window(winid)
  winid = winid or vim.api.nvim_get_current_win()
  for id, session in pairs(state.sessions) do
    if session.winid == winid then
      return session
    end
  end
  return nil
end

-- Update all titlebars
function M.update_titlebars()
  get_titlebar().update_all()
end

-- Re-arrange on resize
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("CcaspSessionResize", { clear = true }),
  callback = function()
    vim.defer_fn(function()
      M.rearrange()
    end, 100)
  end,
})

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

-- Export current session state for layer snapshot
function M._export_state()
  -- Sync current layer's activity into global before snapshot
  for id, act in pairs(state.activity) do
    if act ~= "idle" then
      global_activity[id] = act
    end
  end
  return {
    sessions = deep_copy(state.sessions),
    session_order = deep_copy(state.session_order),
    primary_session = state.primary_session,
    active_session = state.active_session,
    activity = deep_copy(state.activity),
  }
end

-- Import session state from a layer snapshot
function M._import_state(data)
  data = data or {}
  -- Stop existing activity timers before replacing state
  for _, timer in pairs(state.activity_timers) do
    vim.fn.timer_stop(timer)
  end
  for _, timer in pairs(state.activity_burst_timers) do
    vim.fn.timer_stop(timer)
  end
  state.sessions = data.sessions or {}
  state.session_order = data.session_order or {}
  state.primary_session = data.primary_session
  state.active_session = data.active_session
  state.activity = data.activity or {}
  state.activity_timers = {} -- timers don't survive layer switch
  state.activity_burst = {}
  state.activity_burst_timers = {}
  state.activity_suppress = {}

  -- Update terminal module with new primary
  local primary = state.primary_session and state.sessions[state.primary_session]
  local terminal = require("ccasp.terminal")
  if primary then
    terminal._set_state(primary.bufnr, primary.winid)
    terminal._set_claude_running(primary.claude_running or false)
  else
    terminal._set_state(nil, nil)
    terminal._set_claude_running(false)
  end
end

-- Clear the winid reference for the session that owns a given window.
-- Used by layers.lua to protect the anchor window from being closed by _detach_all_windows().
function M._clear_winid(winid)
  for _, session in pairs(state.sessions) do
    if session.winid == winid then
      session.winid = nil
      return
    end
  end
end

-- Detach all session windows (close windows, keep buffers alive)
function M._detach_all_windows()
  state.resizing = true

  for id, session in pairs(state.sessions) do
    -- Ensure terminal buffer survives window close
    if session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr) then
      vim.bo[session.bufnr].bufhidden = "hide"
    end
    -- Destroy titlebar (winbar is removed when window closes)
    get_titlebar().destroy(id)
    -- Close window but keep buffer
    if session.winid and vim.api.nvim_win_is_valid(session.winid) then
      vim.api.nvim_win_close(session.winid, true)
    end
    session.winid = nil
  end

  vim.defer_fn(function() state.resizing = false end, 300)
end

-- Reattach windows for sessions that have valid buffers but no windows.
-- Recreates the split grid, assigns buffers, rebuilds titlebars.
function M._reattach_windows()
  state.resizing = true

  -- Only reattach non-minimized sessions (minimized stay hidden)
  local tb = get_titlebar()
  local ordered = {}
  for _, id in ipairs(state.session_order) do
    local session = state.sessions[id]
    if session and session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr)
        and not (tb.is_minimized and tb.is_minimized(id)) then
      table.insert(ordered, session)
    end
  end

  if #ordered == 0 then
    state.resizing = false
    return
  end

  -- Find a suitable content-area window to host the first session.
  -- After detaching, current window may be a spacer or float — both are wrong.
  -- Walk all windows and pick the first non-spacer, non-float window.
  local content_ok, content = pcall(require, "ccasp.appshell.content")
  local first_win = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(win)
    local is_float = cfg.relative and cfg.relative ~= ""
    local is_spacer = content_ok and content.is_spacer_win and content.is_spacer_win(win)
    if not is_float and not is_spacer then
      first_win = win
      break
    end
  end

  -- Fallback: if every real window was a spacer, create a new split from any spacer
  if not first_win then
    -- Focus any valid window, then create a new window beside it
    local all_wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(all_wins) do
      local cfg = vim.api.nvim_win_get_config(win)
      if not (cfg.relative and cfg.relative ~= "") then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
    vim.cmd("vnew")
    first_win = vim.api.nvim_get_current_win()
  end

  if #ordered >= 5 then
    -- 5+ sessions: use grid builder for proper 2x3/2x4 layout.
    -- Place first session in anchor, then rebuild_to_grid handles all windows.
    -- Terminal processes continue running — only windows are rearranged.
    local first = ordered[1]
    vim.api.nvim_set_current_win(first_win)
    vim.api.nvim_win_set_buf(first_win, first.bufnr)
    first.winid = first_win
    apply_terminal_win_opts(first_win)
    rebuild_to_grid(ordered, false, first_win)
  else
    -- 1-4 sessions: use incremental splits
    local first = ordered[1]
    vim.api.nvim_set_current_win(first_win)
    vim.api.nvim_win_set_buf(first_win, first.bufnr)
    first.winid = first_win
    apply_terminal_win_opts(first_win)

    for i = 2, #ordered do
      local session = ordered[i]
      create_split_window(i - 1, ordered)
      local new_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(new_win, session.bufnr)
      session.winid = new_win
      apply_terminal_win_opts(new_win)
    end
  end

  -- Rebuild titlebars for all sessions
  for _, session in ipairs(ordered) do
    get_titlebar().create(session.id)
    -- Re-attach auto-scroll
    attach_auto_scroll(session.id, session.bufnr)
  end

  -- Equalize windows
  get_titlebar().update_all()
  vim.cmd("wincmd =")

  -- Update terminal module with the reattached primary's new winid
  local primary = state.primary_session and state.sessions[state.primary_session]
  if primary and primary.winid and vim.api.nvim_win_is_valid(primary.winid) then
    require("ccasp.terminal")._set_state(primary.bufnr, primary.winid)
  end

  -- Focus the active session
  local active = state.active_session and state.sessions[state.active_session]
  if active and active.winid and vim.api.nvim_win_is_valid(active.winid) then
    vim.api.nvim_set_current_win(active.winid)
  end

  vim.defer_fn(function() state.resizing = false end, 300)
end

return M
