const { buildChildActivityContext } = require('../services/childActivityContext')
const { chatCompletion, extractJson } = require('../services/openRouterService')

const SYSTEM_PROMPT = `You are a thoughtful parental guidance assistant for a family screen-time and safety app.
Analyze the child's digital activity data and help the parent understand patterns and take practical next steps.

Rules:
- Be calm, supportive, and non-alarmist. Parents may be anxious — stay constructive.
- Do not invent data. Only reference what is provided in the activity snapshot.
- If data is sparse or missing, say so and suggest setup steps (link device, enable tracking).
- Keep language plain and actionable. Avoid medical or legal claims.
- For web activity, note patterns (education, social, games, video) without moralizing.
- Suggested actions should be specific to this app: time limits, bedtime, device lock/unlock, reviewing web activity, talking with the child.

Respond with ONLY valid JSON (no markdown) in this exact shape:
{
  "summary": "2-4 sentence overview for the parent",
  "highlights": ["positive or neutral observations, max 4 items"],
  "concerns": ["optional concerns worth attention, max 3 items — empty array if none"],
  "suggestedActions": [
    {
      "title": "short action title",
      "description": "1-2 sentences on why and how",
      "priority": "high" | "medium" | "low"
    }
  ],
  "screenTimeAssessment": "healthy" | "moderate" | "high" | "unknown"
}`

function normalizeInsights(raw) {
  const summary = typeof raw.summary === 'string' ? raw.summary.trim() : ''
  const highlights = Array.isArray(raw.highlights)
    ? raw.highlights.filter((item) => typeof item === 'string' && item.trim()).slice(0, 4)
    : []
  const concerns = Array.isArray(raw.concerns)
    ? raw.concerns.filter((item) => typeof item === 'string' && item.trim()).slice(0, 3)
    : []
  const suggestedActions = Array.isArray(raw.suggestedActions)
    ? raw.suggestedActions
        .map((action) => ({
          title: typeof action.title === 'string' ? action.title.trim() : '',
          description: typeof action.description === 'string' ? action.description.trim() : '',
          priority: ['high', 'medium', 'low'].includes(action.priority) ? action.priority : 'medium',
        }))
        .filter((action) => action.title && action.description)
        .slice(0, 5)
    : []

  const assessmentValues = ['healthy', 'moderate', 'high', 'unknown']
  const screenTimeAssessment = assessmentValues.includes(raw.screenTimeAssessment)
    ? raw.screenTimeAssessment
    : 'unknown'

  if (!summary) {
    throw new Error('AI response was missing a summary')
  }

  return {
    summary,
    highlights,
    concerns,
    suggestedActions,
    screenTimeAssessment,
  }
}

/**
 * GET /api/auth/children/:childId/ai-insights
 */
const getChildAiInsights = async (req, res, next) => {
  try {
    const child = req.child
    const date = req.query.date || new Date().toISOString().substring(0, 10)

    const context = await buildChildActivityContext(child, date)

    const userPrompt = `Analyze this child's activity for ${date} and return JSON insights for their parent.

Child activity snapshot:
${JSON.stringify(context, null, 2)}`

    const rawText = await chatCompletion({
      systemPrompt: SYSTEM_PROMPT,
      userPrompt,
    })

    let parsed
    try {
      parsed = extractJson(rawText)
    } catch (parseError) {
      console.error('[AI insights] JSON parse failed:', parseError.message)
      console.error('[AI insights] Raw response preview:', rawText.slice(0, 400))
      const error = new Error('AI returned an invalid response. Please try again.')
      error.status = 502
      throw error
    }

    let insights
    try {
      insights = normalizeInsights(parsed)
    } catch (normalizeError) {
      console.error('[AI insights] Normalize failed:', normalizeError.message)
      const error = new Error(normalizeError.message || 'AI response was incomplete. Please try again.')
      error.status = 502
      throw error
    }

    res.status(200).json({
      success: true,
      date,
      childId: child._id.toString(),
      childName: child.username,
      generatedAt: new Date().toISOString(),
      context,
      insights,
    })
  } catch (error) {
    next(error)
  }
}

module.exports = { getChildAiInsights }
