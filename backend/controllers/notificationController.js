const { sendToUser, isUserConnected } = require('../services/websocketService')

const NOTIFICATION_TYPES = ['custom', 'bedtime', 'time_limit']

const sendChildNotification = async (req, res, next) => {
  try {
    const { type = 'custom', title, body } = req.body
    const child = req.child

    if (!NOTIFICATION_TYPES.includes(type)) {
      return res.status(400).json({ error: 'Invalid notification type' })
    }

    let notificationTitle = title
    let notificationBody = body

    if (type === 'bedtime') {
      notificationTitle = title || '🌙 Bedtime'
      notificationBody = body || 'It\'s time to put your device away and get some rest!'
    } else if (type === 'time_limit') {
      notificationTitle = title || '⏰ Screen Time Limit'
      notificationBody = body || 'You\'ve reached your daily screen time limit.'
    } else {
      if (!notificationTitle || !notificationBody) {
        return res.status(400).json({ error: 'Title and body are required for custom notifications' })
      }
    }

    const payload = {
      title: notificationTitle,
      body: notificationBody,
      notificationType: type,
      sentAt: new Date().toISOString(),
    }

    const delivered = sendToUser(child._id, {
      type: 'notification',
      payload,
    })

    res.status(200).json({
      success: true,
      delivered,
      online: isUserConnected(child._id),
      message: delivered
        ? 'Notification sent to child device'
        : 'Child device is offline — notification will not be delivered until they reconnect',
    })
  } catch (error) {
    next(error)
  }
}

module.exports = { sendChildNotification }
