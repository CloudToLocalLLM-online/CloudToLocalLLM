# Stripe Webhook Implementation Summary

## Overview

The Stripe webhook handler processes payment and subscription events from Stripe, ensuring database synchronization and implementing idempotency to prevent duplicate processing.

## Implementation Details

### Webhook Endpoint

**Route:** `POST /api/webhooks/stripe`

**Authentication:** Webhook signature verification (no JWT required)

**Features:**
- Signature verification using Stripe webhook secret
- Idempotency tracking to prevent duplicate processing
- Event logging for audit trail
- Comprehensive error handling

### Event Handlers

#### 1. Payment Intent Succeeded (`payment_intent.succeeded`)

**Purpose:** Update payment transaction status when payment succeeds

**Actions:**
- Updates `payment_transactions` table status to 'succeeded'
- Records Stripe charge ID and receipt URL
- Logs successful payment processing

**Database Updates:**
```sql
UPDATE payment_transactions
SET status = 'succeeded',
    stripe_charge_id = $1,
    receipt_url = $2,
    updated_at = NOW()
WHERE stripe_payment_intent_id = $3
```

#### 2. Payment Intent Failed (`payment_intent.failed`)

**Purpose:** Update payment transaction status when payment fails

**Actions:**
- Updates `payment_transactions` table status to 'failed'
- Records failure code and message
- Logs payment failure details

**Database Updates:**
```sql
UPDATE payment_transactions
SET status = 'failed',
    failure_code = $1,
    failure_message = $2,
    updated_at = NOW()
WHERE stripe_payment_intent_id = $3
```

#### 3. Subscription Created (`customer.subscription.created`)

**Purpose:** Initialize subscription data when created in Stripe

**Actions:**
- Updates subscription with Stripe-provided data
- Sets billing period dates
- Records trial period if applicable
- Logs subscription creation

**Database Updates:**
```sql
UPDATE subscriptions
SET status = $1,
    current_period_start = to_timestamp($2),
    current_period_end = to_timestamp($3),
    trial_start = $4,
    trial_end = $5,
    updated_at = NOW()
WHERE id = $6
```

#### 4. Subscription Updated (`customer.subscription.updated`)

**Purpose:** Sync subscription changes from Stripe

**Actions:**
- Updates subscription status and billing periods
- Records cancellation information
- Updates trial period data
- Logs subscription changes

**Database Updates:**
```sql
UPDATE subscriptions
SET status = $1,
    current_period_start = to_timestamp($2),
    current_period_end = to_timestamp($3),
    cancel_at_period_end = $4,
    canceled_at = $5,
    trial_start = $6,
    trial_end = $7,
    updated_at = NOW()
WHERE stripe_subscription_id = $8
```

#### 5. Subscription Deleted (`customer.subscription.deleted`)

**Purpose:** Mark subscription as canceled when deleted in Stripe

**Actions:**
- Updates subscription status to 'canceled'
- Records cancellation timestamp
- Logs subscription deletion

**Database Updates:**
```sql
UPDATE subscriptions
SET status = 'canceled',
    canceled_at = NOW(),
    updated_at = NOW()
WHERE stripe_subscription_id = $1
```

## Idempotency Implementation

### Webhook Events Table

**Purpose:** Track processed webhook events to prevent duplicate processing

**Schema:**
```sql
CREATE TABLE webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stripe_event_id TEXT UNIQUE NOT NULL,
  event_type TEXT NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  event_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Indexes:**
- `idx_webhook_events_stripe_event_id` - Fast lookup by Stripe event ID
- `idx_webhook_events_event_type` - Filter by event type
- `idx_webhook_events_processed_at` - Sort by processing time

### Idempotency Flow

1. Receive webhook event from Stripe
2. Verify webhook signature
3. Check if event ID already exists in `webhook_events` table
4. If exists, return success without processing
5. If new, insert event record and process event
6. Return success response

## Security Features

### Signature Verification

**Purpose:** Ensure webhook requests are from Stripe

**Implementation:**
```javascript
const stripe = stripeClient.getClient();
event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
```

**Configuration:**
- Webhook secret stored in `STRIPE_WEBHOOK_SECRET` environment variable
- Signature passed in `stripe-signature` header
- Raw body required for verification (mounted before body parsing middleware)

### Error Handling

**Signature Verification Failure:**
- Returns 400 Bad Request
- Logs verification failure
- Does not process event

**Processing Errors:**
- Returns 500 Internal Server Error
- Logs error details with stack trace
- Event marked as failed (can be retried by Stripe)

**Missing Configuration:**
- Returns 500 Internal Server Error
- Logs configuration error
- Prevents webhook processing

## Configuration

### Environment Variables

**Required:**
- `STRIPE_WEBHOOK_SECRET` - Webhook signing secret from Stripe dashboard
- `DATABASE_URL` - PostgreSQL connection string

**Optional:**
- `NODE_ENV` - Environment (production/development)
- `LOG_LEVEL` - Logging level (default: info)

### Stripe Dashboard Setup

1. Navigate to Stripe Dashboard > Developers > Webhooks
2. Click "Add endpoint"
3. Enter webhook URL: `https://api.cloudtolocalllm.online/api/webhooks/stripe`
4. Select events to listen for:
   - `payment_intent.succeeded`
   - `payment_intent.failed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Copy webhook signing secret to `STRIPE_WEBHOOK_SECRET` environment variable

## Testing

### Test Mode

**Setup:**
1. Use Stripe test mode API keys
2. Configure test webhook endpoint
3. Use Stripe CLI for local testing

**Stripe CLI Testing:**
```bash
# Forward webhooks to local server
stripe listen --forward-to localhost:8080/api/webhooks/stripe

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.failed
stripe trigger customer.subscription.created
stripe trigger customer.subscription.updated
stripe trigger customer.subscription.deleted
```

### Manual Testing

**Using Stripe Dashboard:**
1. Navigate to Developers > Webhooks
2. Select webhook endpoint
3. Click "Send test webhook"
4. Choose event type
5. Verify processing in application logs

### Verification

**Check Logs:**
```bash
# View webhook processing logs
grep "Stripe webhook" /var/log/app.log

