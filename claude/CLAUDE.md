# Claude Code Configuration

## Autonomy & Workflow Preferences

**Autonomy Level**: Balanced

- Use plan mode for complex tasks, architectural decisions, and multi-file changes
- Proceed directly on straightforward implementations
- Check in on key technical choices and design decisions
- Ask questions when clarification is needed

## Primary Use Cases

I primarily use Claude Code for:

- **Feature development**: Building new functionality from scratch
- **Refactoring and optimization**: Improving code structure, performance, and maintainability
- **Code understanding and exploration**: Learning about codebases, explaining how things work

## Git Workflow

**CRITICAL**: Never create git commits automatically

- I handle ALL git operations manually (add, commit, push, PR creation)
- Focus on writing code and running tests only
- Do not use git commit, git add, or git push commands
- After completing work, I'll review changes and create commits myself

## Testing

**Automatic test execution**: Always run relevant tests after making code changes

- Automatically verify changes don't break existing functionality
- Run appropriate test commands based on project type (npm test, pytest, go test, etc.)
- Report test results before considering work complete
- This helps catch issues early before I commit changes

## Code Quality Preferences

- Avoid over-engineering - keep solutions simple and focused
- Don't add features beyond what was requested
- Only add error handling for scenarios that can actually occur
- Prefer editing existing files over creating new ones
- No unnecessary comments, docstrings, or type annotations unless requested
- Delete unused code completely - no backwards-compatibility hacks

## Communication Style

- Be concise and direct - short answers, straight to the point
- No verbose explanations or apologies
- No time estimates
- Focus on technical accuracy over validation
- Use code references with file:line format when discussing specific code
