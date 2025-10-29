import { createAnthropic } from '@ai-sdk/anthropic';

export function getAnthropicModel(apiKey: string, baseURL?: string) {
  const anthropic = createAnthropic({
    apiKey,
    ...(baseURL && { baseURL }),
  });

  return anthropic('claude-3-5-sonnet-20240620');
}
