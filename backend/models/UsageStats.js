const mongoose = require('mongoose')

const appUsageSchema = new mongoose.Schema({
  packageName: { type: String, required: true },
  displayName: { type: String, required: true },
  totalMs: { type: Number, required: true, default: 0 },
}, { _id: false })

const usageStatsSchema = new mongoose.Schema({
  deviceId: {
    type: String,
    required: true,
    index: true,
  },
  date: {
    type: String, // Format: yyyy-MM-dd
    required: true,
    index: true,
  },
  deviceInfo: {
    type: String,
    default: 'Unknown Device',
  },
  totalScreenTimeMs: {
    type: Number,
    default: 0,
  },
  apps: [appUsageSchema],
}, {
  timestamps: true, // adds createdAt and updatedAt
})

// Compound index for efficient upserts — one doc per device per day
usageStatsSchema.index({ deviceId: 1, date: 1 }, { unique: true })

module.exports = mongoose.model('UsageStats', usageStatsSchema)
