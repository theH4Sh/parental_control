const User = require('../models/userModel');
const UsageStats = require('../models/UsageStats');
const ChildSettings = require('../models/ChildSettings');
const { formatSettings } = require('./childSettingsController');

/**
 * Returns today's usage stats for all children belonging to the authenticated parent.
 * Optional query: ?date=yyyy-MM-dd (defaults to today)
 */
const getChildrenUsageSummary = async (req, res, next) => {
  try {
    const parent = req.user;
    const date = req.query.date || new Date().toISOString().substring(0, 10);

    const children = await User.find({ parent_id: parent._id }).select('-password').lean();

    const deviceIds = children
      .filter((c) => c.deviceId)
      .map((c) => c.deviceId);

    const statsByDevice = {};
    if (deviceIds.length > 0) {
      const stats = await UsageStats.find({ deviceId: { $in: deviceIds }, date }).lean();
      stats.forEach((s) => {
        statsByDevice[s.deviceId] = s;
      });
    }

    const childIds = children.map((c) => c._id);

    const settingsByChild = {};
    if (childIds.length > 0) {
      const allSettings = await ChildSettings.find({ childId: { $in: childIds } }).lean();
      allSettings.forEach((s) => {
        settingsByChild[s.childId.toString()] = formatSettings(s);
      });
    }

    const result = children.map((child) => {
      const childIdStr = child._id.toString();
      return {
        childId: childIdStr,
        username: child.username,
        email: child.email,
        deviceId: child.deviceId || null,
        usage: child.deviceId ? statsByDevice[child.deviceId] || null : null,
        settings: settingsByChild[childIdStr] || {
          childId: childIdStr,
          dailyTimeLimitMs: 0,
          bedtimeHour: 21,
          bedtimeMinute: 0,
          bedtimeEnabled: false,
        },
      };
    });

    res.status(200).json({ success: true, date, children: result });
  } catch (error) {
    next(error);
  }
};

module.exports = { getChildrenUsageSummary };
