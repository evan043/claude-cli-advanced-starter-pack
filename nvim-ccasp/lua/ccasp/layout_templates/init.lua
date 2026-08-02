-- CCASP Layout Templates - Public API
-- Save and restore complete workspace layouts (layers + sessions + paths + colors)

local M = {}

-- Lazy-loaded modules
local function get_storage() return require("ccasp.layout_templates.storage") end
local function get_layers() return require("ccasp.layers") end
local function get_sessions() return require("ccasp.sessions") end
local function get_titlebar() return require("ccasp.session_titlebar") end

local runtime = require("ccasp.runtime")

local function deep_copy(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = type(v) == "table" and deep_copy(v) or v
  end
  return copy
end

-- Command a saved session definition should launch.
-- Templates written before multi-runtime support stored a bare "claude"
-- literal. Honor whatever a template actually recorded so existing layouts keep
-- the runtime they were saved with; fall back to the configured runtime only
-- when a template expresses no preference at all.
local function template_command(sess_def)
  if type(sess_def.command) == "string" and sess_def.command ~= "" then
    return sess_def.command
  end
  return runtime.command(sess_def.runtime or runtime.default())
end

-- ═══════════════════════════════════════════════════════════════════
-- Core API
-- ═══════════════════════════════════════════════════════════════════

--- Save the current workspace (all layers + sessions) as a named template.
--- @param name string Template name
--- @return boolean success
--- @return string|table error_or_template
function M.save_current(name)
  if not name or name == "" then
    return false, "Template name cannot be empty"
  end

  local storage = get_storage()
  local library = storage.load()

  -- Check for duplicate
  local _, existing = storage.find_template(library, name)
  if existing then
    return false, "Template already exists: " .. name
  end

  local layers = get_layers()
  local sessions = get_sessions()
  local titlebar = get_titlebar()

  if not layers.is_initialized() then
    return false, "Layer system not initialized"
  end

  local active_num = layers.get_active()
  local template_layers = {}

  for num = 1, 9 do
    local layer = layers.get(num)
    if layer then
      local sess_data, tb_data

      if num == active_num then
        -- Active layer: read live state (snapshot may be stale)
        sess_data = sessions._export_state()
        tb_data = titlebar._export_state()
      else
        -- Inactive layer: use stored snapshot
        sess_data = layer.sessions_data
        tb_data = layer.titlebar_data
      end

      if sess_data and sess_data.session_order and #sess_data.session_order > 0 then
        local layer_sessions = {}
        for _, id in ipairs(sess_data.session_order) do
          local session = sess_data.sessions[id]
          if session then
            local color_idx = (tb_data and tb_data.session_colors and tb_data.session_colors[id]) or 1
            local session_runtime = session.runtime
              or runtime.from_command(session.command)
              or runtime.default()
            table.insert(layer_sessions, {
              name = session.name or runtime.label(session_runtime),
              path = session.path or vim.fn.getcwd(),
              color_idx = color_idx,
              command = session.command or runtime.command(session_runtime),
              runtime = session_runtime,
            })
          end
        end

        table.insert(template_layers, {
          name = layer.name,
          sessions = layer_sessions,
        })
      end
    end
  end

  if #template_layers == 0 then
    return false, "No sessions to save"
  end

  local now = storage.now()
  local template = {
    name = name,
    is_default = false,
    created_at = now,
    updated_at = now,
    layers = template_layers,
  }

  table.insert(library.templates, template)
  storage.save(library)

  return true, template
end

--- Apply a saved template, recreating the workspace from scratch.
--- @param name string Template name
--- @return boolean success
--- @return string|nil error_message
function M.apply(name)
  local storage = get_storage()
  local library = storage.load()

  local _, template = storage.find_template(library, name)
  if not template then
    return false, "Template not found: " .. name
  end

  if not template.layers or #template.layers == 0 then
    return false, "Template has no layers"
  end

  local layers = get_layers()
  local sessions = get_sessions()
  local titlebar = get_titlebar()

  -- Suppress auto CLI launches during template apply.  We collect all
  -- {bufnr, command, cd_path} entries and batch-send them after every layer
  -- has been created.  This prevents the race where deferred launches fire
  -- after a layer switch has moved the session out of active state.
  sessions.suppress_cli_launch(true)
  local pending_launches = {}

  -- Apply template as NEW layers (never mutate existing layers).
  local first_new_layer = nil

  for layer_idx, layer_def in ipairs(template.layers) do
    -- Create a new layer for every template layer
    local num = layers.create(layer_def.name)
    if not num then
      vim.notify(
        string.format("Max layers reached — only %d of %d template layers applied", layer_idx - 1, #template.layers),
        vim.log.levels.WARN
      )
      break
    end
    if not first_new_layer then
      first_new_layer = num
    end
    layers.switch_to(num)

    -- Now we're on the target layer with one default session.
    -- Spawn additional sessions at specified paths.
    local spawned_ids = {}
    for sess_idx, sess_def in ipairs(layer_def.sessions) do
      if sess_idx > 8 then break end -- max sessions per layer

      local path = sess_def.path
      if vim.fn.isdirectory(path) == 0 then
        local ccasp = require("ccasp")
        vim.notify(
          string.format("Skipping session '%s': directory not found: %s", ccasp.mask_name(sess_def.name), ccasp.mask_path(path)),
          vim.log.levels.WARN
        )
      else
        if sess_idx == 1 then
          -- First session: reuse the existing default session.
          -- Set its path, name, color, and CLI command type.
          local all = sessions.list()
          if #all > 0 then
            local first_id = all[1].id
            sessions.set_name(first_id, sess_def.name)
            sessions.set_command(first_id, template_command(sess_def))
            titlebar.set_color(first_id, sess_def.color_idx or 1)
            -- Set working directory for the existing terminal
            local first_session = sessions.get(first_id)
            if first_session and first_session.winid and vim.api.nvim_win_is_valid(first_session.winid) then
              vim.api.nvim_set_current_win(first_session.winid)
              vim.cmd("lcd " .. vim.fn.fnameescape(path))
              -- Update path record
              if first_session then first_session.path = path end
            end
            -- Collect for deferred batch launch (includes cd since terminal
            -- was created at the wrong cwd by the default layer spawn).
            if first_session and first_session.bufnr then
              table.insert(pending_launches, {
                bufnr = first_session.bufnr,
                command = template_command(sess_def),
                cd_path = path,
              })
            end
            table.insert(spawned_ids, first_id)
          end
        else
          -- Subsequent sessions: spawn new ones with saved command type
          local id = sessions.spawn_at_path(path, {
            command = template_command(sess_def),
            name = sess_def.name,
            color_idx = sess_def.color_idx or 1,
          })
          if id then
            -- Collect for deferred batch launch (spawn_at_path sets correct
            -- cwd so no cd_path needed, but auto-launch was suppressed).
            local sess = sessions.get(id)
            if sess and sess.bufnr then
              table.insert(pending_launches, {
                bufnr = sess.bufnr,
                command = template_command(sess_def),
              })
            end
            table.insert(spawned_ids, id)
          end
        end
      end
    end

    -- Brief wait between layers to let terminals stabilize
    vim.wait(200, function() return false end)
  end

  -- Re-enable auto CLI launches
  sessions.suppress_cli_launch(false)

  -- Switch to the first template layer
  if first_new_layer and layers.get_active() ~= first_new_layer then
    layers.switch_to(first_new_layer)
  end

  -- Refresh all chrome
  local ft_ok, footer = pcall(require, "ccasp.appshell.footer")
  if ft_ok then footer.refresh() end
  titlebar.update_all()

  -- Batch-launch all CLI commands.  The 500ms delay gives each terminal's
  -- shell time to initialise before we send the command ("claude", "happy", etc).
  vim.defer_fn(function()
    for _, launch in ipairs(pending_launches) do
      if vim.api.nvim_buf_is_valid(launch.bufnr) then
        local job_id = vim.b[launch.bufnr].terminal_job_id
        if job_id and job_id > 0 then
          -- First session in each layer needs cd to correct directory
          -- (terminal was created at the default cwd, not the saved path).
          if launch.cd_path then
            vim.fn.chansend(job_id, 'cd /d "' .. launch.cd_path .. '"\r')
          end
          vim.fn.chansend(job_id, launch.command .. "\r")
        end
      end
    end
  end, 500)

  return true
end

--- Delete a template by name.
--- @param name string
--- @return boolean success
--- @return string|nil error
function M.delete(name)
  local storage = get_storage()
  local library = storage.load()

  local idx = storage.find_template(library, name)
  if not idx then
    return false, "Template not found: " .. name
  end

  table.remove(library.templates, idx)
  storage.save(library)
  return true
end

--- Rename a template.
--- @param old_name string
--- @param new_name string
--- @return boolean success
--- @return string|nil error
function M.rename(old_name, new_name)
  if not new_name or new_name == "" then
    return false, "New name cannot be empty"
  end

  local storage = get_storage()
  local library = storage.load()

  local _, dup = storage.find_template(library, new_name)
  if dup then
    return false, "Template name already exists: " .. new_name
  end

  local idx, template = storage.find_template(library, old_name)
  if not idx then
    return false, "Template not found: " .. old_name
  end

  template.name = new_name
  template.updated_at = storage.now()
  library.templates[idx] = template
  storage.save(library)
  return true
end

--- List all templates as summaries.
--- @return table[] Array of { name, is_default, layer_count, session_count, updated_at }
function M.list()
  local storage = get_storage()
  local library = storage.load()
  local result = {}

  for _, tmpl in ipairs(library.templates) do
    local layer_count = tmpl.layers and #tmpl.layers or 0
    local session_count = 0
    if tmpl.layers then
      for _, layer in ipairs(tmpl.layers) do
        session_count = session_count + (layer.sessions and #layer.sessions or 0)
      end
    end
    table.insert(result, {
      name = tmpl.name,
      is_default = tmpl.is_default or false,
      layer_count = layer_count,
      session_count = session_count,
      updated_at = tmpl.updated_at,
    })
  end

  table.sort(result, function(a, b)
    return (a.updated_at or "") > (b.updated_at or "")
  end)

  return result
end

--- Set a template as the default (auto-load on startup).
--- @param name string
--- @return boolean success
--- @return string|nil error
function M.set_default(name)
  local storage = get_storage()
  local library = storage.load()

  local idx, template = storage.find_template(library, name)
  if not idx then
    return false, "Template not found: " .. name
  end

  -- Clear all defaults
  for _, t in ipairs(library.templates) do
    t.is_default = false
  end

  template.is_default = true
  template.updated_at = storage.now()
  library.templates[idx] = template
  storage.save(library)
  return true
end

--- Clear the default template.
function M.clear_default()
  local storage = get_storage()
  local library = storage.load()
  for _, t in ipairs(library.templates) do
    t.is_default = false
  end
  storage.save(library)
end

--- Get the default template, or nil if none set.
--- @return table|nil template
function M.get_default()
  local storage = get_storage()
  local library = storage.load()
  for _, template in ipairs(library.templates) do
    if template.is_default then
      return template
    end
  end
  return nil
end

-- ═══════════════════════════════════════════════════════════════════
-- Modal Dialogs
-- ═══════════════════════════════════════════════════════════════════

local nf = require("ccasp.ui.icons")

--- Show "Save Layout" floating input modal.
function M.show_save_modal()
  local helpers = require("ccasp.panels.helpers")

  local default_name = "My Layout"
  local width = 44
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default_name })

  local pos = helpers.calculate_position({ width = width, height = 1 })
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = pos.width,
    height = 1,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = " " .. nf.save .. "  Save Layout Template ",
    title_pos = "center",
    footer = " Enter: Save │ Esc: Cancel ",
    footer_pos = "center",
    style = "minimal",
  })

  vim.cmd("startinsert!")

  local function close_modal()
    vim.cmd("stopinsert")
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    helpers.restore_terminal_focus()
  end

  local function confirm()
    local name = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
    vim.cmd("stopinsert")
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if name ~= "" then
      local ok, err = M.save_current(name)
      if ok then
        vim.notify("Layout template saved: " .. name, vim.log.levels.INFO)
      else
        vim.notify("Failed to save: " .. tostring(err), vim.log.levels.ERROR)
      end
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

