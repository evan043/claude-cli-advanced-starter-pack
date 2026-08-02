-- Session-type picker
-- Small floating window that asks which agent CLI a new session should drive.
-- Supports single-key shortcuts, arrow/jk navigation, and <CR> to confirm.

local helpers = require("ccasp.panels.helpers")
local runtime = require("ccasp.runtime")

local M = {}

local state = {
  winid = nil,
  bufnr = nil,
  choices = {},
  cursor = 1,
  on_select = nil,
  title = nil,
}

local function is_open()
  return state.winid and vim.api.nvim_win_is_valid(state.winid)
end

function M.close()
  if is_open() then
    pcall(vim.api.nvim_win_close, state.winid, true)
  end
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    pcall(vim.api.nvim_buf_delete, state.bufnr, { force = true })
  end
  state.winid, state.bufnr, state.on_select = nil, nil, nil
end

local function render()
  if not (state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)) then return end

  local lines = {}
  for i, choice in ipairs(state.choices) do
    local marker = (i == state.cursor) and "▶" or " "
    lines[i] = string.format(" %s  [%s]  %-8s %s", marker, choice.key, choice.label, choice.hint or "")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = " ↑↓/jk move · ⏎ select · esc cancel"

  vim.bo[state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.bo[state.bufnr].modifiable = false

  -- Highlight the selected row
  local ns = vim.api.nvim_create_namespace("ccasp_runtime_picker")
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(state.bufnr, ns, "CursorLine", state.cursor - 1, 0, -1)
  vim.api.nvim_buf_add_highlight(state.bufnr, ns, "Comment", #lines - 1, 0, -1)

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

-- opts.prompt      title text (default "Session type")
-- opts.on_select   fn(runtime_name)
-- opts.happy       label choices with the Happy command instead of the bare CLI
-- opts.names       explicit runtime list (defaults to installed runtimes)
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
  state.title = opts.prompt or "Session type"

  local width = 42
  local height = #state.choices + 2
  local pos = helpers.calculate_position({ width = width, height = height })

  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[state.bufnr].bufhidden = "wipe"
  vim.bo[state.bufnr].filetype = "ccasp-runtime-picker"

  state.winid = vim.api.nvim_open_win(state.bufnr, true, {
    relative = "editor",
    row = pos.row,
    col = pos.col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. state.title .. " ",
    title_pos = "center",
  })
  vim.wo[state.winid].cursorline = false

  local map_opts = { buffer = state.bufnr, nowait = true, silent = true }
  local function move(delta)
    state.cursor = ((state.cursor - 1 + delta) % #state.choices) + 1
    render()
  end

  vim.keymap.set("n", "j", function() move(1) end, map_opts)
  vim.keymap.set("n", "<Down>", function() move(1) end, map_opts)
  vim.keymap.set("n", "k", function() move(-1) end, map_opts)
  vim.keymap.set("n", "<Up>", function() move(-1) end, map_opts)
  vim.keymap.set("n", "<CR>", function() confirm() end, map_opts)
  vim.keymap.set("n", "<Esc>", M.close, map_opts)
  vim.keymap.set("n", "q", M.close, map_opts)

  -- Single-key shortcuts, plus 1..n by position
  for i, choice in ipairs(state.choices) do
    vim.keymap.set("n", choice.key, function() confirm(i) end, map_opts)
    vim.keymap.set("n", tostring(i), function() confirm(i) end, map_opts)
  end

  -- Clicking a row selects it
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse and mouse.line and state.choices[mouse.line] then
      confirm(mouse.line)
    end
  end, map_opts)

  render()
end

return M
