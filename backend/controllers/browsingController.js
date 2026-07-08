const BrowsingEvent = require('../models/BrowsingEvent')
const User = require('../models/userModel')

/**
 * POST /api/browsing-events
 * Child device bulk-uploads captured browsing events.
 */
const syncBrowsingEvents = async (req, res, next) => {
  try {
    const { deviceId, events } = req.body

    if (!deviceId || !Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ success: false, message: 'deviceId and events array are required' })
    }

    const childUser = await User.findOne({ deviceId, role: 'child' })
    if (!childUser) {
      return res.status(404).json({ success: false, message: 'No child linked to this device' })
    }

    const docs = events
      .map((event) => {
        const url = (event.url || '').trim()
        const domain = (event.domain || '').trim()
        if (!url || !domain) return null

        const visitedAt = event.visitedAt
          ? new Date(typeof event.visitedAt === 'number' ? event.visitedAt : event.visitedAt)
          : new Date()

        if (Number.isNaN(visitedAt.getTime())) return null

        return {
          deviceId,
          url,
          domain,
          title: (event.title || domain).toString().slice(0, 500),
          browserPackage: event.browserPackage || '',
          browserName: event.browserName || 'Browser',
          visitedAt,
        }
      })
      .filter(Boolean)

    if (docs.length === 0) {
      return res.status(200).json({ success: true, inserted: 0 })
    }

    // Skip duplicates: same device + url within 10 seconds of an existing record
    const inserted = []
    for (const doc of docs) {
      const existing = await BrowsingEvent.findOne({
        deviceId: doc.deviceId,
        url: doc.url,
        visitedAt: {
          $gte: new Date(doc.visitedAt.getTime() - 10_000),
          $lte: new Date(doc.visitedAt.getTime() + 10_000),
        },
      }).lean()

      if (!existing) {
        inserted.push(doc)
      }
    }

    if (inserted.length > 0) {
      await BrowsingEvent.insertMany(inserted, { ordered: false })
    }

    res.status(200).json({ success: true, inserted: inserted.length })
  } catch (error) {
    next(error)
  }
}

/**
 * GET /api/auth/children/:childId/browsing-history
 * Parent fetches browsing history for a child (today by default).
 */
const getChildBrowsingHistory = async (req, res, next) => {
  try {
    const child = req.child
    if (!child.deviceId) {
      return res.status(200).json({ success: true, events: [], domains: [] })
    }

    const date = req.query.date || new Date().toISOString().substring(0, 10)
    const limit = Math.min(Number(req.query.limit) || 100, 500)

    const start = new Date(`${date}T00:00:00.000Z`)
    const end = new Date(`${date}T23:59:59.999Z`)

    const events = await BrowsingEvent.find({
      deviceId: child.deviceId,
      visitedAt: { $gte: start, $lte: end },
    })
      .sort({ visitedAt: -1 })
      .limit(limit)
      .lean()

    const domainMap = {}
    events.forEach((event) => {
      const key = event.domain
      if (!domainMap[key]) {
        domainMap[key] = { domain: key, visitCount: 0, lastVisited: event.visitedAt, urls: new Set() }
      }
      domainMap[key].visitCount += 1
      domainMap[key].urls.add(event.url)
      if (new Date(event.visitedAt) > new Date(domainMap[key].lastVisited)) {
        domainMap[key].lastVisited = event.visitedAt
      }
    })

    const domains = Object.values(domainMap)
      .map((item) => ({
        domain: item.domain,
        visitCount: item.visitCount,
        lastVisited: item.lastVisited,
        uniqueUrls: item.urls.size,
      }))
      .sort((a, b) => b.visitCount - a.visitCount)

    res.status(200).json({
      success: true,
      date,
      events: events.map((event) => ({
        id: event._id.toString(),
        url: event.url,
        domain: event.domain,
        title: event.title,
        browserName: event.browserName,
        browserPackage: event.browserPackage,
        visitedAt: event.visitedAt,
      })),
      domains,
    })
  } catch (error) {
    next(error)
  }
}

module.exports = { syncBrowsingEvents, getChildBrowsingHistory }
