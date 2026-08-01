---
description: Generate characterization tests before refactoring (Golden Master pattern)
model: sonnet
argument-hint: [file path or function name]
---

# /golden-master - Characterization Test Generator

Capture the current behavior of code as "Golden Master" tests before refactoring. Ensures refactoring preserves existing behavior.

**"No characterization tests = No refactoring."** - Legacy Code Survival Rule

## Quick Start

```bash
/golden-master src/api/client.ts           # Generate tests for entire file
/golden-master src/api/client.ts:fetchData # Generate tests for specific function
/golden-master --verify                    # Re-run and compare against master
/golden-master --update                    # Update golden master after intentional changes
```

## What Is Golden Master Testing?

Golden Master (also called Characterization or Approval Testing) captures the **actual behavior** of code, not what you think it should do:

```
Before Refactoring:
┌─────────────────────────────────────────────────────────┐
│  Input Set → Legacy Code → Capture Output (Golden Master)│
└─────────────────────────────────────────────────────────┘

After Refactoring:
┌─────────────────────────────────────────────────────────┐
│  Input Set → Refactored Code → Compare Against Master   │
│                                    ↓                    │
│                           ✅ Match = Safe to continue   │
│                           ❌ Diff = Investigate!        │
└─────────────────────────────────────────────────────────┘
```

## Why Use Golden Master?

1. **Fast coverage**: Get tests on legacy code in minutes, not days
2. **Behavior documentation**: Discover what code actually does
3. **Refactoring safety net**: Any behavior change triggers failure
4. **Edge case discovery**: Random inputs find unexpected behaviors

## Output Structure

Golden Master tests are stored in `.claude/golden-master/`:

```
.claude/golden-master/
├── src-api-client.ts/
│   ├── fetchData.master.json      # Captured outputs
│   ├── fetchData.inputs.json      # Test inputs
│   ├── fetchData.spec.ts          # Generated test file
│   └── README.md                  # Documentation
├── src-utils-helpers.ts/
│   └── ...
└── manifest.json                  # Index of all masters
```

### Master File Format

```json
// fetchData.master.json
{
  "function": "fetchData",
  "file": "src/api/client.ts",
  "capturedAt": "2026-01-31T12:00:00Z",
  "inputCount": 50,
  "cases": [
    {
      "id": "case_001",
      "input": {
        "url": "/api/users",
        "options": { "method": "GET" }
      },
      "output": {
        "status": 200,
        "data": [{ "id": 1, "name": "John" }]
      },
      "sideEffects": []
    },
    {
      "id": "case_002",
      "input": {
        "url": "/api/invalid",
        "options": { "method": "GET" }
      },
      "output": null,
      "error": {
        "type": "NetworkError",
        "message": "404 Not Found"
      }
    }
  ]
}
```

## Instructions for Claude

When `/golden-master` is invoked:

### Step 1: Identify Target Functions

1. If specific function provided: Target that function only
2. If file provided: Find all exported functions/classes
3. Analyze function signatures to determine input types

```javascript
// Analyze the target file to extract functions
const functions = analyzeFunctions(targetFile);
// Result: [{ name, params, returnType, startLine, endLine }]
```

### Step 2: Generate Input Sets

Create diverse test inputs based on parameter types:

```javascript
const inputGenerators = {
  string: () => [
    '',                          // Empty
    'hello',                     // Normal
    'a'.repeat(1000),           // Long
    'test\nwith\nnewlines',     // Special chars
    '<script>alert(1)</script>' // Injection attempt
  ],

  number: () => [
    0, 1, -1,                   // Boundaries
    999999999,                  // Large
    0.123456789,               // Decimal
    NaN, Infinity, -Infinity   // Edge cases
  ],

  array: () => [
    [],                        // Empty
    [1, 2, 3],                // Normal
    new Array(100).fill(0),   // Large
    [null, undefined, {}]     // Mixed types
  ],

  object: () => [
    {},                        // Empty
    { key: 'value' },         // Normal
    { nested: { deep: {} } }, // Nested
    null, undefined           // Nullish
  ]
};

// Generate combinations
const inputs = generateCombinations(functionParams, inputGenerators);
```

### Step 3: Execute and Capture

Run each input through the function and capture results:

```javascript
const results = [];

for (const input of inputs) {
  try {
    // Mock external dependencies if needed
    const output = await targetFunction(...input.args);

    results.push({
      id: `case_${results.length.toString().padStart(3, '0')}`,
      input: input.args,
      output: serializeOutput(output),
      sideEffects: captureSideEffects()
    });
  } catch (error) {
    results.push({
      id: `case_${results.length.toString().padStart(3, '0')}`,
      input: input.args,
      output: null,
      error: {
        type: error.constructor.name,
        message: error.message
      }
    });
  }
}
```

### Step 4: Generate Test File

Create executable test file:

