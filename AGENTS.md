# Repository Guidelines

## Project Structure & Module Organization

This repository is currently a project workspace with no application source checked in. Keep product code in conventional top-level directories once the application is initialized:

- `src/` for application code, grouped by feature (for example, `src/prompts/` and `src/search/`).
- `tests/` for automated tests that mirror the source layout.
- `public/` for static assets that are safe to serve directly.
- `work/` for disposable local research, drafts, and scripts; do not treat it as production source.
- `outputs/` for user-facing deliverables only.

Do not commit build output, local secrets, generated caches, or downloaded media.

## Build, Test, and Development Commands

No runtime or package manager is configured yet. When the Next.js application is added, standardize on npm and provide these scripts in `package.json`:

- `npm run dev` — run the local development server.
- `npm run build` — create a production build; run before review.
- `npm run start` — serve the production build locally.
- `npm run lint` — run static checks.
- `npm test` — execute the automated test suite.

Document any nonstandard command in `README.md` when it is introduced.

## Coding Style & Naming Conventions

Use TypeScript for application and API code. Prefer 2-space indentation, single quotes, trailing commas, and explicit types at public module boundaries. Name React components in `PascalCase` (`PromptEditor.tsx`), functions and variables in `camelCase`, and route folders in lowercase kebab case (`app/api/prompts/[slug]/route.ts`). Keep business logic out of page components by placing it in feature modules.

Use ESLint and Prettier once configured; do not hand-format files against their output.

## Testing Guidelines

Add unit tests for prompt composition, search filtering, and API validation. Use names such as `prompt-composer.test.ts` and write behavior-focused cases: `it('omits fields unavailable for a landscape prompt')`. Add an integration test for each public API route and a browser test for the copy-prompt flow. New behavior should include a passing test or a brief reason why it cannot be automated.

## Commit & Pull Request Guidelines

No Git history is available yet, so adopt Conventional Commits: `feat: add prompt search endpoint`, `fix: validate upload content type`. Keep commits focused. Pull requests should describe the user-facing change, list validation commands, link the relevant issue, and include screenshots for visual changes. Never include credentials; store local values in `.env.local` and commit only an `.env.example` template.
