const mongoose = require('mongoose')

const childSettingsSchema = new mongoose.Schema(
  {
    childId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    dailyTimeLimitMs: {
      type: Number,
      default: 0, // 0 = no limit
    },
    bedtimeHour: {
      type: Number,
      default: 21,
      min: 0,
      max: 23,
    },
    bedtimeMinute: {
      type: Number,
      default: 0,
      min: 0,
      max: 59,
    },
    bedtimeEnabled: {
      type: Boolean,
      default: false,
    },
    lockDeviceOnLimit: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
)

module.exports = mongoose.model('ChildSettings', childSettingsSchema)