{{#if testing.unit.framework}}
**Using {{testing.unit.framework}}:**

```{{#if (eq testing.unit.framework "vitest")}}typescript
// fetchData.spec.ts
import { describe, it, expect } from 'vitest';
import { fetchData } from '../../../src/api/client';
import goldenMaster from './fetchData.master.json';

describe('Golden Master: fetchData', () => {
  for (const testCase of goldenMaster.cases) {
    it(`case ${testCase.id}: should match golden master`, async () => {
      if (testCase.error) {
        await expect(
          fetchData(...testCase.input)
        ).rejects.toThrow(testCase.error.type);
      } else {
        const result = await fetchData(...testCase.input);
        expect(result).toEqual(testCase.output);
      }
    });
  }
});
{{else}}typescript
// fetchData.spec.ts
import { fetchData } from '../../../src/api/client';
import goldenMaster from './fetchData.master.json';

describe('Golden Master: fetchData', () => {
  for (const testCase of goldenMaster.cases) {
    test(`case ${testCase.id}: should match golden master`, async () => {
      if (testCase.error) {
        await expect(
          fetchData(...testCase.input)
        ).rejects.toThrow(testCase.error.type);
      } else {
        const result = await fetchData(...testCase.input);
        expect(result).toEqual(testCase.output);
      }
    });
  }
});
{{/if}}
```
{{else}}
**Generic Test Template:**

```javascript
// fetchData.spec.js
const goldenMaster = require('./fetchData.master.json');
const { fetchData } = require('../../../src/api/client');

describe('Golden Master: fetchData', () => {
  goldenMaster.cases.forEach((testCase) => {
    test(`case ${testCase.id}`, async () => {
      if (testCase.error) {
        await expect(fetchData(...testCase.input)).rejects.toThrow();
      } else {
        const result = await fetchData(...testCase.input);
        expect(result).toEqual(testCase.output);
      }
    });
  });
});
```
{{/if}}

### Step 5: Verification Mode (--verify)

When running `--verify`:

1. Load existing golden master
2. Re-execute all test cases
3. Compare outputs
4. Report any differences

```
╔═══════════════════════════════════════════════════════════════╗
║  🔍 Golden Master Verification                                 ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Function: fetchData                                          ║
║  Test Cases: 50                                               ║
║  Passed: 48                                                   ║
║  Failed: 2                                                    ║
║                                                               ║
║  ❌ case_023: Output mismatch                                 ║
║     Expected: { status: 200, data: [...] }                    ║
║     Actual:   { status: 200, data: [...], meta: {...} }       ║
║     Diff: + "meta" field added                                ║
║                                                               ║
║  ❌ case_047: New error type                                  ║
║     Expected: NetworkError                                    ║
║     Actual:   TimeoutError                                    ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  ⚠️  Behavior change detected!                                 ║
║                                                               ║
║  Options:                                                     ║
║  [U] Update master (intentional change)                       ║
║  [R] Revert refactoring (unintentional)                       ║
║  [I] Investigate differences                                  ║
╚═══════════════════════════════════════════════════════════════╝
```

### Step 6: Update Manifest

Track all golden masters:

```json
// manifest.json
{
  "version": "1.0",
  "lastUpdated": "2026-01-31T12:00:00Z",
  "masters": [
    {
      "file": "src/api/client.ts",
      "function": "fetchData",
      "path": "src-api-client.ts/fetchData.master.json",
      "inputCount": 50,
      "createdAt": "2026-01-31T12:00:00Z",
      "lastVerified": "2026-01-31T14:30:00Z",
      "status": "passing"
    }
  ]
}
```

## Workflow Integration

### Before Refactoring

```
1. /refactor-analyze src/api/client.ts    # Understand what needs refactoring
2. /golden-master src/api/client.ts       # Capture current behavior
3. /refactor-workflow src/api/client.ts   # Start refactoring
```

### During Refactoring

The `refactor-verify` hook will automatically:
1. Run golden master tests after each Edit
2. Alert if behavior changed
3. Suggest rollback if tests fail

### After Refactoring

```
1. /golden-master --verify                # Confirm behavior preserved
2. Delete characterization tests (optional)
3. Write proper unit tests with TDD
```

## Tech Stack Specifics

{{#if frontend.framework}}
### {{frontend.framework}} Components

For React/Vue components, golden master captures:
- Rendered output (snapshot)
- Event handler results
- Hook state changes
- Props → rendered output mapping
{{/if}}

{{#if backend.framework}}
### {{backend.framework}} Endpoints

For API endpoints, golden master captures:
- Request → Response mapping
- Error responses
- Side effects (database calls, external APIs)
{{/if}}

## Limitations

1. **External dependencies**: Must be mocked for reproducibility
2. **Random behavior**: Use fixed seeds for deterministic results
3. **Time-dependent**: Mock Date/time for consistency
4. **Large outputs**: Truncate or hash very large responses

## Related Commands

- `/refactor-analyze` - Analyze complexity before generating tests
- `/refactor-workflow` - Execute refactoring with verification
- `/ralph` - Continuous test-fix cycle

---

*"Characterization tests are your safety net when walking the refactoring tightrope."*

*Generated from tech-stack.json template*
