package com.example.parental_control_app

import android.net.Uri
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

object BrowserTrackingHelper {
	private var lastCapturePackage = ""
	private var lastCaptureAt = 0L
	private const val CAPTURE_THROTTLE_MS = 2000L

	private val browserPackages = mapOf(
		"com.android.chrome" to "Chrome",
		"com.chrome.beta" to "Chrome Beta",
		"com.chrome.dev" to "Chrome Dev",
		"org.mozilla.firefox" to "Firefox",
		"org.mozilla.firefox_beta" to "Firefox Beta",
		"com.microsoft.emmx" to "Edge",
		"com.sec.android.app.sbrowser" to "Samsung Internet",
		"com.brave.browser" to "Brave",
		"com.opera.browser" to "Opera",
		"com.opera.mini.native" to "Opera Mini",
		"com.duckduckgo.mobile.android" to "DuckDuckGo",
	)

	private val urlBarViewIds = listOf(
		"url_bar",
		"search_box_text",
		"location_bar_edit_text",
		"mozac_browser_toolbar_url_view",
		"url_bar_title",
	)

	fun isBrowser(packageName: String): Boolean = browserPackages.containsKey(packageName)

	fun browserName(packageName: String): String = browserPackages[packageName] ?: "Browser"

	fun captureFromService(service: android.accessibilityservice.AccessibilityService, packageName: String) {
		val now = System.currentTimeMillis()
		if (packageName == lastCapturePackage && now - lastCaptureAt < CAPTURE_THROTTLE_MS) return

		val root = service.rootInActiveWindow ?: return
		try {
			val url = findUrlInNode(root) ?: return
			val normalized = normalizeUrl(url) ?: return
			if (normalized.length < 4 || normalized == "about:blank") return

			val title = findTitleInNode(root) ?: domainFromUrl(normalized)
			BrowsingEventStore.add(
				BrowsingEventStore.BrowsingEvent(
					url = normalized,
					domain = domainFromUrl(normalized),
					title = title,
					browserPackage = packageName,
					browserName = browserName(packageName),
					visitedAt = System.currentTimeMillis(),
				),
			)
			lastCapturePackage = packageName
			lastCaptureAt = now
		} finally {
			root.recycle()
		}
	}

	private fun findUrlInNode(root: AccessibilityNodeInfo): String? {
		for (viewId in urlBarViewIds) {
			val nodes = root.findAccessibilityNodeInfosByViewId("com.android.chrome:id/$viewId")
			if (nodes.isNullOrEmpty()) {
				val generic = findNodesByViewIdSuffix(root, viewId)
				for (node in generic) {
					val text = nodeText(node)
					node.recycle()
					if (looksLikeUrl(text)) return text
				}
			} else {
				for (node in nodes) {
					val text = nodeText(node)
					node.recycle()
					if (looksLikeUrl(text)) return text
				}
			}
		}
		return findUrlRecursive(root, 0)
	}

	private fun findNodesByViewIdSuffix(root: AccessibilityNodeInfo, suffix: String): List<AccessibilityNodeInfo> {
		val result = mutableListOf<AccessibilityNodeInfo>()
		collectNodesByViewIdSuffix(root, suffix, result, 0)
		return result
	}

	private fun collectNodesByViewIdSuffix(
		node: AccessibilityNodeInfo,
		suffix: String,
		result: MutableList<AccessibilityNodeInfo>,
		depth: Int,
	) {
		if (depth > 12) return
		val viewId = node.viewIdResourceName
		if (viewId != null && viewId.endsWith(suffix)) {
			result.add(AccessibilityNodeInfo.obtain(node))
		}
		for (i in 0 until node.childCount) {
			val child = node.getChild(i) ?: continue
			collectNodesByViewIdSuffix(child, suffix, result, depth + 1)
			child.recycle()
		}
	}

	private fun findUrlRecursive(node: AccessibilityNodeInfo, depth: Int): String? {
		if (depth > 14) return null
		val text = nodeText(node)
		if (looksLikeUrl(text)) return text
		for (i in 0 until node.childCount) {
			val child = node.getChild(i) ?: continue
			val found = findUrlRecursive(child, depth + 1)
			child.recycle()
			if (found != null) return found
		}
		return null
	}

	private fun findTitleInNode(root: AccessibilityNodeInfo): String? {
		val titleNodes = root.findAccessibilityNodeInfosByViewId("com.android.chrome:id/line_2")
		if (!titleNodes.isNullOrEmpty()) {
			val text = nodeText(titleNodes[0])
			titleNodes.forEach { it.recycle() }
			if (text.isNotBlank() && !looksLikeUrl(text)) return text
		}
		return null
	}

	private fun nodeText(node: AccessibilityNodeInfo): String {
		val text = node.text?.toString()?.trim().orEmpty()
		if (text.isNotEmpty()) return text
		return node.contentDescription?.toString()?.trim().orEmpty()
	}

	private fun looksLikeUrl(text: String?): Boolean {
		if (text.isNullOrBlank()) return false
		val value = text.trim()
		if (value.startsWith("http://") || value.startsWith("https://")) return true
		if (value.contains(' ') && !value.contains('.')) return false
		if (value.contains('.') && value.length >= 4 && !value.startsWith("Search")) {
			return value.matches(Regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*\\.[a-zA-Z]{2,}(/.*)?$"))
		}
		return false
	}

	private fun normalizeUrl(raw: String): String? {
		val trimmed = raw.trim()
		return when {
			trimmed.startsWith("http://") || trimmed.startsWith("https://") -> trimmed
			trimmed.contains('.') -> "https://$trimmed"
			else -> null
		}
	}

	fun domainFromUrl(url: String): String {
		return try {
			val uri = Uri.parse(url)
			uri.host?.removePrefix("www.") ?: url
		} catch (_: Exception) {
			url
		}
	}
}
