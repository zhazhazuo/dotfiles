-- listing.lua — every session, tab and pane as one JSON document.
--
-- Two ways to run it:
--
--   rex do listing.lua                        print the listing and exit
--   rex do listing.lua snapshot=PATH --all    keep PATH current, and stay running
--
-- The second form is the snapshot daemon. It builds the listing once, writes it
-- to PATH, then rebuilds it a quarter of a second after each change. A rebuild
-- answers inside one process, so the cost is the server's own API calls and not
-- the half second the rex CLI takes to start. A reader therefore never waits on
-- Rex: it reads the file.
--
-- The file is written to a temporary name and renamed into place, so a reader
-- sees either the old document or the new one, never half of either.
--
-- Why the daemon exists at all: the Raycast view has to read a few hundred
-- bytes, and the CLI costs about 0.6 s before it does anything, which is a delay
-- on every open. The daemon pays that once and keeps the answer current while
-- nobody is looking.
--
-- Attaching first is what makes one pass work from outside a Rex terminal: a
-- stream that is attached to no session is refused a view. Program status is
-- read per block, because that is the only channel a program uses to say what it
-- is doing, and a block without a record is still a pane with no state to show.

local ARRAY = {}

local function array(items)
  return setmetatable(items or {}, ARRAY)
end

local function quote(text)
  local out = { '"' }
  for index = 1, #text do
    local byte = text:sub(index, index)
    local code = text:byte(index)
    if byte == '"' then
      out[#out + 1] = '\\"'
    elseif byte == "\\" then
      out[#out + 1] = "\\\\"
    elseif byte == "\n" then
      out[#out + 1] = "\\n"
    elseif byte == "\r" then
      out[#out + 1] = "\\r"
    elseif byte == "\t" then
      out[#out + 1] = "\\t"
    elseif code < 32 then
      out[#out + 1] = string.format("\\u%04x", code)
    else
      out[#out + 1] = byte
    end
  end
  out[#out + 1] = '"'
  return table.concat(out)
end

local function encode(value)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return tostring(value) end
  if kind == "number" then
    if value == math.floor(value) then return string.format("%d", value) end
    return tostring(value)
  end
  if kind == "string" then return quote(value) end
  if getmetatable(value) == ARRAY then
    local parts = {}
    for index = 1, #value do parts[index] = encode(value[index]) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do table.insert(keys, key) end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = quote(tostring(key)) .. ":" .. encode(value[key])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function foreground_program(session_id, block_id)
  local process = rex.call("com.superlogical.terminal.process", {
    session_id = session_id,
    block_id = block_id,
  })
  local foreground = process and process.foreground
  local program = foreground and (foreground.argv0 or foreground.name) or nil
  -- A login shell reports itself as -fish or -zsh.
  if program ~= nil then program = program:gsub("^-", "") end
  return program
end

local function working_directory(session_id, block_id)
  local pwd = rex.call("com.superlogical.terminal.pwd", {
    session_id = session_id,
    block_id = block_id,
  })
  local cwd = pwd and pwd.pwd or nil
  if cwd ~= nil then cwd = cwd:gsub("^file://[^/]*", "") end
  return cwd
end

local function status_record(session_id, block_id)
  local status = rex.call("com.superlogical.terminal.program_status", {
    session_id = session_id,
    block_id = block_id,
  })
  local records = (status and status.records) or {}
  -- The root record carries no id; child records are named `build/test`.
  for _, candidate in ipairs(records) do
    if (candidate.id or "") == "" then return candidate end
  end
  return records[1]
end

local function list_blocks(session_id, window)
  local blocks = array()
  for _, layer in ipairs(window.layers or {}) do
    for _, block in ipairs(layer.blocks or {}) do
      local record = status_record(session_id, block.block_id)
      blocks[#blocks + 1] = {
        block_id = block.block_id,
        program = foreground_program(session_id, block.block_id),
        cwd = working_directory(session_id, block.block_id),
        label = block.label,
        floating = layer.kind ~= "tiled",
        focused = window.focused_block_id == block.block_id,
        state = record and record.state or nil,
        app = record and (record.effective_app or record.app) or nil,
        message = record and record.msg or nil,
        blocked_kind = record and record.kind or nil,
        updated_at = record and record.updated_at or nil,
      }
    end
  end
  return blocks
end

local function build()
  local sessions = array()

  for _, session in ipairs((rex.call("session.list") or {}).sessions or {}) do
    rex.call("session.attach", { session_id = session.session_id })

    local view = rex.session.view({ session_id = session.session_id })
    local windows = array()

    for _, window in ipairs((view and view.windows) or {}) do
      windows[#windows + 1] = {
        window_id = window.window_id,
        label = window.label,
        active = (view.active_window_id == window.window_id),
        blocks = list_blocks(session.session_id, window),
      }
    end

    sessions[#sessions + 1] = {
      session_id = session.session_id,
      label = session.label,
      windows = windows,
    }
  end

  return { sessions = sessions }
end

local snapshot_path = rex.args.snapshot

if snapshot_path == nil then
  return build()
end

local function write()
  local listing = build()
  listing.generated_at = os.time()
  local temporary = snapshot_path .. ".tmp"
  local file = io.open(temporary, "w")
  if file == nil then
    rex.log("listing: cannot write " .. temporary)
    return
  end
  file:write(encode(listing))
  file:close()
  os.rename(temporary, snapshot_path)
end

write()

-- A status change, a new pane or a renamed tab all change the document. The
-- changes arrive in bursts, so one rebuild follows the last of a burst.
local pending

local function refresh()
  if pending then pending:cancel() end
  pending = rex.after(0.25, function()
    pending = nil
    write()
  end)
end

for _, event in ipairs({
  "session_view_changed",
  "session_created",
  "session_destroyed",
  "session_label_changed",
  "window_created",
  "window_closed",
  "window_label_changed",
  "active_window_changed",
  "block_created",
  "block_closed",
  "terminal.program_status_changed",
  "terminal.program_status_removed",
  "terminal.process_changed",
  "terminal.pwd_changed",
}) do
  rex.on(event, refresh)
end
