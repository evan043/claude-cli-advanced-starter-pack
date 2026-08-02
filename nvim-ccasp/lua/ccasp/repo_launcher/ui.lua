-- ccasp/repo_launcher/ui.lua - Repository Launcher UI
-- Two panels:
--   1. Path Input Dialog  - small floating input for pasting/typing a directory path
--   2. Repo Browser       - library panel showing pinned + recent repos
--
-- Controls (Path Dialog):
--   Enter:  Validate and open repo
--   Tab:    Switch to Repo Browser
--   Esc:    Cancel and restore terminal focus
--
-- Controls (Repo Browser):
--   j/k, arrows:  Navigate repos (skips headers/separators)
--   Enter:        Open selected repo
--   p:            Toggle pin on selected repo
--   d:            Remove selected repo from library
--   /:            Search repos by name or path
--   n:            Open path input dialog
--   _:            Minimize to taskbar
--   Esc:          Clear search (if active), otherwise close
--   q:            Close and restore terminal focus

local M = {}
local helpers = require("ccasp.panels.helpers")
local nf = require("ccasp.ui.icons")
local function get_ccasp() return require("ccasp") end

-- Dialog state (path input)
local dialog_state = {
  bufnr = nil,
  winid = nil,
}

-- Browser state (repo library)
local browser_state = {
  bufnr = nil,
  winid = nil,
  item_lines = {}, -- line_number -> repo entry for navigation
  search_query = "",
  search_active = false,
}

-------------------------------------------------------------------------------
-- Utility: relative time display
-------------------------------------------------------------------------------

--- Convert an ISO 8601 timestamp to a human-readable relative time string.
--- @param iso_string string|nil  e.g. "2026-02-08T12:30:00.000Z"
--- @return string  e.g. "2m ago", "1h ago", "3d ago"
local function relative_time(iso_string)
  if not iso_string then return "" end

  local y, mo, d, h, mi, s = iso_string:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return "" end

  local then_time = os.time({
    year = tonumber(y), month = tonumber(mo), day = tonumber(d),
    hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
  })
  -- Use UTC "now" so the diff is correct against the UTC timestamp
  local now_time = os.time(os.date("!*t"))
  local diff = now_time - then_time

  if diff < 0 then return "just now" end
  if diff < 60 then return "just now" end
  if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
  if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
  if diff < 604800 then return math.floor(diff / 86400) .. "d ago" end
  return math.floor(diff / 604800) .. "w ago"
end

-------------------------------------------------------------------------------
-- Close helpers
-------------------------------------------------------------------------------

local function close_path_dialog()
  if dialog_state.winid and vim.api.nvim_win_is_valid(dialog_state.winid) then
    vim.api.nvim_win_close(dialog_state.winid, true)
  end
  dialog_state.winid = nil
  dialog_state.bufnr = nil
end

local function close_browser()
  if browser_state.winid and vim.api.nvim_win_is_valid(browser_state.winid) then
    vim.api.nvim_win_close(browser_state.winid, true)
  end
  browser_state.winid = nil
  browser_state.bufnr = nil
  browser_state.item_lines = {}
end

local function close_browser_and_restore()
  close_browser()
  helpers.restore_terminal_focus()
end

-------------------------------------------------------------------------------
-- Browser navigation
-------------------------------------------------------------------------------

--- Move cursor to the next/previous actionable line in the browser.
--- @param direction number  1 for down, -1 for up
local function navigate_browser(direction)
  if not browser_state.winid or not vim.api.nvim_win_is_valid(browser_state.winid) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(browser_state.winid)
  local line = cursor[1]
  local total = vim.api.nvim_buf_line_count(browser_state.bufnr)

  local next_line = line + direction
  while next_line >= 1 and next_line <= total do
    if browser_state.item_lines[next_line] then
      vim.api.nvim_win_set_cursor(browser_state.winid, { next_line, 2 })
      return
    end
    next_line = next_line + direction
  end
end

