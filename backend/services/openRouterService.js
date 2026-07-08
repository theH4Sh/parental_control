const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions'

// Works reliably on OpenRouter; override with OPENROUTER_MODEL in .env if needed.
const DEFAULT_MODEL = 'openrouter/auto'

function getApiKey() {
  return (
    process.env.OPENROUTER_API_KEY
    || process.env.OPEN_ROUTER_API_KEY
    || process.env.OPENROUTER_KEY
    || ''
  )
}

function getModel() {
  return process.env.OPENROUTER_MODEL || DEFAULT_MODEL
}

function extractMessageContent(message) {
  const content = message?.content
  if (typeof content === 'string') return content.trim()
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part
        if (part && typeof part.text === 'string') return part.text
        if (part && typeof part.content === 'string') return part.content
        return ''
      })
      .join('')
      .trim()
  }
  if (content && typeof content === 'object' && typeof content.text === 'string') {
    return content.text.trim()
  }
  return ''
}

/**
 * Calls OpenRouter chat completions and returns the assistant message text.
 */
async function chatCompletion({ systemPrompt, userPrompt, temperature = 0.4 }) {
  const apiKey = getApiKey()
  if (!apiKey) {
    const error = new Error('AI insights are not configured. Add OPENROUTER_API_KEY to the backend environment.')
    error.status = 503
    throw error
  }

  try {
    return await requestCompletion({
      apiKey,
      systemPrompt,
      userPrompt,
      temperature,
      useJsonMode: true,
    })
  } catch (error) {
    const message = (error.message || '').toLowerCase()
    const jsonModeUnsupported =
      message.includes('response_format')
      || message.includes('json_object')
      || message.includes('json mode')

    if (jsonModeUnsupported && error.status === 502) {
      console.warn('[OpenRouter] JSON mode unsupported for model, retrying without response_format')
      return requestCompletion({
        apiKey,
        systemPrompt,
        userPrompt,
        temperature,
        useJsonMode: false,
      })
    }
    throw error
  }
}

async function requestCompletion({ apiKey, systemPrompt, userPrompt, temperature, useJsonMode }) {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 45_000)

  try {
    const payload = {
      model: getModel(),
      temperature,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    }
    if (useJsonMode) {
      payload.response_format = { type: 'json_object' }
    }

    const response = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': process.env.APP_URL || 'http://localhost:8000',
        'X-Title': 'Parental Control App',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    })

    const rawText = await response.text()
    let body
    try {
      body = rawText ? JSON.parse(rawText) : {}
    } catch {
      const error = new Error('AI provider returned an unreadable response. Please try again.')
      error.status = 502
      throw error
    }

    if (!response.ok) {
      const message =
        body?.error?.message
        || body?.message
        || `OpenRouter request failed (${response.status})`
      console.error('[OpenRouter]', response.status, message)
      const error = new Error(message)
      error.status = 502
      throw error
    }

    const content = extractMessageContent(body?.choices?.[0]?.message)
    if (!content) {
      console.error('[OpenRouter] Empty content in response:', JSON.stringify(body?.choices?.[0]).slice(0, 500))
      const error = new Error('AI returned an empty response. Check OPENROUTER_MODEL or try again.')
      error.status = 502
      throw error
    }

    return content
  } catch (error) {
    if (error.name === 'AbortError') {
      const timeoutError = new Error('AI request timed out. Please try again.')
      timeoutError.status = 504
      throw timeoutError
    }
    throw error
  } finally {
    clearTimeout(timeout)
  }
}

function extractJson(text) {
  const trimmed = text.trim()

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fenced) {
    return JSON.parse(fenced[1].trim())
  }

  const start = trimmed.indexOf('{')
  const end = trimmed.lastIndexOf('}')
  if (start !== -1 && end !== -1 && end > start) {
    return JSON.parse(trimmed.slice(start, end + 1))
  }

  return JSON.parse(trimmed)
}

module.exports = { chatCompletion, extractJson, getApiKey, getModel }
