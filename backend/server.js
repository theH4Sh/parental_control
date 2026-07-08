const express = require('express')
const http = require('http')
const mongoose = require('mongoose')
const morgan = require('morgan')
const cors = require('cors')
require('dotenv').config()

const userRoutes = require('./routes/userRoutes')
const usageStatsRoutes = require('./routes/usageStats')
const browsingRoutes = require('./routes/browsingRoutes')
const { initWebSocket } = require('./services/websocketService')

const app = express()

// Middleware
app.use(express.json({ limit: '10mb' }))
app.use(cors())
app.use(morgan('dev'))

// MongoDB Connection
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('✅ MongoDB Connected'))
  .catch((err) => console.log('❌ MongoDB Error:', err))

// API Routes
app.use('/api', usageStatsRoutes)
app.use('/api', browsingRoutes)
app.use('/api/auth', userRoutes)

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// Error Handling
app.use((err, req, res, next) => {
  console.error(err.stack)
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
  })
})

const port = process.env.PORT || 8000
const server = http.createServer(app)
initWebSocket(server)

server.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Server running on port: ${port}`)
})