--- Generic picker modal: shows a list of templates, returns selected name via callback.
--- @param title string Modal title
--- @param footer_text string Footer hint
--- @param on_select fun(name: string) Called with selected template name
local function show_picker_modal(title, footer_text, on_select)
  local helpers = require("ccasp.panels.helpers")
  local all = M.list()

  if #all == 0 then
    vim.notify("No saved templates", vim.log.levels.INFO)
    helpers.restore_terminal_focus()
    return
  end

  local width = 44
  local lines = {}
  local item_lines = {}

  table.insert(lines, "")
  for _, tmpl in ipairs(all) do
    local marker = tmpl.is_default and nf.star_filled or " "
    local line = string.format("  %s %s (%dL/%dS)", marker, tmpl.name, tmpl.layer_count, tmpl.session_count)
    table.insert(lines, line)
    item_lines[#lines] = { name = tmpl.name }
  end
  table.insert(lines, "")

  local height = #lines
  local buf = helpers.create_buffer("ccasp://template-picker")
  local pos = helpers.calculate_position({ width = width, height = height })
  local win = helpers.create_window(buf, {
    width = pos.width,
    height = pos.height,
    row = pos.row,
    col = pos.col,
    border = "rounded",
    title = title,
    footer = footer_text,
    footer_pos = "center",
  })

  vim.wo[win].cursorline = true
  helpers.set_buffer_content(buf, lines)
  helpers.sandbox_buffer(buf)

  -- Highlights
  local ns = helpers.prepare_highlights("ccasp_template_picker", buf)
  for i, line_text in ipairs(lines) do
    if item_lines[i] then
      local tmpl_info = item_lines[i]
      -- Find matching template to check if it's default
      for _, t in ipairs(all) do
        if t.name == tmpl_info.name and t.is_default then
          vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", i - 1, 0, -1)
          break
        end
      end
    end
  end

  local panel = { bufnr = buf, winid = win }
  local function close_modal()
    helpers.close_panel(panel)
  end

  local function execute_at_cursor()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    local cursor = vim.api.nvim_win_get_cursor(win)
    local item = item_lines[cursor[1]]
    if item then
      close_modal()
      vim.schedule(function() on_select(item.name) end)
    end
  end

  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", execute_at_cursor, opts)
  vim.keymap.set("n", "<Esc>", close_modal, opts)
  vim.keymap.set("n", "q", close_modal, opts)

  -- Navigation (skip non-item lines)
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
      close_modal()
      vim.schedule(function() on_select(item.name) end)
    end
  end, opts)

  -- Default cursor on first item
  for line = 1, #lines do
    if item_lines[line] then
      vim.api.nvim_win_set_cursor(win, { line, 0 })
      break
    end
  end
