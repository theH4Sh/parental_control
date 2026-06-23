const express = require('express');
const { loginUser, signUpUser, getUser, verifyEmail, forgotPassword, resetPassword } = require('../controllers/userController');
const { registerChild, getChildren } = require('../controllers/childController');
const { getChildrenUsageSummary } = require('../controllers/usageStatsController');
const requireAuth = require('../middlewares/requireAuth');
const isParent = require('../middlewares/isParent');
const isVerified = require('../middlewares/isVerified');

const router = express.Router();

// Auth routes
router.post('/login', loginUser);
router.post('/signup', signUpUser);
router.get('/verify/:token', verifyEmail);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password/:token', resetPassword);

// Protected routes
router.get('/children/usage-summary', requireAuth, isVerified, isParent, getChildrenUsageSummary);
router.get('/children', requireAuth, isVerified, isParent, getChildren);
router.get('/:username', requireAuth, isVerified, getUser);
router.post('/children', requireAuth, isVerified, isParent, registerChild);

module.exports = router;