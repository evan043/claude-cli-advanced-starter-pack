-- Headless test: multi-runtime support (Claude / Codex / Happy wrapper)
-- Run: nvim --headless --clean -c "lua vim.opt.rtp:prepend('nvim-ccasp')" -c "luafile nvim-ccasp/tests/runtime_test.lua" 2>&1

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  PASS: " .. name)
  else
    failed = failed + 1
    print("  FAIL: " .. name .. " — " .. tostring(err))
  end
end

local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %s, got %s", msg or "assertion", tostring(expected), tostring(actual)))
  end
end

local function assert_true(val, msg)
  if not val then error(msg or "expected true") end
end

print("=== CCASP Runtime Tests ===")
print("")

local ccasp = require("ccasp")
ccasp.setup({ layout = "appshell" })

local runtime = require("ccasp.runtime")

print("-- runtime specs --")

test("claude and codex are known runtimes", function()
  assert_eq("claude", runtime.normalize("claude"))
  assert_eq("codex", runtime.normalize("CODEX"))
  assert_eq(nil, runtime.normalize("gpt"))
end)

test("spec falls back to claude for unknown names", function()
  assert_eq("claude", runtime.spec("nonsense").name)
end)

test("each runtime exposes a distinct shortcut key and badge", function()
  assert_true(runtime.spec("claude").key ~= runtime.spec("codex").key, "keys must differ")
  assert_true(runtime.spec("claude").short ~= runtime.spec("codex").short, "badges must differ")
end)

test("prompts_dir differs per runtime", function()
  local root = "/tmp/project"
  assert_true(runtime.prompts_dir(root, "claude"):find("%.claude/commands"), "claude dir")
  assert_true(runtime.prompts_dir(root, "codex"):find("%.codex/prompts"), "codex dir")
end)

print("")
print("-- happy wrapper --")

test("happy_command wraps each runtime", function()
  assert_eq("happy", runtime.happy_command("claude"))
  assert_eq("happy codex", runtime.happy_command("codex"))
end)

test("from_command unwraps happy to the real runtime", function()
  assert_eq("claude", runtime.from_command("happy"))
  assert_eq("codex", runtime.from_command("happy codex"))
  assert_eq("claude", runtime.from_command("happy --yolo"))
end)

test("from_command handles bare and shimmed binaries", function()
  assert_eq("claude", runtime.from_command("claude"))
  assert_eq("codex", runtime.from_command("codex.cmd"))
  assert_eq("claude", runtime.from_command("claude --resume"))
  assert_eq(nil, runtime.from_command("someothercli"))
end)

test("is_happy_command detects the wrapper", function()
  assert_true(runtime.is_happy_command("happy codex"), "happy codex")
  assert_true(runtime.is_happy_command("happy"), "happy")
  assert_true(not runtime.is_happy_command("codex"), "bare codex is not happy")
end)

print("")
print("-- picker --")

test("runtime_picker loads", function()
  local picker = require("ccasp.runtime_picker")
  assert_true(type(picker.open) == "function", "open")
  assert_true(type(picker.close) == "function", "close")
end)

test("picker short-circuits when only one runtime is offered", function()
  local picker = require("ccasp.runtime_picker")
  local chosen = nil
  picker.open({ names = { "codex" }, on_select = function(n) chosen = n end })
  vim.wait(300, function() return chosen ~= nil end)
  assert_eq("codex", chosen, "single choice auto-selects without a window")
end)

