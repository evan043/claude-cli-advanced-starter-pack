---
description: Code style enforcement framework
model: sonnet
---

# AI Constitution Framework

Code style and architecture preferences enforcement system.

---

## Overview

The AI Constitution defines project-specific coding standards, architecture patterns, security rules, and best practices that Claude should follow when editing code in this project.

## Quick Commands

| Action | Description |
|--------|-------------|
| Initialize | `ccasp constitution-init` or run from `/menu` |
| View | Open `.claude/config/constitution.yaml` |
| Edit | Modify rules directly in the YAML file |
| Validate | Schema validation happens automatically via hooks |

## Presets

| Preset | Sampling | Sections | Use Case |
|--------|----------|----------|----------|
| **senior** | 5% (1-in-20) | All except custom | Senior fullstack developer defaults |
| **minimal** | 2% (1-in-50) | Security only | Minimal overhead, critical security |
| **strict** | 15% (1-in-7) | All sections | Maximum enforcement |
| **custom** | Configurable | User-selected | Full customization |

## Constitution Sections

### Code Style (CS-*)
- Naming conventions
- Import organization
- Type annotations
- Comment standards

### Architecture (ARCH-*)
- Directory structure
- Module boundaries
- State management patterns
- API design

### Security (SEC-*)
- Input validation
- Credential handling
- SQL injection prevention
- XSS prevention

### Performance (PERF-*)
- Memoization patterns
- Async best practices
- Bundle optimization

### Git (GIT-*)
- Commit message format
- Branch naming
- PR requirements

### Dependencies (DEP-*)
- Version constraints
- Security scanning
- License compliance

## Enforcement Flow

When Claude edits code, the constitution-enforcer hook:

1. **Samples** - Checks if this edit should be validated (1-in-20 default)
2. **Loads** - Reads constitution.yaml and determines applicable rules
3. **Validates** - Checks edit against enabled rules for the file's domain
4. **Reports** - Shows violations with:
   - **STOP**: What rule was violated
   - **EXPLAIN**: Why this matters
   - **SUGGEST**: Correct approach
   - **REFACTOR**: Claude auto-fixes if `auto_fix: true`

## Sensitive Pattern Bypass

Security-related patterns **always** trigger validation, bypassing sampling:
- password, secret, credential
- api_key, token, auth
- private_key, encryption

## Domain Detection

Rules apply based on file path patterns:
- `src/components/*` → frontend
- `backend/*`, `api/*` → backend
- `test/*`, `*.test.*` → testing
- `.github/*`, `docker*` → deployment

## Configuration

Edit `.claude/config/constitution.yaml`:

```yaml
enforcement:
  enabled: true
  sampling_rate: 0.05  # 5% of edits checked
  tools:
    - Edit
    - Write
  sensitive_patterns:
    - password
    - secret
    - api_key

sections:
  code_style:
    title: "Code Style"
    enabled: true
    rules:
      - id: CS-001
        description: "Use const for immutable values"
        severity: warning
        auto_fix: false
```

## Neovim Integration

If using the Neovim sidebar (Tab 2 - Settings):
- Press `[c]` to open the Constitution Editor
- Edit sections with live word count
- Toggle rules on/off
- Save with automatic backup

## Troubleshooting

### Constitution not enforcing
1. Check `enforcement.enabled: true` in YAML
2. Verify hook is registered in settings.json
3. Increase `sampling_rate` for testing (1.0 = every edit)

### Too many violations
1. Disable non-critical sections
2. Lower severity from `error` to `warning`
3. Reduce `sampling_rate`

### Performance concerns
1. Default 5% sampling has minimal impact
2. Disable verbose sections like `custom`
3. Use file_patterns to limit rule scope

---

## Related Commands

- `/claude-audit` - Audit CLAUDE.md against best practices
- `/refactor-check` - Pre-commit quality gates
- `/create-hook` - Create custom enforcement hooks
