---
description: Auto-generate Playwright smoke tests for critical user flows
---

# Create Smoke Test

Generate Playwright E2E tests automatically by analyzing your application's routes and components.

## Usage

```
/create-smoke-test
/create-smoke-test --page login
/create-smoke-test --flow checkout
/create-smoke-test --category deploy-regression
/create-smoke-test --category auth-flow
/create-smoke-test --category route-loading
```

## What It Does

1. **Analyze Routes** - Discover pages from router configuration
2. **Identify Flows** - Map critical user journeys
3. **Generate Tests** - Create Playwright test files
4. **Add Selectors** - Include data-testid recommendations

## Smoke Test Categories

### Authentication
- Login flow
- Logout flow
- Password reset
- Session persistence

### Navigation
- Home page loads
- All routes accessible
- Navigation links work
- 404 handling

### Critical Paths
- User registration
- Core feature usage
- Payment flow (if applicable)
- Data submission forms

### Deploy Regression
- API endpoint existence verification
- Response shape validation (required fields present)
- Status code contracts (expected codes match)
- CORS header checks on preflight
- Pagination parameter handling
- Template: `templates/testing/deploy-regression.spec.template.ts`

### Auth Flow
- Login sets cookie/token correctly
- Session persists across page reload
- Invalid credentials show error message
- Protected routes redirect to login when unauthenticated
- Logout clears all auth state
- Expired token triggers refresh (no infinite loop)
- Template: `templates/testing/auth-flow.spec.template.ts`

### Route Loading
- All routes render visible content (not blank)
- No JS console errors during route load
- No stuck loading spinners after network idle
- Client-side route transitions work
- Chunk loading failures show error boundary
- Unknown routes show 404 page
- Route load time under configurable threshold
- Template: `templates/testing/route-loading.spec.template.ts`

## Implementation

### Step 1: Discover Routes

**React Router:**
```typescript
// Analyze src/routes.tsx or src/App.tsx
// Extract route paths and components
```

**Next.js:**
```bash
# List pages directory
ls -la pages/ app/
```

### Step 2: Generate Test File

```typescript
// tests/smoke/navigation.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Navigation Smoke Tests', () => {
  test('home page loads', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Your App/);
    await expect(page.locator('main')).toBeVisible();
  });

  test('login page accessible', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('[data-testid="login-form"]')).toBeVisible();
  });

  // Additional generated tests...
});
```

### Step 3: Add Test Helpers

```typescript
// tests/helpers/auth.ts
export async function loginAs(page, user) {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', user.email);
  await page.fill('[data-testid="password"]', user.password);
  await page.click('[data-testid="submit"]');
  await page.waitForURL('/dashboard');
}
```

## Output Structure

```
tests/
├── smoke/
│   ├── auth.spec.ts               # Authentication flows
│   ├── navigation.spec.ts         # Page accessibility
│   ├── critical-paths.spec.ts     # Core user journeys
│   ├── deploy-regression.spec.ts  # API contract validation (post-deploy)
│   ├── auth-flow.spec.ts          # Full auth lifecycle (cookie/token)
│   └── route-loading.spec.ts      # Lazy load & chunk error tests
├── helpers/
│   ├── auth.ts              # Auth utilities
│   ├── fixtures.ts          # Test data
│   └── selectors.ts         # Shared selectors
└── playwright.config.ts     # Test configuration
```

## Template Placeholders

When generating tests from templates, fill these placeholders from your project:

| Template | Placeholder | Source |
|----------|------------|--------|
| deploy-regression | `{{API_BASE}}` | Backend URL from env config |
| deploy-regression | `{{ENDPOINTS}}` | API route handlers (FastAPI/Express routers) |
| deploy-regression | `{{AUTH_HEADER}}` | Auth token format from auth service |
| auth-flow | `{{LOGIN_URL}}` | Router config (typically `/login`) |
| auth-flow | `{{PROTECTED_ROUTES}}` | Routes with auth guards |
| auth-flow | `{{CREDENTIALS}}` | Test user from fixtures/seed data |
| auth-flow | `{{COOKIE_NAME}}` | Cookie name from auth middleware |
| route-loading | `{{ROUTES}}` | All routes from `routes.tsx` / router config |
| route-loading | `{{BASE_URL}}` | Dev server URL (e.g. `http://localhost:5174`) |
| route-loading | `{{LOAD_TIMEOUT}}` | Performance budget in ms (e.g. `10000`) |

## Generated Test Example

```typescript
import { test, expect } from '@playwright/test';
import { loginAs } from '../helpers/auth';
import { testUser } from '../helpers/fixtures';

test.describe('Authentication Smoke Tests', () => {
  test('user can log in with valid credentials', async ({ page }) => {
    await page.goto('/login');

    // Fill login form
    await page.fill('[data-testid="email-input"]', testUser.email);
    await page.fill('[data-testid="password-input"]', testUser.password);

    // Submit and verify
    await page.click('[data-testid="login-button"]');
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
  });

  test('user sees error for invalid credentials', async ({ page }) => {
    await page.goto('/login');
    await page.fill('[data-testid="email-input"]', 'invalid@test.com');
    await page.fill('[data-testid="password-input"]', 'wrongpassword');
    await page.click('[data-testid="login-button"]');

    await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
  });
});
```

## Selector Recommendations

For reliable tests, add these data-testid attributes to your components:

```html
<!-- Forms -->
<form data-testid="login-form">
  <input data-testid="email-input" />
  <input data-testid="password-input" />
  <button data-testid="login-button">Login</button>
</form>

<!-- Navigation -->
<nav data-testid="main-nav">
  <a data-testid="nav-home">Home</a>
  <a data-testid="nav-dashboard">Dashboard</a>
</nav>

<!-- Content -->
<main data-testid="page-content">
  <h1 data-testid="page-title">Welcome</h1>
</main>
```

## Configuration

Add to `playwright.config.ts`:

```typescript
export default {
  testDir: './tests',
  projects: [
    {
      name: 'smoke',
      testMatch: /smoke\/.+\.spec\.ts/,
      use: { baseURL: 'http://localhost:3000' },
    },
  ],
};
```

## Related Commands

- `/e2e-test` - Run E2E tests
- `/refactor-check` - Pre-commit validation
- `/deploy-full` - Full-stack deploy (run deploy-regression tests after)
- `/feature-audit` - Discover routes missing test coverage
