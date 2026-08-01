---
description: Audit and analyze current context token usage
model: haiku
---

# /context-audit - Token Budget Audit

Analyze current session context and token usage against budget thresholds.

{{#if tokenManagement.enabled}}

## Configuration

| Setting | Value |
|---------|-------|
| Daily Budget | {{tokenManagement.dailyBudget}} tokens |
| Compact Threshold | {{tokenManagement.thresholds.compact}} ({{#if tokenManagement.dailyBudget}}~{{tokenManagement.dailyBudget * tokenManagement.thresholds.compact}} tokens{{/if}}) |
| Archive Threshold | {{tokenManagement.thresholds.archive}} ({{#if tokenManagement.dailyBudget}}~{{tokenManagement.dailyBudget * tokenManagement.thresholds.archive}} tokens{{/if}}) |
| Respawn Threshold | {{tokenManagement.thresholds.respawn}} ({{#if tokenManagement.dailyBudget}}~{{tokenManagement.dailyBudget * tokenManagement.thresholds.respawn}} tokens{{/if}}) |
| Tracking File | {{tokenManagement.trackingFile}} |

## Audit Actions

### 1. Context Size Analysis
- Count total messages in conversation
- Estimate token usage per message type
- Identify largest context consumers

### 2. Compaction Opportunities
- Identify verbose tool outputs that could be summarized
- Find duplicate information in context
- Suggest messages that could be archived

### 3. Budget Status
- Current usage vs daily budget
- Time remaining in budget period
- Projected usage based on current rate

## Recommendations by Threshold

### At Compact Threshold ({{tokenManagement.thresholds.compact}})
- Summarize verbose tool outputs
- Remove intermediate exploration results
- Keep only essential context

### At Archive Threshold ({{tokenManagement.thresholds.archive}})
- Archive current session to `.claude/docs/sessions/`
- Create summary of accomplishments
- Start new session with essential context only

### At Respawn Threshold ({{tokenManagement.thresholds.respawn}})
- Force session restart
- Save all progress to files
- Create handoff document for new session

## Instructions for Claude

When this command is invoked:

1. **Analyze Context**
   - Estimate current token usage
   - Calculate percentage of daily budget used

2. **Generate Report**
   ```
   Token Budget Audit
   ─────────────────────
   Estimated Usage: X tokens (Y% of budget)
   Status: [OK | COMPACT | ARCHIVE | RESPAWN]

   Top Context Consumers:
   1. Tool outputs: ~X tokens
   2. Code blocks: ~X tokens
   3. Conversation: ~X tokens
   ```

3. **Provide Recommendations**
   - If below compact threshold: Continue normally
   - If at compact threshold: Suggest compaction strategies
   - If at archive threshold: Offer to archive session
   - If at respawn threshold: Initiate respawn protocol

{{else}}

## Token Management Disabled

Token budget management is not enabled for this project.

To enable:
1. Run `/menu` → Project Settings → Token Management
2. Or manually set `tokenManagement.enabled: true` in tech-stack.json

{{/if}}

---

*Generated from tech-stack.json template*
