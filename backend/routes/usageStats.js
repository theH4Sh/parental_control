const express = require('express')
const mongoose = require('mongoose')
const UsageStats = require('../models/UsageStats')
const User = require('../models/userModel')
const ChildSettings = require('../models/ChildSettings')
const { sendToUser } = require('../services/websocketService')

const router = express.Router()

// POST /api/register-device
// Registers a new device (or re-links an existing one) and returns deviceId.
// When authenticated as a child, associates deviceId with that user account.
router.post('/register-device', async (req, res, next) => {
  try {
    let deviceId = req.body?.deviceId || null
    if (!deviceId) {
      deviceId = new mongoose.Types.ObjectId().toString()
    }

    const authorization = req.headers.authorization
    if (authorization) {
      const jwt = require('jsonwebtoken')
      const User = require('../models/userModel')
      try {
        const token = authorization.split(' ')[1]
        const decoded = jwt.verify(token, process.env.SECRET)
        if (decoded && decoded._id) {
          const user = await User.findById(decoded._id)
          if (user && user.role === 'child') {
            await User.findByIdAndUpdate(decoded._id, { deviceId })
            console.log(`Associated deviceId ${deviceId} with child user ${decoded._id}`)
          }
        }
      } catch (err) {
        console.error('Failed to associate device with user:', err.message)
      }
    }

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

    const existingBefore = await UsageStats.findOne({ deviceId, date })
    const previousTotal = existingBefore?.totalScreenTimeMs ?? 0

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

    // Notify child via WebSocket if they exceeded their daily limit
    const childUser = await User.findOne({ deviceId, role: 'child' })
    if (childUser) {
      const settings = await ChildSettings.findOne({ childId: childUser._id })
      if (
        settings &&
        settings.dailyTimeLimitMs > 0 &&
        previousTotal < settings.dailyTimeLimitMs &&
        totalScreenTimeMs >= settings.dailyTimeLimitMs
      ) {
        sendToUser(childUser._id, {
          type: 'notification',
          payload: {
            title: '⏰ Time\'s Up!',
            body: 'You\'ve reached your daily screen time limit. Please take a break and put your device away!',
            notificationType: 'time_limit',
            sentAt: new Date().toISOString(),
          },
        })
      }
    }

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
