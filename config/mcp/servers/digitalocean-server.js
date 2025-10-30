#!/usr/bin/env node
/**
 * DigitalOcean MCP Server
 * Provides automation and management capabilities for DigitalOcean infrastructure
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

class DigitalOceanMCPServer {
  constructor() {
    this.token = process.env.DIGITALOCEAN_TOKEN;
    this.clusterName = process.env.DO_CLUSTER_NAME || 'cloudtolocalllm';
    this.region = process.env.DO_REGION || 'tor1';
    this.registry = process.env.DO_REGISTRY || 'registry.digitalocean.com/cloudtolocalllm';
  }

  /**
   * List all Kubernetes clusters
   */
  async listClusters() {
    const { stdout } = await execAsync('doctl kubernetes cluster list --format Name,Region,Status,Version --no-header');
    return stdout.trim().split('\n').map(line => {
      const [name, region, status, version] = line.trim().split(/\s+/);
      return { name, region, status, version };
    });
  }

  /**
   * Get cluster information
   */
  async getCluster(clusterName = this.clusterName) {
    const { stdout } = await execAsync(`doctl kubernetes cluster get ${clusterName} --format Name,Region,Status,Version,NodePools --no-header`);
    const [name, region, status, version, nodePools] = stdout.trim().split(/\s+/);
    return { name, region, status, version, nodePools };
  }

  /**
   * Get cluster kubeconfig
   */
  async getKubeconfig(clusterName = this.clusterName) {
    await execAsync(`doctl kubernetes cluster kubeconfig save ${clusterName}`);
    return { success: true, message: `Kubeconfig saved for ${clusterName}` };
  }

  /**
   * List container registry repositories
   */
  async listRegistryRepositories() {
    const { stdout } = await execAsync('doctl registry repository list --format Name,LatestTag,TagCount --no-header');
    return stdout.trim().split('\n').map(line => {
      const [name, latestTag, tagCount] = line.trim().split(/\s+/);
      return { name, latestTag, tagCount: parseInt(tagCount) };
    });
  }

  /**
   * Login to container registry
   */
  async loginToRegistry() {
    await execAsync('doctl registry login');
    return { success: true, message: 'Logged in to DigitalOcean Container Registry' };
  }

  /**
   * Get load balancer for cluster
   */
  async getLoadBalancer() {
    const { stdout } = await execAsync('doctl compute load-balancer list --format Name,IP,Status --no-header');
    return stdout.trim().split('\n').map(line => {
      const [name, ip, status] = line.trim().split(/\s+/);
      return { name, ip, status };
    });
  }

  /**
   * Scale node pool
   */
  async scaleNodePool(clusterName, poolName, nodeCount) {
    await execAsync(`doctl kubernetes cluster node-pool update ${clusterName} ${poolName} --count ${nodeCount}`);
    return { success: true, message: `Scaled ${poolName} to ${nodeCount} nodes` };
  }

  /**
   * Get cluster resources
   */
  async getClusterResources() {
    const { stdout } = await execAsync('kubectl get all --all-namespaces');
    return stdout;
  }

  /**
   * Handle MCP tool calls
   */
  async handleToolCall(toolName, args) {
    switch (toolName) {
      case 'list_clusters':
        return await this.listClusters();
      case 'get_cluster':
        return await this.getCluster(args.clusterName);
      case 'get_kubeconfig':
        return await this.getKubeconfig(args.clusterName);
      case 'list_registry_repos':
        return await this.listRegistryRepositories();
      case 'login_registry':
        return await this.loginToRegistry();
      case 'get_load_balancer':
        return await this.getLoadBalancer();
      case 'scale_node_pool':
        return await this.scaleNodePool(args.clusterName, args.poolName, args.nodeCount);
      case 'get_resources':
        return await this.getClusterResources();
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  }
}

// Export for MCP usage
export default DigitalOceanMCPServer;

// If run directly, start MCP server
if (import.meta.url === `file://${process.argv[1]}`) {
  const server = new DigitalOceanMCPServer();
  console.log('DigitalOcean MCP Server ready');
  
  // Listen for MCP protocol messages on stdin
  process.stdin.on('data', async (data) => {
    try {
      const message = JSON.parse(data.toString());
      const result = await server.handleToolCall(message.tool, message.args || {});
      console.log(JSON.stringify({ success: true, result }));
    } catch (error) {
      console.log(JSON.stringify({ success: false, error: error.message }));
    }
  });
}

