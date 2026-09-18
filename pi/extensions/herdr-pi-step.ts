/**
 * herdr-pi-step — show what the focused Pi session is doing, in the Herdr tab bar.
 *
 * Contract:
 *   This extension publishes the current step as the pane metadata token
 *   `pi_step` over Herdr's socket (`pane.report_metadata`). The Herdr config
 *   entry `ui.tab_bar_right` runs `~/.config/herdr/status-pi-step.sh`, which
 *   reads the focused pane's token with `herdr pane get` and prints it.
 *
 * Why a metadata token and not a metadata title:
 *   `TerminalState::border_label()` prefers the metadata title over the agent
 *   label, so a title report would also relabel pane borders (and title /
 *   display_agent share one field set that partial reports can clobber).
 *   Tokens are a separate, display-only namespace: no pane-border or sidebar
 *   side effects, and other integrations' title/display_agent survive.
 *
 * Step priority (first match wins):
 *   1. `todo` in-progress item -> activeForm (present-continuous), else subject
 *   2. the running tool -> short present-continuous phrase ("editing x.ts");
 *      "thinking" between the turn start and the first tool call
 *   3. the pi session name (`/name`)
 *   4. nothing -> the token is cleared and the Herdr segment hides
 *
 * This file is local and is NOT managed by herdr. `herdr integration install pi`
 * owns `herdr-agent-state.ts`; never merge the two files.
 *
 * Tests: bun pi/extensions/__tests__/herdr-pi-step.test.ts
 */

import net from "node:net";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SOURCE = "user:pi-step";
const TOKEN_NAME = "pi_step";
/** Herdr caps `ttl_ms` at 24h; a dead pi session self-clears after this. */
const TTL_MS = 86_400_000;
const MAX_STEP_CHARS = 72;
const MIN_REPORT_INTERVAL_MS = 1000;
const THINKING_LABEL = "thinking";
const MAX_COMMAND_CHARS = 48;

export type TaskLike = {
  id?: number;
  subject?: string;
  activeForm?: string;
  status?: string;
};

export type StepSources = {
  todoStep?: string;
  toolStep?: string;
  sessionName?: string;
};

export type StepReporter = {
  set(text: string | undefined): void;
  /** Resolves once nothing is queued (used on shutdown). */
  settle(): Promise<void>;
  dispose(): void;
};

function firstLine(text: string): string {
  const flat = text.replace(/\s+/g, " ").trim();
  return flat;
}

/** Collapse whitespace, drop control characters, clip at a word boundary. */
export function clipStep(raw: string | undefined | null): string | undefined {
  if (!raw) return undefined;
  const flat = firstLine(
    Array.from(raw)
      .filter((ch) => ch.charCodeAt(0) >= 0x20)
      .join(""),
  );
  if (!flat) return undefined;
  if (flat.length <= MAX_STEP_CHARS) return flat;
  const cut = flat.slice(0, MAX_STEP_CHARS);
  const boundary = cut.lastIndexOf(" ");
  return (boundary > MAX_STEP_CHARS * 0.6 ? cut.slice(0, boundary) : cut).trim();
}

/** The agent's own declared current step, if it maintains a todo list. */
export function inProgressStep(tasks: TaskLike[] | undefined): string | undefined {
  if (!Array.isArray(tasks)) return undefined;
  const active = tasks.find((task) => task?.status === "in_progress");
  if (!active) return undefined;
  return clipStep(active.activeForm) ?? clipStep(active.subject);
}

/** Last-write-wins replay of todo snapshots from the session branch. */
export function replayTodos(branch: Iterable<unknown>): TaskLike[] {
  let tasks: TaskLike[] = [];
  for (const entry of branch ?? []) {
    const message = (entry as { message?: { role?: string; toolName?: string; details?: unknown } })
      ?.message;
    if (message?.role !== "toolResult" || message.toolName !== "todo") continue;
    const next = tasksFromDetails(message.details);
    if (next) tasks = next;
  }
  return tasks;
}

/** The todo tool returns the full list under `details`; reject other shapes. */
export function tasksFromDetails(details: unknown): TaskLike[] | undefined {
  const tasks = (details as { tasks?: unknown } | undefined)?.tasks;
  if (!Array.isArray(tasks)) return undefined;
  return tasks.filter((task): task is TaskLike => Boolean(task) && typeof task === "object");
}

export function pickStep(sources: StepSources): string | undefined {
  return (
    clipStep(sources.todoStep) ??
    clipStep(sources.toolStep) ??
    clipStep(sources.sessionName)
  );
}

function fileLabel(value: unknown): string | undefined {
  if (typeof value !== "string" || !value.trim()) return undefined;
  const parts = value.trim().split(/[\\/]/);
  return parts[parts.length - 1] || undefined;
}

