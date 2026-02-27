# AI Agent Guide for discourse-kanban

## Linting

This plugin has **two independent linting systems** that must both pass for CI to be green.

### 1. Core `bin/lint` (from repo root `/var/www/discourse`)

```bash
bin/lint plugins/discourse-kanban/path/to/changed/file
```

Covers: rubocop, syntax_tree, prettier, eslint, ember-template-lint, yaml-syntax, i18n-lint, stylelint. Only checks the specific files you pass. **This alone is NOT sufficient for CI.**

### 2. Plugin `pnpm lint` (from plugin directory)

```bash
cd plugins/discourse-kanban && pnpm lint
```

Covers: eslint, prettier, ember-template-lint, stylelint, TypeScript (`ember-tsc -b`). **Checks ALL files in the plugin**, not just changed ones. This is what CI runs. Fix issues with `pnpm lint:fix`.

### After every change, run both

```bash
# From repo root
bin/lint plugins/discourse-kanban/path/to/changed/files

# From plugin directory
cd plugins/discourse-kanban && pnpm lint
```

### Common gotchas

- **Pre-existing lint failures**: `pnpm lint` checks ALL files, so you may see failures in files you didn't touch. Fix them — CI will fail otherwise.
- **SCSS prettier**: Prettier formats SCSS strictly (e.g., `&, &:visited` must be on separate lines). Always verify `.scss` files.
- **`bin/lint` passes but `pnpm lint` fails**: `bin/lint` only checks files you explicitly pass. `pnpm lint` checks everything including TypeScript types.

## Testing

### Ruby specs

```bash
# All plugin specs
bin/rspec plugins/discourse-kanban/spec/

# Single file
bin/rspec plugins/discourse-kanban/spec/path/file_spec.rb

# Single example by line number
bin/rspec plugins/discourse-kanban/spec/path/file_spec.rb:123

# System tests only
bin/rspec plugins/discourse-kanban/spec/system/
```

### Known issues

- `core_features_spec.rb` has 2 failures (`lists latest topics`) caused by a core shared example expecting exactly 4 topics while seed data adds extra ones. This affects all plugins, not just kanban.