# Check for errors
grep "ERROR.*webhook" /var/log/app.log
```

**Check Database:**
```sql
-- View processed webhook events
SELECT * FROM webhook_events ORDER BY processed_at DESC LIMIT 10;

-- Check payment transaction updates
SELECT id, status, stripe_payment_intent_id, updated_at
FROM payment_transactions
WHERE updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;

-- Check subscription updates
SELECT id, status, stripe_subscription_id, updated_at
FROM subscriptions
WHERE updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;
```

## Monitoring

### Key Metrics

**Webhook Processing:**
- Total webhooks received
- Webhooks processed successfully
- Webhooks failed
- Processing time per event type
- Duplicate events detected

**Event Types:**
- Payment success rate
- Payment failure rate
- Subscription creation rate
- Subscription cancellation rate

### Logging

**Info Level:**
- Webhook received
- Event processed successfully
- Idempotent event detected

**Warning Level:**
- Payment transaction not found
- Subscription not found
- Unhandled event type

**Error Level:**
- Signature verification failed
- Processing error
- Database error
- Configuration error

### Alerts

**Critical:**
- Webhook signature verification failures > 5 per minute
- Processing errors > 10% of events
- Database connection failures

**Warning:**
- Processing time > 5 seconds
- Duplicate events > 5% of total
- Unhandled event types

## Troubleshooting

### Common Issues

**1. Signature Verification Fails**

**Symptoms:**
- 400 Bad Request responses
- "Webhook signature verification failed" in logs

**Solutions:**
- Verify `STRIPE_WEBHOOK_SECRET` is correct
- Ensure webhook endpoint receives raw body (mounted before body parsing)
- Check Stripe dashboard for correct webhook URL
- Verify webhook secret matches endpoint

**2. Events Not Processing**

**Symptoms:**
- Webhooks received but database not updated
- No error logs

**Solutions:**
- Check database connection
- Verify payment transactions exist before webhook
- Check subscription records exist
- Review event handler logic

**3. Duplicate Processing**

**Symptoms:**
- Same event processed multiple times
- Duplicate database updates

**Solutions:**
- Verify `webhook_events` table exists
- Check idempotency logic
- Review database transaction handling
- Ensure unique constraint on `stripe_event_id`

**4. Missing Events**

**Symptoms:**
- Expected webhooks not received
- Database out of sync with Stripe

**Solutions:**
- Verify webhook endpoint is accessible from internet
- Check Stripe dashboard for webhook delivery status
- Review webhook event selection in Stripe
- Check firewall/security group rules

## Best Practices

### Development

1. **Use Stripe CLI for local testing**
   - Forward webhooks to localhost
   - Trigger test events
   - Verify processing

2. **Test idempotency**
   - Send same event multiple times
   - Verify only processed once
   - Check database state

3. **Test error scenarios**
   - Invalid signatures
   - Missing database records
   - Network failures

### Production

1. **Monitor webhook delivery**
   - Check Stripe dashboard regularly
   - Set up alerts for failures
   - Review processing logs

2. **Handle retries gracefully**
   - Stripe retries failed webhooks
   - Ensure idempotency works correctly
   - Log retry attempts

3. **Keep webhook secret secure**
   - Store in environment variables
   - Rotate periodically
   - Never commit to version control

4. **Maintain database consistency**
   - Use transactions for updates
   - Handle race conditions
   - Verify data integrity

## Related Documentation

- [Stripe Webhook Documentation](https://stripe.com/docs/webhooks)
- [Admin API Documentation](../../docs/API/ADMIN_API.md)
- [Payment Service](../services/README.md)
- [Subscription Service](../services/README.md)

## Migration

### Database Migration

**File:** `database/migrations/002_webhook_events_table.sql`

**Run Migration:**
```bash
# Using migration script
node database/migrations/run-migration.js 002_webhook_events_table.sql

# Or manually
psql $DATABASE_URL -f database/migrations/002_webhook_events_table.sql
```

**Verify Migration:**
```sql
-- Check table exists
\dt webhook_events

-- Check indexes
\di webhook_events*

-- Check constraints
\d webhook_events
```

## Deployment Checklist

- [ ] Database migration applied
- [ ] `STRIPE_WEBHOOK_SECRET` environment variable set
- [ ] Webhook endpoint configured in Stripe dashboard
- [ ] Webhook events selected in Stripe
- [ ] Test webhook sent and processed successfully
- [ ] Monitoring and alerts configured
- [ ] Documentation updated
- [ ] Team notified of new webhook endpoint

## Support

For issues or questions:
1. Check application logs for errors
2. Review Stripe dashboard webhook delivery logs
3. Verify database state
4. Contact development team with:
   - Webhook event ID
   - Timestamp
   - Error logs
   - Database state
