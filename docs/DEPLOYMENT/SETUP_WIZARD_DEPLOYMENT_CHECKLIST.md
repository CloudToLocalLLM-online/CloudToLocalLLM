# Setup Wizard Deployment Checklist

## Pre-Deployment Preparation

### Code Review and Testing
- [ ] **Code Review Complete**
  - [ ] All setup wizard components reviewed
  - [ ] Security review completed
  - [ ] Performance review completed
  - [ ] Accessibility review completed

- [ ] **Unit Tests Passing**
  - [ ] All service layer tests pass
  - [ ] All widget tests pass
  - [ ] All model tests pass
  - [ ] Code coverage >= 80%

- [ ] **Integration Tests Passing**
  - [ ] Complete wizard flow tests pass
  - [ ] API integration tests pass
  - [ ] Database integration tests pass
  - [ ] Cross-platform compatibility tests pass

- [ ] **End-to-End Tests Passing**
  - [ ] Full setup wizard flow (Chrome)
  - [ ] Full setup wizard flow (Firefox)
  - [ ] Full setup wizard flow (Safari)
  - [ ] Full setup wizard flow (Edge)
  - [ ] Mobile responsiveness tests

### Documentation
- [ ] **User Documentation**
  - [ ] First-time setup guide complete
  - [ ] Troubleshooting guide complete
  - [ ] FAQ updated
  - [ ] Screenshots/videos updated

- [ ] **Developer Documentation**
  - [ ] API documentation updated
  - [ ] Architecture documentation updated
  - [ ] Deployment guide updated
  - [ ] Troubleshooting guide for developers

### Infrastructure Preparation
- [ ] **Database Changes**
  - [ ] Migration scripts tested
  - [ ] Backup procedures verified
  - [ ] Rollback procedures tested
  - [ ] Performance impact assessed

- [ ] **API Backend Updates**
  - [ ] Container management endpoints ready
  - [ ] Setup status endpoints ready
  - [ ] Download management endpoints ready
  - [ ] Validation endpoints ready

- [ ] **Frontend Build**
  - [ ] Flutter web build successful
  - [ ] Assets properly included
  - [ ] Environment variables configured
  - [ ] Feature flags configured

## Deployment Configuration

### Feature Flags
- [ ] **Setup Wizard Feature Flags**
  ```json
  {
    "setupWizardEnabled": true,
    "setupWizardRolloutPercentage": 10,
    "containerCreationEnabled": true,
    "platformDetectionEnabled": true,
    "downloadTrackingEnabled": true,
    "validationTestsEnabled": true,
    "setupAnalyticsEnabled": true,
    "setupSkipOptionsEnabled": true
  }
  ```

- [ ] **Gradual Rollout Configuration**
  - [ ] Start with 10% of new users
  - [ ] Monitor for 24 hours
  - [ ] Increase to 25% if stable
  - [ ] Monitor for 24 hours
  - [ ] Increase to 50% if stable
  - [ ] Monitor for 24 hours
  - [ ] Full rollout (100%) if stable

### Environment Variables
- [ ] **Production Environment**
  ```bash
  SETUP_WIZARD_ENABLED=true
  SETUP_WIZARD_ROLLOUT_PERCENTAGE=10
  CONTAINER_API_URL=https://cloudtolocalllm.online/api
  DOWNLOAD_BASE_URL=https://github.com/CloudToLocalLLM/releases
  SETUP_API_TIMEOUT=120
  ENABLE_SETUP_ANALYTICS=true
  ```

- [ ] **Staging Environment**
  ```bash
  SETUP_WIZARD_ENABLED=true
  SETUP_WIZARD_ROLLOUT_PERCENTAGE=100
  CONTAINER_API_URL=https://staging.cloudtolocalllm.online/api
  DOWNLOAD_BASE_URL=https://github.com/CloudToLocalLLM/releases
  SETUP_API_TIMEOUT=60
  ENABLE_SETUP_ANALYTICS=false
  ```

### Database Migrations
- [ ] **Setup Status Tables**
  ```sql
  -- Verify tables exist
  SHOW TABLES LIKE 'user_setup_status';
  SHOW TABLES LIKE 'user_setup_progress';
  SHOW TABLES LIKE 'setup_analytics';
  
  -- Verify indexes
  SHOW INDEX FROM user_setup_status;
  SHOW INDEX FROM setup_analytics;
  ```

- [ ] **Migration Verification**
  - [ ] Tables created successfully
  - [ ] Indexes created successfully
  - [ ] Foreign key constraints working
  - [ ] Default values correct

## Deployment Process

### Pre-Deployment Checks
- [ ] **System Health**
  - [ ] All services running normally
  - [ ] Database performance normal
  - [ ] No ongoing incidents
  - [ ] Monitoring systems operational

- [ ] **Backup Verification**
  - [ ] Database backup completed
  - [ ] Application backup completed
  - [ ] Configuration backup completed
  - [ ] Rollback plan verified

