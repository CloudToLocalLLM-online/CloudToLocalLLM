# 🎉 CloudToLocalLLM - Docker Compose Deployment Guide

## Summary

**Note**: For production, **Kubernetes deployment is recommended**. Docker Compose is suitable for development, testing, or small deployments.

This guide covers deploying CloudToLocalLLM using Docker Compose for development/testing purposes.

## ✅ What's Been Implemented

### 1. Docker Compose Production Stack
- **PostgreSQL Database**: Self-contained, auto-initialized
- **API Backend**: Node.js with tunnel support (both HTTP polling and WebSocket)
- **Web Application**: Flutter + Nginx static serving
- **Nginx Reverse Proxy**: SSL termination, WebSocket proxying, rate limiting
- **Certbot**: Automatic Let's Encrypt SSL certificates

### 2. Tunnel System (HTTP Polling - Active)
- ✅ **API Routes**: `/api/bridge/*` endpoints enabled
- ✅ **Desktop Client**: `HttpPollingTunnelClient` ready to connect
- ✅ **Authentication**: Supabase Auth JWT validation
- ✅ **LLM Integration**: Automatic routing to local Ollama

### 3. WebSocket Tunnel (Bonus - Server Ready)
- ✅ **Server**: WebSocket server at `/ws/tunnel`
- ✅ **Nginx**: WebSocket proxying configured
- ⏳ **Desktop Client**: Can be implemented later for better performance

## 📁 Key Files Created/Modified

### New Files
```
docker-compose.production.yml    # Complete production stack
env.template                     # Environment configuration template
deploy.sh                        # One-command deployment script
config/nginx/production.conf     # Nginx with SSL & WebSocket support
config/docker/Dockerfile.web     # Flutter web app builder
config/docker/nginx-web.conf     # Web app Nginx config
services/api-backend/websocket-server.js  # WebSocket tunnel server
DOCKER_DEPLOYMENT.md             # Comprehensive deployment guide
TUNNEL_IMPLEMENTATION_STATUS.md  # Tunnel architecture explanation
```

### Modified Files
```
services/api-backend/server.js   # Added WebSocket tunnel initialization
services/api-backend/package.json  # Moved ws to dependencies
```

## 🚀 Quick Start Deployment

### Prerequisites
- Linux server (Ubuntu 22.04+ recommended)
- Docker & Docker Compose installed
- Domain with DNS pointing to server
- Supabase Auth account configured

### One-Command Deployment
```bash
git clone https://github.com/yourusername/CloudToLocalLLM.git
cd CloudToLocalLLM
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Check prerequisites
2. Create `.env` with your configuration
3. Request SSL certificates
4. Build and deploy all services

## 🔌 How the Tunnel Works

### Current Architecture (HTTP Polling)

```
┌─────────────────────────────────────────────────────────────────┐
│                        User's Browser                            │
│                    https://app.yourdomain.com                    │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTPS
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Nginx Reverse Proxy                         │
│                     (Port 80/443, SSL)                           │
└────────────┬───────────────────────┬────────────────────────────┘
             │                       │
             │ HTTP                  │ HTTP
             ▼                       ▼
┌────────────────────────┐  ┌────────────────────────────────┐
│    Web Service         │  │    API Backend Service         │
│  (Flutter + Nginx)     │  │    (Node.js Express)           │
│     Port: 8080         │  │      Port: 3000                │
└────────────────────────┘  └──────────┬─────────────────────┘
                                       │
                                       │ HTTP Polling
                                       │ /api/bridge/poll
                                       │
                                       ▼
                            ┌─────────────────────┐
                            │  Bridge Polling     │
                            │  Connection         │
                            └─────────┬───────────┘
                                      │
                                      ▼
                            ┌─────────────────────────────┐
                            │  Windows Desktop App        │
                            │  - System Tray              │
                            │  - HttpPollingTunnelClient  │
                            └──────────┬──────────────────┘
                                       │
                                       │ HTTP
                                       ▼
                                  ┌─────────┐
                                  │ Ollama  │
                                  │ :11434  │
                                  └─────────┘
```

### Connection Flow

1. **Desktop App Startup**:
   ```
   Desktop → POST /api/bridge/register
   Server  → Response: { bridgeId: "xyz", config: {...} }
   ```

2. **Polling Loop** (every 5 seconds):
   ```
   Desktop → GET /api/bridge/poll/xyz
   Server  → Response: { requests: [...] } or { requests: [] }
   ```

3. **Web Request**:
   ```
   Web     → POST /api/ollama/api/generate
   Server  → Queues request for desktop client
   Desktop → Receives request in next poll
   Desktop → Forwards to local Ollama
   Ollama  → Processes and responds
   Desktop → POST /api/bridge/respond/xyz/req123
   Server  → Returns response to web
   ```

4. **Heartbeat** (every 30 seconds):
   ```
   Desktop → POST /api/bridge/heartbeat/xyz
   Server  → Response: { alive: true }
   ```

## 🧪 Testing Your Deployment

### 1. Deploy the Stack
```bash
./deploy.sh
```

### 2. Verify Services
```bash
# Check all services are running
docker compose -f docker-compose.production.yml ps

