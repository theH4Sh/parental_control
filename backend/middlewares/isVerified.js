const jwt = require('jsonwebtoken');
const User = require('../models/userModel');

/**
 * Middleware that checks if the authenticated user (req.user set by requireAuth) has
 * a verified email (isVerified flag). If not, it returns a 403 response.
 */
const isVerified = async (req, res, next) => {
  try {
    // req.user should already contain the decoded JWT payload
    const { _id } = req.user;
    if (!_id) {
      return res.status(401).json({ error: 'User not authenticated' });
    }
    const user = await User.findById(_id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (!user.isVerified) {
      return res.status(403).json({ error: 'Email not verified' });
    }
    // attach full user object for downstream handlers if needed
    req.user = user;
    next();
  } catch (err) {
    console.error('isVerified middleware error:', err);
    res.status(500).json({ error: 'Server error in verification check' });
  }
};

module.exports = isVerified;
