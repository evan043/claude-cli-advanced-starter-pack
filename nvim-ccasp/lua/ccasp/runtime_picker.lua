-- Session-type picker
-- Small floating window that asks which agent CLI a new session should drive.
-- Single-key shortcuts, Tab to toggle, arrow/jk navigation, <CR> to confirm.
--
-- Built with panels.helpers like the other menus in this plugin. sandbox_buffer
-- neutralises destructive normal-mode keys (it maps c/d/x/... to no-ops), so the
-- picker's own shortcuts have to be mapped AFTER it or they would be swallowed.

local helpers = require("ccasp.panels.helpers")
local runtime = require("ccasp.runtime")

local M = {}

local state = {
  winid = nil,
  bufnr = nil,
  choices = {},
  cursor = 1,
  on_select = nil,
}

local function is_open()
  return state.winid and vim.api.nvim_win_is_valid(state.winid)
end

function M.close()
  if is_open() then
    pcall(vim.api.nvim_win_close, state.winid, true)
  end
  state.winid, state.bufnr, state.on_select = nil, nil, nil
end

local function render()
  if not (state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)) then return end

  local lines = {}
  for i, choice in ipairs(state.choices) do
    lines[i] = string.format(" %s  [%s]  %-8s %s",
      (i == state.cursor) and "▶" or " ",
      choice.key, choice.label, choice.hint or "")
  end
  helpers.set_buffer_content(state.bufnr, lines)

  local ns = vim.api.nvim_create_namespace("ccasp_runtime_picker")
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)
  helpers.add_highlight(state.bufnr, ns, "CursorLine", state.cursor - 1, 0, -1)

  if is_open() then
    pcall(vim.api.nvim_win_set_cursor, state.winid, { state.cursor, 0 })
  end
end

local function confirm(index)
  local choice = state.choices[index or state.cursor]
  local callback = state.on_select
  M.close()
  if choice and callback then
    vim.schedule(function() callback(choice.name) end)
  end
end

-- opts.prompt     title text (default "Session type")
-- opts.on_select  fn(runtime_name)
-- opts.happy      label choices with the Happy command instead of the bare CLI
-- opts.names      explicit runtime list (defaults to installed runtimes)
function M.open(opts)
  opts = opts or {}

  -- Callers usually reach here from a focused terminal session. In terminal or
  -- insert mode the picker's normal-mode mappings never fire -- keystrokes go
  -- to the terminal instead -- so leave those modes and reopen on the next
  -- tick, since the mode change does not land synchronously.
  local mode = vim.api.nvim_get_mode().mode
  if (mode == "t" or mode == "i" or mode == "ic") and not opts._mode_settled then
    if mode == "t" then
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    else
      vim.cmd("stopinsert")
    end
    opts._mode_settled = true
    vim.schedule(function() M.open(opts) end)
    return
  end

  M.close()

  local names = opts.names or runtime.available()
  if #names == 0 then names = { runtime.FALLBACK } end

  -- Nothing to choose between: skip the window entirely.
  if #names == 1 then
    if opts.on_select then vim.schedule(function() opts.on_select(names[1]) end) end
    return
  end

  state.choices = {}
  state.cursor = 1
  local active = runtime.default()
  for i, name in ipairs(names) do
    local spec = runtime.spec(name)
    table.insert(state.choices, {
      name = name,
      key = spec.key or tostring(i),
      label = spec.label,
      hint = opts.happy and runtime.happy_command(name) or spec.command,
    })
    if name == active then state.cursor = #state.choices end
  end

  state.on_select = opts.on_select

  local width = 44
  local height = #state.choices
  local pos = helpers.calculate_position({ width = width, height = height })

  state.bufnr = helpers.create_buffer("ccasp://runtime-picker")
  vim.bo[state.bufnr].filetype = "ccasp-runtime-picker"
  state.winid = helpers.create_window(state.bufnr, {
    width = width,
    height = height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. (opts.prompt or "Session type") .. " ",
    title_pos = "center",
    footer = " c/x or 1/2 pick  Tab toggle  Enter confirm  Esc cancel ",
    footer_pos = "center",
  })
  vim.wo[state.winid].cursorline = false

  -- Neutralise destructive keys first; our shortcuts are mapped after so they
  -- take precedence over the no-ops sandbox_buffer installs for c/x.
  helpers.sandbox_buffer(state.bufnr)

  local map_opts = { buffer = state.bufnr, nowait = true, silent = true }
  local function move(delta)
    state.cursor = ((state.cursor - 1 + delta) % #state.choices) + 1
    render()
  end

  for _, key in ipairs({ "j", "<Down>" }) do
    vim.keymap.set("n", key, function() move(1) end, map_opts)
  end
  for _, key in ipairs({ "k", "<Up>" }) do
    vim.keymap.set("n", key, function() move(-1) end, map_opts)
  end
  -- Tab cycles, which is the natural gesture for a two-item choice.
  for _, key in ipairs({ "<Tab>", "<S-Tab>" }) do
    vim.keymap.set("n", key, function() move(1) end, map_opts)
  end

  vim.keymap.set("n", "<CR>", function() confirm() end, map_opts)
  vim.keymap.set("n", "<Space>", function() confirm() end, map_opts)
  vim.keymap.set("n", "<Esc>", M.close, map_opts)
  vim.keymap.set("n", "q", M.close, map_opts)

  -- Per-choice shortcuts, plus 1..n by position.
  for i, choice in ipairs(state.choices) do
    vim.keymap.set("n", choice.key, function() confirm(i) end, map_opts)
    vim.keymap.set("n", choice.key:upper(), function() confirm(i) end, map_opts)
    vim.keymap.set("n", tostring(i), function() confirm(i) end, map_opts)
  end

  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse and mouse.line and state.choices[mouse.line] then
      confirm(mouse.line)
    end
  end, map_opts)

  render()

  -- The flyout is sandboxed too; if anything steals focus back, its no-op maps
  -- would swallow these keys silently. Assert focus once the window settles.
  vim.schedule(function()
    if is_open() and vim.api.nvim_get_current_win() ~= state.winid then
      pcall(vim.api.nvim_set_current_win, state.winid)
    end
  end)

  return state.winid
end

return M
