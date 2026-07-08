package com.example.parental_control_app

object BrowsingEventStore {
	data class BrowsingEvent(
		val url: String,
		val domain: String,
		val title: String,
		val browserPackage: String,
		val browserName: String,
		val visitedAt: Long,
	)

	private val events = mutableListOf<BrowsingEvent>()
	private val lock = Any()
	private var lastUrl = ""
	private var lastUrlAt = 0L
	private const val MAX_EVENTS = 300
	private const val DEDUPE_MS = 8000L

	fun add(event: BrowsingEvent) {
		synchronized(lock) {
			if (event.url == lastUrl && event.visitedAt - lastUrlAt < DEDUPE_MS) return
			lastUrl = event.url
			lastUrlAt = event.visitedAt
			events.add(event)
			while (events.size > MAX_EVENTS) {
				events.removeAt(0)
			}
		}
	}

	fun drain(): List<Map<String, Any?>> {
		synchronized(lock) {
			if (events.isEmpty()) return emptyList()
			val copy = events.map { event ->
				mapOf(
					"url" to event.url,
					"domain" to event.domain,
					"title" to event.title,
					"browserPackage" to event.browserPackage,
					"browserName" to event.browserName,
					"visitedAt" to event.visitedAt,
				)
			}
			events.clear()
			return copy
		}
	}

	fun pendingCount(): Int = synchronized(lock) { events.size }
}
