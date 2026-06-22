const express = require('express')
const mongoose = require('mongoose')
const UsageStats = require('../models/UsageStats')

const router = express.Router()

// POST /api/register-device
// Registers a new device and returns a unique deviceId
router.post('/register-device', async (req, res, next) => {
  try {
    const deviceId = new mongoose.Types.ObjectId().toString()
    res.status(201).json({
      success: true,
      deviceId,
    })
  } catch (err) {
    next(err)
  }
})

// POST /api/usage-stats
// Upsert daily usage stats for a device
router.post('/usage-stats', async (req, res, next) => {
  try {
    const { deviceId, date, deviceInfo, totalScreenTimeMs, apps } = req.body

    if (!deviceId || !date || !apps) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: deviceId, date, apps',
      })
    }

    const doc = await UsageStats.findOneAndUpdate(
      { deviceId, date },
      {
        $set: {
          deviceInfo: deviceInfo || 'Unknown Device',
          totalScreenTimeMs: totalScreenTimeMs || 0,
          apps,
        },
      },
      { upsert: true, new: true, runValidators: true }
    )

    res.status(200).json({
      success: true,
      data: doc,
    })
  } catch (err) {
    next(err)
  }
})

// GET /api/usage-stats/:deviceId
// Get usage stats history for a device (optional query: ?date=yyyy-MM-dd)
router.get('/usage-stats/:deviceId', async (req, res, next) => {
  try {
    const { deviceId } = req.params
    const { date } = req.query

    const filter = { deviceId }
    if (date) {
      filter.date = date
    }

    const stats = await UsageStats.find(filter)
      .sort({ date: -1 })
      .limit(30) // last 30 days max

    res.status(200).json({
      success: true,
      count: stats.length,
      data: stats,
    })
  } catch (err) {
    next(err)
  }
})

module.exports = router