function commandLabel(command: unknown): string | undefined {
  if (typeof command !== "string") return undefined;
  const flat = firstLine(command).replace(/^cd\s+\S+\s*&&\s*/i, "");
  if (!flat) return undefined;
  if (/^(bun|npm|pnpm|yarn|npx)\s+(run\s+)?test\b|^cargo\s+test\b|^pytest\b|^go\s+test\b/i.test(flat))
    return "running tests";
  if (/^(bun|npm|pnpm|yarn)\s+run\s+build\b|^cargo\s+build\b|^make\b|^just\b/i.test(flat))
    return "building";
  if (/^(bun|npm|pnpm|yarn)\s+(install|add)\b/i.test(flat)) return "installing dependencies";
  return `running \`${flat.slice(0, MAX_COMMAND_CHARS)}\``;
}

/** Present-continuous phrase for the tool that is executing right now. */
export function toolPhrase(toolName: unknown, args: unknown): string | undefined {
  const name = typeof toolName === "string" ? toolName : "";
  const a = (args ?? {}) as Record<string, unknown>;
  switch (name) {
    case "bash":
    case "powershell":
      return commandLabel(a.command);
    case "read":
    case "read_symbol":
    case "read_enclosing": {
      const file = fileLabel(a.path) ?? fileLabel(a.file);
      return file ? `reading ${file}` : "reading files";
    }
    case "module_report": {
      const file = fileLabel(a.path);
      return file ? `outlining ${file}` : "outlining a module";
    }
    case "edit": {
      const file = fileLabel(a.path) ?? fileLabel(a.file);
      return file ? `editing ${file}` : "editing files";
    }
    case "write": {
      const file = fileLabel(a.path) ?? fileLabel(a.file);
      return file ? `writing ${file}` : "writing a file";
    }
    case "grep": {
      const pattern = typeof a.pattern === "string" ? a.pattern.slice(0, 32) : undefined;
      return pattern ? `searching for ${pattern}` : "searching the code";
    }
    case "find": {
      const pattern = typeof a.pattern === "string" ? a.pattern.slice(0, 32) : undefined;
      return pattern ? `locating ${pattern}` : "locating files";
    }
    case "ls":
      return "listing files";
    case "agent_browser":
      return "browsing the web";
    case "ctx_execute":
      return "running a sandbox snippet";
    case "ctx_execute_file": {
      const file = fileLabel(a.path);
      return file ? `analyzing ${file}` : "analyzing a file";
    }
    case "ctx_batch_execute":
      return "running a command batch";
    case "ctx_search":
      return "searching the knowledge base";
    case "ctx_index":
    case "ctx_fetch_and_index":
      return "indexing reference docs";
    case "lens_diagnostics":
      return "checking diagnostics";
    case "ask_user_question":
      return "waiting for your answer";
    case "subagent":
      return "delegating to a subagent";
    case "todo":
      return undefined;
    default:
      return name ? `running ${name}` : undefined;
  }
}

function isSubagentContext(): boolean {
  return (
    Boolean(process.env.PI_SUBAGENT_PARENT_SESSION) ||
    Boolean(process.env.PI_SUBAGENT_CHILD)
  );
}

function shouldReleaseOnQuit(event: unknown): boolean {
  return (event as { reason?: string } | undefined)?.reason === "quit";
}

export function buildReport(
  paneId: string,
  text: string | undefined,
  seq: number,
): Record<string, unknown> {
  return {
    id: `${SOURCE}:${Date.now()}:${Math.random().toString(36).slice(2)}`,
    method: "pane.report_metadata",
    params: {
      pane_id: paneId,
      source: SOURCE,
      agent: "pi",
      seq,
      ttl_ms: TTL_MS,
      tokens: { [TOKEN_NAME]: text ?? null },
    },
  };
}

/**
 * Throttled, last-write-wins reporter: at most one report per interval, one in
 * flight at a time, duplicate text skipped, trailing change never dropped.
 */
export function createStepReporter(
  send: (request: unknown) => Promise<void>,
  options: {
    buildRequest?: (text: string | undefined) => unknown;
    minIntervalMs?: number;
    now?: () => number;
  } = {},
): StepReporter {
  const minIntervalMs = options.minIntervalMs ?? MIN_REPORT_INTERVAL_MS;
  const now = options.now ?? (() => Date.now());
  const buildRequest = options.buildRequest ?? ((text) => buildReport("test", text, 0));

  let desired: string | undefined;
  let sent: string | undefined;
  let sentAt = 0;
  let hasSent = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let inFlight: Promise<void> | undefined;

  function schedule(delay: number): void {
    if (timer) return;
    timer = setTimeout(() => {
      timer = undefined;
      void pump();
    }, delay);
    timer.unref?.();
  }

  async function pump(force = false): Promise<void> {
    while (!hasSent || desired !== sent) {
      const wait = sentAt + minIntervalMs - now();
      if (!force && hasSent && wait > 0) {
        schedule(wait);
        return;
      }
      sent = desired;
      sentAt = now();
      hasSent = true;
      await send(buildRequest(sent));
    }
  }

  function kick(): void {
    if (timer) return;
    if (inFlight) return;
    inFlight = pump()
      .catch(() => undefined)
      .finally(() => {
        inFlight = undefined;
        if (!hasSent || desired !== sent) {
          if (timer) return;
          if (now() >= sentAt + minIntervalMs) kick();
          else schedule(sentAt + minIntervalMs - now());
        }
      });
  }

  return {
    set(text: string | undefined): void {
      const next = clipStep(text);
      if (next === desired) return;
      desired = next;
      kick();
    },
    async settle(): Promise<void> {
      if (timer) {
        clearTimeout(timer);
        timer = undefined;
      }
      await inFlight;
      // Bypass the throttle: shutdown cannot wait out the report interval.
      await pump(true).catch(() => undefined);
    },
    dispose(): void {
      if (timer) {
        clearTimeout(timer);
        timer = undefined;
      }
    },
  };
}