end

--- Show "Rename Template" picker → then rename input.
function M.show_rename_modal()
  show_picker_modal(
    " " .. nf.edit .. "  Rename Template ",
    " Enter: Select │ Esc: Cancel ",
    function(selected_name)
      -- Now show rename input
      local helpers = require("ccasp.panels.helpers")
      local width = 44
      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].bufhidden = "wipe"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { selected_name })

      local pos = helpers.calculate_position({ width = width, height = 1 })
      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = pos.width,
        height = 1,
        row = pos.row,
        col = pos.col,
        border = "rounded",
        title = " " .. nf.edit .. "  New Name ",
        title_pos = "center",
        footer = " Enter: Apply │ Esc: Cancel ",
        footer_pos = "center",
        style = "minimal",
      })

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
        if new_name ~= "" and new_name ~= selected_name then
          local ok, err = M.rename(selected_name, new_name)
          if ok then
            vim.notify("Template renamed: " .. new_name, vim.log.levels.INFO)
          else
            vim.notify("Rename failed: " .. tostring(err), vim.log.levels.ERROR)
          end
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
  )
end

--- Show "Delete Template" picker → confirmation.
function M.show_delete_modal()
  show_picker_modal(
    " " .. nf.delete .. "  Delete Template ",
    " Enter: Select │ Esc: Cancel ",
    function(selected_name)
      -- Show confirmation
      local helpers = require("ccasp.panels.helpers")
      local width = 36
      local height = 7

      local buf = helpers.create_buffer("ccasp://delete-template")
      local pos = helpers.calculate_position({ width = width, height = height })
      local win = helpers.create_window(buf, {
        width = pos.width,
        height = pos.height,
        row = pos.row,
        col = pos.col,
        border = "rounded",
        title = " " .. nf.delete .. "  Delete Template ",
        footer = " y: Yes │ n/Esc: No ",
        footer_pos = "center",
      })

      vim.wo[win].cursorline = true

      local lines = {}
      local item_lines = {}

      table.insert(lines, "")
      table.insert(lines, "  Delete \"" .. selected_name .. "\"?")
      table.insert(lines, "")
      table.insert(lines, "  " .. string.rep("─", width - 4))
      table.insert(lines, "    Yes - Delete template")
      item_lines[#lines] = { action = "yes" }
      table.insert(lines, "    No  - Cancel")
      item_lines[#lines] = { action = "no" }
      table.insert(lines, "")

      helpers.set_buffer_content(buf, lines)
      helpers.sandbox_buffer(buf)

      local ns = helpers.prepare_highlights("ccasp_delete_template", buf)
      for i, line_text in ipairs(lines) do
        if line_text:match('Delete "') then
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

      local function do_delete()
        close_modal()
        vim.schedule(function()
          local ok, err = M.delete(selected_name)
          if ok then
            vim.notify("Template deleted: " .. selected_name, vim.log.levels.INFO)
          else
            vim.notify("Delete failed: " .. tostring(err), vim.log.levels.ERROR)
          end
        end)
      end

      local function execute_at_cursor()
        if not win or not vim.api.nvim_win_is_valid(win) then return end
        local cursor = vim.api.nvim_win_get_cursor(win)
        local item = item_lines[cursor[1]]
        if item then
          if item.action == "yes" then do_delete()
          elseif item.action == "no" then close_modal() end
        end
      end

      local opts = { buffer = buf, noremap = true, silent = true }
      vim.keymap.set("n", "<CR>", execute_at_cursor, opts)
      vim.keymap.set("n", "y", do_delete, opts)
      vim.keymap.set("n", "n", close_modal, opts)
      vim.keymap.set("n", "q", close_modal, opts)
      vim.keymap.set("n", "<Esc>", close_modal, opts)

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

      vim.keymap.set("n", "<LeftMouse>", function()
        local mouse = vim.fn.getmousepos()
        local line = mouse.line
        if line < 1 then return end
        pcall(vim.api.nvim_win_set_cursor, win, { line, 0 })
        local item = item_lines[line]
        if item then
          if item.action == "yes" then do_delete()
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
  )
end

--- Show "Set Default" picker. Selecting a template sets it as default.
--- Selecting the current default clears it.
function M.show_set_default_modal()
  show_picker_modal(
    " " .. nf.star_filled .. "  Set Default Template ",
    " Enter: Select │ Esc: Cancel ",
    function(selected_name)
      -- Check if it's already default → toggle off
      local current_default = M.get_default()
      if current_default and current_default.name == selected_name then
        M.clear_default()
        vim.notify("Default cleared", vim.log.levels.INFO)
      else
        local ok, err = M.set_default(selected_name)
        if ok then
          vim.notify("Default set: " .. selected_name, vim.log.levels.INFO)
        else
          vim.notify("Failed: " .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
  )
end

return M
