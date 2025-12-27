# Stripe API Configuration Guide

## Overview

This guide covers the setup and configuration of Stripe API keys for the Admin Center payment gateway integration.

## Stripe Account Setup

### 1. Create Stripe Account

1. Go to https://stripe.com
2. Sign up for a new account or log in
3. Complete account verification
4. Enable payment methods (credit cards, etc.)

### 2. Get API Keys

Stripe provides two sets of API keys:

- **Test Mode Keys**: For development and staging
- **Live Mode Keys**: For production

## Test Mode Configuration (Staging/Development)

### 1. Get Test API Keys

1. Log in to Stripe Dashboard
2. Click "Developers" in the left sidebar
3. Click "API keys"
4. Toggle to "Test mode" (top right)
5. Copy the following keys:
   - **Publishable key**: `pk_test_...`
   - **Secret key**: `sk_test_...` (click "Reveal test key")

### 2. Configure Test Keys in Kubernetes

Edit `k8s/secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudtolocalllm-secrets
  namespace: cloudtolocalllm-staging
type: Opaque
stringData:
  # Stripe Test Keys
  stripe-test-secret-key: "sk_test_YOUR_SECRET_KEY_HERE"
  stripe-test-publishable-key: "pk_test_YOUR_PUBLISHABLE_KEY_HERE"
  stripe-test-webhook-secret: "whsec_YOUR_WEBHOOK_SECRET_HERE"
```

### 3. Apply Secrets

```bash
kubectl apply -f k8s/secrets.yaml -n cloudtolocalllm-staging
```

### 4. Test Stripe Integration

Use Stripe test cards to verify integration:

**Successful Payment:**
```
Card Number: 4242 4242 4242 4242
Expiry: Any future date
CVC: Any 3 digits
ZIP: Any 5 digits
```

**Declined Payment:**
```
Card Number: 4000 0000 0000 0002
Expiry: Any future date
CVC: Any 3 digits
```

**Requires Authentication (3D Secure):**
```
Card Number: 4000 0025 0000 3155
Expiry: Any future date
CVC: Any 3 digits
```

More test cards: https://stripe.com/docs/testing

## Production Mode Configuration

### 1. Activate Stripe Account

Before using live keys, you must activate your Stripe account:

1. Go to Stripe Dashboard
2. Click "Activate your account" banner
3. Complete business information
4. Provide bank account details
5. Verify identity (may require documents)
6. Wait for approval (usually 1-2 business days)

### 2. Get Live API Keys

1. Log in to Stripe Dashboard
2. Click "Developers" in the left sidebar
3. Click "API keys"
4. Toggle to "Live mode" (top right)
5. Copy the following keys:
   - **Publishable key**: `pk_live_...`
   - **Secret key**: `sk_live_...` (click "Reveal live key")

**IMPORTANT:** Treat live keys as highly sensitive credentials!

### 3. Configure Live Keys in Kubernetes

Edit `k8s/secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudtolocalllm-secrets
  namespace: cloudtolocalllm
type: Opaque
stringData:
  # Stripe Live Keys
  stripe-live-secret-key: "sk_live_YOUR_SECRET_KEY_HERE"
  stripe-live-publishable-key: "pk_live_YOUR_PUBLISHABLE_KEY_HERE"
  stripe-live-webhook-secret: "whsec_YOUR_WEBHOOK_SECRET_HERE"
```

### 4. Apply Secrets

```bash
kubectl apply -f k8s/secrets.yaml -n cloudtolocalllm
```

### 5. Verify Production Deployment

```bash
# Check that production uses live keys
kubectl get deployment api-backend -n cloudtolocalllm -o yaml | grep STRIPE

# Should show:
# - name: STRIPE_SECRET_KEY
#   valueFrom:
#     secretKeyRef:
#       key: stripe-live-secret-key
```

## Webhook Configuration

Webhooks allow Stripe to notify your application about payment events.

