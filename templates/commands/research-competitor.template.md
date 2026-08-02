---
description: Comprehensive 6-phase competitive intelligence analysis
type: project
complexity: high
---

# /research-competitor

Comprehensive 6-phase competitive intelligence analysis for any product or market.

## Usage

```bash
/research-competitor [product-name]
/research-competitor "Product Name" --domain "market domain"
/research-competitor --continue   # Resume previous analysis
```

## Overview

This command runs a structured 6-phase competitive analysis:

| Phase | Name | Est. Time | Output |
|-------|------|-----------|--------|
| 1 | Competitor Discovery | 5 min | Competitor list |
| 2 | Feature Extraction | 10 min | Feature inventory |
| 3 | Pricing Analysis | 5 min | Pricing comparison |
| 4 | Tech Stack Discovery | 5 min | Tech insights |
| 5 | Market Sentiment | 8 min | Review analysis |
| 6 | Feature Gap Analysis | 5 min | Gap matrix + priorities |

**Total estimated time: ~38 minutes**

## Instructions

When this command is invoked:

### Step 1: Gather Context

Ask the user (if not provided):
1. What is the product/service being analyzed?
2. What market domain does it operate in?
3. Are there known competitors to include?

### Step 2: Run Discovery Phase

```
Use WebSearch to find:
- "[product] alternatives"
- "[product] competitors"
- "best [domain] tools 2026"
```

Compile a list of 5-10 competitors with:
- Company name
- Website URL
- Brief description

### Step 3: Feature Extraction

For each competitor:
1. Visit their product/features page using WebFetch
2. Extract key features
3. Note unique selling points

Output: Feature inventory matrix

### Step 4: Pricing Analysis

For each competitor:
1. Find pricing page
2. Extract tiers and pricing
3. Identify: Free tier? Starting price? Enterprise?

Output: Pricing comparison table

### Step 5: Tech Stack Discovery

For each competitor:
1. Check builtwith.com or wappalyzer data
2. Analyze job postings for tech hints
3. Check page source for framework indicators

Output: Tech stack inventory

### Step 6: Market Sentiment

For each competitor:
1. Search for reviews on G2, Capterra, Product Hunt
2. Check social media sentiment
3. Analyze Reddit discussions

Output: Sentiment summary with ratings

### Step 7: Gap Analysis

1. Compare your product features vs competitors
2. Identify gaps (features they have, you don't)
3. Identify differentiators (features you have, they don't)
4. Prioritize by demand and competitive coverage

Output: Feature gap matrix with priorities

### Step 8: Generate Report

Save comprehensive report to:
`docs/competitive-analysis/[product-slug]-analysis-[date].md`

Include:
- Executive summary
- Competitor profiles
- Feature comparison matrix
- Pricing analysis
- SWOT analysis
- Prioritized recommendations

## Output Format

```markdown
# Competitive Analysis: [Product Name]

## Executive Summary
[2-3 paragraph overview]

## Competitors Analyzed
| Competitor | Website | Category | Overall Rating |
|------------|---------|----------|----------------|

## Feature Gap Matrix
| Feature | Our Product | Competitor A | Competitor B | Priority |
|---------|-------------|--------------|--------------|----------|

## Pricing Comparison
| Provider | Free Tier | Starting | Enterprise | Model |
|----------|-----------|----------|------------|-------|

## SWOT Analysis
### Strengths
### Weaknesses
### Opportunities
### Threats

## Recommendations
1. [Priority: High] ...
2. [Priority: Medium] ...
```

## MCP Tools Used

This skill uses free alternatives where possible:

| Purpose | Primary | Fallback |
|---------|---------|----------|
| Search | DuckDuckGo MCP | WebSearch |
| Scraping | Crawl4AI (uvx) | WebFetch |

## Installation (Optional Enhancement)

For better scraping capabilities:
```bash
# Install Crawl4AI MCP
uvx crawl4ai-mcp
```

## Examples

```bash
# Analyze competitors for a CRM product
/research-competitor "HubSpot" --domain "CRM software"

# Analyze AI writing tools market
/research-competitor "Jasper AI" --domain "AI writing assistants"

# Continue previous analysis
/research-competitor --continue
```

## Related Commands

- `/research-features` - Deep dive into specific feature areas
- `/research-market` - Broader market analysis
- `/phase-dev-plan` - Turn findings into development roadmap

---
*Part of CCASP Competitor Analysis toolkit*
