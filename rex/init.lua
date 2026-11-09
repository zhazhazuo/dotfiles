-- Rex configuration, migrated from tmux, Herdr and Ghostty.
-- Prefix is ctrl+s, as in every source.

-- ~/dotfiles/tmux/options.conf:23
rex.bind("ctrl+s>ctrl+s", "pane.send_key", { key = "ctrl+s" })

-- ~/dotfiles/tmux/binds.conf:4
rex.bind("ctrl+s>shift+\\", "pane.split", { direction = "right" })

-- ~/dotfiles/tmux/binds.conf:15-18
rex.bind("ctrl+s>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+s>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+s>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+s>l", "pane.focus", { direction = "right" })

-- ~/dotfiles/tmux/binds.conf:34
rex.bind("ctrl+s>ctrl+c", "session.switch")

-- ~/.config/herdr/config.toml:20 resize mode
rex.mode("resize", { exclusive = true })
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/escape", "client.mode.exit")
rex.bind("ctrl+s>r", "client.mode.enter", { name = "resize" })
rex.bind("resize/left", "pane.resize", { direction = "left" })
rex.bind("resize/down", "pane.resize", { direction = "down" })
rex.bind("resize/up", "pane.resize", { direction = "up" })
rex.bind("resize/right", "pane.resize", { direction = "right" })

-- ~/.config/herdr/config.toml sessions
rex.bind("ctrl+s>shift+n", "session.new")
rex.bind("ctrl+s>shift+w", "session.rename")
rex.bind("ctrl+s>shift+d", "session.close")
rex.bind("ctrl+s>s", "session.switch")
rex.bind("ctrl+s>g", "session.switch")

-- ~/.config/herdr/config.toml client
rex.bind("ctrl+s>shift+r", "client.config.reload")
rex.bind("ctrl+s>b", "client.sidebar.toggle")

-- ~/.config/herdr/config.toml tabs
rex.bind("ctrl+s>c", "client.tab.new")
rex.bind("ctrl+s>shift+x", "client.tab.close")
rex.bind("ctrl+s>p", "client.tab.previous")
rex.bind("ctrl+s>n", "client.tab.next")
rex.bind("ctrl+s>,", "client.tab.rename")

-- ~/.config/herdr/config.toml panes
rex.bind("ctrl+s>v", "pane.split", { direction = "right" })
rex.bind("ctrl+s>-", "pane.split", { direction = "down" })
rex.bind("ctrl+s>x", "pane.close")
rex.bind("ctrl+s>z", "pane.zoom")

-- ~/.config/herdr/config.toml:9 detach. Herdr leaves the server running.
-- Rex always keeps its server running, so this closes the window instead.
rex.bind("ctrl+s>q", "client.window.close")

-- ~/.config/herdr/config.toml:110 prefix+w recent tab toggle.
-- Herdr swaps the two most recent tabs. Rex steps back one tab in order.
rex.bind("ctrl+s>w", "client.tab.previous")

-- ~/.config/herdr/config.toml:111 prefix+tab last workspace toggle.
-- Herdr swaps the two most recent workspaces. Rex steps back one session.
-- Herdr's prefix+tab returns to the session you were in before this one. Rex
-- keeps no record of that: the app holds the session it shows and the server
-- cannot ask for it. A key press does say where it is, in the session of the
-- focused pane, so the visit order is remembered here from press to press. A
-- session chosen another way is learned on the next press.
local recent_sessions = {}
local RECENT_SESSIONS_MAX = 10

local function app_client()
  for _, client in ipairs((rex.call("client.list") or {}).clients or {}) do
    if client.info ~= nil and client.info.kind == "app" then return client end
  end
  return nil
end

