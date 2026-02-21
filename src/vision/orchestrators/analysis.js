/**
 * Orchestrator Analysis Phase
 * Handles web search, tool discovery, and MCP matching
 */

import { loadVision, updateVision } from '../state-manager.js';
import { searchSimilarApps, searchUIPatterns } from '../analysis/index.js';
import { discoverNpmPackages, discoverPipPackages, rankByRelevance } from '../analysis/tool-discovery.js';
import { matchMCPServers, getMCPCapabilities } from '../analysis/mcp-matcher.js';
import { log, transitionStage, OrchestratorStage } from './lifecycle.js';

/**
 * Run analysis phase
 */
export async function analyze(orchestrator) {
  transitionStage(orchestrator, OrchestratorStage.ANALYSIS);

  if (!orchestrator.vision) {
    throw new Error('Vision not initialized. Call initialize() first.');
  }

  try {
    const results = {
      similarApps: [],
      uiPatterns: [],
      npmPackages: [],
      pipPackages: [],
      mcpServers: [],
      toolRecommendations: []
    };

    const prompt = orchestrator.vision.prompt || {};
    const parsedPrompt = prompt.parsed || {};
    const features = (orchestrator.vision.metadata?.features || parsedPrompt.features || [])
      .map(f => (typeof f === 'string' ? f : (f?.feature || f?.name || '')))
      .filter(Boolean);
    const technologies = parsedPrompt.technologies || [];

    // Web search for similar apps (if enabled)
    if (orchestrator.config.analysis.webSearchEnabled) {
      log(orchestrator, 'info', 'Searching for similar apps...');
      results.similarApps = await searchSimilarApps(features);

      log(orchestrator, 'info', 'Searching for UI patterns...');
      results.uiPatterns = await searchUIPatterns(features);
    }

    // Discover npm packages
    log(orchestrator, 'info', 'Discovering npm packages...');
    results.npmPackages = await discoverNpmPackages(
      features,
      orchestrator.config.analysis.maxToolSuggestions
    );

    // Discover pip packages (if Python detected)
    if (technologies.includes('python') || technologies.includes('fastapi')) {
      log(orchestrator, 'info', 'Discovering pip packages...');
      results.pipPackages = await discoverPipPackages(
        features,
        orchestrator.config.analysis.maxToolSuggestions
      );
    }

    // Match MCP servers (if enabled)
    if (orchestrator.config.analysis.mcpMatchingEnabled) {
      log(orchestrator, 'info', 'Matching MCP servers...');
      results.mcpServers = await matchMCPServers(features);

      // Get capabilities for matched servers
      for (const server of results.mcpServers) {
        server.capabilities = await getMCPCapabilities(server.name);
      }
    }

    // Rank and combine tool recommendations
    const allTools = [
      ...results.npmPackages.map(p => ({ ...p, type: 'npm' })),
      ...results.pipPackages.map(p => ({ ...p, type: 'pip' })),
      ...results.mcpServers.map(s => ({ ...s, type: 'mcp' }))
    ];

    results.toolRecommendations = rankByRelevance(allTools, features);

    // Save analysis results
    orchestrator.analysisResults = results;

    await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
      vision.analysis = results;
      vision.orchestrator.stage = orchestrator.stage;
      return vision;
    });

    orchestrator.vision = await loadVision(orchestrator.projectRoot, orchestrator.vision.slug);

    log(orchestrator, 'info', 'Analysis complete', {
      similarApps: results.similarApps.length,
      npmPackages: results.npmPackages.length,
      pipPackages: results.pipPackages.length,
      mcpServers: results.mcpServers.length
    });

    return {
      success: true,
      stage: orchestrator.stage,
      results
    };

  } catch (error) {
    log(orchestrator, 'error', `Analysis failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      stage: orchestrator.stage
    };
  }
}