### Deployment Steps
- [ ] **Stage 1: Database Migration**
  ```bash
  # Run on production database
  mysql -u root -p cloudtolocalllm < migrations/setup_wizard_tables.sql
  
  # Verify migration
  mysql -u root -p cloudtolocalllm -e "SHOW TABLES LIKE '%setup%';"
  ```

- [ ] **Stage 2: API Backend Deployment**
  ```bash
  # Deploy API backend with new endpoints
  cd /opt/cloudtolocalllm
  git pull origin main
  docker-compose build api-backend
  docker-compose up -d api-backend
  
  # Verify API health
  curl -f https://cloudtolocalllm.online/api/health
  ```

- [ ] **Stage 3: Frontend Deployment**
  ```bash
  # Deploy Flutter web app
  ./scripts/deploy/complete_deployment.sh
  
  # Verify deployment
  ./scripts/deploy/verify_deployment.sh
  ```

- [ ] **Stage 4: Feature Flag Activation**
  ```bash
  # Update feature flags (start with 10%)
  curl -X POST https://cloudtolocalllm.online/api/admin/feature-flags \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"setupWizardRolloutPercentage": 10}'
  ```

### Post-Deployment Verification
- [ ] **Functional Testing**
  - [ ] Setup wizard appears for new test user
  - [ ] Container creation works
  - [ ] Platform detection works
  - [ ] Download links functional
  - [ ] Validation tests pass
  - [ ] Setup completion works

- [ ] **Performance Testing**
  - [ ] Page load times acceptable
  - [ ] Container creation time < 2 minutes
  - [ ] API response times normal
  - [ ] Database query performance normal

- [ ] **Error Monitoring**
  - [ ] No new error spikes
  - [ ] Setup-related errors < 5%
  - [ ] Container creation success rate > 95%
  - [ ] Download success rate > 98%

## Monitoring and Alerting

### Key Metrics to Monitor
- [ ] **Setup Wizard Metrics**
  - [ ] Setup completion rate
  - [ ] Step abandonment rates
  - [ ] Average setup time
  - [ ] Error rates by step

- [ ] **Container Creation Metrics**
  - [ ] Container creation success rate
  - [ ] Container creation time
  - [ ] Container health check success rate
  - [ ] Container cleanup success rate

- [ ] **Download Metrics**
  - [ ] Download success rate
  - [ ] Download speed/performance
  - [ ] Platform distribution
  - [ ] Alternative mirror usage

- [ ] **Validation Metrics**
  - [ ] Validation test success rates
  - [ ] Common validation failures
  - [ ] Validation test performance
  - [ ] User retry patterns

### Alerting Configuration
- [ ] **Critical Alerts**
  - [ ] Setup completion rate < 80%
  - [ ] Container creation failure rate > 10%
  - [ ] API error rate > 5%
  - [ ] Database connection failures

- [ ] **Warning Alerts**
  - [ ] Setup completion rate < 90%
  - [ ] Average setup time > 15 minutes
  - [ ] Download failure rate > 5%
  - [ ] Validation failure rate > 10%

### Dashboard Setup
- [ ] **Setup Wizard Dashboard**
  - [ ] Real-time setup metrics
  - [ ] Step-by-step funnel analysis
  - [ ] Error rate trends
  - [ ] Platform distribution

- [ ] **Performance Dashboard**
  - [ ] API response times
  - [ ] Container creation times
  - [ ] Database query performance
  - [ ] System resource usage

## Rollback Procedures

### Rollback Triggers
- [ ] **Automatic Rollback Conditions**
  - [ ] Setup completion rate < 50%
  - [ ] Container creation failure rate > 25%
  - [ ] Critical API errors > 10%
  - [ ] Database performance degradation

- [ ] **Manual Rollback Conditions**
  - [ ] User complaints > 10 per hour
  - [ ] Support ticket volume spike
  - [ ] Security vulnerability discovered
  - [ ] Data integrity issues

### Rollback Process
- [ ] **Stage 1: Disable Feature**
  ```bash
  # Immediately disable setup wizard
  curl -X POST https://cloudtolocalllm.online/api/admin/feature-flags \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"setupWizardEnabled": false}'
  ```

- [ ] **Stage 2: Revert Frontend**
  ```bash
  # Revert to previous version
  cd /opt/cloudtolocalllm
  git reset --hard HEAD~1
  ./scripts/deploy/complete_deployment.sh
  ```

- [ ] **Stage 3: Revert API Backend**
  ```bash
  # Revert API backend if needed
  docker-compose down api-backend
  git checkout HEAD~1 -- api-backend/
  docker-compose build api-backend
  docker-compose up -d api-backend
  ```

- [ ] **Stage 4: Database Cleanup**
  ```sql
  -- Clean up setup data if needed (be careful!)
  -- Only run if data integrity is compromised
  DELETE FROM user_setup_progress WHERE created_at > 'DEPLOYMENT_TIME';
  ```

### Post-Rollback Verification
- [ ] **System Health Check**
  - [ ] All services operational
  - [ ] No setup wizard visible
  - [ ] Original functionality intact
  - [ ] Performance back to normal