rex.action{
  name        = "session_toggle_recent",
  title       = "Session: Last Two",
  description = "Switch to the session this key last came from, and back on the next press.",
  run         = function(ctx)
    local session = ctx.session_id
    if session == nil then error("no session to switch from", 0) end

    local order = { session }
    for _, visited in ipairs(recent_sessions) do
      if visited ~= session and #order < RECENT_SESSIONS_MAX then table.insert(order, visited) end
    end
    recent_sessions = order

    -- The second entry is where the key last came from. On the first press there
    -- is none, so the neighbouring session in the list stands in.
    local target = order[2]
    if target == nil then
      local all = (rex.call("session.list") or {}).sessions or {}
      for index, entry in ipairs(all) do
        if entry.session_id == session and #all > 1 then
          target = all[index == 1 and #all or index - 1].session_id
          break
        end
      end
    end
    if target == nil then error("no other session to switch to", 0) end

    local app = app_client()
    if app == nil then error("the Rex app is not connected", 0) end
    local asked, err = rex.call("client.perform", {
      client_id  = app.client_id,
      action     = "session.select",
      args       = { session_id = target },
      session_id = target,
      origin     = "key",
    })
    if asked == nil then error(err, 0) end

    return { session_id = target }
  end,
}
rex.bind("ctrl+s>tab", "session_toggle_recent")

-- Not migrated: ~/.config/herdr/config.toml:117-128, prefix+C, prefix+M and
-- prefix+P agent panes. The machine runs no claude or opencode on the pane's
-- PATH, so the keys had nothing to start. A plain split with "-" or "v" and
-- the agent typed into it does the same job.

-- ~/.config/herdr/config.toml:141 prefix+T scratch popup, 80% by 80%.
-- A floating layer replaces the popup window.
rex.action{
  name  = "scratch",
  title = "Open Scratch Popup",
  run   = function(ctx, args)
    local layer, err = rex.session.new_layer{
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus  = true,
      layout = rex.layout.block{ flavor = "com.superlogical.terminal.shell" },
    }
    if err ~= nil then error(err, 0) end
    return { layer_id = layer.layer_id, block_id = layer.block_ids[1] }
  end,
}
rex.bind("ctrl+s>shift+t", "scratch")

-- Pane movement. Herdr bound neither move nor swap, so these keys are new.
-- pane.move swaps the pane with its neighbour in that direction.
rex.bind("ctrl+s>shift+h", "pane.move", { direction = "left" })
rex.bind("ctrl+s>shift+j", "pane.move", { direction = "down" })
rex.bind("ctrl+s>shift+k", "pane.move", { direction = "up" })
rex.bind("ctrl+s>shift+l", "pane.move", { direction = "right" })

-- Move the pane out of this tab: to a chosen tab, or into a new one.
rex.bind("ctrl+s>shift+o", "pane.move_to_tab")
rex.bind("ctrl+s>shift+a", "pane.move_to_new_tab")

-- Rex actions with no key of their own and no app default.
rex.bind("ctrl+s>e", "pane.balance")
rex.bind("ctrl+s>shift+q", "client.visibility.toggle")
rex.bind("ctrl+s>shift+tab", "session.next")

-- Flip the orientation of the split that holds the focused pane: a row of
-- panes becomes a stack, and a stack becomes a row. Rex sets a split's
-- direction when the split is created, so this moves the pane to the
-- perpendicular side of its sibling and lets the server rebuild the split.
local function layout_leaves(node, out)
  out = out or {}
  if type(node) ~= "table" then return out end
  if node.block_id ~= nil then
    table.insert(out, node.block_id)
  elseif node.split ~= nil then
    layout_leaves(node.split.before, out)
    layout_leaves(node.split.after, out)
  end
  return out
end

-- Returns the split that holds block_id directly, and which side it is on.
local function split_around(node, block_id)
  if type(node) ~= "table" or node.split == nil then return nil end
  for _, side in ipairs({ "before", "after" }) do
    local child = node.split[side]
    if type(child) == "table" then
      if child.block_id == block_id then
        return node.split, side
      end
      local found, where = split_around(child, block_id)
      if found ~= nil then return found, where end
    end
  end
  return nil
end

rex.action{
  name        = "flip_split",
  title       = "Flip Split Orientation",
  description = "Turn the focused pane's row into a stack, or its stack into a row.",
  args        = { block = "string?" },
  run         = function(ctx, args)
    local target = args.block or ctx.block_id
    if target == nil then error("no focused pane to flip", 0) end

    local view, verr = rex.session.view{}
    if view == nil then error(verr, 0) end

    for _, window in ipairs(view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        local split, side = split_around(layer.layout, target)
        if split ~= nil then
          local other = split[side == "before" and "after" or "before"]
          local anchor = layout_leaves(other)[1]
          if anchor == nil then error("the other side of the split is empty", 0) end

          local direction = split.direction == "horizontal" and "vertical" or "horizontal"
          local moved, merr = rex.session.move_block{
            block_id        = target,
            anchor_block_id = anchor,
            direction       = direction,
            side            = side,
            ratio           = split.ratio,
          }
          if moved == nil then error(merr, 0) end

          return {
            block_id        = target,
            direction       = direction,
            side            = side,
            anchor_block_id = anchor,
          }
        end
      end
    end

    error("the focused pane is not inside a split", 0)
  end,
}
rex.bind("ctrl+s>space", "flip_split")

-- A pane is hidden by floating it and minimising the new layer, because a
-- window must keep a visible pane and only a floating layer can be minimised.
-- Floating takes the pane out of the layout, and the server cannot say later
-- where it sat, so the restore point is recorded here first. The list is
-- last-in-first-out, so two hidden panes come back in the reverse order. The
-- record lives in the config's Lua state: reloading the config, or restarting
-- Rex, forgets a hidden pane's place, and restore_pane then says so.
local hidden_panes = {}

-- The split that holds block_id directly, with the block to restore beside.
-- The block next to the pane is the one to split: the last block of the other
-- side when the pane sat after it, the first when it sat before. Splitting that
-- one puts the pane back next to its old neighbour and in the same order.
local function split_beside(node, block_id)
  local split, side = split_around(node, block_id)
  if split == nil then return nil end
  local leaves = layout_leaves(split[side == "before" and "after" or "before"])
  local anchor = side == "before" and leaves[1] or leaves[#leaves]
  if anchor == nil then return nil end
  return { anchor = anchor, direction = split.direction, side = side, ratio = split.ratio }
end

-- The layer and window that hold a block, or nil when it is not in a window.
local function layer_of(view, block_id)
  for _, window in ipairs(view.windows or {}) do
    for _, layer in ipairs(window.layers or {}) do
      for _, leaf in ipairs(layout_leaves(layer.layout)) do
        if leaf == block_id then return layer, window end
      end
    end
  end
  return nil
end

rex.action{
  name        = "minimise_pane",
  title       = "Minimise Pane",
  description = "Hide the focused pane as a minimised floating panel, and remember where it sat.",
  keywords    = "hide minimise minimize stash shrink",
  args        = { block = "string?", session = "string?" },
  run         = function(ctx, args)
    local session = args.session or ctx.session_id
    local target = args.block or ctx.block_id
    if session == nil then error("no session to minimise a pane in", 0) end
    if target == nil then error("no focused pane to minimise", 0) end

    local view, verr = rex.session.view{ session_id = session }
    if view == nil then error(verr, 0) end

    local layer, window = layer_of(view, target)
    if layer == nil then error("the pane is not in a window of this session", 0) end

    if layer.kind == "floating" then
      local hidden, herr = rex.session.set_layer_state{
        session_id = session,
        layer_id   = layer.layer_id,
        state      = "minimized",
      }
      if hidden == nil then error(herr, 0) end
      table.insert(hidden_panes, {
        session_id = session,
        block_id   = target,
        layer_id   = layer.layer_id,
        window_id  = window.window_id,
        floating   = true,
      })
      return { block_id = target, layer_id = layer.layer_id, floating = true, revision = hidden.revision }
    end

    -- A window must keep one visible pane, so its last tiled pane stays.
    if #layout_leaves(layer.layout) < 2 then
      error("the window has one pane, and a window must keep a visible pane", 0)
    end

    local point = split_beside(layer.layout, target)
    local floated, ferr = rex.session.float_block{
      session_id = session,
      block_id   = target,
      bounds     = { 0.1, 0.1, 0.8, 0.8 },
    }
    if floated == nil then error(ferr, 0) end

    local hidden, herr = rex.session.set_layer_state{
      session_id = session,
      layer_id   = floated.layer_id,
      state      = "minimized",
    }
    if hidden == nil then
      -- Leave nothing behind: put the pane back in the split it came from.
      rex.session.move_block{
        session_id      = session,
        block_id        = target,
        anchor_block_id = point.anchor,
        direction       = point.direction,
        side            = point.side,
        ratio           = point.ratio,
      }
      error(herr, 0)
    end

    table.insert(hidden_panes, {
      session_id = session,
      block_id   = target,
      layer_id   = floated.layer_id,
      window_id  = window.window_id,
      floating   = false,
      anchor     = point.anchor,
      direction  = point.direction,
      side       = point.side,
      ratio      = point.ratio,
    })
    return {
      block_id = target,
      layer_id = floated.layer_id,
      anchor_block_id = point.anchor,
      revision = hidden.revision,
    }
  end,
}
rex.bind("ctrl+s>m", "minimise_pane")

rex.action{
  name        = "restore_pane",
  title       = "Restore Minimised Pane",
  description = "Put the last minimised pane back in its old split, or back on screen if it was floating.",
  keywords    = "restore unhide minimise minimize unstash show",
  args        = { block = "string?", session = "string?" },
  run         = function(ctx, args)
    local session = args.session or ctx.session_id
    if session == nil then error("no session to restore a pane in", 0) end

    local record
    for i = #hidden_panes, 1, -1 do
      local entry = hidden_panes[i]
      local matches = entry.session_id == session
      if matches and args.block ~= nil then matches = entry.block_id == args.block end
      if matches then
        record = table.remove(hidden_panes, i)
        break
      end
    end
    if record == nil then
      error("no pane was minimised in this session since the config loaded", 0)
    end

    if record.floating then
      local shown, serr = rex.session.set_layer_state{
        session_id = session,
        layer_id   = record.layer_id,
        state      = "normal",
        focus      = true,
      }
      if shown == nil then error(serr, 0) end
      return { block_id = record.block_id, floating = true, revision = shown.revision }
    end

    local view, verr = rex.session.view{ session_id = session }
    if view == nil then error(verr, 0) end

    -- The pane's old neighbour may have closed while the pane was hidden. Then
    -- the first pane left in the window takes its place as the anchor.
    local anchors = {}
    for _, window in ipairs(view.windows or {}) do
      if window.window_id == record.window_id then
        if record.anchor ~= nil then table.insert(anchors, record.anchor) end
        if window.focused_block_id ~= nil then table.insert(anchors, window.focused_block_id) end
        for _, layer in ipairs(window.layers or {}) do
          if layer.kind == "tiled" then
            for _, leaf in ipairs(layout_leaves(layer.layout)) do
              table.insert(anchors, leaf)
            end
          end
        end
      end
    end

    local used
    for _, anchor in ipairs(anchors) do
      if anchor ~= record.block_id then
        local moved, merr = rex.session.move_block{
          session_id      = session,
          block_id        = record.block_id,
          anchor_block_id = anchor,
          direction       = record.direction,
          side            = record.side,
          ratio           = record.ratio,
        }
        if moved ~= nil then
          used = anchor
          break
        end
      end
    end

    if used == nil then
      -- Nothing in the window can hold the pane. Show it as a floating panel
      -- rather than keep it hidden with no place to return to.
      local shown, serr = rex.session.set_layer_state{
        session_id = session,
        layer_id   = record.layer_id,
        state      = "normal",
        focus      = true,
      }
      if shown == nil then error("the pane has no place to return to", 0) end
      return { block_id = record.block_id, floating = true, fallback = true }
    end

    rex.session.focus_block{ session_id = session, block_id = record.block_id }
    return {
      block_id        = record.block_id,
      anchor_block_id = used,
      direction       = record.direction,
      side            = record.side,
      ratio           = record.ratio,
    }
  end,
}
rex.bind("ctrl+s>shift+m", "restore_pane")

-- Not migrated: ~/.config/herdr/config.toml:131-139, five of the six Annotate
-- plugin keys (prefix+shift+a, prefix+ctrl+a, prefix+m, prefix+o,
-- prefix+shift+o). Rex has no plugin surface, and the clipboard and manage
-- actions have no equivalent. prefix+a is rebuilt below as plannotator_review.
--
-- Herdr's annotate.capture reviews the terminal selection, which Rex has no way
-- to read, so this reviews a named document, or the focused pane's whole text.
-- Herdr's --deliver-to pane hand-off becomes the wrapper's job: it pastes the
-- new annotations into the target block's prompt as one paste event.
rex.action({
  name        = "plannotator_review",
  title       = "Review with Plannotator",
  description = "Review a document, the last message an agent wrote, or a plain pane's text, in a floating Plannotator pane, and paste the annotations into that pane's prompt.",
  keywords    = "annotate review plan plannotator message",
  args        = { path = "string?", source = "string?", target = "string?", session = "string?" },
  run         = function(ctx, args)
    local terminal = "com.superlogical.terminal"
    local session = args.session or ctx.session_id
    local target = args.target or ctx.block_id

    if session == nil then error("no session to review in", 0) end
    if target == nil then error("no block to review", 0) end

    -- A call that names another session is answered only for a stream attached to
    -- it, so a review of a pane outside the caller's session attaches first.
    rex.call("session.attach", { session_id = session })

    -- The review pane starts where the target's program is, so a review of the
    -- focused pane finds its relative paths, and so the message lookup reads the
    -- transcript of the session started there.
    local cwd
    local pwd = rex.call(terminal .. ".pwd", {
      session_id = session,
      block_id   = target,
      args       = {},
    })
    if pwd ~= nil and type(pwd.pwd) == "string" then
      -- A file URL: file://host/path, or file:///path.
      cwd = pwd.pwd:gsub("^file://[^/]*", "")
    end

    -- An agent pane is reviewed from its transcript, which holds the message
    -- without the prompt box, the status line or the terminal's line breaks.
    -- Plannotator's own picker lists that transcript's replies, which is the flow
    -- the Herdr plugin uses: the reply worth reviewing is rarely the last one.
    -- Any other pane is reviewed as a folder with Plannotator's file tree, which
    -- is what the Herdr plugin's folder key does. source=pane keeps the screen.
    local mode = "folder"
    local source = args.source or "auto"
    if source == "message" or source == "pick" or source == "pane" then
      mode = source == "pane" and "-" or source
    elseif source == "auto" and args.path == nil then
      local process = rex.call(terminal .. ".process", {
        session_id = session,
        block_id   = target,
        args       = {},
      })
      local foreground = process and process.foreground
      local program = foreground and (foreground.argv0 or foreground.name) or nil
      if program ~= nil then program = program:gsub("^-", "") end
      if program == "pi" then mode = "pick" end
    end

    local layer, err = rex.session.new_layer({
      bounds = { 0.05, 0.05, 0.9, 0.85 },
      focus  = true,
      layout = rex.layout.block({
        flavor  = "com.superlogical.terminal.shell",
        label   = "review",
        options = {
          shell   = "none",
          cwd     = cwd,
          command = {
            "/bin/sh", "-c",
            'exec "$HOME/dotfiles/rex/scripts/plannotator-review.sh" "$@"',
            "plannotator-review", args.path or mode, session, target,
          },
          exit = { on_completion = true },
        },
      }),
    })
    if layer == nil then error(err, 0) end

    return {
      block_id = layer.block_ids[1],
      document = args.path
        or (mode == "pick" and "a chosen agent message")
        or (mode == "message" and "last agent message")
        or (mode == "-" and "pane text")
        or "this folder",
    }
  end,
})
rex.bind("ctrl+s>a", "plannotator_review")
