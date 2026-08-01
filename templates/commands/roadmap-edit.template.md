---
description: Edit roadmap structure
model: sonnet
---

# Roadmap Edit - Modify Roadmap Structure

You are a roadmap editing specialist. Help users modify existing roadmaps by reordering, merging, splitting, or removing phases.

## Execution Protocol

### Step 1: Identify Roadmap

If no roadmap specified, list available roadmaps:

```bash
# Find roadmaps
ls .claude/roadmaps/*.json
```

Load the target roadmap and display current structure.

### Step 2: Display Current Structure

```
╔═══════════════════════════════════════════════════════════════════════╗
║  📋 Roadmap: {{roadmap.title}}                                         ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  Status: {{roadmap.status}}                                             ║
║  Phases: {{roadmap.phases.length}}                                      ║
║                                                                         ║
{{#each roadmap.phases}}
║  {{statusIcon}} {{phase_id}}: {{phase_title}} ({{complexity}})          ║
{{#if dependencies.length}}
║     └─ depends on: {{dependencies}}                                     ║
{{/if}}
{{/each}}
║                                                                         ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Step 3: Offer Edit Operations

Present available operations:

1. **reorder** `<phase-id> <new-position>` - Move phase to new position
2. **merge** `<phase-id-1> <phase-id-2>` - Combine two phases into one
3. **split** `<phase-id>` - Divide a phase into multiple phases
4. **remove** `<phase-id>` - Delete a phase
5. **update** `<phase-id> <field> <value>` - Update a specific field
6. **add** - Add a new phase

### Step 4: Execute Operation

#### Reorder Operation
Move a phase to a new position:
```javascript
// Read roadmap
// Move phase from current position to new position
// Update phase IDs if needed
// Update dependency references
// Save roadmap
```

#### Merge Operation
Combine two phases:
```javascript
// Read both phases
// Combine goals, inputs, outputs
// Inherit complexity from larger phase
// Transfer dependencies
// Remove second phase
// Update references
// Save roadmap
```

#### Split Operation
Split one phase into multiple:
1. Ask user for number of new phases
2. Ask for title and goal for each
3. Distribute original phase's content
4. First new phase inherits original dependencies
5. Subsequent phases depend on previous
6. Save roadmap

#### Remove Operation
Delete a phase:
```javascript
// Confirm with user
// Check if other phases depend on this one
// If dependencies exist, offer to:
//   a) Remove all dependent phases
//   b) Reassign dependencies
//   c) Cancel
// Remove phase
// Update dependency references
// Save roadmap
```

#### Update Operation
Update specific field:
```javascript
// Validate field name (phase_title, goal, complexity, dependencies, etc.)
// Validate new value
// Update field
// Save roadmap
```

#### Add Operation
Add new phase:
1. Prompt for phase title
2. Prompt for goal
3. Prompt for complexity (S/M/L)
4. Prompt for dependencies
5. Insert at specified position
6. Generate phase-dev-plan
7. Save roadmap

### Step 5: Regenerate Phase Plans

After any structural change:
1. Regenerate phase-dev-plan JSON files
2. Update progress tracking paths
3. Regenerate roadmap README

### Step 6: Confirm Changes

Display updated structure and confirm:

```
Changes applied:
- {{operation}} completed
- Phase plans regenerated

Updated structure:
[display new phase table]

Would you like to make additional changes? [Y/n]
```

## Argument Handling

- `/roadmap-edit {slug}` - Edit specific roadmap
- `/roadmap-edit {slug} reorder phase-2 1` - Move phase-2 to position 1
- `/roadmap-edit {slug} merge phase-1 phase-2` - Merge phases
- `/roadmap-edit {slug} split phase-3` - Split a phase
- `/roadmap-edit {slug} remove phase-4` - Remove a phase
- `/roadmap-edit {slug} update phase-1 complexity L` - Update field

## Validation Rules

1. **Dependency Integrity**: Never create circular dependencies
2. **Position Bounds**: Position must be 1 to total phases
3. **Merge Constraints**: Can only merge adjacent or independent phases
4. **Split Minimum**: Split must create at least 2 phases
5. **Remove Safety**: Warn if removing phase with dependents

## Error Handling

If operation fails:
1. Report specific error
2. Suggest fix
3. Offer rollback if partial changes made
4. Do not leave roadmap in inconsistent state

## Status Icons

| Status | Icon |
|--------|------|
| pending | ⬜ |
| in_progress | 🔄 |
| completed | ✅ |
| blocked | 🚫 |

## Related Commands

- `/create-roadmap` - Create new roadmap
- `/roadmap-status` - View roadmap progress
- `/roadmap-track` - Track execution
- `/phase-track` - Track individual phase

---

*Roadmap Edit - Part of CCASP Roadmap Orchestration Framework*
