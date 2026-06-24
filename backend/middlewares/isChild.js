const isChild = (req, res, next) => {
  const user = req.user
  if (!user) return res.status(401).json({ error: 'Not authenticated' })

  if (user.role !== 'child') {
    return res.status(403).json({ error: 'Child access required' })
  }

  next()
}

module.exports = isChild
