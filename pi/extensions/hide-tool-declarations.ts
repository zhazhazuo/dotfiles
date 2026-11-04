/**
 * hide-tool-declarations — keep the tool declarations small without losing tool access.
 *
 * Why this exists
 * ---------------
 * pi has three ways to keep a tool out of a request, and none of them covers a third-party
 * tool that registers itself `direct` and active:
 *
 *   - `defaultTools` / `--tools` remove the tool from the active set. A `direct` tool that
 *     is inactive is also not callable, so the model can no longer reach it at all.
 *   - `exposure: "codemode"` or `"deferred"` keeps a tool callable without declaring it,
 *     but exposure is fixed where the tool is registered, inside the package.
 *
 * The Confluence, pi-lens, subagent, browser and Atlassian packages all register `direct`
 * and active. In session 01a18b58 their declarations cost 58,425 bytes, about 14,600
 * tokens, on every one of 754 model calls.
 *
 * How it works
 * ------------
 * `prepareLoadout().hiddenDeclarations` is the one projection that fits. A hidden tool
 * stays active and callable against `ctx.executeTool()`, but its declaration leaves the
 * request and its name leaves the `<tools>` list and `<rules>` section of the system
 * prompt. This extension hides every `direct` tool outside the whitelist, and registers
 * `run_tool` so a hidden tool stays callable on instruction.
 *
 * The filter is applied per request, not to the session: the transcript keeps the full
 * active set, so `/tree`, `/fork` and resume restore it unchanged.
 *
 * Awareness
 * ---------
 * A hidden tool is invisible, and nothing else in the prompt says it exists. The
 * `before_agent_start` handler therefore adds one `hidden_tools` section that names the
 * domains and the way to reach them. It is built from the live registry on every run,
 * so a package that adds or drops tools changes the prompt without an edit here. A group
 * with no hidden tools is left out, and any tool the groups do not match lands on a final
 * `other` line, so no tool stays silently invisible.
 *
 * Configuration
 * -------------
 * The whitelist lives in `tool-whitelist.json` in the pi agent directory, under
 * `keepDeclared`. The file is created from `defaultToolsKeptDeclared` on first load.
 * `/tool-whitelist` opens a checklist in the TUI and writes the file on every change;
 * in other modes it prints the current list, and `/tool-whitelist reset` restores the
 * default. `run_tool` is always kept, so a wrong entry cannot close the only path to a
 * hidden tool. A hand edit applies on `/reload` or in a new session.
 *
 * Measured on the 64-tool loadout of this machine, the default whitelist declares 19 tools
 * and 17,554 bytes of declarations in a headless session; `ask_user_question` adds about
 * 3.9 KB in an interactive one. Every hidden domain stays reachable through `run_tool` or
 * a codemode script.
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import {
  getAgentDir,
  getSettingsListTheme,
  type ExtensionAPI,
  type ExtensionContext,
  type ToolLoadout,
} from "@earendil-works/pi-coding-agent"
import { Container, type SettingItem, SettingsList } from "@earendil-works/pi-tui"
import { Type } from "typebox"

/** Name of the tool that runs a tool whose declaration is hidden. */
export const RUN_TOOL_NAME = "run_tool"

/** File in the agent directory that holds the whitelist. */
export const WHITELIST_FILE_NAME = "tool-whitelist.json"

/** Command that opens the whitelist checklist. */
export const WHITELIST_COMMAND_NAME = "tool-whitelist"

/**
 * Tools declared when no whitelist file exists.
 *
 * The file reader stays because the system prompt names it in the skills hint. `codemode`
 * and `tool_search` stay because they are the discovery path for everything hidden.
 * `ask_user_question` stays because it is the only way to offer selectable options. The
 * subagent tools stay because delegation is routine work rather than an occasional reach
 * for a domain tool.
 *
 * `ls` stays because all ten subagent type definitions allow it, and a hidden declaration
 * contradicts every one of them.
 */
