/**
 * Bash policy for pi.
 *   deny  -> blocked
 *   allow -> runs without asking (only for single simple commands)
 *   other -> confirmation prompt (blocked when there is no UI)
 */

import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEvent,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";

const DENY: RegExp[] = [
  // Brew
  /^brew/,

  // Bazel
  /^bzl (build|run|test)/,
  /^BZL_/,

  // GitHub CLI
  /^gh /,

  // Git mutations
  /^git (add|am|apply|branch|checkout|cherry-pick|clone|commit|config|filter-branch|gc|init|merge|mv|prune|pull|push|rebase|remote|reset|restore|revert|rm|stash|submodule|switch|tag|update-ref|worktree)/,

  // Docker mutations (and compatible CLIs / VM manager)
  /^docker (build|commit|compose|container|cp|create|exec|export|image|import|kill|load|login|network|pause|pull|push|restart|rm|rmi|run|save|start|stop|system|tag|unpause|update|volume)/,
  /^(docker-compose|podman|nerdctl|colima)/,

  // Package installs
  /^(go install|npm install|pip install|uv pip install|uv tool install)/,

  // Kubernetes mutations
  /^kmux (restart|scale)/,
  /^kubectl (annotate|apply|attach|autoscale|cordon|cp|create|delete|drain|edit|exec|expose|label|patch|replace|rollout|run|scale|set|taint|uncordon)/,

  // Terraform
  /^terraform/,
  /^tfenv/,
];

const ALLOW: RegExp[] = [
  /^cargo test/,
  /^cat/,
  /^cd/,
  /^find/,
  /^git diff/,
  /^go (build|doc|generate|test|vet)/,
  /^gofumpt/,
  /^golangci-lint/,
  /^grep/,
  /^head/,
  /^ls/,
  /^mockgen/,
  /^npm (run test|test)/,
  /^prettier/,
  /^pytest/,
  /^tee/,
  /^wc/,
  /^xargs grep/,
];

// Operators, substitution, redirection, newlines: never auto-approved.
const COMPLEX = /[;|&`<>()]|\$\(|\$\{|\n/;

export default function (pi: ExtensionAPI) {
  pi.on(
    "tool_call",
    async (
      event: ToolCallEvent,
      ctx: ExtensionContext,
    ): Promise<ToolCallEventResult | undefined> => {
      if (event.toolName !== "bash") return undefined;

      const command = String(event.input.command ?? "");
      const normalized = command.replace(/^\s+/, "").replace(/[ \t]+/g, " ");

      if (DENY.some((p) => p.test(normalized))) {
        return { block: true, reason: `Blocked by bash policy: ${command}` };
      }

      if (!COMPLEX.test(normalized) && ALLOW.some((p) => p.test(normalized))) {
        return undefined;
      }

      if (!ctx.hasUI) {
        return {
          block: true,
          reason: "Command not in allow list (no UI for confirmation)",
        };
      }
      const ok = await ctx.ui.confirm("Allow bash command?", command);
      return ok ? undefined : { block: true, reason: "Denied by user" };
    },
  );
}
