/**
 * Account Requirements Detector
 *
 * Detects required accounts and API keys from tools and MCP servers.
 *
 * @module vision/analysis/account/requirements
 */

/**
 * Detect account requirements from tools and MCP servers
 *
 * @param {Array<Object>} tools - Selected npm/pip packages
 * @param {Array<Object>} mcpServers - Selected MCP servers
 * @returns {Array<Object>} Required accounts and setup steps
 *
 * @example
 * const requirements = detectAccountRequirements(
 *   [{ name: 'stripe', type: 'npm' }],
 *   [{ server: 'railway-mcp-server' }]
 * );
 * // [
 * //   { service: 'Stripe', accountType: 'paid', setupUrl: '...', required: true },
 * //   { service: 'Railway', accountType: 'free-tier', setupUrl: '...', required: true }
 * // ]
 */
export function detectAccountRequirements(tools = [], mcpServers = []) {
  const requirements = new Map();
  const normalizedTools = Array.isArray(tools)
    ? tools
    : (tools && Array.isArray(tools.tools) ? tools.tools : []);
  const normalizedMcpServers = Array.isArray(mcpServers)
    ? mcpServers
    : (mcpServers && Array.isArray(mcpServers.mcpServers) ? mcpServers.mcpServers : []);

  // Detect from MCP servers (primary source)
  normalizedMcpServers.forEach(mcp => {
    const mcpReqs = getMCPAccountRequirements(mcp.server);
    mcpReqs.forEach(req => {
      requirements.set(req.service, req);
    });
  });

  // Detect from npm/pip packages
  normalizedTools.forEach(tool => {
    const toolReqs = getToolAccountRequirements(tool.name);
    toolReqs.forEach(req => {
      // Only add if not already present (MCP takes precedence)
      if (!requirements.has(req.service)) {
        requirements.set(req.service, req);
      }
    });
  });

  return Array.from(requirements.values());
}

/**
 * Get account requirements for MCP server
 * @private
 */
