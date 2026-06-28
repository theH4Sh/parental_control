const User = require('../models/userModel');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const validator = require('validator');

const sanitizeChild = (user) => ({
  id: user._id,
  username: user.username,
  email: user.email,
  role: user.role,
  isVerified: user.isVerified,
  deviceId: user.deviceId || null,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
});

/**
 * Register a child account. Only a verified parent can call this endpoint.
 * The parent (req.user) must have role 'parent' and be verified (handled by middleware).
 * Request body should contain: username, email, password.
 * The created child will have its `parent_id` set to the parent's _id and role set to 'child'.
 */
const registerChild = async (req, res, next) => {
  const { username, email, password } = req.body;
  const parent = req.user; // set by requireAuth & isVerified & isParent

  try {
    // Basic validation
    if (!username || !email || !password) {
      return res.status(400).json({ error: 'All fields are required' });
    }

    // Ensure the parent is indeed a parent (middleware already checks)
    if (parent.role !== 'parent') {
      return res.status(403).json({ error: 'Only parents can register children' });
    }

    // Use existing signup logic but force role to 'child' and link parent_id
    // Reuse the same validation from User.signup (username, email, password)
    const existing = await User.findOne({ $or: [{ email }, { username }] });
    if (existing) {
      return res.status(409).json({ error: 'User with given email or username already exists' });
    }

    // Hash password using same bcrypt flow as signup
    const bcrypt = require('bcrypt');
    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(password, salt);

    const child = await User.create({
      username,
      email,
      password: hash,
      role: 'child',
      parent_id: parent._id,
      isVerified: true // children can be considered verified by default (or you could add extra flow)
    });

    // Issue a token for the newly created child (optional, here we return it)
    const token = jwt.sign({ _id: child._id, role: child.role }, process.env.SECRET, { expiresIn: '3d' });

    res.status(201).json({ message: 'Child registered successfully', childId: child._id, token });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all registered children for the authenticated parent.
 */
const getChildren = async (req, res, next) => {
  const parent = req.user; // set by requireAuth

  try {
    const children = await User.find({ parent_id: parent._id }).select('-password');
    res.status(200).json({ success: true, children });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/auth/children/:childId/profile — parent fetches a child's account details
 */
const getChildProfile = async (req, res, next) => {
  try {
    res.status(200).json({ success: true, user: sanitizeChild(req.child) });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /api/auth/children/:childId/profile — parent updates child's username and/or email
 * Body: { username?, email? }
 */
const updateChildProfile = async (req, res, next) => {
  try {
    const { username, email } = req.body;
    const child = req.child;

    if (!username && !email) {
      return res.status(400).json({ error: 'Provide a new username or email to update' });
    }

    if (username !== undefined) {
      const trimmed = username.trim();
      if (trimmed.length < 3) {
        return res.status(400).json({ error: 'Username must be at least 3 characters long' });
      }
      if (trimmed !== child.username) {
        const taken = await User.findOne({ username: trimmed });
        if (taken) {
          return res.status(409).json({ error: 'Username already taken' });
        }
        child.username = trimmed;
      }
    }

    if (email !== undefined) {
      const trimmed = email.trim().toLowerCase();
      if (!validator.isEmail(trimmed)) {
        return res.status(400).json({ error: 'Invalid email address' });
      }
      if (trimmed !== child.email) {
        const taken = await User.findOne({ email: trimmed });
        if (taken) {
          return res.status(409).json({ error: 'Email already in use' });
        }
        child.email = trimmed;
      }
    }

    await child.save();

    res.status(200).json({
      success: true,
      message: 'Child profile updated successfully',
      user: sanitizeChild(child),
    });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /api/auth/children/:childId/password — parent resets child's password
 * Body: { newPassword }
 */
const resetChildPassword = async (req, res, next) => {
  try {
    const { newPassword } = req.body;
    const child = req.child;

    if (!newPassword) {
      return res.status(400).json({ error: 'New password is required' });
    }

    if (!validator.isStrongPassword(newPassword)) {
      return res.status(400).json({ error: 'Password is not strong enough' });
    }

    const salt = await bcrypt.genSalt(10);
    child.password = await bcrypt.hash(newPassword, salt);
    await child.save();

    res.status(200).json({ success: true, message: 'Child password updated successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerChild,
  getChildren,
  getChildProfile,
  updateChildProfile,
  resetChildPassword,
};
