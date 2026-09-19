package com.streamplayer.app

object M3uParser {
    private val attr = Regex("""([\w-]+)="([^"]*)"""")

    fun parse(text: String): List<MediaEntry> {
        val out = ArrayList<MediaEntry>()
        var pending: MediaEntry? = null
        text.lineSequence().forEach { raw ->
            val line = raw.trim()
            when {
                line.startsWith("#EXTINF", ignoreCase = true) -> {
                    val attrs = attr.findAll(line).associate { it.groupValues[1] to it.groupValues[2] }
                    val name = line.substringAfterLast(',', attrs["tvg-name"] ?: "Canal").trim()
                    pending = MediaEntry(
                        name = name.ifBlank { attrs["tvg-name"] ?: "Canal" },
                        url = "",
                        logo = attrs["tvg-logo"],
                        group = attrs["group-title"].orEmpty().ifBlank { "Outros" },
                        tvgId = attrs["tvg-id"],
                        channelNumber = attrs["tvg-chno"]
                    )
                }
                line.isNotBlank() && !line.startsWith("#") && pending != null -> {
                    out += pending!!.copy(url = line)
                    pending = null
                }
            }
        }
        return out
    }
}
