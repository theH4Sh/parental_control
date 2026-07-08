const express = require('express');
const { loginUser, signUpUser, getUser, verifyEmail, forgotPassword, resetPassword } = require('../controllers/userController');
const { registerChild, getChildren, getChildProfile, updateChildProfile, resetChildPassword } = require('../controllers/childController');
const { getChildrenUsageSummary } = require('../controllers/usageStatsController');
const { getChildSettings, updateChildSettings, getMySettings } = require('../controllers/childSettingsController');
const { sendChildNotification } = require('../controllers/notificationController');
const { getProfile, updateProfile, changePassword } = require('../controllers/profileController');
const { getChildBrowsingHistory } = require('../controllers/browsingController');
const requireAuth = require('../middlewares/requireAuth');
const isParent = require('../middlewares/isParent');
const isChild = require('../middlewares/isChild');
const isVerified = require('../middlewares/isVerified');
const canAccessChild = require('../middlewares/canAccessChild');

const router = express.Router();

// Auth routes
router.post('/login', loginUser);
router.post('/signup', signUpUser);
router.get('/verify/:token', verifyEmail);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);

// Protected routes — specific paths before /:username
router.get('/me', requireAuth, isVerified, getProfile);
router.put('/me', requireAuth, isVerified, updateProfile);
router.put('/me/password', requireAuth, isVerified, changePassword);
router.get('/children/usage-summary', requireAuth, isVerified, isParent, getChildrenUsageSummary);
router.get('/children/:childId/settings', requireAuth, isVerified, isParent, canAccessChild, getChildSettings);
router.put('/children/:childId/settings', requireAuth, isVerified, isParent, canAccessChild, updateChildSettings);
router.get('/children/:childId/profile', requireAuth, isVerified, isParent, canAccessChild, getChildProfile);
router.put('/children/:childId/profile', requireAuth, isVerified, isParent, canAccessChild, updateChildProfile);
router.put('/children/:childId/password', requireAuth, isVerified, isParent, canAccessChild, resetChildPassword);
router.post('/children/:childId/notify', requireAuth, isVerified, isParent, canAccessChild, sendChildNotification);
router.get('/children/:childId/browsing-history', requireAuth, isVerified, isParent, canAccessChild, getChildBrowsingHistory);
router.get('/my-settings', requireAuth, isVerified, isChild, getMySettings);
router.get('/children', requireAuth, isVerified, isParent, getChildren);
router.post('/children', requireAuth, isVerified, isParent, registerChild);
router.get('/:username', requireAuth, isVerified, getUser);

module.exports = router;
