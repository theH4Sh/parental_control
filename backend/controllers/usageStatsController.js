const User = require('../models/userModel');
const UsageStats = require('../models/UsageStats');

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

    const result = children.map((child) => ({
      childId: child._id.toString(),
      username: child.username,
      email: child.email,
      deviceId: child.deviceId || null,
      usage: child.deviceId ? statsByDevice[child.deviceId] || null : null,
    }));

    res.status(200).json({ success: true, date, children: result });
  } catch (error) {
    next(error);
  }
};

module.exports = { getChildrenUsageSummary };
