const User = require('../models/userModel');
const jwt = require('jsonwebtoken');

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

module.exports = { registerChild };
