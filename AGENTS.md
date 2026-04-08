# AI Agent Guide for discourse-kanban

## Linting

This plugin has **two independent linting systems** that must both pass for CI to be green.

### 1. Core `bin/lint` (from discourse repo root)

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

