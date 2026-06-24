const ChildSettings = require('../models/ChildSettings')
const { sendToUser } = require('../services/websocketService')

const formatSettings = (doc) => ({
  childId: doc.childId.toString(),
  dailyTimeLimitMs: doc.dailyTimeLimitMs,
  bedtimeHour: doc.bedtimeHour,
  bedtimeMinute: doc.bedtimeMinute,
  bedtimeEnabled: doc.bedtimeEnabled,
})

async function getOrCreateSettings(childId) {
  let settings = await ChildSettings.findOne({ childId })
  if (!settings) {
    settings = await ChildSettings.create({ childId })
  }
  return settings
}

const getChildSettings = async (req, res, next) => {
  try {
    const settings = await getOrCreateSettings(req.child._id)
    res.status(200).json({ success: true, settings: formatSettings(settings) })
  } catch (error) {
    next(error)
  }
}

const updateChildSettings = async (req, res, next) => {
  try {
    const { dailyTimeLimitMs, bedtimeHour, bedtimeMinute, bedtimeEnabled } = req.body

    const update = {}
    if (dailyTimeLimitMs !== undefined) update.dailyTimeLimitMs = Math.max(0, Number(dailyTimeLimitMs))
    if (bedtimeHour !== undefined) update.bedtimeHour = Math.min(23, Math.max(0, Number(bedtimeHour)))
    if (bedtimeMinute !== undefined) update.bedtimeMinute = Math.min(59, Math.max(0, Number(bedtimeMinute)))
    if (bedtimeEnabled !== undefined) update.bedtimeEnabled = Boolean(bedtimeEnabled)

    const settings = await ChildSettings.findOneAndUpdate(
      { childId: req.child._id },
      { $set: update },
      { upsert: true, new: true, runValidators: true }
    )

    const formatted = formatSettings(settings)
    sendToUser(req.child._id, { type: 'settings_updated', payload: formatted })

    res.status(200).json({ success: true, settings: formatted })
  } catch (error) {
    next(error)
  }
}

const getMySettings = async (req, res, next) => {
  try {
    const settings = await getOrCreateSettings(req.user._id)
    res.status(200).json({ success: true, settings: formatSettings(settings) })
  } catch (error) {
    next(error)
  }
}

module.exports = { getChildSettings, updateChildSettings, getMySettings, getOrCreateSettings, formatSettings }