function getMCPAccountRequirements(serverName) {
  const mcpRequirements = {
    'railway-mcp-server': [
      {
        service: 'Railway',
        accountType: 'free-tier',
        required: true,
        category: 'deployment',
        setupUrl: 'https://railway.app/new',
        setupSteps: [
          'Sign up at railway.app',
          'Create a new project',
          'Generate API token from Account Settings',
          'Add token to .env as RAILWAY_API_TOKEN'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0, // Free tier available
        freeTierLimits: '$5 monthly credit',
        docs: 'https://docs.railway.app/develop/tokens'
      }
    ],

    'cloudflare-mcp-server': [
      {
        service: 'Cloudflare',
        accountType: 'free-tier',
        required: true,
        category: 'deployment',
        setupUrl: 'https://dash.cloudflare.com/sign-up',
        setupSteps: [
          'Go to "My Profile" > "API Tokens"',
          'Create token with "Edit Cloudflare Workers" template',
          'Add token to .env as CLOUDFLARE_API_TOKEN'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0,
        freeTierLimits: '100,000 requests/day for Workers',
        docs: 'https://developers.cloudflare.com/workers/configuration/api'
      }
    ],

    'postgres-mcp': [
      {
        service: 'PostgreSQL Database',
        accountType: 'self-hosted',
        required: true,
        category: 'database',
        setupUrl: 'https://www.postgresql.org/download/',
        setupSteps: [
          'Install PostgreSQL locally OR use hosted service (Railway, Supabase)',
          'Create database',
          'Note connection string',
          'Add to .env as DATABASE_URL'
        ],
        setupTimeMinutes: 20,
        monthlyCost: 0, // Can be free with Railway/Supabase free tier
        alternatives: ['Railway Postgres', 'Supabase', 'Neon', 'AWS RDS'],
        docs: 'https://www.postgresql.org/docs/'
      }
    ],

    'github-mcp-server': [
      {
        service: 'GitHub',
        accountType: 'free',
        required: true,
        category: 'version-control',
        setupUrl: 'https://github.com/join',
        setupSteps: [
          'Sign up/login at github.com',
          'Go to Settings > Developer settings > Personal access tokens',
          'Generate new token (classic) with repo and workflow scopes',
          'Add token to .env as GITHUB_TOKEN'
        ],
        setupTimeMinutes: 5,
        monthlyCost: 0,
        docs: 'https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token'
      }
    ],

    'brave-search-mcp': [
      {
        service: 'Brave Search API',
        accountType: 'free-tier',
        required: false,
        category: 'search',
        setupUrl: 'https://brave.com/search/api/',
        setupSteps: [
          'Sign up for Brave Search API',
          'Get API key from dashboard',
          'Add key to .env as BRAVE_API_KEY'
        ],
        setupTimeMinutes: 5,
        monthlyCost: 0,
        freeTierLimits: '2,000 queries/month free',
        docs: 'https://brave.com/search/api/docs'
      }
    ],

    'slack-mcp-server': [
      {
        service: 'Slack',
        accountType: 'free-tier',
        required: false,
        category: 'notifications',
        setupUrl: 'https://api.slack.com/apps',
        setupSteps: [
          'Create Slack workspace (if needed)',
          'Create new Slack app at api.slack.com/apps',
          'Add OAuth scopes: chat:write, files:write',
          'Install app to workspace',
          'Copy OAuth token to .env as SLACK_BOT_TOKEN'
        ],
        setupTimeMinutes: 15,
        monthlyCost: 0,
        docs: 'https://api.slack.com/start'
      }
    ],

    'stripe-mcp-server': [
      {
        service: 'Stripe',
        accountType: 'free-test',
        required: false,
        category: 'payments',
        setupUrl: 'https://dashboard.stripe.com/register',
        setupSteps: [
          'Sign up at stripe.com',
          'Get test API keys from dashboard',
          'Add keys to .env: STRIPE_SECRET_KEY, STRIPE_PUBLISHABLE_KEY',
          'Activate account for production when ready'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0, // Pay-as-you-go, no monthly fee
        pricingModel: 'Per-transaction fee',
        docs: 'https://stripe.com/docs/keys'
      }
    ],

    'sendgrid-mcp-server': [
      {
        service: 'SendGrid',
        accountType: 'free-tier',
        required: false,
        category: 'email',
        setupUrl: 'https://signup.sendgrid.com/',
        setupSteps: [
          'Sign up at sendgrid.com',
          'Verify email address',
          'Create API key with Mail Send permission',
          'Add key to .env as SENDGRID_API_KEY'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0,
        freeTierLimits: '100 emails/day free',
        docs: 'https://sendgrid.com/docs/api-reference/'
      }
    ],

    'aws-s3-mcp': [
      {
        service: 'AWS',
        accountType: 'free-tier',
        required: false,
        category: 'storage',
        setupUrl: 'https://portal.aws.amazon.com/billing/signup',
        setupSteps: [
          'Create AWS account',
          'Create IAM user with S3 access',
          'Generate access key and secret',
          'Add to .env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY',
          'Create S3 bucket'
        ],
        setupTimeMinutes: 20,
        monthlyCost: 0,
        freeTierLimits: '5GB storage, 20,000 GET requests/month',
        docs: 'https://docs.aws.amazon.com/s3/'
      }
    ],

    'redis-mcp': [
      {
        service: 'Redis',
        accountType: 'self-hosted',
        required: false,
        category: 'caching',
        setupUrl: 'https://redis.io/download',
        setupSteps: [
          'Install Redis locally OR use Upstash (free tier)',
          'Get connection URL',
          'Add to .env as REDIS_URL'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0,
        alternatives: ['Upstash (free tier)', 'Railway Redis', 'Redis Cloud'],
        docs: 'https://redis.io/docs/'
      }
    ],

    'openai-mcp-server': [
      {
        service: 'OpenAI',
        accountType: 'paid',
        required: false,
        category: 'ai',
        setupUrl: 'https://platform.openai.com/signup',
        setupSteps: [
          'Sign up at platform.openai.com',
          'Add payment method',
          'Create API key',
          'Add key to .env as OPENAI_API_KEY'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0, // Pay-per-use
        pricingModel: 'Pay-per-token',
        docs: 'https://platform.openai.com/docs/api-reference'
      }
    ],

    'anthropic-mcp-server': [
      {
        service: 'Anthropic',
        accountType: 'paid',
        required: false,
        category: 'ai',
        setupUrl: 'https://console.anthropic.com/',
        setupSteps: [
          'Sign up at console.anthropic.com',
          'Add payment method',
          'Create API key',
          'Add key to .env as ANTHROPIC_API_KEY'
        ],
        setupTimeMinutes: 10,
        monthlyCost: 0, // Pay-per-use
        pricingModel: 'Pay-per-token',
        docs: 'https://docs.anthropic.com/claude/reference/getting-started-with-the-api'
      }
    ]
  };

  return mcpRequirements[serverName] || [];
}

/**
 * Get account requirements for npm/pip package
 * @private
 */
function getToolAccountRequirements(toolName) {
  const toolRequirements = {
    'stripe': [
      {
        service: 'Stripe',
        accountType: 'free-test',
        required: true,
        category: 'payments',
        setupUrl: 'https://dashboard.stripe.com/register',
        setupSteps: ['Sign up at stripe.com', 'Get test API keys'],
        setupTimeMinutes: 10,
        monthlyCost: 0
      }
    ],
    'sendgrid': [
      {
        service: 'SendGrid',
        accountType: 'free-tier',
        required: true,
        category: 'email',
        setupUrl: 'https://signup.sendgrid.com/',
        setupSteps: ['Sign up', 'Create API key'],
        setupTimeMinutes: 10,
        monthlyCost: 0
      }
    ],
    'twilio': [
      {
        service: 'Twilio',
        accountType: 'free-trial',
        required: true,
        category: 'communications',
        setupUrl: 'https://www.twilio.com/try-twilio',
        setupSteps: ['Sign up', 'Get Account SID and Auth Token'],
        setupTimeMinutes: 10,
        monthlyCost: 0
      }
    ],
    'next-auth': [
      {
        service: 'OAuth Providers',
        accountType: 'varies',
        required: false,
        category: 'authentication',
        setupUrl: 'https://next-auth.js.org/providers/',
        setupSteps: ['Set up OAuth apps for desired providers (Google, GitHub, etc.)'],
        setupTimeMinutes: 20,
        monthlyCost: 0
      }
    ]
  };

  return toolRequirements[toolName] || [];
}
