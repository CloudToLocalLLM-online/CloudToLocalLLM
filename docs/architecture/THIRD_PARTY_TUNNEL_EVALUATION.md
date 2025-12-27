# Third-Party Tunnel Solution Evaluation

## Requirements Analysis

### Current Requirements
- **Protocol**: WebSocket-based HTTP reverse proxy
- **Client**: Flutter/Dart desktop application
- **Server**: Node.js API backend
- **Authentication**: JWT-based (Supabase Auth)
- **Traffic**: HTTP requests to local Ollama (localhost:11434)
- **Features Needed**:
  - Persistent connection
  - Automatic reconnection
  - Request/response correlation
  - User isolation
  - Rate limiting
  - Health monitoring

## Third-Party Options Evaluation

### Option 1: **frp (Fast Reverse Proxy)** ⭐ Recommended
- **Language**: Go
- **License**: Apache 2.0
- **GitHub**: fatedier/frp
- **Pros**:
  - Production-ready, battle-tested
  - Supports TCP, HTTP, WebSocket
  - Built-in authentication
  - Self-hosted solution
  - Excellent documentation
  - Active maintenance
- **Cons**:
  - Requires separate frp server deployment
  - Go server (separate from Node.js)
  - Need to integrate with existing JWT auth
- **Integration Complexity**: Medium
- **Fit**: Excellent - supports WebSocket tunneling natively

### Option 2: **bore** 
- **Language**: Rust
- **License**: MIT
- **GitHub**: ekzhang/bore
- **Pros**:
  - Simple, lightweight
  - Single binary deployment
  - Fast performance
- **Cons**:
  - Less feature-rich
  - Limited authentication options
  - Would need custom JWT integration
  - No built-in user management
- **Integration Complexity**: High (needs significant customization)
- **Fit**: Medium - too simple for requirements

### Option 3: **localtunnel**
- **Language**: Node.js
- **License**: MIT
- **GitHub**: localtunnel/localtunnel
- **Pros**:
  - Node.js (matches server stack)
  - Simple API
  - WebSocket support
- **Cons**:
  - Less maintained
  - Limited authentication options
  - Would need custom JWT integration
  - Public subdomain-based (can be self-hosted)
- **Integration Complexity**: Medium-High
- **Fit**: Medium - requires significant customization

### Option 4: **inlets**
- **Language**: Go
- **License**: MIT
- **GitHub**: inlets/inlets
- **Pros**:
  - Kubernetes-native
  - Modern architecture
  - Supports HTTP/HTTPS/WebSocket
- **Cons**:
  - Kubernetes-focused
  - More complex setup
  - Would need custom JWT integration
- **Integration Complexity**: High
- **Fit**: Low - overkill for requirements

### Option 5: **Cloudflare Tunnel (cloudflared)**
- **Language**: Go
- **License**: Apache 2.0
- **GitHub**: cloudflare/cloudflared
- **Pros**:
  - Production-grade
  - Excellent performance
  - Built-in DDoS protection
  - Free tier available
- **Cons**:
  - Requires Cloudflare account
  - Less control over infrastructure
  - Custom JWT integration needed
  - May have data routing concerns
- **Integration Complexity**: Medium
- **Fit**: Good - if Cloudflare dependency is acceptable

### Option 6: **Chisel**
- **Language**: Go
- **License**: MIT
- **GitHub**: jpillora/chisel
- **Pros**:
  - Fast TCP/UDP tunneling over HTTP
  - WebSocket-based transport
  - Single binary, easy deployment
  - Supports HTTP CONNECT method
  - Good for reverse tunneling
  - Self-hosted
- **Cons**:
  - Less feature-rich than frp
  - Basic authentication (token-based)
  - Would need custom JWT integration
  - Limited documentation compared to frp
- **Integration Complexity**: Medium
- **Fit**: Good - simpler than frp, WebSocket native

### Option 7: **sish (Secure Shell HTTP(S) Reverse Tunnel)**
- **Language**: Go
- **License**: MIT
- **GitHub**: antipatterns/sish
- **Pros**:
  - SSH-based but with HTTP/HTTPS support
  - Self-hosted ngrok alternative
  - Supports custom domains
  - Good security model
  - WebSocket support
- **Cons**:
  - SSH-based (adds complexity)
  - Less active development
  - Would need SSH client in Flutter app
  - JWT integration requires custom work
- **Integration Complexity**: High (SSH complexity)
- **Fit**: Medium - SSH adds unnecessary complexity

### Option 8: **Pagekite**
- **Language**: Python
- **License**: AGPL (paid versions available)
- **GitHub**: pagekite/PyPagekite
- **Pros**:
  - HTTP reverse proxy tunnel
  - Simple to use
  - WebSocket support
  - Good documentation
- **Cons**:
  - Python dependency
  - AGPL license (commercial use concerns)
  - Less maintained recently
  - Would need custom JWT integration