### 1. Create Webhook Endpoint (Test Mode)

1. Go to Stripe Dashboard > Developers > Webhooks
2. Toggle to "Test mode"
3. Click "Add endpoint"
4. Enter URL: `https://api-staging.cloudtolocalllm.online/api/webhooks/stripe`
5. Select events to listen for:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `charge.refunded`
   - `charge.dispute.created`
6. Click "Add endpoint"
7. Copy the "Signing secret" (starts with `whsec_`)

### 2. Create Webhook Endpoint (Live Mode)

1. Go to Stripe Dashboard > Developers > Webhooks
2. Toggle to "Live mode"
3. Click "Add endpoint"
4. Enter URL: `https://api.cloudtolocalllm.online/api/webhooks/stripe`
5. Select the same events as test mode
6. Click "Add endpoint"
7. Copy the "Signing secret" (starts with `whsec_`)

### 3. Configure Webhook Secrets

Update `k8s/secrets.yaml` with webhook signing secrets:

```yaml
stringData:
  # Test webhook secret
  stripe-test-webhook-secret: "whsec_YOUR_TEST_WEBHOOK_SECRET"
  
  # Live webhook secret
  stripe-live-webhook-secret: "whsec_YOUR_LIVE_WEBHOOK_SECRET"
```

### 4. Test Webhook Locally

Use Stripe CLI to test webhooks:

```bash
# Install Stripe CLI
# Windows: scoop install stripe
# Mac: brew install stripe/stripe-cli/stripe
# Linux: Download from https://github.com/stripe/stripe-cli/releases

# Login to Stripe
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger customer.subscription.created
```

## Subscription Products and Prices

### 1. Create Products

Create subscription products in Stripe Dashboard:

1. Go to Products > Add product
2. Create three products:

**Free Tier:**
- Name: "CloudToLocalLLM Free"
- Description: "Basic features with limited usage"
- Price: $0/month
- Billing period: Monthly

**Premium Tier:**
- Name: "CloudToLocalLLM Premium"
- Description: "Advanced features with increased limits"
- Price: $9.99/month
- Billing period: Monthly

**Enterprise Tier:**
- Name: "CloudToLocalLLM Enterprise"
- Description: "Full features with unlimited usage"
- Price: $29.99/month
- Billing period: Monthly

### 2. Get Price IDs

After creating products, copy the Price IDs:

1. Go to Products
2. Click on each product
3. Copy the Price ID (starts with `price_`)

### 3. Configure Price IDs

Add price IDs to `k8s/configmap.yaml`:

```yaml
data:
  # Stripe Price IDs
  STRIPE_PRICE_FREE: "price_FREE_TIER_ID"
  STRIPE_PRICE_PREMIUM: "price_PREMIUM_TIER_ID"
  STRIPE_PRICE_ENTERPRISE: "price_ENTERPRISE_TIER_ID"
```

## Environment Variables

The API backend uses these environment variables for Stripe:

| Variable | Description | Example |
|----------|-------------|---------|
| `STRIPE_SECRET_KEY` | Stripe secret API key | `sk_test_...` or `sk_live_...` |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key | `pk_test_...` or `pk_live_...` |
| `STRIPE_WEBHOOK_SECRET` | Webhook signing secret | `whsec_...` |
| `STRIPE_PRICE_FREE` | Free tier price ID | `price_...` |
| `STRIPE_PRICE_PREMIUM` | Premium tier price ID | `price_...` |
| `STRIPE_PRICE_ENTERPRISE` | Enterprise tier price ID | `price_...` |

## Security Best Practices

### 1. Key Management

- **Never commit API keys to version control**
- Store keys in Kubernetes secrets
- Use separate keys for test and production
- Rotate keys every 90 days
- Restrict key permissions (use restricted keys if possible)

### 2. Webhook Security

- Always verify webhook signatures
- Use HTTPS for webhook endpoints
- Implement idempotency for webhook handlers
- Log all webhook events
- Monitor for suspicious webhook activity

