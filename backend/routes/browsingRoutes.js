const express = require('express')
const { syncBrowsingEvents } = require('../controllers/browsingController')

const router = express.Router()

router.post('/browsing-events', syncBrowsingEvents)

module.exports = router