--- Place cursor on the first actionable item in the browser.
local function move_to_first_item()
  if not browser_state.winid or not vim.api.nvim_win_is_valid(browser_state.winid) then
    return
  end

  local total = vim.api.nvim_buf_line_count(browser_state.bufnr)
  for i = 1, total do
    if browser_state.item_lines[i] then
      vim.api.nvim_win_set_cursor(browser_state.winid, { i, 2 })
      return
    end
  end
end

-------------------------------------------------------------------------------
-- Browser rendering
-------------------------------------------------------------------------------

local function render_browser()
  local bufnr = browser_state.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  local storage = require("ccasp.repo_launcher.storage")

  local lines = {}
  browser_state.item_lines = {}

  if browser_state.search_active and browser_state.search_query ~= "" then
    -- Search results view
    local repos = storage.search(browser_state.search_query)

    table.insert(lines, "")
    table.insert(lines, "  " .. nf.search .. " Search: " .. browser_state.search_query)
    table.insert(lines, "  " .. string.rep("─", 40))
    table.insert(lines, "")

    if #repos == 0 then
      table.insert(lines, "  No matching repos found")
    else
      for _, repo in ipairs(repos) do
        local pin_icon = repo.pinned and (nf.pin .. " ") or "  "
        local time_str = relative_time(repo.last_opened)
        local display = string.format("  %s%s %s  %s", pin_icon, nf.repo, get_ccasp().mask_name(repo.name), time_str)
        table.insert(lines, display)
        browser_state.item_lines[#lines] = repo
      end
    end
  else
    -- Normal view: Pinned + Recent sections
    local pinned = storage.get_pinned()

    table.insert(lines, "")
    table.insert(lines, "  " .. nf.pin .. " PINNED")
    table.insert(lines, "  " .. string.rep("─", 40))

    if #pinned == 0 then
      table.insert(lines, "  (no pinned repos)")
      table.insert(lines, "")
    else
      for _, repo in ipairs(pinned) do
        local time_str = relative_time(repo.last_opened)
        local display = string.format("  %s %s  %s", nf.pin, get_ccasp().mask_name(repo.name), time_str)
        table.insert(lines, display)
        browser_state.item_lines[#lines] = repo
      end
      table.insert(lines, "")
    end

    -- Recent section (exclude pinned repos to avoid duplication)
    local recent = storage.get_recent(20)
    local unpinned_recent = {}
    for _, repo in ipairs(recent) do
      if not repo.pinned then
        table.insert(unpinned_recent, repo)
      end
    end

    table.insert(lines, "  " .. nf.clock .. " RECENT")
    table.insert(lines, "  " .. string.rep("─", 40))

    if #unpinned_recent == 0 then
      table.insert(lines, "  (no recent repos)")
    else
      for _, repo in ipairs(unpinned_recent) do
        local time_str = relative_time(repo.last_opened)
        local display = string.format("  %s %s  %s", nf.repo, get_ccasp().mask_name(repo.name), time_str)
        table.insert(lines, display)
        browser_state.item_lines[#lines] = repo
      end
    end
  end

  -- Bottom padding
  table.insert(lines, "")

  helpers.set_buffer_content(bufnr, lines)

  -- Apply highlights
  local ns = helpers.prepare_highlights("ccasp_repo_browser", bufnr)
  for i, line in ipairs(lines) do
    if line:match("PINNED") or line:match("RECENT") or line:match("Search:") then
      helpers.add_highlight(bufnr, ns, "Title", i - 1, 0, -1)
    elseif line:match("^  " .. string.rep("─", 5)) then
      helpers.add_highlight(bufnr, ns, "NonText", i - 1, 0, -1)
    elseif line:match("^  %(no ") or line:match("^  No matching") then
      helpers.add_highlight(bufnr, ns, "Comment", i - 1, 0, -1)
    end
  end

  helpers.highlight_keybindings(bufnr, ns, lines)
end

-------------------------------------------------------------------------------
-- Path Input Dialog
-------------------------------------------------------------------------------

--- Open a small centered floating dialog for typing/pasting a repository path.
--- The buffer is editable (NOT sandboxed) so the user can type freely.
function M.open_path_dialog()
  close_path_dialog()
  close_browser()

  local width = 56
  local height = 1 -- single editable line
  local pos = helpers.calculate_position({ width = width, height = height })

  -- Create an editable scratch buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  -- Set initial content: empty line for typing
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

  -- Keep buffer editable - this is an input field
  vim.bo[bufnr].modifiable = true

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = pos.row,
    col = pos.col,
    style = "minimal",
    border = "rounded",
    title = " " .. nf.path_input .. " Open Repository ",
    title_pos = "center",
    footer = " [Enter] Open  [Tab] Browse  [Esc] Cancel ",
    footer_pos = "center",
  })

  dialog_state.bufnr = bufnr
  dialog_state.winid = winid

  -- Enter insert mode so user can type immediately
  vim.cmd("startinsert")

  -- Keymaps (all insert-mode since user types into the buffer)
  local opts = { buffer = bufnr, nowait = true, silent = true }

  -- Enter: validate path and open repo
  vim.keymap.set("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
    local input = vim.fn.trim(lines[1] or "")
    -- Strip surrounding quotes (common when pasting from Windows Explorer)
    input = input:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    vim.cmd("stopinsert")
    close_path_dialog()

    if input == "" then
      helpers.restore_terminal_focus()
      return
    end

    local path = vim.fn.expand(input) -- expand ~ and env vars

    if vim.fn.isdirectory(path) == 0 then
      vim.notify("Not a valid directory: " .. get_ccasp().mask_path(path), vim.log.levels.ERROR)
      helpers.restore_terminal_focus()
      return
    end

    vim.schedule(function()
      local mode = vim.api.nvim_get_mode().mode
      if mode == "t" or mode == "i" then
        vim.cmd("stopinsert")
      end
      require("ccasp.repo_launcher").open_repo_pick(path)
    end)
  end, opts)

  -- Tab: switch to repo browser
  vim.keymap.set("i", "<Tab>", function()
    close_path_dialog()
    vim.schedule(function()
      M.open_browser()
    end)
  end, opts)

  -- Esc: cancel (from insert mode)
  vim.keymap.set("i", "<Esc>", function()
    close_path_dialog()
    helpers.restore_terminal_focus()
  end, opts)

  -- Normal mode fallbacks (user might press Esc twice, landing in normal mode)
  vim.keymap.set("n", "<Esc>", function()
    close_path_dialog()
    helpers.restore_terminal_focus()
  end, opts)
  vim.keymap.set("n", "q", function()
    close_path_dialog()
    helpers.restore_terminal_focus()
  end, opts)
  vim.keymap.set("n", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
    local input = vim.fn.trim(lines[1] or "")
    -- Strip surrounding quotes (common when pasting from Windows Explorer)
    input = input:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    close_path_dialog()

    if input == "" then
      helpers.restore_terminal_focus()
      return
    end

    local path = vim.fn.expand(input)

    if vim.fn.isdirectory(path) == 0 then
      vim.notify("Not a valid directory: " .. get_ccasp().mask_path(path), vim.log.levels.ERROR)
      helpers.restore_terminal_focus()
      return
    end

    vim.schedule(function()
      local mode = vim.api.nvim_get_mode().mode
      if mode == "t" or mode == "i" then
        vim.cmd("stopinsert")
      end
      require("ccasp.repo_launcher").open_repo_pick(path)
    end)
  end, opts)
end

-------------------------------------------------------------------------------
-- Repo Browser
-------------------------------------------------------------------------------

--- Open the repo library browser panel.
--- Shows pinned and recent repos in a centered floating window.
function M.open_browser()
  close_path_dialog()

  -- If already open, just focus it
  if helpers.focus_if_open(browser_state.winid) then
    return
  end

  local width = 60
  local height = 22
  local pos = helpers.calculate_position({ width = width, height = height })

  local bufnr = helpers.create_buffer("ccasp://repo-browser")

  local winid = helpers.create_window(bufnr, {
    width = width,
    height = height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. nf.repo .. " Repository Library ",
    title_pos = "center",
    footer = " j/k Move  Enter Open  p Pin  d Del  / Search  n New  Esc/q Close ",
    footer_pos = "center",
  })

  browser_state.bufnr = bufnr
  browser_state.winid = winid
  browser_state.search_query = ""
  browser_state.search_active = false
  browser_state.item_lines = {}

  -- Sandbox first so panel-specific keymaps can override individual keys
  helpers.sandbox_buffer(bufnr)
  helpers.setup_window_manager(bufnr, winid, "Repo Browser")
  helpers.setup_minimize(bufnr, winid, "Repo Browser", browser_state)

  -- Render content into the buffer
  render_browser()

  -- Panel-specific keymaps (override sandbox where needed)
  local opts = { buffer = bufnr, nowait = true, silent = true }

  -- Close
  vim.keymap.set("n", "q", close_browser_and_restore, opts)
  vim.keymap.set("n", "<Esc>", function()
    if browser_state.search_active then
      browser_state.search_query = ""
      browser_state.search_active = false
      render_browser()
      move_to_first_item()
    else
      close_browser_and_restore()
    end
  end, opts)

  -- Navigation (override sandbox blocks on j/k)
  vim.keymap.set("n", "j", function() navigate_browser(1) end, opts)
  vim.keymap.set("n", "k", function() navigate_browser(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() navigate_browser(1) end, opts)
  vim.keymap.set("n", "<Up>", function() navigate_browser(-1) end, opts)

  -- Enter: open selected repo
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_win_get_cursor(browser_state.winid)[1]
    local repo = browser_state.item_lines[line]
    if repo then
      close_browser()
      vim.schedule(function()
        require("ccasp.repo_launcher").open_repo_pick(repo.path)
      end)
    end
  end, opts)

  -- Mouse click: navigate to clicked line (single), open repo (double)
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse and mouse.line and browser_state.item_lines[mouse.line] then
      pcall(vim.api.nvim_win_set_cursor, browser_state.winid, { mouse.line, 2 })
    end
  end, opts)
  vim.keymap.set("n", "<2-LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse and mouse.line then
      local repo = browser_state.item_lines[mouse.line]
      if repo then
        close_browser()
        vim.schedule(function()
          require("ccasp.repo_launcher").open_repo_pick(repo.path)
        end)
      end
    end
  end, opts)

  -- p: toggle pin (override sandbox block on p)
  vim.keymap.set("n", "p", function()
    local line = vim.api.nvim_win_get_cursor(browser_state.winid)[1]
    local repo = browser_state.item_lines[line]
    if repo then
      local storage = require("ccasp.repo_launcher.storage")
      storage.toggle_pin(repo.path)
      render_browser()
      -- Try to keep cursor on the same repo after re-render
      for ln, r in pairs(browser_state.item_lines) do
        if r.path == repo.path then
          vim.api.nvim_win_set_cursor(browser_state.winid, { ln, 2 })
          return
        end
      end
      move_to_first_item()
    end
  end, opts)

  -- d: remove repo from library (override sandbox block on d)
  vim.keymap.set("n", "d", function()
    local line = vim.api.nvim_win_get_cursor(browser_state.winid)[1]
    local repo = browser_state.item_lines[line]
    if repo then
      local storage = require("ccasp.repo_launcher.storage")
      storage.remove(repo.path)
      render_browser()
      move_to_first_item()
    end
  end, opts)

  -- n: open path input dialog
  vim.keymap.set("n", "n", function()
    close_browser()
    vim.schedule(function()
      M.open_path_dialog()
    end)
  end, opts)

  -- /: search mode
  vim.keymap.set("n", "/", function()
    vim.ui.input({ prompt = "Search repos: " }, function(query)
      if query and query ~= "" then
        browser_state.search_query = query
        browser_state.search_active = true
      else
        browser_state.search_query = ""
        browser_state.search_active = false
      end
      render_browser()
      move_to_first_item()
      -- Refocus browser after vim.ui.input closes
      if browser_state.winid and vim.api.nvim_win_is_valid(browser_state.winid) then
        vim.api.nvim_set_current_win(browser_state.winid)
      end
    end)
  end, opts)

  -- Place cursor on the first actionable item
  move_to_first_item()