const defaultToolsKeptDeclared: readonly string[] = [
  "read",
  "bash",
  "edit",
  "write",
  "grep",
  "find",
  "ls",
  "todo",
  "ask_user_question",
  "codemode",
  "tool_search",
  RUN_TOOL_NAME,
  "agent_types",
  "agent_spawn",
  "agent_steer",
  "agent_wait",
  "agent_status",
  "agent_output",
  "agent_update",
  "agent_pause",
  "agent_stop",
]

/** The whitelist in force. Replaced by the file, the command, or the reset. */
let toolsKeptDeclared: ReadonlySet<string> = new Set(defaultToolsKeptDeclared)

/** A load error worth showing once the user can see it. */
let whitelistLoadWarning: string | undefined

/** The hidden declarations of the most recent loadout, or undefined before the first loadout. */
let lastHiddenDeclarations: readonly string[] | undefined

/** The pi-lens tools, named explicitly because they share no one prefix. */
const piLensToolNames: ReadonlySet<string> = new Set([
  "lens_diagnostics",
  "symbol_search",
  "effective_config",
  "project_report",
  "module_report",
  "read_symbol",
  "read_enclosing",
  "pi_lens_activate_tools",
])

/** One domain of hidden tools, with the line the prompt devotes to it. */
interface HiddenToolGroup {
  /** Domain word the model matches a task against. */
  readonly label: string
  /** What the domain covers, phrased as the model's own vocabulary. */
  readonly summary: string
  readonly matchesName: (name: string) => boolean
}

/**
 * Domains of hidden tools, in the order the prompt lists them.
 *
 * The subagent group excludes `agent_browser*` names in its own matcher, so the browser group
 * keeps them even though the subagent line comes first. A new package that matches no group
 * appears on the `other` line until a group is added here.
 */
const hiddenToolGroups: readonly HiddenToolGroup[] = [
  {
    label: "pi-lens",
    summary: "code navigation — symbol search, module outline, file outline, diagnostics, resolved config.",
    matchesName: (name) => piLensToolNames.has(name),
  },
  {
    label: "confluence",
    summary:
      "Confluence pages — read, search, children, comments, attachments, versions, and the write operations.",
    matchesName: (name) => name.startsWith("confluence_"),
  },
  {
    label: "agent_*",
    summary: "subagents — spawn, steer, wait, output, stop.",
    matchesName: (name) => name.startsWith("agent_") && !name.startsWith("agent_browser"),
  },
  {
    label: "agent_browser",
    summary: "browser — open a page, read refs, click, type, screenshot.",
    matchesName: (name) => name.startsWith("agent_browser"),
  },
  {
    label: "mcp__atlassian",
    summary: "Jira and Confluence over MCP — reach them with tool_search.",
    matchesName: (name) => name.startsWith("mcp__"),
  },
]

/** Path of the whitelist file in the agent directory. */
function whitelistFilePath(): string {
  return join(getAgentDir(), WHITELIST_FILE_NAME)
}

/**
 * Names that stay declared, as configured.
 *
 * A missing file is written from the default so the list can be edited. An unreadable or
 * malformed file falls back to the default and records one warning, because a broken
 * config must not leave every tool hidden.
 */
function readWhitelistFile(): readonly string[] {
  const path = whitelistFilePath()
  if (!existsSync(path)) {
    writeWhitelistFile(defaultToolsKeptDeclared)
    return defaultToolsKeptDeclared
  }
  try {
    const parsed: unknown = JSON.parse(readFileSync(path, "utf8"))
    const list = (parsed as { keepDeclared?: unknown } | null)?.keepDeclared
    if (Array.isArray(list) && list.every((name) => typeof name === "string")) {
      whitelistLoadWarning = undefined
      return list as readonly string[]
    }
    whitelistLoadWarning = `${path} has no keepDeclared string array. Using the default whitelist.`
  } catch (error) {
    whitelistLoadWarning = `${path} could not be read: ${(error as Error).message}. Using the default whitelist.`
  }
  return defaultToolsKeptDeclared
}

