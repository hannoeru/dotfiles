# Principles

## Core
- Don't hold back. Give it your all.
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
- MUST use subagents for complex problem verification
- After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.

## Workflow Structure
- Follow Explore-Plan-Code-Commit approach
- Always read and understand existing code before making changes
- Create detailed plans before implementation
- Use iterative approaches
- Course-correct early and frequently

## Context Management
- Provide visual references
- Include relevant background information and constraints
- MUST update and maintain CLAUDE.md files for persistent project context
- Document project-specific patterns and conventions

## Problem-Solving Approach
- Leverage thinking capabilities for complex multi-step reasoning
- Focus on understanding problem requirements rather than just passing tests
- Use test-driven development

## Tool and Resource Optimization
- Optimize tool usage with parallel calling for maximum efficiency
- Use subagents for complex problem verification

## For projects containing package.json

### Bash commands
- pnpm build: Build the project
- pnpm typecheck: Run the typechecker
- pnpm test: Run the test suite
- pnpm lint: Run the linter
- pnpm lint:fix: Run the linter and fix issues

### Code style
- Use ES modules (import/export) syntax, not CommonJS (require)
- Destructure imports when possible (eg. import { foo } from 'bar')

### Workflow
- Be sure to typecheck when you're done making a series of code changes
- Prefer running single tests, and not the whole test suite, for performance
