const User = require('../models/userModel')

const canAccessChild = async (req, res, next) => {
  try {
    const parent = req.user
    const { childId } = req.params

    if (!childId) {
      return res.status(400).json({ error: 'Child ID is required' })
    }

    const child = await User.findById(childId)
    if (!child || child.role !== 'child') {
      return res.status(404).json({ error: 'Child not found' })
    }

    if (child.parent_id?.toString() !== parent._id.toString()) {
      return res.status(403).json({ error: 'Not authorized to access this child' })
    }

    req.child = child
    next()
  } catch (error) {
    next(error)
  }
}

module.exports = canAccessChild