-- helpers.sandbox_buffer maps c/d/x/... to no-ops so destructive normal-mode
-- keys cannot fire in a menu. The picker's shortcuts are c and x, so they must
-- be mapped after sandboxing or they are silently swallowed.
test("picker shortcuts survive buffer sandboxing", function()
  local picker = require("ccasp.runtime_picker")
  picker.open({ names = { "claude", "codex" }, on_select = function() end })
  vim.wait(250)

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  assert_eq("ccasp-runtime-picker", vim.bo[buf].filetype, "picker window is focused")

  local mapped = {}
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do mapped[m.lhs] = true end
  assert_true(mapped["d"], "buffer is sandboxed")
  assert_true(mapped["c"], "'c' mapped despite sandbox")
  assert_true(mapped["x"], "'x' mapped despite sandbox")
  assert_true(mapped["<Tab>"], "'<Tab>' toggles")
  assert_true(mapped["<Down>"] and mapped["<Up>"], "arrow navigation mapped")

  picker.close()
end)

test("picker shortcut keys actually select", function()
  local picker = require("ccasp.runtime_picker")
  local function press(key)
    local chosen = nil
    picker.open({ names = { "claude", "codex" }, on_select = function(n) chosen = n end })
    -- Opening can defer a tick when the current window is a terminal, so wait
    -- for the picker to actually be focused rather than a fixed delay.
    local ready = vim.wait(1500, function()
      local b = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
      return vim.bo[b].filetype == "ccasp-runtime-picker"
    end)
    if not ready then return "picker-never-focused" end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "x", false)
    vim.wait(600, function() return chosen ~= nil end)
    return chosen
  end
  assert_eq("codex", press("x"), "x selects Codex")
  assert_eq("claude", press("c"), "c selects Claude")
  assert_eq("codex", press("<Tab><CR>"), "Tab then Enter selects Codex")
  assert_eq("codex", press("<Down><CR>"), "Down then Enter selects Codex")
end)

print("")
print("-- mixed-runtime sessions in one layer --")

local sessions = require("ccasp.sessions")
pcall(ccasp.open)
vim.wait(1200, function() return false end)

sessions.suppress_cli_launch(true)

local cwd = vim.fn.getcwd()
local claude_id = sessions.spawn_at_path(cwd, { runtime = "claude", name = "Claude A" })
vim.wait(400, function() return false end)
local codex_id = sessions.spawn_at_path(cwd, { runtime = "codex", name = "Codex B" })
vim.wait(400, function() return false end)

test("both sessions were created", function()
  assert_true(claude_id ~= nil, "claude session id")
  assert_true(codex_id ~= nil, "codex session id")
end)

test("each session carries its own runtime and command", function()
  local a = sessions.get(claude_id)
  local b = sessions.get(codex_id)
  assert_eq("claude", a.runtime, "session A runtime")
  assert_eq("codex", b.runtime, "session B runtime")
  assert_eq("claude", a.command, "session A command")
  assert_eq("codex", b.command, "session B command")
end)

test("get_runtime reports per-session runtime", function()
  assert_eq("claude", sessions.get_runtime(claude_id))
  assert_eq("codex", sessions.get_runtime(codex_id))
end)

test("set_runtime switches a live session and retags it", function()
  assert_true(sessions.set_runtime(claude_id, "codex"), "set_runtime returns true")
  assert_eq("codex", sessions.get_runtime(claude_id), "retagged")
  assert_eq("codex", sessions.get(claude_id).command, "command updated")
  -- put it back so the template test below saves a genuinely mixed layer
  sessions.set_runtime(claude_id, "claude")
  assert_eq("claude", sessions.get_runtime(claude_id), "restored")
end)

test("a happy command tags the wrapped runtime", function()
  sessions.set_command(codex_id, runtime.happy_command("codex"))
  assert_eq("codex", sessions.get_runtime(codex_id), "happy codex still tags codex")
  assert_true(runtime.is_happy_command(sessions.get(codex_id).command), "marked as happy")
  sessions.set_command(codex_id, runtime.command("codex"))
end)

print("")
print("-- hybrid layout templates --")

local layout_templates = require("ccasp.layout_templates")
local storage = require("ccasp.layout_templates.storage")

