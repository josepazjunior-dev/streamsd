package com.streamplayer.app

data class Playlist(
    val id: Long = System.currentTimeMillis(),
    val name: String,
    val source: String,
    val isFile: Boolean = false,
    val itemCount: Int = 0,
)

data class MediaEntry(
    val name: String,
    val url: String,
    val logo: String? = null,
    val group: String = "Outros",
    val tvgId: String? = null,
    val channelNumber: String? = null,
) {
    val mediaType: MediaType
        get() {
            val text = "$group $name".lowercase()
            return when {
                listOf("serie", "series", "temporada", "season").any { it in text } -> MediaType.SERIES
                listOf("filme", "filmes", "movie", "vod", "cinema").any { it in text } -> MediaType.MOVIE
                else -> MediaType.LIVE
            }
        }
}

enum class MediaType { LIVE, MOVIE, SERIES }
