const UsageStats = require('../models/UsageStats')
const BrowsingEvent = require('../models/BrowsingEvent')
const ChildSettings = require('../models/ChildSettings')
const { formatSettings } = require('../controllers/childSettingsController')

function formatMs(ms) {
  const total = Math.max(0, Number(ms) || 0)
  const hours = Math.floor(total / 3_600_000)
  const minutes = Math.floor((total % 3_600_000) / 60_000)
  if (hours > 0) return `${hours}h ${minutes}m`
  if (minutes > 0) return `${minutes}m`
  return `${Math.floor(total / 1000)}s`
}

function formatBedtime(hour, minute) {
  const h = Number(hour) || 0
  const m = Number(minute) || 0
  const period = h >= 12 ? 'PM' : 'AM'
  const displayHour = h % 12 === 0 ? 12 : h % 12
  return `${displayHour}:${String(m).padStart(2, '0')} ${period}`
}

function describeLockState(settings) {
  if (settings.forceDeviceLock) return 'Device is locked by parent'
  if (settings.unlockUntil && new Date(settings.unlockUntil) > new Date()) {
    return `Temporarily unlocked until ${new Date(settings.unlockUntil).toISOString()}`
  }
  if (settings.dailyTimeLimitMs > 0 && settings.limitStartedAt) {
    const elapsed = Date.now() - new Date(settings.limitStartedAt).getTime()
    const remaining = settings.dailyTimeLimitMs - elapsed
    if (remaining <= 0 && settings.lockDeviceOnLimit !== false) {
      return 'Daily time limit reached — device should be locked'
    }
    if (remaining > 0) {
      return `Active countdown timer — ${formatMs(remaining)} remaining of ${formatMs(settings.dailyTimeLimitMs)} limit`
    }
  }
  return 'No active lock'
}

/**
 * Builds a compact activity snapshot for AI analysis.
 */
async function buildChildActivityContext(child, date = new Date().toISOString().substring(0, 10)) {
  const settingsDoc = await ChildSettings.findOne({ childId: child._id }).lean()
  const settings = settingsDoc
    ? formatSettings(settingsDoc)
    : {
        dailyTimeLimitMs: 0,
        limitStartedAt: null,
        bedtimeHour: 21,
        bedtimeMinute: 0,
        bedtimeEnabled: false,
        lockDeviceOnLimit: true,
        unlockUntil: null,
        forceDeviceLock: false,
      }

  let usage = null
  if (child.deviceId) {
    usage = await UsageStats.findOne({ deviceId: child.deviceId, date }).lean()
  }

  const topApps = (usage?.apps || [])
    .slice()
    .sort((a, b) => (b.totalMs || 0) - (a.totalMs || 0))
    .slice(0, 8)
    .map((app) => ({
      name: app.displayName || app.packageName,
      time: formatMs(app.totalMs || 0),
      totalMs: app.totalMs || 0,
    }))

  let browsingDomains = []
  let recentUrls = []
  if (child.deviceId) {
    const start = new Date(`${date}T00:00:00.000Z`)
    const end = new Date(`${date}T23:59:59.999Z`)

    const events = await BrowsingEvent.find({
      deviceId: child.deviceId,
      visitedAt: { $gte: start, $lte: end },
    })
      .sort({ visitedAt: -1 })
      .limit(80)
      .lean()

    const domainMap = {}
    events.forEach((event) => {
      const key = event.domain
      if (!domainMap[key]) {
        domainMap[key] = { domain: key, visitCount: 0, lastVisited: event.visitedAt }
      }
      domainMap[key].visitCount += 1
    })

    browsingDomains = Object.values(domainMap)
      .sort((a, b) => b.visitCount - a.visitCount)
      .slice(0, 10)
      .map((item) => ({
        domain: item.domain,
        visits: item.visitCount,
      }))

    recentUrls = events.slice(0, 15).map((event) => ({
      domain: event.domain,
      title: (event.title || event.domain || '').slice(0, 120),
      browser: event.browserName || 'Browser',
      visitedAt: event.visitedAt,
    }))
  }

  const hasDevice = Boolean(child.deviceId)
  const hasUsage = Boolean(usage && (usage.totalScreenTimeMs > 0 || topApps.length > 0))
  const hasBrowsing = browsingDomains.length > 0

  return {
    date,
    child: {
      username: child.username,
      email: child.email,
      deviceLinked: hasDevice,
      deviceInfo: usage?.deviceInfo || (hasDevice ? 'Linked device' : 'No device linked yet'),
    },
    screenTime: {
      total: formatMs(usage?.totalScreenTimeMs || 0),
      totalMs: usage?.totalScreenTimeMs || 0,
      topApps,
    },
    parentalControls: {
      dailyLimit: settings.dailyTimeLimitMs > 0 ? formatMs(settings.dailyTimeLimitMs) : 'Not set',
      bedtime: settings.bedtimeEnabled
        ? formatBedtime(settings.bedtimeHour, settings.bedtimeMinute)
        : 'Not enabled',
      lockState: describeLockState(settings),
      lockOnLimit: settings.lockDeviceOnLimit !== false,
    },
    webActivity: {
      topDomains: browsingDomains,
      recentVisits: recentUrls,
      totalVisitsToday: recentUrls.length > 0 ? browsingDomains.reduce((sum, d) => sum + d.visits, 0) : 0,
    },
    dataAvailability: {
      hasDevice,
      hasUsage,
      hasBrowsing,
      isSparse: !hasUsage && !hasBrowsing,
    },
  }
}

module.exports = { buildChildActivityContext, formatMs }
