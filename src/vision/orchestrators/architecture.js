/**
 * Orchestrator Architecture Phase
 * Handles diagram generation, API contracts, and state design
 */

import { loadVision, updateVision } from '../state-manager.js';
import {
  generateComponentDiagram,
  generateDataFlowDiagram,
  generateSequenceDiagram
} from '../architecture/index.js';
import { generateRESTEndpoints, formatOpenAPISpec } from '../architecture/api-contracts.js';
import { designStores, generateStateShape } from '../architecture/state-design.js';
import { generateASCIIWireframe, extractComponentList } from '../ui/index.js';
import { log, transitionStage, OrchestratorStage } from './lifecycle.js';

/**
 * Run architecture phase
 */
export async function architect(orchestrator) {
  transitionStage(orchestrator, OrchestratorStage.ARCHITECTURE);

  if (!orchestrator.vision) {
    throw new Error('Vision not initialized. Call initialize() first.');
  }

  try {
    const artifacts = {
      diagrams: {},
      apiContracts: null,
      stateDesign: null,
      wireframes: null,
      componentList: []
    };

    const prompt = orchestrator.vision.prompt || {};
    const parsedPrompt = prompt.parsed || {};
    const technologies = parsedPrompt.technologies || [];
    const features = (orchestrator.vision.metadata?.features || parsedPrompt.features || [])
      .map(f => (typeof f === 'string' ? f : (f?.feature || f?.name || '')))
      .filter(Boolean);

    const components = buildComponents(features, technologies);
    const flowFeatures = buildFlowFeatures(features);

    // Generate component diagram
    log(orchestrator, 'info', 'Generating component diagram...');
    artifacts.diagrams.component = await generateComponentDiagram(components, { technologies });

    // Generate data flow diagram
    log(orchestrator, 'info', 'Generating data flow diagram...');
    artifacts.diagrams.dataFlow = await generateDataFlowDiagram(flowFeatures, { technologies });

    // Generate sequence diagrams for key flows
    log(orchestrator, 'info', 'Generating sequence diagrams...');
    artifacts.diagrams.sequences = [];
    for (const feature of features.slice(0, 3)) { // Top 3 features
      const sequence = await generateSequenceDiagram([{
        caller: 'User',
        handler: 'API',
        method: 'POST',
        path: `/api/${feature.replace(/\s+/g, '-').toLowerCase()}`,
        usesDatabase: true,
        processing: `Process ${feature}`
      }]);
      artifacts.diagrams.sequences.push({
        feature,
        diagram: sequence
      });
    }

    // Generate REST endpoints if backend detected
    if (technologies.some(t =>
      ['fastapi', 'express', 'django', 'flask', 'nest'].includes(t?.toLowerCase())
    )) {
      log(orchestrator, 'info', 'Generating API contracts...');
      const endpoints = await generateRESTEndpoints(features);
      artifacts.apiContracts = formatOpenAPISpec({
        title: orchestrator.vision.title,
        endpoints
      });
    }

    // Generate state design if frontend detected
    if (technologies.some(t =>
      ['react', 'vue', 'angular', 'svelte'].includes(t?.toLowerCase())
    )) {
      log(orchestrator, 'info', 'Designing state management...');
      artifacts.stateDesign = {
        stores: await designStores(features),
        stateShape: await generateStateShape(features)
      };
    }

    // Generate ASCII wireframes
    log(orchestrator, 'info', 'Generating ASCII wireframes...');
    artifacts.wireframes = await generateASCIIWireframe(
      {
        navbar: { items: ['Overview', 'Bots', 'Plugins', 'Settings'] },
        sidebar: { items: ['Dashboard', 'Bot Registry', 'Lifecycle', 'Policies'] },
        stats: [
          { title: 'Bots', value: '12' },
          { title: 'Plugins', value: '8' },
          { title: 'Envs', value: '3' }
        ]
      },
      { type: inferLayoutType(features), width: 70 }
    );

    // Extract component list from wireframes
    artifacts.componentList = extractComponentList(artifacts.wireframes);

    // Save architecture artifacts
    orchestrator.architectureArtifacts = artifacts;

    await updateVision(orchestrator.projectRoot, orchestrator.vision.slug, (vision) => {
      vision.architecture = artifacts;
      vision.orchestrator.stage = orchestrator.stage;
      return vision;
    });

    orchestrator.vision = await loadVision(orchestrator.projectRoot, orchestrator.vision.slug);

    log(orchestrator, 'info', 'Architecture complete', {
      diagrams: Object.keys(artifacts.diagrams).length,
      hasApiContracts: !!artifacts.apiContracts,
      hasStateDesign: !!artifacts.stateDesign,
      componentCount: artifacts.componentList.length
    });

    return {
      success: true,
      stage: orchestrator.stage,
      artifacts
    };

  } catch (error) {
    log(orchestrator, 'error', `Architecture failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      stage: orchestrator.stage
    };
  }
}

function buildComponents(features, technologies) {
  const hasFrontend = technologies.some(t => ['react', 'vue', 'angular', 'svelte', 'next.js'].includes(String(t).toLowerCase()));
  const hasBackend = technologies.some(t => ['node', 'express', 'fastapi', 'django', 'flask', 'nest'].includes(String(t).toLowerCase()));
  const components = [];

  if (hasFrontend) {
    components.push({ name: 'Frontend', type: 'Frontend', dependencies: ['API'] });
  }
  if (hasBackend || features.length > 0) {
    components.push({ name: 'API', type: 'API', dependencies: ['Database'] });
  }
  components.push({ name: 'Database', type: 'Database', dependencies: [] });

  return components;
}

function buildFlowFeatures(features) {
  if (!features.length) {
    return [{
      name: 'Core Flow',
      flows: ['User -> API', 'API -> Database', 'Database -> API', 'API -> User']
    }];
  }

  return features.slice(0, 5).map(feature => ({
    name: feature,
    flows: ['User -> API', `API -> ${feature}`, `${feature} -> Database`, 'Database -> API', 'API -> User']
  }));
}

function inferLayoutType(features) {
  if (features.some(f => /form|input|create|edit/i.test(f))) return 'form';
  if (features.some(f => /table|list|grid/i.test(f))) return 'table';
  if (features.some(f => /modal|dialog/i.test(f))) return 'modal';
  return 'dashboard';
}
