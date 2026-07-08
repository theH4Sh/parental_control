const ChildSettings = require('../models/ChildSettings')
const { sendToUser } = require('../services/websocketService')

const formatSettings = (doc) => ({
  childId: doc.childId.toString(),
  dailyTimeLimitMs: doc.dailyTimeLimitMs,
  limitStartedAt: doc.limitStartedAt ? doc.limitStartedAt.toISOString() : null,
  bedtimeHour: doc.bedtimeHour,
  bedtimeMinute: doc.bedtimeMinute,
  bedtimeEnabled: doc.bedtimeEnabled,
  lockDeviceOnLimit: doc.lockDeviceOnLimit !== false,
  unlockUntil: doc.unlockUntil ? doc.unlockUntil.toISOString() : null,
  forceDeviceLock: doc.forceDeviceLock === true,
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
    let settings = await getOrCreateSettings(req.child._id)
    settings = await ensureLimitStarted(settings)
    res.status(200).json({ success: true, settings: formatSettings(settings) })
  } catch (error) {
    next(error)
  }
}

const updateChildSettings = async (req, res, next) => {
  try {
    const { dailyTimeLimitMs, bedtimeHour, bedtimeMinute, bedtimeEnabled, lockDeviceOnLimit, unlockUntil, forceDeviceLock, restartLimitTimer } = req.body

    const update = {}
    if (dailyTimeLimitMs !== undefined) {
      const newLimit = Math.max(0, Number(dailyTimeLimitMs))
      update.dailyTimeLimitMs = newLimit

      const existing = await ChildSettings.findOne({ childId: req.child._id })
      const prevLimit = existing?.dailyTimeLimitMs ?? 0

      if (newLimit === 0) {
        update.limitStartedAt = null
      } else if (
        restartLimitTimer === true ||
        prevLimit !== newLimit ||
        !existing?.limitStartedAt
      ) {
        update.limitStartedAt = new Date()
      }
    }
    if (bedtimeHour !== undefined) update.bedtimeHour = Math.min(23, Math.max(0, Number(bedtimeHour)))
    if (bedtimeMinute !== undefined) update.bedtimeMinute = Math.min(59, Math.max(0, Number(bedtimeMinute)))
    if (bedtimeEnabled !== undefined) update.bedtimeEnabled = Boolean(bedtimeEnabled)
    if (lockDeviceOnLimit !== undefined) update.lockDeviceOnLimit = Boolean(lockDeviceOnLimit)
    if (forceDeviceLock !== undefined) update.forceDeviceLock = Boolean(forceDeviceLock)
    if (unlockUntil !== undefined) {
      if (unlockUntil === null || unlockUntil === '') {
        update.unlockUntil = null
      } else {
        const parsed = new Date(unlockUntil)
        if (Number.isNaN(parsed.getTime())) {
          return res.status(400).json({ error: 'Invalid unlockUntil date' })
        }
        update.unlockUntil = parsed
      }
    }
    if (forceDeviceLock === true) {
      update.unlockUntil = null
    }

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
    let settings = await getOrCreateSettings(req.user._id)
    settings = await ensureLimitStarted(settings)
    res.status(200).json({ success: true, settings: formatSettings(settings) })
  } catch (error) {
    next(error)
  }
}

async function ensureLimitStarted(settings) {
  if (settings.dailyTimeLimitMs > 0 && !settings.limitStartedAt) {
    settings.limitStartedAt = new Date()
    await settings.save()
  }
  return settings
}

module.exports = { getChildSettings, updateChildSettings, getMySettings, getOrCreateSettings, formatSettings, ensureLimitStarted }