test("saving a mixed layer records each session's runtime", function()
  local ok = layout_templates.save_current("Hybrid Layer Test")
  assert_true(ok, "save_current succeeded")

  local lib = storage.load()
  local _, tmpl = storage.find_template(lib, "Hybrid Layer Test")
  assert_true(tmpl ~= nil, "template saved")

  local seen = {}
  for _, layer in ipairs(tmpl.layers or {}) do
    for _, sess in ipairs(layer.sessions or {}) do
      if sess.runtime then seen[sess.runtime] = (seen[sess.runtime] or 0) + 1 end
    end
  end
  assert_true(seen.claude and seen.claude > 0, "claude session persisted with runtime")
  assert_true(seen.codex and seen.codex > 0, "codex session persisted with runtime")
end)

test("legacy templates without a runtime field still resolve a command", function()
  -- Templates written before multi-runtime support only stored `command`.
  assert_eq("claude", runtime.from_command("claude"), "legacy claude pin")
  assert_eq("codex", runtime.from_command("codex"), "legacy codex pin")
end)

pcall(layout_templates.delete, "Hybrid Layer Test")

print("")
print("-- launch wiring --")

test("Happy honours an explicit runtime", function()
  local launcher = require("ccasp.repo_launcher")
  launcher.open_repo_happy(cwd, "codex")
  vim.wait(600, function() return false end)

  local found
  for _, listed in ipairs(sessions.list()) do
    local s = sessions.get(listed.id)
    if s and s.command == runtime.happy_command("codex") then found = s end
  end
  assert_true(found ~= nil, "a session launched with `happy codex`")
  assert_eq("codex", found.runtime, "tagged as codex")
end)

test("sessions.list exposes command and runtime", function()
  local listed = sessions.list()
  assert_true(#listed > 0, "at least one session listed")
  local any = false
  for _, s in ipairs(listed) do
    if s.command ~= nil and s.runtime ~= nil then any = true end
  end
  assert_true(any, "list projection carries command/runtime for UIs to render")
end)

-- Every interactive entry point must go through the picker. A bare
-- open_repo/open_repo_happy call silently falls back to the default runtime,
-- which is how Happy ended up always launching Claude.
test("no interactive launch site bypasses the runtime picker", function()
  local root = "H:/CCASP/claude-cli-advanced-starter-pack/nvim-ccasp/lua/ccasp/"
  local offenders = {}
  for _, rel in ipairs({ "repo_launcher/ui.lua", "appshell/flyout.lua" }) do
    local fh = io.open(root .. rel, "r")
    if fh then
      local n = 0
      for line in fh:lines() do
        n = n + 1
        -- Match calls that are NOT the _pick variants.
        if line:match("open_repo_happy%s*%(") and not line:match("open_repo_happy_pick") then
          table.insert(offenders, rel .. ":" .. n)
        elseif line:match("%.open_repo%s*%(") and not line:match("open_repo_pick") then
          table.insert(offenders, rel .. ":" .. n)
        end
      end
      fh:close()
    end
  end
  assert_true(#offenders == 0, "bypassing call sites: " .. table.concat(offenders, ", "))
end)

test("the <C-S-n> spawn action routes through the picker", function()
  -- Resolved lazily so the test fails loudly if the module name ever moves.
  local ok = pcall(require, "ccasp.runtime_picker")
  assert_true(ok, "runtime_picker resolvable")
  local map
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if m.lhs == "<C-S-N>" or m.lhs == "<C-S-n>" then map = m end
  end
  assert_true(map ~= nil, "<C-S-n> is mapped")
  assert_true(not tostring(map.desc or ""):match("Claude"),
    "description should not name a single runtime, got: " .. tostring(map.desc))
end)

sessions.suppress_cli_launch(false)
pcall(sessions.kill_all)

print("")
print(string.format("Results: %d passed, %d failed", passed, failed))
print(failed == 0 and "ALL PASSED" or "FAILED")
vim.cmd(failed == 0 and "qall!" or "cquit")
