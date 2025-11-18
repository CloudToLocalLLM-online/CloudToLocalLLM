# Payment Gateway Services

This directory contains the payment gateway integration services for the Admin Center, built on top of Stripe.

## Services Overview

### 1. Stripe Client (`stripe-client.js`)

The Stripe client wrapper provides a configured Stripe instance with error handling and logging.

**Features:**

- Automatic initialization with environment-based API keys
- Test/production mode support
- Standardized error handling
- Comprehensive error mapping

**Usage:**

```javascript
import stripeClient from './services/stripe-client.js';

// Initialize (happens automatically on first use)
const stripe = stripeClient.getClient();

// Check if in test mode
const isTest = stripeClient.isTest();

// Handle Stripe errors
try {
  // Stripe operation
} catch (error) {
  const standardizedError = stripeClient.handleStripeError(error);
  // Use standardizedError for consistent error responses
}
```

### 2. Payment Service (`payment-service.js`)

Handles payment processing through Stripe, including creating payment intents and storing transactions.

**Features:**

- Process one-time payments
- Store transaction records in database
- Handle payment success and failure
- Retrieve transaction history

**Usage:**

```javascript
import PaymentService from './services/payment-service.js';

const paymentService = new PaymentService(db);

// Process a payment
const result = await paymentService.processPayment({
  userId: 'user-uuid',
  amount: 29.99,
  currency: 'USD',
  paymentMethodId: 'pm_xxx',
  subscriptionId: 'sub-uuid', // optional
  metadata: {
    /* custom data */
  },
});

if (result.success) {
  console.log('Payment succeeded:', result.transaction);
} else {
  console.error('Payment failed:', result.error);
}

// Get transaction details
const transaction = await paymentService.getTransaction('transaction-uuid');

// Get user transactions
const transactions = await paymentService.getUserTransactions('user-uuid', {
  limit: 50,
  offset: 0,
  status: 'succeeded',
});
```

### 3. Subscription Service (`subscription-service.js`)

Manages subscription lifecycle including creation, updates, cancellation, and webhook processing.

**Features:**

- Create subscriptions with Stripe
- Update subscription tiers
- Cancel subscriptions (immediate or at period end)
- Handle Stripe webhooks
- Manage customer records

**Usage:**

```javascript
import SubscriptionService from './services/subscription-service.js';

const subscriptionService = new SubscriptionService(db);

// Create a subscription
const result = await subscriptionService.createSubscription({
  userId: 'user-uuid',
  tier: 'premium',
  paymentMethodId: 'pm_xxx',
  priceId: 'price_xxx',
  metadata: {
    /* custom data */
  },
});

// Update a subscription
const updateResult = await subscriptionService.updateSubscription('sub-uuid', {
  tier: 'enterprise',
  priceId: 'price_yyy',
});

// Cancel a subscription
const cancelResult = await subscriptionService.cancelSubscription(
  'sub-uuid',
  false
); // false = at period end

// Handle webhook
await subscriptionService.handleWebhook(stripeEvent);
```

### 4. Refund Service (`refund-service.js`)

Processes refunds for transactions with audit logging.

**Features:**

- Full and partial refunds
- Refund reason tracking
- Audit logging of admin actions
- Transaction status updates

**Usage:**

```javascript
import RefundService from './services/refund-service.js';

const refundService = new RefundService(db);

// Process a refund
const result = await refundService.processRefund({
  transactionId: 'transaction-uuid',
  amount: 29.99, // null for full refund
  reason: 'customer_request',
  reasonDetails: 'Customer requested refund due to...',
  adminUserId: 'admin-uuid',
  adminRole: 'finance_admin',
  ipAddress: '192.168.1.1',
  userAgent: 'Mozilla/5.0...',
});

if (result.success) {
  console.log('Refund processed:', result.refund);
} else {
  console.error('Refund failed:', result.error);
}

// Get refund details
const refund = await refundService.getRefund('refund-uuid');

// Get transaction refunds
const refunds = await refundService.getTransactionRefunds('transaction-uuid');
```

## Environment Configuration

Create a `.env` file based on `.env.example`:

```bash
# Test mode keys (for development)
STRIPE_SECRET_KEY_TEST=sk_test_your_test_key_here
STRIPE_PUBLISHABLE_KEY_TEST=pk_test_your_test_key_here

# Production mode keys
STRIPE_SECRET_KEY_PROD=sk_live_your_production_key_here
STRIPE_PUBLISHABLE_KEY_PROD=pk_live_your_production_key_here

# Webhook secret
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Environment
NODE_ENV=development
```

## Database Schema

The services require the following database tables:

- `payment_transactions` - Stores payment transaction records
- `subscriptions` - Stores subscription records
- `refunds` - Stores refund records
- `admin_audit_logs` - Stores admin action logs

See `database/migrations/001_admin_center_schema.sql` for the complete schema.

## Error Handling

All services return standardized error responses:

```javascript
{
  code: 'ERROR_CODE',
  message: 'Human-readable error message',
  details: { /* additional error details */ },
  statusCode: 400
}
```

Common error codes:

- `CARD_DECLINED` - Card was declined
- `INVALID_REQUEST` - Invalid parameters
- `PAYMENT_GATEWAY_ERROR` - Stripe API error
- `GATEWAY_CONNECTION_ERROR` - Network error
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `REFUND_ERROR` - Refund processing error

## Testing

Use Stripe test mode for development and testing:

**Test Cards:**

- Success: `4242 4242 4242 4242`
- Declined: `4000 0000 0000 0002`
- Requires authentication: `4000 0025 0000 3155`

See [Stripe Testing Documentation](https://stripe.com/docs/testing) for more test cards.

## Webhook Setup

1. Create a webhook endpoint in Stripe Dashboard
2. Set the endpoint URL to: `https://your-domain.com/api/webhooks/stripe`
3. Select events to listen for:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copy the webhook signing secret to `STRIPE_WEBHOOK_SECRET`

## Security Considerations

- Never commit API keys to version control
- Use environment variables for all secrets
- Always verify webhook signatures
- Implement rate limiting on payment endpoints
- Log all payment operations for audit purposes
- Use HTTPS for all payment-related endpoints
- Follow PCI DSS compliance guidelines

## Monitoring

Monitor the following metrics:

- Payment success/failure rates
- Refund rates
- Subscription churn
- Stripe API response times
- Webhook processing times

Use Grafana dashboards for visualization and alerting.

## Support

For Stripe-related issues:

- [Stripe Documentation](https://stripe.com/docs)
- [Stripe Support](https://support.stripe.com/)
- [Stripe API Reference](https://stripe.com/docs/api)

For internal issues, contact the development team.