end

-------------------------------------------------------------------------------
-- Happy Repo Browser (picker for launching Happy sessions)
-------------------------------------------------------------------------------

-- Happy browser state
local happy_browser_state = {
  bufnr = nil,
  winid = nil,
  item_lines = {},
}

local function close_happy_browser()
  if happy_browser_state.winid and vim.api.nvim_win_is_valid(happy_browser_state.winid) then
    vim.api.nvim_win_close(happy_browser_state.winid, true)
  end
  happy_browser_state.winid = nil
  happy_browser_state.bufnr = nil
  happy_browser_state.item_lines = {}
end

local function close_happy_browser_and_restore()
  close_happy_browser()
  helpers.restore_terminal_focus()
end

local function navigate_happy_browser(direction)
  if not happy_browser_state.winid or not vim.api.nvim_win_is_valid(happy_browser_state.winid) then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(happy_browser_state.winid)
  local line = cursor[1]
  local total = vim.api.nvim_buf_line_count(happy_browser_state.bufnr)
  local next_line = line + direction
  while next_line >= 1 and next_line <= total do
    if happy_browser_state.item_lines[next_line] then
      vim.api.nvim_win_set_cursor(happy_browser_state.winid, { next_line, 2 })
      return
    end
    next_line = next_line + direction
  end