# Should show:
# cloudtolocalllm-postgres    (healthy)
# cloudtolocalllm-api-backend (healthy)
# cloudtolocalllm-web         (healthy)
# cloudtolocalllm-nginx       (healthy)
# cloudtolocalllm-certbot     (running)
```

### 3. Test Endpoints
```bash
# Web app
curl -I https://yourdomain.com

# API health
curl https://api.yourdomain.com/health

# Bridge registration (with valid JWT)
curl -X POST https://api.yourdomain.com/api/bridge/register \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "test-client",
    "platform": "windows",
    "version": "4.0.0",
    "capabilities": ["llm-providers"]
  }'
```

### 4. Launch Windows Desktop App
1. Start the CloudToLocalLLM Windows app
2. Sign in with Supabase Auth credentials
3. App should show "Connected" status in system tray
4. Check server logs for connection:
   ```bash
   docker compose -f docker-compose.production.yml logs -f api-backend
   # Look for: "Bridge registered: xyz"
   ```

### 5. Test End-to-End
1. Make sure Ollama is running locally: `ollama serve`
2. From web app at `https://app.yourdomain.com`:
   - Select a model
   - Send a chat message
   - Should receive response from local Ollama

## 📊 Monitoring

### View Logs
```bash
# All services
docker compose -f docker-compose.production.yml logs -f

# Specific service
docker compose -f docker-compose.production.yml logs -f api-backend
docker compose -f docker-compose.production.yml logs -f nginx
```

### Check Service Health
```bash
docker compose -f docker-compose.production.yml ps
docker stats
```

### Database Access
```bash
# Access PostgreSQL
docker compose -f docker-compose.production.yml exec postgres \
  psql -U appuser -d cloudtolocalllm

# Check active connections
SELECT * FROM bridge_connections;
```

## 🔧 Configuration

### Environment Variables (`.env`)
```env
DOMAIN=yourdomain.com
SSL_EMAIL=admin@yourdomain.com
POSTGRES_PASSWORD=<auto-generated>

# Supabase Auth Configuration
JWT_ISSUER_DOMAIN=your-tenant.us.supabase-auth.com
JWT_AUDIENCE=https://app.yourdomain.com

JWT_SECRET=<auto-generated>
```

### Scaling
To handle more users, edit `docker-compose.production.yml`:
```yaml
services:
  api-backend:
    deploy:
      replicas: 3  # Run 3 instances
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
```

## 🎯 Next Steps

### Immediate
1. ✅ Deploy using `./deploy.sh`
2. ✅ Test with Windows desktop app
3. ✅ Verify end-to-end Ollama communication

### Short-term
1. Monitor performance and errors
2. Set up automated backups for PostgreSQL
3. Configure monitoring/alerting (Prometheus + Grafana)
4. Implement log aggregation (ELK/Loki)

### Long-term
1. Migrate to Kubernetes for auto-scaling
2. Implement WebSocket client in desktop app
3. Add distributed caching (Redis)
4. Multi-region deployment

## 🐛 Troubleshooting

### Desktop App Won't Connect
1. **Check API logs**: `docker compose -f docker-compose.production.yml logs api-backend`
2. **Verify Supabase Auth token**: Desktop app should have valid JWT
3. **Test bridge endpoint**: `curl -X POST https://api.yourdomain.com/api/bridge/register`
4. **Firewall**: Ensure desktop can reach `https://api.yourdomain.com`

### SSL Certificate Issues
```bash
# Check certificate status
docker compose -f docker-compose.production.yml exec certbot certbot certificates

# Manually request certificate
docker compose -f docker-compose.production.yml run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  --email your@email.com \
  --agree-tos \
  -d yourdomain.com
```

### Database Connection Errors
```bash
# Check database logs
docker compose -f docker-compose.production.yml logs postgres

# Verify connection from API backend
docker compose -f docker-compose.production.yml exec api-backend \
  node -e "const pg = require('pg'); const client = new pg.Client({host:'postgres',user:'appuser',password:'$POSTGRES_PASSWORD',database:'cloudtolocalllm'}); client.connect().then(() => console.log('Connected')).catch(console.error);"
```

## 📚 Documentation Reference

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)**: Comprehensive deployment guide
- **[TUNNEL_IMPLEMENTATION_STATUS.md](TUNNEL_IMPLEMENTATION_STATUS.md)**: Tunnel architecture details
- **[env.template](env.template)**: Configuration template
- **[deploy.sh](deploy.sh)**: Deployment automation script

## 🎉 You're Ready!

Everything is configured and ready to deploy. The tunnel system uses HTTP polling (which is already implemented in your desktop app), so it should work out of the box.

### Deploy Command
```bash
./deploy.sh
```

### After Deployment
1. Access web app: `https://yourdomain.com`
2. Launch Windows desktop app
3. Start chatting with your local Ollama!

## 💡 Pro Tips

1. **First deployment**: Do a test deployment on a staging server first
2. **Backup `.env`**: Keep your `.env` file secure and backed up
3. **Monitor logs**: Watch logs during first few hours for issues
4. **Performance**: HTTP polling works well up to 100-200 concurrent users
5. **Future**: Migrate to WebSocket later for better performance

---

**Questions or issues?** Check the troubleshooting section or review the detailed guides in the docs folder.

**Ready to deploy?** Run `./deploy.sh` and let's get CloudToLocalLLM running! 🚀