/** Write the whitelist as JSON. */
function writeWhitelistFile(names: readonly string[]): void {
  writeFileSync(whitelistFilePath(), `${JSON.stringify({ keepDeclared: [...names] }, null, 2)}\n`)
}

/** Read the file into force. Returns the names now kept. */
function loadWhitelist(): readonly string[] {
  const names = readWhitelistFile()
  toolsKeptDeclared = new Set(names)
  return names
}

/**
 * Whether a tool's declaration stays in the request.
 *
 * `run_tool` is kept whatever the file says: hiding it leaves every hidden tool unreachable.
 */
function isKeptDeclared(name: string): boolean {
  return name === RUN_TOOL_NAME || toolsKeptDeclared.has(name)
}

/**
 * Declared tools whose declarations this request leaves out.
 *
 * Only `direct` tools are hidden. A tool that `tool_search` loads keeps its `deferred`
 * exposure, so it stays declared once loaded; hiding it again would undo the search.
 * A hidden name stays active and callable.
 */
function hiddenToolNames(loadout: ToolLoadout): readonly string[] {
  const hidden = loadout.declared
    .map((tool) => tool.name)
    .filter((name) => !isKeptDeclared(name) && loadout.getExposure(name) === "direct")
  lastHiddenDeclarations = hidden
  return hidden
}

/**
 * Names the prompt section reports, kept in step with the declarations the request drops.
 *
 * The loadout snapshot is exact and covers tools that connect after the first prompt is
 * built, such as MCP tools. The registry scan is the fallback before any loadout has run.
 */
function hiddenDeclarationNames(pi: ExtensionAPI): readonly string[] {
  if (lastHiddenDeclarations) return lastHiddenDeclarations
  const active = new Set(pi.getActiveTools())
  return pi
    .getAllTools()
    .filter(
      (tool) =>
        active.has(tool.name) &&
        (tool.exposure ?? "direct") === "direct" &&
        !isKeptDeclared(tool.name),
    )
    .map((tool) => tool.name)
}

/**
 * The `hidden_tools` prompt section: how to reach an undeclared tool, and one line per domain.
 * Returns an empty string when nothing is hidden.
 *
 * The text carries no count. MCP tools connect after the first prompt is built, so a count
 * written here is short by five on the first run of a session. A claim that is sometimes
 * wrong costs more than the number is worth.
 *
 * The text is wrapped in `<hidden_tools>` tags by the prompt builder, so the tags are not here.
 */
function buildHiddenToolsSection(hiddenNames: readonly string[]): string {
  if (hiddenNames.length === 0) return ""
  const claimed = new Set<string>()
  const groupLines: string[] = []
  for (const group of hiddenToolGroups) {
    const members = hiddenNames.filter((name) => !claimed.has(name) && group.matchesName(name))
    if (members.length === 0) continue
    for (const name of members) claimed.add(name)
    groupLines.push(`- ${group.label}: ${group.summary}`)
  }
  const unclaimed = hiddenNames.filter((name) => !claimed.has(name))
  if (unclaimed.length > 0) groupLines.push(`- other: ${unclaimed.join(", ")}`)
  return [
    `Some installed tools are not declared to you. Find one with a codemode script:`,
    `searchTools("phrase") lists matches, describeTool(name) shows its arguments, and`,
    `tools.name(args) runs it. Or run it directly: ${RUN_TOOL_NAME}({tool: name, args: {...}}).`,
    ...groupLines,
  ].join("\n")
}

/** One line per kept tool and a count of the rest, for modes without the checklist. */
function describeWhitelist(pi: ExtensionAPI): string {
  const all = pi.getAllTools()
  const kept = all.filter((tool) => isKeptDeclared(tool.name)).map((tool) => tool.name)
  return `Declared: ${kept.join(", ")}\nHidden: ${all.length - kept.length} tool(s). Edit ${whitelistFilePath()} or run /${WHITELIST_COMMAND_NAME} in the TUI.`
}

/** Re-run the loadout so a changed whitelist takes effect without a restart. */
function reapplyWhitelist(pi: ExtensionAPI): void {
  pi.setActiveTools(pi.getActiveTools())
}

