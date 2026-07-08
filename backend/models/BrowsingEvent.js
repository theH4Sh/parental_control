const mongoose = require('mongoose')

const browsingEventSchema = new mongoose.Schema(
  {
    deviceId: {
      type: String,
      required: true,
      index: true,
    },
    url: {
      type: String,
      required: true,
    },
    domain: {
      type: String,
      required: true,
      index: true,
    },
    title: {
      type: String,
      default: '',
    },
    browserPackage: {
      type: String,
      default: '',
    },
    browserName: {
      type: String,
      default: 'Browser',
    },
    visitedAt: {
      type: Date,
      required: true,
      index: true,
    },
  },
  { timestamps: true }
)

browsingEventSchema.index({ deviceId: 1, visitedAt: -1 })
browsingEventSchema.index({ deviceId: 1, url: 1, visitedAt: 1 })

module.exports = mongoose.model('BrowsingEvent', browsingEventSchema)
