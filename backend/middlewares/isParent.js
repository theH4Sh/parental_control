const isParent = (req, res, next) => {
    const user = req.user // assume requireAuth already decoded the JWT
    if (!user) return res.status(401).json({ error: 'Not authenticated' })

    if (user.role !== 'parent') {
        return res.status(403).json({ error: 'Parent access required' })
    }

    next()
}

module.exports = isParent