/** Open the checklist of every registered tool, writing the file on each change. */
async function openWhitelistChecklist(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
  await ctx.ui.custom((tui, theme, _kb, done) => {
    const draft = new Set(pi.getAllTools().filter((tool) => isKeptDeclared(tool.name)).map((tool) => tool.name))
    const items: SettingItem[] = pi.getAllTools().map((tool) => ({
      id: tool.name,
      label: tool.name,
      currentValue: draft.has(tool.name) ? "declared" : "hidden",
      values: ["declared", "hidden"],
    }))

    const container = new Container()
    container.addChild(
      new (class {
        render(_width: number) {
          return [
            theme.fg("accent", theme.bold("Tool declarations")),
            theme.fg("muted", `Saved to ${whitelistFilePath()}`),
            "",
          ]
        }
        invalidate() {}
      })(),
    )

    const settingsList = new SettingsList(
      items,
      Math.min(items.length + 2, 18),
      getSettingsListTheme(),
      (id, newValue) => {
        if (newValue === "declared") draft.add(id)
        else draft.delete(id)
        draft.add(RUN_TOOL_NAME)
        toolsKeptDeclared = new Set(draft)
        writeWhitelistFile([...draft])
        reapplyWhitelist(pi)
      },
      () => {
        done(undefined)
      },
    )

    container.addChild(settingsList)

    return {
      capturesViewportInput: settingsList.capturesViewportInput,
      render(width: number) {
        return container.render(width)
      },
      invalidate() {
        container.invalidate()
      },
      handleInput(data: string) {
        settingsList.handleInput?.(data)
        tui.requestRender()
      },
    }
  })
}

/**
 * Registers `run_tool`, hides every declaration outside the whitelist, adds the
 * `hidden_tools` prompt section, and exposes `/tool-whitelist` to edit the list.
 */
export default function (pi: ExtensionAPI) {
  loadWhitelist()

  pi.registerTool({
    name: RUN_TOOL_NAME,
    label: "Run tool",
    description:
      "Run a registered tool by name when the user asks for it. Undeclared tools, such as confluence_read or lens_diagnostics, run only through this tool.",
    parameters: Type.Object({
      tool: Type.String({ description: "Registered tool name" }),
      args: Type.Optional(
        Type.Record(Type.String(), Type.Unknown(), {
          description: "Arguments for that tool, matching its own schema",
        }),
      ),
    }),
    reachesTools: () => "all",
    prepareLoadout: (loadout) => ({ hiddenDeclarations: hiddenToolNames(loadout) }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const outcome = await ctx.executeTool(params.tool, params.args ?? {}, { signal })
      return outcome.isError ? { ...outcome.result, isError: true } : outcome.result
    },
  })

  pi.registerCommand(WHITELIST_COMMAND_NAME, {
    description: "Choose which tool declarations stay in the model request",
    handler: async (args, ctx) => {
      if (args.trim() === "reset") {
        toolsKeptDeclared = new Set(defaultToolsKeptDeclared)
        writeWhitelistFile(defaultToolsKeptDeclared)
        reapplyWhitelist(pi)
        ctx.ui.notify(`Whitelist reset to ${defaultToolsKeptDeclared.length} tool(s).`, "info")
        return
      }
      if (ctx.mode !== "tui") {
        ctx.ui.notify(describeWhitelist(pi), "info")
        return
      }
      await openWhitelistChecklist(pi, ctx)
    },
  })

  pi.on("session_start", (_event, ctx) => {
    loadWhitelist()
    reapplyWhitelist(pi)
    if (whitelistLoadWarning) ctx.ui.notify(whitelistLoadWarning, "warning")
  })

  pi.on("before_agent_start", (event) => {
    const content = buildHiddenToolsSection(hiddenDeclarationNames(pi))
    if (content) event.systemPromptOptions.sections["hidden_tools"] = content
    else delete event.systemPromptOptions.sections["hidden_tools"]
  })
}
