---
description: Generate comprehensive API documentation
type: project
complexity: medium
allowed-tools: Bash, Read, Write, Grep, Glob
category: documentation
---

# /api-docs

Auto-generate OpenAPI/Swagger documentation for your API.

## Usage

```
/api-docs
/api-docs --generate
/api-docs --serve
/api-docs --postman
```

## What It Does

1. **Detect API Framework** - Identify Express, FastAPI, etc.
2. **Generate OpenAPI Spec** - Create OpenAPI 3.0 specification
3. **Add Documentation** - Document all endpoints
4. **Request/Response Examples** - Add example payloads
5. **Generate Postman Collection** - Export for testing
6. **Host Documentation** - Set up Swagger UI or Redoc

---

## Step 1: Detect API Framework

{{#if backend.framework}}

**Detected Backend:** {{backend.framework}}

{{#if (eq backend.framework "express")}}
**Strategy:** Install swagger-jsdoc + swagger-ui-express
{{/if}}

{{#if (eq backend.framework "fastapi")}}
**Strategy:** Use built-in OpenAPI generator
{{/if}}

{{#if (eq backend.framework "nest")}}
**Strategy:** Use @nestjs/swagger
{{/if}}

{{else}}

No backend framework detected. Will analyze routes manually.

{{/if}}

---

## Step 2: Installation & Setup

### Express.js

```bash
npm install swagger-jsdoc swagger-ui-express
npm install --save-dev @types/swagger-jsdoc @types/swagger-ui-express
```

Create `src/swagger.js`:

```javascript
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '{{projectName}} API',
      version: '1.0.0',
      description: 'API documentation for {{projectName}}',
      contact: {
        name: 'API Support',
        email: 'support@example.com',
      },
    },
    servers: [
      {
        url: '{{deployment.backend.productionUrl}}',
        description: 'Production server',
      },
      {
        url: 'http://localhost:{{backend.devServerPort || 8001}}',
        description: 'Development server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./src/routes/*.js', './src/routes/*.ts'], // Path to route files
};

const specs = swaggerJsdoc(options);

module.exports = { specs, swaggerUi };
```

Add to `app.js`:

```javascript
const { specs, swaggerUi } = require('./swagger');

// Serve Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs, {
  explorer: true,
  customCss: '.swagger-ui .topbar { display: none }',
}));

// Serve raw OpenAPI JSON
app.get('/api-docs.json', (req, res) => {
  res.json(specs);
});
```

### FastAPI (Python)

FastAPI has built-in OpenAPI support. Enhance it:

```python
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

app = FastAPI(
    title="{{projectName}} API",
    description="API documentation for {{projectName}}",
    version="1.0.0",
    contact={
        "name": "API Support",
        "email": "support@example.com",
    },
    servers=[
        {"url": "{{deployment.backend.productionUrl}}", "description": "Production"},
        {"url": "http://localhost:{{backend.devServerPort || 8001}}", "description": "Development"},
    ],
)

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    # Add custom examples
    openapi_schema["info"]["x-logo"] = {
        "url": "https://example.com/logo.png"
    }
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

# Docs available at:
# /docs (Swagger UI)
# /redoc (ReDoc)
# /openapi.json (Raw OpenAPI spec)
```

### NestJS

```bash
npm install @nestjs/swagger swagger-ui-express
```

Update `main.ts`:

```typescript
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const config = new DocumentBuilder()
    .setTitle('{{projectName}} API')
    .setDescription('API documentation for {{projectName}}')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api-docs', app, document);

  await app.listen(3000);
}
bootstrap();
```

---

## Step 3: Document Endpoints

### Express with JSDoc Comments

```javascript
/**
 * @swagger
 * /api/users:
 *   get:
 *     summary: Get all users
 *     description: Retrieve a list of all users in the system
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Number of items per page
 *     responses:
 *       200:
 *         description: List of users
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 users:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/User'
 *                 total:
 *                   type: integer
 *                 page:
 *                   type: integer
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */
router.get('/api/users', async (req, res) => {
  // Implementation
});

/**
 * @swagger
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       required:
 *         - id
 *         - email
 *         - name
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *           description: User ID
 *         email:
 *           type: string
 *           format: email
 *           description: User email address
 *         name:
 *           type: string
 *           description: User full name
 *         role:
 *           type: string
 *           enum: [admin, user]
 *           description: User role
 *         createdAt:
 *           type: string
 *           format: date-time
 *           description: Creation timestamp
 *       example:
 *         id: "123e4567-e89b-12d3-a456-426614174000"
 *         email: "user@example.com"
 *         name: "John Doe"
 *         role: "user"
 *         createdAt: "2024-01-15T10:30:00Z"
 */
```

### FastAPI with Pydantic Models

```python
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

class User(BaseModel):
    id: str
    email: EmailStr
    name: str
    role: str = "user"
    created_at: datetime

    class Config:
        json_schema_extra = {
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "user@example.com",
                "name": "John Doe",
                "role": "user",
                "created_at": "2024-01-15T10:30:00Z"
            }
        }

class UserListResponse(BaseModel):
    users: List[User]
    total: int
    page: int

@router.get(
    "/api/users",
    response_model=UserListResponse,
    summary="Get all users",
    description="Retrieve a list of all users in the system",
    tags=["Users"],
    responses={
        200: {
            "description": "List of users",
            "content": {
                "application/json": {
                    "example": {
                        "users": [
                            {
                                "id": "123e4567-e89b-12d3-a456-426614174000",
                                "email": "user@example.com",
                                "name": "John Doe",
                                "role": "user",
                                "created_at": "2024-01-15T10:30:00Z"
                            }
                        ],
                        "total": 1,
                        "page": 1
                    }
                }
            }
        },
        401: {"description": "Unauthorized"},
        500: {"description": "Server error"}
    }
)
async def get_users(
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(10, ge=1, le=100, description="Items per page"),
    current_user: User = Depends(get_current_user)
):
    # Implementation
    pass
```

### NestJS with Decorators

```typescript
import { ApiTags, ApiOperation, ApiResponse, ApiQuery } from '@nestjs/swagger';
import { Controller, Get, Query } from '@nestjs/common';

@ApiTags('Users')
@Controller('api/users')
export class UsersController {
  @Get()
  @ApiOperation({ summary: 'Get all users' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'List of users',
    type: [UserDto],
  })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async getUsers(
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 10,
  ) {
    // Implementation
  }
}
```

---

## Step 4: Generate Examples

Add request/response examples to all endpoints:

```javascript
/**
 * @swagger
 * /api/users:
 *   post:
 *     summary: Create new user
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateUserRequest'
 *           examples:
 *             example1:
 *               summary: Admin user
 *               value:
 *                 email: "admin@example.com"
 *                 name: "Admin User"
 *                 password: "SecurePass123!"
 *                 role: "admin"
 *             example2:
 *               summary: Regular user
 *               value:
 *                 email: "user@example.com"
 *                 name: "Regular User"
 *                 password: "MyPassword456!"
 *                 role: "user"
 */
```

---

## Step 5: Generate Postman Collection

### From OpenAPI Spec

```bash
# Install converter
npm install -g openapi-to-postmanv2

# Convert OpenAPI to Postman
openapi2postmanv2 -s http://localhost:{{backend.devServerPort}}/api-docs.json \
  -o postman-collection.json \
  -p

# Import postman-collection.json into Postman
```

### Manual Export

Add script to `package.json`:

```json
{
  "scripts": {
    "postman": "node scripts/generate-postman.js"
  }
}
```

Create `scripts/generate-postman.js`:

```javascript
const fs = require('fs');
const converter = require('openapi-to-postmanv2');

const openapiData = fs.readFileSync('./openapi.json', 'utf8');

converter.convert(
  { type: 'string', data: openapiData },
  {},
  (err, conversionResult) => {
    if (err) {
      console.error('Error converting:', err);
      return;
    }

    if (conversionResult.result) {
      const collection = conversionResult.output[0].data;
      fs.writeFileSync(
        'postman-collection.json',
        JSON.stringify(collection, null, 2)
      );
      console.log('Postman collection generated!');
    }
  }
);
```

---

## Step 6: Host Documentation

### Swagger UI (Already configured above)

Access at: `http://localhost:{{backend.devServerPort}}/api-docs`

### ReDoc (Alternative UI)

```bash
npm install redoc-express
```

```javascript
const { redoc } = require('redoc-express');

app.use('/redoc', redoc({
  title: '{{projectName}} API Docs',
  specUrl: '/api-docs.json',
  nonce: '',
  redocOptions: {
    theme: {
      colors: {
        primary: { main: '#6366f1' },
      },
    },
  },
}));
```

### Static HTML Export

```bash
# Generate static HTML from OpenAPI spec
npx redoc-cli bundle openapi.json -o docs/api.html

# Or with Swagger UI
npx swagger-ui-watcher openapi.json -o docs/swagger.html
```

### Deploy to GitHub Pages

```yaml
# .github/workflows/docs.yml
name: Deploy API Docs

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm run build:docs
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs
```

---

## Configuration Files

### openapi.json (Generated)

The OpenAPI specification file will be generated at:
- Express: `http://localhost:{{backend.devServerPort}}/api-docs.json`
- FastAPI: `http://localhost:{{backend.devServerPort}}/openapi.json`

### package.json Scripts

```json
{
  "scripts": {
    "docs": "open http://localhost:{{backend.devServerPort}}/api-docs",
    "docs:generate": "node scripts/generate-openapi.js",
    "docs:postman": "openapi2postmanv2 -s ./openapi.json -o postman.json",
    "docs:build": "redoc-cli bundle openapi.json -o docs/api.html"
  }
}
```

---

## Best Practices

### 1. Keep Docs in Sync

Use TypeScript interfaces or Pydantic models as single source of truth.

### 2. Add Examples

Every endpoint should have request/response examples.

### 3. Document Errors

Include all possible error responses with examples.

### 4. Authentication

Document authentication requirements clearly.

### 5. Rate Limiting

Document rate limits in endpoint descriptions.

### 6. Deprecation

Mark deprecated endpoints with `deprecated: true`.

```javascript
/**
 * @swagger
 * /api/old-endpoint:
 *   get:
 *     deprecated: true
 *     summary: Old endpoint (deprecated)
 *     description: Use /api/new-endpoint instead
 */
```

---

## Validation

Test your OpenAPI spec:

```bash
# Install validator
npm install -g @apidevtools/swagger-cli

# Validate spec
swagger-cli validate openapi.json
```

---

## Related Commands

- `/create-smoke-test` - Generate API tests
- `/security-scan` - Check API security
- `/monitoring-setup` - Add API monitoring

---

*API documentation powered by CCASP*