### 3. PCI Compliance

- Never store full credit card numbers
- Use Stripe Elements for card input
- Implement 3D Secure (SCA) for European customers
- Follow PCI DSS guidelines
- Regular security audits

### 4. Access Control

- Limit who has access to Stripe Dashboard
- Enable two-factor authentication
- Use team roles (restrict access to live keys)
- Audit Stripe Dashboard access logs
- Revoke access for former team members

## Testing Checklist

Before going live, test the following:

### Payment Processing

- [ ] Successful payment with test card
- [ ] Declined payment with test card
- [ ] 3D Secure authentication flow
- [ ] Payment with different currencies
- [ ] Payment error handling

### Subscriptions

- [ ] Create subscription
- [ ] Upgrade subscription
- [ ] Downgrade subscription
- [ ] Cancel subscription (immediate)
- [ ] Cancel subscription (end of period)
- [ ] Subscription renewal
- [ ] Failed subscription payment

### Refunds

- [ ] Full refund
- [ ] Partial refund
- [ ] Refund declined payment
- [ ] Refund with reason

### Webhooks

- [ ] Payment success webhook
- [ ] Payment failure webhook
- [ ] Subscription created webhook
- [ ] Subscription updated webhook
- [ ] Subscription deleted webhook
- [ ] Refund webhook
- [ ] Dispute webhook

## Monitoring and Alerts

### Stripe Dashboard

Monitor these metrics in Stripe Dashboard:

- **Payments**: Success rate, failure rate, average transaction value
- **Subscriptions**: MRR, churn rate, new subscriptions
- **Disputes**: Dispute rate, dispute resolution time
- **Refunds**: Refund rate, refund amount

### Application Monitoring

Set up alerts for:

- High payment failure rate (> 10%)
- Webhook processing failures
- API errors from Stripe
- Unusual refund activity
- Subscription cancellation spikes

### Grafana Dashboards

Create dashboards for:

- Payment gateway metrics
- Subscription metrics
- Refund metrics
- Webhook processing metrics

## Troubleshooting

### Common Issues

**Issue: "Invalid API Key"**
- Verify API key is correct
- Check if using test key in production (or vice versa)
- Ensure key has not been revoked

**Issue: "Webhook signature verification failed"**
- Verify webhook secret is correct
- Check if using test secret in production
- Ensure webhook endpoint is HTTPS

**Issue: "Payment requires authentication"**
- Implement 3D Secure (SCA)
- Use Stripe Elements with built-in authentication
- Handle `requires_action` status

**Issue: "Customer not found"**
- Verify customer ID is correct
- Check if customer was deleted
- Ensure using correct Stripe account (test vs live)

### Debug Mode

Enable debug logging for Stripe:

```javascript
// In stripe-client.js
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2023-10-16',
  maxNetworkRetries: 3,
  timeout: 30000,
  telemetry: false,
  // Enable debug logging
  typescript: true,
});

// Log all Stripe API calls
stripe.on('request', (request) => {
  console.log('Stripe API Request:', {
    method: request.method,
    path: request.path,
  });
});

stripe.on('response', (response) => {
  console.log('Stripe API Response:', {
    status: response.status_code,
    request_id: response.request_id,
  });
});
```

## Support

### Stripe Support

- Documentation: https://stripe.com/docs
- Support: https://support.stripe.com
- Status: https://status.stripe.com

### CloudToLocalLLM Support

- Email: cmaltais@cloudtolocalllm.online
- Documentation: `docs/API/ADMIN_API.md`
- Logs: `kubectl logs deployment/api-backend -n cloudtolocalllm`

## References

- [Stripe API Documentation](https://stripe.com/docs/api)
- [Stripe Testing Guide](https://stripe.com/docs/testing)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)
- [Stripe Security Best Practices](https://stripe.com/docs/security)
- [PCI Compliance Guide](https://stripe.com/docs/security/guide)