end

local function move_to_first_happy_item()
  if not happy_browser_state.winid or not vim.api.nvim_win_is_valid(happy_browser_state.winid) then
    return
  end
  local total = vim.api.nvim_buf_line_count(happy_browser_state.bufnr)
  for i = 1, total do
    if happy_browser_state.item_lines[i] then
      vim.api.nvim_win_set_cursor(happy_browser_state.winid, { i, 2 })
      return
    end
  end
end

local function render_happy_browser()
  local bufnr = happy_browser_state.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  local storage = require("ccasp.repo_launcher.storage")
  local lines = {}
  happy_browser_state.item_lines = {}

  -- Pinned repos
  local pinned = storage.get_pinned()

  table.insert(lines, "")
  table.insert(lines, "  " .. nf.pin .. " PINNED")
  table.insert(lines, "  " .. string.rep("─", 40))

  if #pinned == 0 then
    table.insert(lines, "  (no pinned repos)")
    table.insert(lines, "")
  else
    for _, repo in ipairs(pinned) do
      local time_str = relative_time(repo.last_opened)
      local display = string.format("  %s %s  %s", nf.pin, get_ccasp().mask_name(repo.name), time_str)
      table.insert(lines, display)
      happy_browser_state.item_lines[#lines] = repo
    end
    table.insert(lines, "")
  end

  -- Recent repos (exclude pinned)
  local recent = storage.get_recent(20)
  local unpinned_recent = {}
  for _, repo in ipairs(recent) do
    if not repo.pinned then
      table.insert(unpinned_recent, repo)
    end
  end

  table.insert(lines, "  " .. nf.clock .. " RECENT")
  table.insert(lines, "  " .. string.rep("─", 40))

  if #unpinned_recent == 0 then
    table.insert(lines, "  (no recent repos)")
  else
    for _, repo in ipairs(unpinned_recent) do
      local time_str = relative_time(repo.last_opened)
      local display = string.format("  %s %s  %s", nf.repo, get_ccasp().mask_name(repo.name), time_str)
      table.insert(lines, display)
      happy_browser_state.item_lines[#lines] = repo
    end
  end

  table.insert(lines, "")

  helpers.set_buffer_content(bufnr, lines)

  -- Highlights
  local ns = helpers.prepare_highlights("ccasp_happy_browser", bufnr)
  for i, line in ipairs(lines) do
    if line:match("PINNED") or line:match("RECENT") then
      helpers.add_highlight(bufnr, ns, "Title", i - 1, 0, -1)
    elseif line:match("^  " .. string.rep("─", 5)) then
      helpers.add_highlight(bufnr, ns, "NonText", i - 1, 0, -1)
    elseif line:match("^  %(no ") then
      helpers.add_highlight(bufnr, ns, "Comment", i - 1, 0, -1)
    end
  end
end

--- Open the Happy repo browser picker.
--- Shows pinned and recent repos; selecting one spawns a Happy session.
function M.open_happy_browser()
  close_path_dialog()
  close_browser()

  -- If already open, just focus it
  if helpers.focus_if_open(happy_browser_state.winid) then
    return
  end

  local width = 60
  local height = 22
  local pos = helpers.calculate_position({ width = width, height = height })

  local bufnr = helpers.create_buffer("ccasp://happy-repo-browser")

  local winid = helpers.create_window(bufnr, {
    width = width,
    height = height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. nf.terminal .. " New Happy Session — Select Repo ",
    title_pos = "center",
    footer = " j/k Move  Enter Open  Esc/q Close ",
    footer_pos = "center",
  })

  happy_browser_state.bufnr = bufnr
  happy_browser_state.winid = winid
  happy_browser_state.item_lines = {}

  helpers.sandbox_buffer(bufnr)
  helpers.setup_window_manager(bufnr, winid, "Happy Repo Picker")

  render_happy_browser()

  -- Keymaps
  local opts = { buffer = bufnr, nowait = true, silent = true }

  vim.keymap.set("n", "q", close_happy_browser_and_restore, opts)
  vim.keymap.set("n", "<Esc>", close_happy_browser_and_restore, opts)

  vim.keymap.set("n", "j", function() navigate_happy_browser(1) end, opts)
  vim.keymap.set("n", "k", function() navigate_happy_browser(-1) end, opts)
  vim.keymap.set("n", "<Down>", function() navigate_happy_browser(1) end, opts)
  vim.keymap.set("n", "<Up>", function() navigate_happy_browser(-1) end, opts)

  -- Enter: open selected repo with Happy, asking which agent to drive
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_win_get_cursor(happy_browser_state.winid)[1]
    local repo = happy_browser_state.item_lines[line]
    if repo then
      close_happy_browser()
      vim.schedule(function()
        require("ccasp.repo_launcher").open_repo_happy_pick(repo.path)
      end)
    end
  end, opts)

  -- Mouse click: navigate (single), open (double)
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse and mouse.line and happy_browser_state.item_lines[mouse.line] then
      pcall(vim.api.nvim_win_set_cursor, happy_browser_state.winid, { mouse.line, 2 })
    end
  end, opts)
  vim.keymap.set("n", "<2-LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse and mouse.line then
      local repo = happy_browser_state.item_lines[mouse.line]
      if repo then
        close_happy_browser()
        vim.schedule(function()
          require("ccasp.repo_launcher").open_repo_happy_pick(repo.path)
        end)
      end
    end
  end, opts)

  move_to_first_happy_item()
end

-------------------------------------------------------------------------------
-- Public: close all UI panels
-------------------------------------------------------------------------------

--- Close all UI panels (path dialog, repo browser, happy browser), restoring terminal focus.
function M.close_all()
  local had_open = false

  if dialog_state.winid and vim.api.nvim_win_is_valid(dialog_state.winid) then
    had_open = true
  end
  if browser_state.winid and vim.api.nvim_win_is_valid(browser_state.winid) then
    had_open = true
  end
  if happy_browser_state.winid and vim.api.nvim_win_is_valid(happy_browser_state.winid) then
    had_open = true
  end

  close_path_dialog()
  close_browser()
  close_happy_browser()

  if had_open then
    helpers.restore_terminal_focus()
  end
end

return M
