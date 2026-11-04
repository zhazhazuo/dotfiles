/**
 * browser-instruction-broker — Keeps pi-agent-browser-native's browser playbook
 * out of every session system prompt.
 *
 * pi-agent-browser-native registers a `browser` instruction group on the public
 * `pi:instruction-groups` bus and, whenever nothing claims that group, eagerly
 * injects its full playbook into `systemPromptOptions.sections.agent_browser`.
 * That section measures about 36 KB, roughly 70% of the shared system prompt.
 * Pi 1.1.0 ships no instruction-group manager, so the eager path is the only
 * live path and there is nothing to claim the group on its own.
 *
 * This extension emits the collector object pi-agent-browser-native expects and
 * reports the group as managed, which is the extension's own documented signal
 * to stop injecting the duplicate section. The playbook is not lost: it is
 * delivered where browser work actually happens, in the `browser` subagent
 * definition produced by scripts/generate-browser-subagent.mjs.
 *
 * Manageability is derived from the registration rather than assumed. If
 * pi-agent-browser-native is absent, or never publishes its group, no group is
 * captured, `isManaged()` reports false, and Pi falls back to stock eager
 * behaviour. Set PI_BROWSER_BROKER=off to force that stock behaviour while
 * debugging.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Channel pi-agent-browser-native subscribes to before accepting a collector. */
const INSTRUCTION_GROUP_CHANNEL = "pi:instruction-groups";

/** Environment variable that forces stock eager prompt injection when it equals the disabled value. */
const BROKER_DISABLED_ENV = "PI_BROWSER_BROKER";

/** Value of BROKER_DISABLED_ENV that disables claiming. */
const BROKER_DISABLED_VALUE = "off";

/**
 * The group descriptor pi-agent-browser-native passes to `register`. Only the
 * fields this extension inspects are typed; the rest are preserved by the
 * extension itself and are not needed here.
 */
interface BrowserInstructionGroup {
  name?: string;
  description?: string;
  tools?: string[];
  instructions?: (ctx: unknown) => string;
}

/**
 * Claims pi-agent-browser-native's `browser` instruction group so its playbook
 * stops being injected into every session system prompt.
 */
export default function browserInstructionBroker(pi: ExtensionAPI): void {
  if (process.env[BROKER_DISABLED_ENV] === BROKER_DISABLED_VALUE) {
    return;
  }

  let receivedInstructionGroup: BrowserInstructionGroup | undefined;

  const instructionGroupCollector = {
    /**
     * Called synchronously by pi-agent-browser-native with its `browser` group.
     * Capturing it is what lets isManaged() report ownership truthfully.
     */
    register(group: BrowserInstructionGroup): void {
      receivedInstructionGroup = group;
    },

    /**
     * Reports whether this extension owns delivery of the browser instructions.
     * True only after the group was actually registered, so a missing or
     * unloaded pi-agent-browser-native degrades to stock eager injection.
     */
    isManaged(): boolean {
      return receivedInstructionGroup !== undefined;
    },
  };

  pi.on("session_start", () => {
    pi.events.emit(INSTRUCTION_GROUP_CHANNEL, instructionGroupCollector);
  });
}
