---
description: Ralph Loop - Continuous test-fix cycle until all tests pass
model: sonnet
argument-hint: [test command or 'auto']
---

# /ralph - Ralph Loop (Continuous Test-Fix Cycle)

**"I'm helping!"** - Ralph Wiggum

Run tests continuously, fixing failures automatically until all tests pass or max iterations reached.

## Quick Start

```bash
/ralph                    # Auto-detect test command, run loop
/ralph npm test           # Use specific test command
/ralph --max 5            # Limit to 5 iterations
/ralph --playwright       # Run Playwright E2E tests
/ralph --bdd              # Enable BDD mode (requirement-first workflow)
/ralph --stop             # Stop current Ralph loop
```

## BDD Mode (`--bdd`)

When `--bdd` flag is used, Ralph enforces a Behavior-Driven Development workflow:

1. **Check for requirements**: Scans for `REQUIREMENTS.md` or `*.feature` files
2. **Parse scenarios**: Extracts Gherkin-style `Given/When/Then` from requirements
3. **Verify test coverage**: Ensures BDD scenarios have corresponding test stubs
4. **Block implementation**: Prevents code changes if scenarios lack tests
5. **Standard Ralph loop**: Once tests exist, runs the normal test-fix cycle

**Supported BDD frameworks**: jest-cucumber, Cucumber, pytest-bdd, Behave

The BDD hook (`ralph-bdd-mode`) runs before the standard Ralph enforcer, creating a
two-layer workflow: BDD scenarios → test stubs → implementation → Ralph test-fix loop.

{{#if testing.bdd.enabled}}
**BDD is enabled** for this project via tech-stack.json.
{{/if}}

## How It Works

```
╔═══════════════════════════════════════════════════════════════╗
║  🔄 Ralph Loop - Iteration 1/10                                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  1. Run tests → Capture failures                              ║
║  2. Analyze error messages                                    ║
║  3. Fix the failing code                                      ║
║  4. Re-run tests                                              ║
║  5. Repeat until ✅ ALL PASS or ❌ MAX ITERATIONS              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## Configuration

{{#if testing.e2e.framework}}
**E2E Framework**: {{testing.e2e.framework}}
**Test Command**: `{{testing.e2e.testCommand}}`
{{else}}
**E2E Framework**: Not configured
{{/if}}

{{#if testing.unit.framework}}
**Unit Framework**: {{testing.unit.framework}}
**Test Command**: `{{testing.unit.testCommand}}`
{{/if}}

## Ralph Loop State File

The loop state is tracked in `.claude/ralph-loop.json`:

```json
{
  "active": true,
  "iteration": 3,
  "maxIterations": 10,
  "testCommand": "npm test",
  "startedAt": "2026-01-31T12:00:00Z",
  "failures": [
    {
      "iteration": 1,
      "test": "LoginPage.spec.ts",
      "error": "Expected 'Welcome' but got 'Loading'",
      "fixed": true
    },
    {
      "iteration": 2,
      "test": "api.test.ts",
      "error": "Timeout waiting for response",
      "fixed": true
    }
  ],
  "summary": {
    "totalFailures": 5,
    "fixedFailures": 3,
    "remainingFailures": 2
  }
}
```

## Instructions for Claude

When `/ralph` is invoked:

### Step 1: Initialize Loop

1. Check for existing Ralph loop state in `.claude/ralph-loop.json`
2. If `--stop` flag, terminate loop and show summary
3. Parse arguments for test command or use auto-detection

**Auto-detection order**:
{{#if testing.e2e.framework}}
1. `{{testing.e2e.testCommand}}` (E2E - configured)
{{else}}
1. `npx playwright test` (if playwright.config exists)
2. `npx cypress run` (if cypress.config exists)
{{/if}}
3. `npm test` (fallback)

### Step 2: Create/Update State File

```javascript
// Write to .claude/ralph-loop.json
{
  "active": true,
  "iteration": 1,
  "maxIterations": args.max || 10,
  "testCommand": detectedCommand,
  "startedAt": new Date().toISOString(),
  "failures": []
}
```

### Step 3: Execute Loop

```
FOR iteration = 1 TO maxIterations:

  1. Display iteration banner:
     ╔═══════════════════════════════════════╗
     ║  🔄 Ralph Loop - Iteration {N}/{MAX}  ║
     ╚═══════════════════════════════════════╝

  2. Run test command via Bash:
     - Capture stdout/stderr
     - Parse for failure patterns

  3. IF all tests pass:
     - Display success banner
     - Update state: active = false
     - Show summary
     - EXIT LOOP ✅

  4. IF tests fail:
     - Parse error messages
     - Identify failing files/lines
     - Read failing test file
     - Read source file being tested
     - Analyze the failure
     - Apply fix using Edit tool
     - Log fix to state.failures[]
     - CONTINUE TO NEXT ITERATION

  5. Update .claude/ralph-loop.json with current state
```

### Step 4: Handle Max Iterations

If max iterations reached without all tests passing:

```
╔═══════════════════════════════════════════════════════════════╗
║  ⚠️  Ralph Loop - Max Iterations Reached                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Iterations: 10/10                                            ║
║  Fixed: 7 failures                                            ║
║  Remaining: 2 failures                                        ║
║                                                               ║
║  Remaining failures:                                          ║
║  • LoginPage.spec.ts:45 - Timeout error                       ║
║  • api.test.ts:102 - Network error                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

Use AskUserQuestion:
```
header: "Continue?"
question: "Ralph loop reached max iterations. How would you like to proceed?"
options:
  - label: "Continue 5 more iterations"
    description: "Keep trying to fix remaining failures"
  - label: "Show detailed failure analysis"
    description: "Deep dive into remaining failures"
  - label: "Stop and commit progress"
    description: "Commit fixes made so far"
```

## Error Pattern Recognition

Common test failure patterns to detect:

| Pattern | Likely Cause | Fix Strategy |
|---------|--------------|--------------|
| `Expected X but received Y` | Assertion mismatch | Check logic, update expected value |
| `Timeout` | Async issue | Add waits, check selectors |
| `Cannot find element` | Selector changed | Update selector |
| `TypeError: X is not a function` | API change | Check imports, update calls |
| `Network error` | API down/changed | Mock API or fix endpoint |
| `ECONNREFUSED` | Server not running | Start server or mock |

{{#if agents.testing}}
## Testing Agent Integration

When Ralph loop is active and testing agent is available:

**Recommended Agent**: {{agents.testing.name}}

The testing specialist can help with:
- Complex test debugging
- Fixture design
- Mock strategies
- Cross-browser issues

To deploy: Use Task tool with the testing agent for deep analysis.
{{/if}}

## Exit Conditions

Ralph loop stops when:

1. ✅ **All tests pass** - Success!
2. ❌ **Max iterations reached** - Ask user how to proceed
3. 🛑 **User invokes `/ralph --stop`** - Manual termination
4. ⚠️ **Same failure 3 times** - Likely unfixable automatically, ask for help
5. 💥 **Critical error** - Test command itself fails (not test failures)

## Related Commands

- `/create-task-list` - Includes Ralph loop as testing option
- `/phase-track` - Track phase progress with test verification
{{#if testing.e2e.framework}}
- `/e2e-test` - Run {{testing.e2e.framework}} tests directly
{{/if}}

---

*"Me fail English? That's unpossible!"* - Ralph Wiggum
