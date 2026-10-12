/**
 * MCP policy for pi (self-contained, same shape as bash-policy).
 *   deny  -> blocked
 *   allow -> runs without asking
 *   other -> confirmation prompt (blocked when there is no UI)
 *
 * Patterns are matched against the pi tool name: mcp__<server>__<tool>, where
 * every character other than letters, digits and `_` in server and tool is `_`.
 */

import type {
  ExtensionAPI,
  ExtensionContext,
  ToolCallEvent,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";

const ALLOW: RegExp[] = [
  // Atlassian
  /^mcp__atlassian__createIssueLink$/,
  /^mcp__atlassian__createJiraIssue$/,
  /^mcp__atlassian__getConfluencePage$/,
  /^mcp__atlassian__getConfluencePageDescendants$/,
  /^mcp__atlassian__getIssueLinkTypes$/,
  /^mcp__atlassian__getJiraIssue$/,
  /^mcp__atlassian__getJiraProjectIssueTypesMetadata$/,
  /^mcp__atlassian__searchConfluenceUsingCql$/,
  /^mcp__atlassian__searchJiraIssuesUsingJql$/,

  // Datadog Google Workspace
  /^mcp__datadog_google_workspace__get_doc_as_markdown$/,
  /^mcp__datadog_google_workspace__get_presentation$/,
  /^mcp__datadog_google_workspace__get_slide$/,
  /^mcp__datadog_google_workspace__get_slide_thumbnail$/,

  // Datadog
  /^mcp__datadog__aggregate_spans$/,
  /^mcp__datadog__analyze_datadog_logs$/,
  /^mcp__datadog__explore_profiling_flame_graph$/,
  /^mcp__datadog__get_datadog_dashboard$/,
  /^mcp__datadog__get_datadog_metric$/,
  /^mcp__datadog__get_datadog_metric_context$/,
  /^mcp__datadog__get_datadog_notebook$/,
  /^mcp__datadog__get_datadog_trace$/,
  /^mcp__datadog__get_profiling_profile_types$/,
  /^mcp__datadog__list_datadog_skills$/,
  /^mcp__datadog__load_datadog_skill$/,
  /^mcp__datadog__search_datadog_logs$/,
  /^mcp__datadog__search_datadog_metrics$/,
  /^mcp__datadog__search_datadog_services$/,
  /^mcp__datadog__search_datadog_spans$/,
];

export default function (pi: ExtensionAPI) {
  pi.on(
    "tool_call",
    async (
      event: ToolCallEvent,
      ctx: ExtensionContext,
    ): Promise<ToolCallEventResult | undefined> => {
      if (!event.toolName.startsWith("mcp__")) return undefined;

      if (ALLOW.some((p) => p.test(event.toolName))) {
        return undefined;
      }

      if (!ctx.hasUI) {
        return {
          block: true,
          reason: "MCP tool not in allow list (no UI for confirmation)",
        };
      }
      const ok = await ctx.ui.confirm(
        "Allow MCP tool?",
        `${event.toolName}\n${JSON.stringify(event.input, null, 2)}`,
      );
      return ok ? undefined : { block: true, reason: "Denied by user" };
    },
  );
}
