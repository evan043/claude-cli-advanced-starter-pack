---
description: Run comprehensive security scan on codebase
type: project
complexity: medium
allowed-tools: Bash, Read, Grep, Glob, WebSearch
category: security
---

# /security-scan

Run a multi-layer security audit on your codebase.

## Usage

```
/security-scan
/security-scan --full
/security-scan --quick
```

## What It Does

1. **Dependency Audit** - Check for vulnerable packages
2. **OWASP Check** - Scan for common vulnerabilities
3. **Secret Detection** - Find accidentally committed secrets
4. **Security Report** - Generate actionable findings

---

## Step 1: Dependency Audit

Check for vulnerable dependencies:

```bash
# Node.js projects
npm audit --json

# Python projects
pip-audit

# Ruby projects
bundle audit
```

Parse output and report vulnerabilities by severity:
- Critical (CVSS 9.0-10.0)
- High (CVSS 7.0-8.9)
- Medium (CVSS 4.0-6.9)
- Low (CVSS 0.1-3.9)

---

## Step 2: OWASP Top 10 Scan

Scan for common vulnerabilities:

### A01: Broken Access Control

```bash
# Search for missing authorization checks
grep -r "req.user" --include="*.js" --include="*.ts"
grep -r "current_user" --include="*.py"
```

### A02: Cryptographic Failures

```bash
# Weak crypto usage
grep -r "md5\|sha1" --include="*.js" --include="*.py"
grep -r "ECB" --include="*.java"
```

### A03: Injection

```bash
# SQL injection patterns
grep -r "execute.*+\|query.*+" --include="*.js" --include="*.py"
grep -r "raw\|execute_raw" --include="*.rb"

# Command injection
grep -r "exec\|eval\|execSync\|spawn" --include="*.js"
grep -r "os.system\|subprocess.call" --include="*.py"
```

### A04: Insecure Design

Look for:
- Missing rate limiting
- Lack of input validation
- Unvalidated redirects

### A05: Security Misconfiguration

```bash
# Debug mode in production
grep -r "DEBUG.*=.*True\|debug.*:.*true" --include="*.py" --include="*.js"

# Exposed error details
grep -r "app.debug\|app.use(errorHandler)" --include="*.js"
```

### A06: Vulnerable Components

Already covered in dependency audit.

### A07: Identification and Authentication Failures

```bash
# Weak password policies
grep -r "password.*length.*<.*8" --include="*.js" --include="*.py"

# Missing MFA checks
grep -r "login\|authenticate" --include="*.js" --include="*.py"
```

### A08: Software and Data Integrity Failures

```bash
# Unsigned packages
grep -r "verify.*false\|checksum.*false" package.json requirements.txt

# Untrusted deserialization
grep -r "pickle.load\|unserialize\|YAML.load" --include="*.py" --include="*.js"
```

### A09: Security Logging and Monitoring Failures

```bash
# Missing security logging
grep -r "login.*attempt\|failed.*auth" --include="*.log"
```

### A10: Server-Side Request Forgery (SSRF)

```bash
# URL parameters used in requests
grep -r "axios.get.*req.query\|requests.get.*request.args" --include="*.js" --include="*.py"
```

---

## Step 3: Secret Detection

Scan for accidentally committed secrets:

### Patterns to Search

```bash
# API keys and tokens
grep -r "api[_-]?key.*=\|secret.*=\|token.*=" --include="*.js" --include="*.py" --include="*.env*"

# AWS credentials
grep -r "AKIA[0-9A-Z]{16}" .

# Private keys
find . -name "*.pem" -o -name "*.key" -o -name "*_rsa"

# Database connection strings
grep -r "postgres://\|mysql://\|mongodb://" --include="*.js" --include="*.py"

# JWT secrets
grep -r "jwt.*secret\|JWT_SECRET" --include="*.js" --include="*.env*"

# Generic passwords
grep -r "password.*=.*['\"](?!{{)[a-zA-Z0-9]" --include="*.js" --include="*.py"
```

### Files to Check

- `.env` files in git history
- Config files with credentials
- Test files with real credentials
- Docker files with secrets
- CI/CD config files

### Git History Scan

```bash
# Check if .env is tracked
git ls-files | grep -E "\.env$|credentials|secrets"

# Search git history for secrets
git log -p | grep -i "password\|secret\|api_key"
```

---

## Step 4: Generate Security Report

### Report Structure

```markdown
# Security Scan Report

**Date:** [timestamp]
**Scanned:** [project name]

## Executive Summary

- Total Findings: [count]
- Critical: [count]
- High: [count]
- Medium: [count]
- Low: [count]

## Critical Findings

### 1. [Vulnerability Title]

**Severity:** Critical
**Category:** OWASP A03 (Injection)
**Location:** src/api/users.js:42
**Description:** SQL query built with string concatenation, vulnerable to SQL injection.

**Code:**
```javascript
const query = `SELECT * FROM users WHERE id = ${userId}`;
```

**Remediation:**
```javascript
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```

**Risk:** Attackers can extract entire database.
**Effort:** Low (15 minutes)

---

## Dependency Vulnerabilities

### Package: lodash@4.17.15

**Severity:** High
**CVE:** CVE-2020-8203
**Description:** Prototype pollution vulnerability
**Remediation:** Upgrade to lodash@4.17.21

```bash
npm install lodash@4.17.21
```

---

## Secret Exposure

### File: config/database.js

**Severity:** Critical
**Description:** Database password hardcoded in source

**Code:**
```javascript
password: 'mySecretPassword123'
```

**Remediation:**
```javascript
password: process.env.DATABASE_PASSWORD
```

**Action:** Rotate database credentials immediately.

---

## Recommendations

1. **Immediate Actions** (Critical findings)
   - [ ] Fix SQL injection in users.js
   - [ ] Rotate exposed database credentials
   - [ ] Remove .env from git history

2. **Short Term** (High findings)
   - [ ] Update vulnerable dependencies
   - [ ] Add input validation layer
   - [ ] Implement rate limiting

3. **Long Term** (Medium/Low findings)
   - [ ] Set up automated security scanning in CI
   - [ ] Implement Content Security Policy
   - [ ] Enable security headers

---

## Security Score: 6.5/10

**Calculation:**
- Critical issues: -2.0
- High issues: -1.0
- Medium issues: -0.5
- Good practices: +0.0

**Target:** 9.0/10
```

---

## Configuration

Add to `.claude/config/security.json`:

```json
{
  "scan": {
    "enabled": true,
    "excludePaths": [
      "node_modules/",
      "dist/",
      "build/",
      ".git/"
    ],
    "secretPatterns": [
      "AKIA[0-9A-Z]{16}",
      "api[_-]?key.*=",
      "jwt.*secret"
    ],
    "thresholds": {
      "critical": 0,
      "high": 5,
      "medium": 10
    }
  }
}
```

---

## Integration with CI/CD

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm audit --audit-level=moderate
      - run: npx snyk test
      - run: git secrets --scan
```

---

## Related Commands

- `/create-smoke-test` - Add security-focused E2E tests
- `/deploy-full` - Pre-deployment security check
- `/refactor-check` - Include security linting

---

*Security scanning powered by CCASP - Always verify findings manually*
