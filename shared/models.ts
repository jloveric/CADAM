import type { Model } from './types';

// Model ids persisted in conversation settings (and submitted by stale
// clients) outlive the picker catalog. Map retired ids to their successors
// so old conversations keep resolving to a routable, correctly priced model.
export const LEGACY_MODEL_IDS: Record<string, Model> = {
  // gpt-5.5 is available again in the picker — keep this empty unless a
  // truly retired id needs remapping.
};

export function normalizeModelId(model: Model): Model {
  return LEGACY_MODEL_IDS[model] ?? model;
}

export type OpenAIReasoningEffort =
  | 'none'
  | 'minimal'
  | 'low'
  | 'medium'
  | 'high'
  | 'xhigh'
  | 'max';

type OpenAIModelConfig = {
  /** Model id sent to the OpenAI API (no `openai/` prefix). */
  apiModel: string;
  /** Default reasoning effort when thinking is enabled for this picker entry. */
  reasoningEffort?: OpenAIReasoningEffort;
};

/**
 * Picker ids → OpenAI API model + optional fixed reasoning effort.
 * Entries like `openai/gpt-5.4-mini-medium` are convenience aliases: the
 * API only knows `gpt-5.4-mini`, and "medium" is the effort knob.
 */
const OPENAI_MODEL_CONFIG: Record<string, OpenAIModelConfig> = {
  'openai/gpt-5.6-sol': { apiModel: 'gpt-5.6-sol' },
  'openai/gpt-5.5': { apiModel: 'gpt-5.5' },
  'openai/gpt-5.4-mini': { apiModel: 'gpt-5.4-mini' },
  'openai/gpt-5.4-mini-medium': {
    apiModel: 'gpt-5.4-mini',
    reasoningEffort: 'medium',
  },
  'openai/gpt-5.4-nano': {
    apiModel: 'gpt-5.4-nano',
    reasoningEffort: 'minimal',
  },
};

export function openaiModelConfig(modelId: Model): OpenAIModelConfig {
  const configured = OPENAI_MODEL_CONFIG[modelId];
  if (configured) return configured;
  return { apiModel: modelId.slice('openai/'.length) };
}

/** Strip the `openai/` picker prefix for direct OpenAI API calls. */
export function openaiApiModelId(modelId: Model): string {
  return openaiModelConfig(modelId).apiModel;
}