function sendRequestAttempt(
  endpoint: string,
  request: unknown,
  timeoutMs: number,
): Promise<boolean> {
  return new Promise((resolve) => {
    let done = false;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const finish = (delivered: boolean) => {
      if (done) return;
      done = true;
      if (timeout) clearTimeout(timeout);
      socket.destroy();
      resolve(delivered);
    };

    const socket = net.createConnection(endpoint);
    socket.on("error", () => finish(false));
    socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
    socket.on("data", () => finish(true));
    socket.on("end", () => finish(false));
    timeout = setTimeout(() => finish(false), timeoutMs);
    timeout.unref?.();
  });
}

async function sendRequest(endpoint: string, request: unknown): Promise<void> {
  if (await sendRequestAttempt(endpoint, request, 500)) return;
  await sendRequestAttempt(endpoint, request, 1500);
}

export type StepExtensionOptions = {
  minIntervalMs?: number;
  now?: () => number;
};

/**
 * Wire the reporter to a live pi session. Returns false when this process is
 * not a Herdr-owned root session (plain terminal, headless, or subagent child),
 * so callers can tell "inert" from "active".
 */
export function createStepExtension(
  pi: ExtensionAPI,
  options: StepExtensionOptions = {},
): boolean {
  const socketPath = process.env.HERDR_SOCKET_PATH;
  const paneId = process.env.HERDR_PANE_ID;
  if (process.env.HERDR_ENV !== "1" || !socketPath || !paneId) return false;
  // A pi-subagents child shares this pane but does not own its label.
  if (isSubagentContext()) return false;

  const endpoint =
    process.platform === "win32" && socketPath ? `\\\\.\\pipe\\${socketPath}` : socketPath;
  let seq = Date.now() * 1000;
  const nextSeq = () => ++seq;

  const reporter = createStepReporter(
    (request) => sendRequest(endpoint, request),
    {
      buildRequest: (text) => buildReport(paneId, text, nextSeq()),
      minIntervalMs: options.minIntervalMs,
      now: options.now,
    },
  );

  let rootSession = false;
  let tasks: TaskLike[] = [];
  let toolStep: string | undefined;
  let thinking = false;
  let sessionName: string | undefined;

  function resolveStep(): void {
    reporter.set(
      pickStep({
        todoStep: inProgressStep(tasks),
        toolStep: thinking ? THINKING_LABEL : toolStep,
        sessionName,
      }),
    );
  }

  pi.on("session_start", async (_event, ctx) => {
    // Headless modes (rpc/json/print) have no pane Herdr can label.
    if (ctx?.mode !== "tui") return;
    rootSession = true;
    tasks = replayTodos(ctx?.sessionManager?.getBranch?.() ?? []);
    sessionName =
      clipStep((pi as { getSessionName?: () => string }).getSessionName?.()) ??
      clipStep(ctx?.sessionManager?.getSessionName?.());
    thinking = ctx?.isIdle?.() === false;
    resolveStep();
  });

  pi.on("session_info_changed", (event) => {
    if (!rootSession) return;
    sessionName = clipStep((event as { name?: string })?.name);
    resolveStep();
  });

  pi.on("agent_start", () => {
    if (!rootSession) return;
    thinking = true;
    toolStep = undefined;
    resolveStep();
  });

  pi.on("tool_execution_start", (event) => {
    if (!rootSession) return;
    const toolName = (event as { toolName?: string })?.toolName;
    if (toolName === "todo") return;
    thinking = false;
    toolStep = toolPhrase(toolName, (event as { args?: unknown })?.args);
    resolveStep();
  });

  pi.on("tool_result", (event) => {
    if (!rootSession) return;
    if ((event as { toolName?: string })?.toolName !== "todo") return;
    const next = tasksFromDetails((event as { details?: unknown })?.details);
    if (!next) return;
    tasks = next;
    resolveStep();
  });

  pi.on("agent_settled", () => {
    if (!rootSession) return;
    thinking = false;
    resolveStep();
  });

  pi.on("session_shutdown", async (event) => {
    if (!rootSession) return;
    if (!shouldReleaseOnQuit(event)) return;
    rootSession = false;
    tasks = [];
    toolStep = undefined;
    thinking = false;
    sessionName = undefined;
    reporter.set(undefined);
    await reporter.settle();
    reporter.dispose();
  });

  return true;
}

export default function (pi: ExtensionAPI): void {
  createStepExtension(pi);
}
