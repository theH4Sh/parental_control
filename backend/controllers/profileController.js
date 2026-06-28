const User = require('../models/userModel');
const bcrypt = require('bcrypt');
const validator = require('validator');
const jwt = require('jsonwebtoken');

const createToken = (user) => {
  return jwt.sign(
    { _id: user._id, username: user.username, role: user.role },
    process.env.SECRET,
    { expiresIn: '3d' }
  );
};

const sanitizeUser = (user) => ({
  id: user._id,
  username: user.username,
  email: user.email,
  role: user.role,
  isVerified: user.isVerified,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
});

/**
 * GET /api/auth/me — current user profile
 */
const getProfile = async (req, res, next) => {
  try {
    res.status(200).json({ success: true, user: sanitizeUser(req.user) });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /api/auth/me — update username and/or email
 * Body: { username?, email?, currentPassword }
 */
const updateProfile = async (req, res, next) => {
  try {
    const { username, email, currentPassword } = req.body;
    const user = req.user;

    if (!currentPassword) {
      return res.status(400).json({ error: 'Current password is required' });
    }

    const match = await bcrypt.compare(currentPassword, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    if (!username && !email) {
      return res.status(400).json({ error: 'Provide a new username or email to update' });
    }

    if (username !== undefined) {
      const trimmed = username.trim();
      if (trimmed.length < 3) {
        return res.status(400).json({ error: 'Username must be at least 3 characters long' });
      }
      if (trimmed !== user.username) {
        const taken = await User.findOne({ username: trimmed });
        if (taken) {
          return res.status(409).json({ error: 'Username already taken' });
        }
        user.username = trimmed;
      }
    }

    if (email !== undefined) {
      const trimmed = email.trim().toLowerCase();
      if (!validator.isEmail(trimmed)) {
        return res.status(400).json({ error: 'Invalid email address' });
      }
      if (trimmed !== user.email) {
        const taken = await User.findOne({ email: trimmed });
        if (taken) {
          return res.status(409).json({ error: 'Email already in use' });
        }
        user.email = trimmed;
        if (user.role === 'parent') {
          user.isVerified = false;
        }
      }
    }

    await user.save();
    const token = createToken(user);

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: sanitizeUser(user),
      token,
      username: user.username,
      role: user.role,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /api/auth/me/password — change password
 * Body: { currentPassword, newPassword }
 */
const changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = req.user;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current password and new password are required' });
    }

    if (!validator.isStrongPassword(newPassword)) {
      return res.status(400).json({ error: 'New password is not strong enough' });
    }

    const match = await bcrypt.compare(currentPassword, user.password);
    if (!match) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.status(200).json({ success: true, message: 'Password changed successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getProfile, updateProfile, changePassword };