- **Integration Complexity**: Medium-High
- **Fit**: Medium - license concerns

### Option 9: **VSCode Remote Tunnel (vscode-tunnel)**
- **Language**: Node.js/TypeScript
- **License**: MIT
- **GitHub**: microsoft/vscode-remote-tunnel
- **Pros**:
  - Production-grade (Microsoft)
  - Node.js (matches server stack)
  - Designed for reverse tunneling
  - Good security model
  - WebSocket support
- **Cons**:
  - Designed specifically for VSCode Remote
  - May require significant customization
  - Authentication built for Microsoft accounts
  - Would need custom JWT integration
  - Less flexible than generic solutions
- **Integration Complexity**: High (needs customization)
- **Fit**: Medium - designed for different use case

### Option 10: **Traefik with Tunnel Plugin**
- **Language**: Go
- **License**: MIT
- **GitHub**: traefik/traefik
- **Pros**:
  - Production-grade reverse proxy
  - Extensive plugin ecosystem
  - Great for Kubernetes/Docker
  - HTTP/2 and WebSocket native
  - Excellent documentation
- **Cons**:
  - More complex setup
  - Requires additional tunnel plugin/configuration
  - Overkill if only used for tunneling
  - Would need custom tunnel implementation
- **Integration Complexity**: High
- **Fit**: Low - overkill, better as general proxy

### Option 11: **ZeroTier / Tailscale (Mesh VPN)**
- **Language**: C++ / Go
- **License**: Various (Business licenses for some features)
- **GitHub**: zerotier/ZeroTierOne, tailscale/tailscale
- **Pros**:
  - Production-grade mesh VPN
  - Excellent security (Zero Trust)
  - Easy to use
  - Great performance
  - Built-in authentication
- **Cons**:
  - Full VPN solution (overkill for HTTP tunnel)
  - Creates network interfaces
  - May require root/admin access
  - Commercial licenses for some features
  - Not designed for HTTP reverse proxy
- **Integration Complexity**: High (network-level changes)
- **Fit**: Low - wrong use case (full VPN vs reverse proxy)

### Option 12: **ngrok (Self-Hosted)**
- **Language**: Go
- **License**: Apache 2.0 (self-hosted version)
- **GitHub**: inconshreveable/ngrok
- **Pros**:
  - Industry standard
  - Excellent documentation
  - Production-ready
  - WebSocket support
  - Self-hosted version available
- **Cons**:
  - Older codebase (original ngrok)
  - Less maintained (company focuses on paid service)
  - Would need custom JWT integration
  - Setup complexity
- **Integration Complexity**: Medium-High
- **Fit**: Good - if self-hosted version works

## Top Recommendations

### 🥇 First Choice: **frp (Fast Reverse Proxy)**
### 🥈 Second Choice: **Chisel** (Simpler Alternative)

### Why frp?
1. **Production-Ready**: Used by thousands of projects
2. **WebSocket Native**: Full WebSocket support
3. **Self-Hosted**: Complete control
4. **Active Development**: Regular updates and security patches
5. **Flexible Auth**: Can integrate with custom JWT validation
6. **Multi-Protocol**: Supports HTTP, TCP, UDP, WebSocket
7. **Good Documentation**: Extensive docs and examples

### Integration Architecture

```
[Flutter Desktop] → [frp Client (frpc)] → [frp Server (frps)] → [Node.js API] → [Web Users]
       ↑                    ↑                      ↑                    ↑
   Local App         Connects via          Runs on same        Validates JWT
                      WebSocket            infrastructure      and routes
```

### Implementation Plan

#### Phase 1: Setup frp Server
1. Deploy frp server (frps) alongside Node.js API
2. Configure authentication with JWT validation
3. Set up WebSocket proxy configuration

#### Phase 2: Integrate frp Client
1. Bundle frpc (frp client) with Flutter desktop app
2. Configure frpc to connect to frps with JWT token
3. Map local Ollama (localhost:11434) to frp tunnel

#### Phase 3: Node.js Integration
1. Replace custom TunnelProxy with frp API integration
2. Implement JWT validation for frp connections
3. Route HTTP requests through frp tunnels

#### Phase 4: Migration
1. Test new tunnel system
2. Migrate existing connections
3. Remove custom tunnel code

### frp Configuration Example

#### Server Side (frps.ini)
```ini
[common]
bind_port = 7000
authentication_method = token
token = your_secret_token

# WebSocket support
allow_ports = 6000-7000
```

#### Client Side (frpc.ini)
```ini
[common]
server_addr = app.cloudtolocalllm.online
server_port = 7000
token = jwt_token_from_auth

[web]
type = http
local_port = 11434
custom_domains = tunnel.{user_id}.cloudtolocalllm.online
```

### Alternative: Use frp as HTTP Proxy

Instead of custom subdomains, integrate frp with existing API:

```javascript
// Node.js: Route requests through frp
const frpClient = new FrpClient({
  serverAddr: 'localhost:7000',
  token: jwtToken,
});

// Forward HTTP request through frp tunnel
const response = await frpClient.forwardRequest({
  localPort: 11434,
  path: '/api/chat',
  method: 'POST',
  body: requestBody,
});
```

## Decision Matrix

| Solution | Complexity | Features | Maintenance | Fit Score | Notes |
|----------|-----------|----------|-------------|-----------|-------|
| **frp** | ⭐⭐⭐ Medium | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Active | **9/10** | Best overall fit |
| **chisel** | ⭐⭐ Low | ⭐⭐⭐⭐ Very Good | ⭐⭐⭐⭐ Active | **8/10** | Simpler than frp, good alternative |
| **cloudflared** | ⭐⭐⭐ Medium | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Active | 7/10 | Requires Cloudflare |
| **ngrok (self-hosted)** | ⭐⭐⭐ Medium | ⭐⭐⭐⭐ Very Good | ⭐⭐⭐ Moderate | 7/10 | Industry standard but less maintained |
| **localtunnel** | ⭐⭐⭐ Medium | ⭐⭐⭐ Good | ⭐⭐ Low | 6/10 | Node.js native |
| **inlets** | ⭐⭐⭐⭐ High | ⭐⭐⭐⭐ Very Good | ⭐⭐⭐⭐ Active | 6/10 | Kubernetes-focused |
| **bore** | ⭐⭐ Low | ⭐⭐ Basic | ⭐⭐⭐ Moderate | 5/10 | Too simple |
| **sish** | ⭐⭐⭐⭐ High | ⭐⭐⭐ Good | ⭐⭐⭐ Moderate | 5/10 | SSH complexity |
| **pagekite** | ⭐⭐⭐ Medium | ⭐⭐⭐ Good | ⭐⭐ Low | 5/10 | License concerns |
| **vscode-tunnel** | ⭐⭐⭐⭐ High | ⭐⭐⭐ Good | ⭐⭐⭐⭐ Active | 4/10 | Wrong use case |
| **traefik** | ⭐⭐⭐⭐ High | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Active | 4/10 | Overkill |
| **zerotier/tailscale** | ⭐⭐⭐⭐ High | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Active | 3/10 | Wrong use case (full VPN) |

## Next Steps

1. **Evaluate frp in detail**:
   - Test frp WebSocket support
   - Verify JWT authentication integration
   - Check Dart/Flutter client library availability

2. **Create proof-of-concept**:
   - Deploy frp server
   - Integrate with Node.js API
   - Test with Flutter desktop app

3. **Migration planning**:
   - Document migration steps
   - Create rollback plan
   - Set up monitoring

## Questions to Answer

1. Can frp client be embedded in Flutter app? (Need native wrapper)
2. How to integrate JWT validation with frp authentication?
3. Can we use frp's HTTP proxy mode instead of WebSocket?
4. Performance comparison: frp vs custom implementation?

## Alternative Recommendation: **Chisel**

### Why Consider Chisel?
1. **Simpler**: Less complex than frp, easier to integrate
2. **WebSocket Native**: Built on HTTP/WebSocket transport
3. **Single Binary**: Simple deployment
4. **Go-Based**: Fast performance, cross-platform
5. **Active Development**: Regular updates
6. **Good for HTTP Tunneling**: Specifically designed for reverse tunneling

### Chisel Integration Example

```javascript
// Server-side: Start Chisel server
const { exec } = require('child_process');
exec('chisel server --port 8080 --reverse');

// Client-side: Connect with Flutter
// Would need to bundle chisel binary or use HTTP client library
```

### Chisel vs frp Comparison

| Feature | frp | Chisel |
|---------|-----|--------|
| Complexity | Medium | Low |
| WebSocket Support | ✅ | ✅ |
| HTTP Support | ✅ | ✅ |
| Configuration | INI files | Command-line flags |
| Authentication | Token + plugins | Token-based |
| Multi-protocol | TCP/HTTP/UDP/WebSocket | TCP over HTTP |
| Documentation | Excellent | Good |
| Community | Large | Medium |
| Best For | Enterprise deployments | Simple reverse tunneling |

### Chisel Architecture

```
[Flutter Desktop] → [Chisel Client] → [Chisel Server] → [Node.js API] → [Web Users]
       ↑                  ↑                  ↑                ↑
   Local App        HTTP/WS tunnel      Self-hosted    Validates JWT
```

### Recommendation Decision

**Choose frp if:**
- You need enterprise-grade features
- Multiple protocol support is important
- Extensive documentation is needed
- Complex authentication requirements

**Choose Chisel if:**
- You want simplicity
- WebSocket/HTTP tunneling is sufficient
- Faster integration is priority
- Less configuration overhead

Both are excellent choices. Chisel is simpler but frp is more feature-rich.