- [ ] **User Impact Assessment**
  - [ ] Count affected users
  - [ ] Reset setup status if needed
  - [ ] Communicate with affected users
  - [ ] Plan remediation steps

## Gradual Rollout Plan

### Phase 1: Limited Rollout (10%)
- [ ] **Duration**: 24 hours
- [ ] **Target**: 10% of new users
- [ ] **Success Criteria**:
  - [ ] Setup completion rate > 85%
  - [ ] Container creation success rate > 95%
  - [ ] No critical errors
  - [ ] User feedback positive

### Phase 2: Expanded Rollout (25%)
- [ ] **Duration**: 24 hours
- [ ] **Target**: 25% of new users
- [ ] **Success Criteria**:
  - [ ] Setup completion rate > 85%
  - [ ] Performance impact < 5%
  - [ ] Support ticket volume normal
  - [ ] No data integrity issues

### Phase 3: Majority Rollout (50%)
- [ ] **Duration**: 24 hours
- [ ] **Target**: 50% of new users
- [ ] **Success Criteria**:
  - [ ] Setup completion rate > 85%
  - [ ] System stability maintained
  - [ ] Resource usage within limits
  - [ ] User satisfaction maintained

### Phase 4: Full Rollout (100%)
- [ ] **Duration**: Ongoing
- [ ] **Target**: All new users
- [ ] **Success Criteria**:
  - [ ] Setup completion rate > 85%
  - [ ] All systems stable
  - [ ] User onboarding improved
  - [ ] Support burden reduced

## Post-Deployment Tasks

### Week 1: Intensive Monitoring
- [ ] **Daily Reviews**
  - [ ] Check all metrics dashboards
  - [ ] Review error logs
  - [ ] Analyze user feedback
  - [ ] Monitor support tickets

- [ ] **Performance Optimization**
  - [ ] Identify bottlenecks
  - [ ] Optimize slow queries
  - [ ] Improve error handling
  - [ ] Enhance user experience

### Week 2-4: Stabilization
- [ ] **Bug Fixes**
  - [ ] Address reported issues
  - [ ] Improve error messages
  - [ ] Enhance troubleshooting
  - [ ] Update documentation

- [ ] **Feature Refinement**
  - [ ] Improve platform detection
  - [ ] Enhance download experience
  - [ ] Optimize validation tests
  - [ ] Streamline user flow

### Month 2+: Long-term Monitoring
- [ ] **Analytics Review**
  - [ ] Analyze setup completion trends
  - [ ] Identify improvement opportunities
  - [ ] Plan feature enhancements
  - [ ] Update success metrics

- [ ] **Continuous Improvement**
  - [ ] A/B test improvements
  - [ ] Gather user feedback
  - [ ] Plan next iterations
  - [ ] Update documentation

## Success Criteria

### Primary Metrics
- [ ] **Setup Completion Rate**: > 85%
- [ ] **Container Creation Success**: > 95%
- [ ] **Download Success Rate**: > 98%
- [ ] **Validation Success Rate**: > 90%

### Secondary Metrics
- [ ] **Average Setup Time**: < 10 minutes
- [ ] **User Satisfaction**: > 4.0/5.0
- [ ] **Support Ticket Reduction**: > 20%
- [ ] **New User Activation**: > 80%

### Technical Metrics
- [ ] **API Response Time**: < 500ms
- [ ] **Container Creation Time**: < 2 minutes
- [ ] **Page Load Time**: < 3 seconds
- [ ] **Error Rate**: < 2%

## Communication Plan

### Internal Communication
- [ ] **Pre-Deployment**
  - [ ] Notify development team
  - [ ] Inform support team
  - [ ] Update operations team
  - [ ] Brief management

- [ ] **During Deployment**
  - [ ] Real-time status updates
  - [ ] Issue escalation procedures
  - [ ] Rollback decision process
  - [ ] Communication channels

- [ ] **Post-Deployment**
  - [ ] Success/failure summary
  - [ ] Lessons learned
  - [ ] Next steps planning
  - [ ] Documentation updates

### External Communication
- [ ] **User Communication**
  - [ ] Feature announcement
  - [ ] Help documentation
  - [ ] Support channel updates
  - [ ] Community notifications

- [ ] **Stakeholder Updates**
  - [ ] Progress reports
  - [ ] Success metrics
  - [ ] Issue summaries
  - [ ] Future roadmap

## Sign-off

### Technical Sign-off
- [ ] **Development Team Lead**: _________________ Date: _______
- [ ] **QA Team Lead**: _________________ Date: _______
- [ ] **DevOps Engineer**: _________________ Date: _______
- [ ] **Security Review**: _________________ Date: _______

### Business Sign-off
- [ ] **Product Manager**: _________________ Date: _______
- [ ] **Engineering Manager**: _________________ Date: _______
- [ ] **Operations Manager**: _________________ Date: _______

### Final Deployment Authorization
- [ ] **Deployment Manager**: _________________ Date: _______

---

**Deployment Date**: _________________
**Deployment Time**: _________________
**Deployed By**: _________________
**Rollback Deadline**: _________________

**Notes**:
_________________________________________________
_________________________________________________
_________________________________________________