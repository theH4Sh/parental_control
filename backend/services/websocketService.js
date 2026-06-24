const WebSocket = require('ws')
const jwt = require('jsonwebtoken')
const url = require('url')

const clients = new Map()

function initWebSocket(server) {
  const wss = new WebSocket.Server({ server, path: '/ws' })

  wss.on('connection', (ws, req) => {
    const { query } = url.parse(req.url, true)
    const token = query.token

    if (!token) {
      ws.close(4001, 'Missing token')
      return
    }

    let decoded
    try {
      decoded = jwt.verify(token, process.env.SECRET)
    } catch {
      ws.close(4002, 'Invalid token')
      return
    }

    const userId = decoded._id.toString()
    clients.set(userId, ws)
    console.log(`🔌 WebSocket connected: user ${userId} (${decoded.role})`)

    ws.send(JSON.stringify({ type: 'connected', payload: { userId } }))

    ws.on('close', () => {
      if (clients.get(userId) === ws) {
        clients.delete(userId)
      }
      console.log(`🔌 WebSocket disconnected: user ${userId}`)
    })

    ws.on('error', (err) => {
      console.error(`WebSocket error for user ${userId}:`, err.message)
    })
  })

  console.log('✅ WebSocket server ready at /ws')
}

function sendToUser(userId, message) {
  const ws = clients.get(userId.toString())
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message))
    return true
  }
  return false
}

function isUserConnected(userId) {
  const ws = clients.get(userId.toString())
  return ws != null && ws.readyState === WebSocket.OPEN
}

module.exports = { initWebSocket, sendToUser, isUserConnected }
