# Test Guide Example

This is an example of a complete Test Guide created by the Oracle phase.

## Example: Simple Calculator API

### Level 1: Syntax (Does it run?)

- [ ] `npm run build` completes without errors
- [ ] `tsc --noEmit` passes with zero type errors
- [ ] `eslint src/` passes with zero warnings
- [ ] All TypeScript files have corresponding `.test.ts` files

### Level 2: I/O (Does it work?)

#### Core Functions

- [ ] `add(a, b)` returns the sum of two numbers
- [ ] `add(0, x)` returns `x` (identity)
- [ ] `add(-5, 3)` returns `-2` (handles negative numbers)
- [ ] `add(Number.MAX_SAFE_INTEGER, 1)` returns `Number.MAX_SAFE_INTEGER + 1` (handles large numbers)
- [ ] `divide(10, 2)` returns `5`
- [ ] `divide(10, 0)` throws `DivisionByZeroError`

#### API Endpoints

- [ ] `GET /api/health` returns `200` with `{ status: "ok" }`
- [ ] `POST /api/calculate` with `{ operation: "add", a: 5, b: 3 }` returns `200` with `{ result: 8 }`
- [ ] `POST /api/calculate` with invalid operation returns `400` with `{ error: "Invalid operation" }`
- [ ] `POST /api/calculate` with missing fields returns `400` with error details

### Level 3: Property (What invariants hold?)

- [ ] For all numbers a, b, c: `add(add(a, b), c) === add(a, add(b, c))` (associativity)
- [ ] For all numbers a, b: `add(a, b) === add(b, a)` (commutativity)
- [ ] For all numbers x: `add(x, 0) === x` (identity element)
- [ ] For all non-zero numbers a: `multiply(a, 1) === a` (identity for multiplication)
- [ ] For all numbers a, b: `divide(a, b) * b === a` (within floating-point precision)

### Level 4: Formal (What are the business rules?)

- [ ] Results are always finite numbers (never `NaN` or `Infinity` unless explicitly requested)
- [ ] Integer operations never lose precision (use BigInt when necessary)
- [ ] Division by zero always throws a specific error, never returns `NaN`
- [ ] All API responses include a `requestId` for tracing
- [ ] Rate limiting: max 100 requests per minute per IP

### Level 5: Semantic (Does it meet user intent?)

#### Gherkin Scenarios

- [ ] Scenario: Basic addition
  Given the calculator API is running
  When I send a POST request to `/api/calculate` with `{ "operation": "add", "a": 5, "b": 3 }`
  Then the response status is 200
  And the response body contains `{ "result": 8 }`

- [ ] Scenario: Division by zero
  Given the calculator API is running
  When I send a POST request to `/api/calculate` with `{ "operation": "divide", "a": 10, "b": 0 }`
  Then the response status is 400
  And the response body contains `{ "error": "Division by zero" }`

- [ ] Scenario: Invalid operation
  Given the calculator API is running
  When I send a POST request to `/api/calculate` with `{ "operation": "modulo", "a": 10, "b": 3 }`
  Then the response status is 400
  And the response body contains `{ "error": "Invalid operation: modulo" }`

#### Non-Functional Requirements

- [ ] Performance: 95th percentile response time < 50ms
- [ ] Security: All inputs are validated against numeric injection
- [ ] Security: API rate limiting is enforced per IP address
- [ ] Accessibility: API documentation includes examples for all operations
- [ ] Observability: All requests are logged with operation, inputs, and result

## How This Test Guide Is Used

During task iterations, the Test Guide provides context about what "correct" means:

1. When implementing the `add` function, Claude sees the I/O criteria and property tests
2. When implementing the `/api/calculate` endpoint, Claude sees the expected API contract
3. When writing tests, Claude sees that property-based tests are required
4. When reviewing code, Claude verifies that business rules (like no NaN results) are enforced
