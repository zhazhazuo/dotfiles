-- Resize the focused pane to about 61.8% of its window after focus changes.
-- Run with: rex do ~/dotfiles/rex/scripts/golden-ratio.lua --all
--
-- From fo zcodes' dotfiles, config/rex/golden_ratio.lua, kept close to the
-- original so a later version can be diffed against it. The daemon form is what
-- rex/launchd keeps running; `test=1` runs the checks built into the file.

local GOLDEN_RATIO = 0.6180339887498949
local MINIMUM_RATIO = 0.05
local MAXIMUM_RATIO = 0.95
local MINIMUM_DELTA = 0.02
local DEBOUNCE_SECONDS = 0.12

local function append_path(path, step)
  local copy = {}
  for index, existing in ipairs(path) do
    copy[index] = existing
  end
  copy[#copy + 1] = step
  return copy
end

local function find_path(node, block_id, ancestors)
  if not node then
    return nil
  end
  if node.block_id == block_id then
    return ancestors
  end

  local split = node.split
  if not split then
    return nil
  end

  for _, side in ipairs({ "before", "after" }) do
    local path = append_path(ancestors, {
      split = split,
      focused_side = side,
    })
    local found = find_path(split[side], block_id, path)
    if found then
      return found
    end
  end
  return nil
end

local function first_block_id(node)
  if not node then
    return nil
  end
  if node.block_id then
    return node.block_id
  end

  local split = node.split
  if not split then
    return nil
  end
  return first_block_id(split.before) or first_block_id(split.after)
end

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

local function make_plan(layout, focused_block_id)
  local path = find_path(layout, focused_block_id, {})
  if not path or #path == 0 then
    return {}
  end

  local crossings = {}
  for _, step in ipairs(path) do
    local direction = step.split.direction
    crossings[direction] = (crossings[direction] or 0) + 1
  end

  local plan = {}
  for _, step in ipairs(path) do
    local split = step.split
    local before_block_id = first_block_id(split.before)
    local after_block_id = first_block_id(split.after)
    if not before_block_id or not after_block_id then
      return nil, "split has no blocks on both sides"
    end

    local share = GOLDEN_RATIO ^ (1 / crossings[split.direction])
    local target_ratio = share
    if step.focused_side == "after" then
      target_ratio = 1 - share
    end

    plan[#plan + 1] = {
      direction = split.direction,
      before_block_id = before_block_id,
      after_block_id = after_block_id,
      current_ratio = split.ratio,
      ratio = clamp(target_ratio, MINIMUM_RATIO, MAXIMUM_RATIO),
    }
  end
  return plan
end

local function active_window(view)
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == view.active_window_id then
      return window
    end
  end
  return nil
end

local function focused_signature(view)
  local window = active_window(view)
  if not window then
    return nil
  end
  if not window.focused_block_id then
    return window.window_id .. ":"
  end
  return window.window_id .. ":" .. window.focused_block_id
end

local function apply_to_view(session_id, view)
  local window = active_window(view)
  if not window or window.zoomed_block_id then
    return
  end

  local tiled_layer
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" then
      tiled_layer = layer
      break
    end
  end
  if not tiled_layer or not tiled_layer.layout then
    return
  end

  local focused_block_id = window.focused_block_id
  if not focused_block_id then
    return
  end

  local plan, plan_error = make_plan(tiled_layer.layout, focused_block_id)
  if not plan then
    rex.log("warn", "golden ratio: " .. plan_error)
    return
  end

  for _, resize in ipairs(plan) do
    if math.abs(resize.current_ratio - resize.ratio) >= MINIMUM_DELTA then
      local result, err = rex.session.resize_pane{
        session_id = session_id,
        direction = resize.direction,
        before_block_id = resize.before_block_id,
        after_block_id = resize.after_block_id,
        ratio = resize.ratio,
      }
      if not result then
        rex.log("warn", "golden ratio: " .. tostring(err))
        return
      end
    end
  end
end

local function run_tests()
  local function pane(block_id)
    return { block_id = block_id }
  end

  local function split(direction, ratio, before, after)
    return {
      split = {
        direction = direction,
        ratio = ratio,
        before = before,
        after = after,
      },
    }
  end

  local function close(actual, expected)
    assert(math.abs(actual - expected) < 1e-9,
      "expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end

  local nested = split("horizontal", 0.5, pane("a"),
    split("horizontal", 0.5, pane("b"), pane("c")))
  local nested_plan = assert(make_plan(nested, "b"))
  assert(#nested_plan == 2)
  close(nested_plan[1].ratio, 1 - math.sqrt(GOLDEN_RATIO))
  close(nested_plan[2].ratio, math.sqrt(GOLDEN_RATIO))
  close((1 - nested_plan[1].ratio) * nested_plan[2].ratio, GOLDEN_RATIO)
  assert(nested_plan[1].before_block_id == "a")
  assert(nested_plan[1].after_block_id == "b")

  local mixed = split("horizontal", 0.5, pane("left"),
    split("vertical", 0.5, pane("top"), pane("bottom")))
  local mixed_plan = assert(make_plan(mixed, "bottom"))
  assert(#mixed_plan == 2)
  close(1 - mixed_plan[1].ratio, GOLDEN_RATIO)
  close(1 - mixed_plan[2].ratio, GOLDEN_RATIO)
  assert(#make_plan(mixed, "missing") == 0)
  assert(#make_plan(pane("alone"), "alone") == 0)
  print("golden_ratio.lua: tests passed")
end

if rex.args and rex.args.test then
  run_tests()
  return
end

local last_revision = {}
local last_focus = {}
local pending_timers = {}

local function attach_and_remember(session_id)
  local attached, attach_error = rex.session.attach{ session_id = session_id }
  if not attached or not attached.view then
    rex.log("warn", "golden ratio: cannot attach to session: " .. tostring(attach_error))
    return
  end

  last_revision[session_id] = attached.view.revision
  last_focus[session_id] = focused_signature(attached.view)
end

local sessions, sessions_error = rex.call("session.list")
if sessions then
  for _, session in ipairs(sessions.sessions or {}) do
    attach_and_remember(session.session_id)
  end
else
  rex.log("warn", "golden ratio: cannot list sessions: " .. tostring(sessions_error))
end

rex.on("session_view_changed", function(ctx, event)
  local session_id = ctx.session_id
  local revision = event.revision
  if not session_id or type(revision) ~= "number" then
    return
  end
  if revision <= (last_revision[session_id] or -1) then
    return
  end
  last_revision[session_id] = revision

  local previous_timer = pending_timers[session_id]
  if previous_timer then
    previous_timer:cancel()
  end

  local timer
  timer = rex.after(DEBOUNCE_SECONDS, function()
    if pending_timers[session_id] ~= timer then
      return
    end
    pending_timers[session_id] = nil

    local view, err = rex.session.view{ session_id = session_id }
    if not view then
      rex.log("warn", "golden ratio: cannot read session view: " .. tostring(err))
      return
    end
    if view.revision < revision then
      return
    end
    if view.revision > last_revision[session_id] then
      last_revision[session_id] = view.revision
    end

    local signature = focused_signature(view)
    if signature == last_focus[session_id] then
      return
    end
    last_focus[session_id] = signature
    apply_to_view(session_id, view)
  end)
  pending_timers[session_id] = timer
end)

rex.on("session_created", function(_, event)
  if event.session_id then
    attach_and_remember(event.session_id)
  end
end)

rex.on("session_destroyed", function(_, event)
  local session_id = event.session_id
  if not session_id then
    return
  end
  local timer = pending_timers[session_id]
  if timer then
    timer:cancel()
  end
  pending_timers[session_id] = nil
  last_revision[session_id] = nil
  last_focus[session_id] = nil
end)
