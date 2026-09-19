package com.streamplayer.app

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URI
import javax.net.ssl.SSLException

class AppViewModel(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("stream_player", Context.MODE_PRIVATE)
    private val _playlists = MutableStateFlow(loadPlaylists())
    val playlists: StateFlow<List<Playlist>> = _playlists.asStateFlow()
    private val _entries = MutableStateFlow<List<MediaEntry>>(emptyList())
    val entries: StateFlow<List<MediaEntry>> = _entries.asStateFlow()
    private val _busy = MutableStateFlow<String?>(null)
    val busy: StateFlow<String?> = _busy.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun clearError() { _error.value = null }

    fun addUrl(name: String, url: String) = viewModelScope.launch {
        _busy.value = "Baixando lista..."
        runCatching {
            val body = withContext(Dispatchers.IO) {
                val c = URL(url).openConnection() as HttpURLConnection
                c.connectTimeout = 15000
                c.readTimeout = 30000
                c.setRequestProperty("User-Agent", "StreamPlayer/1.0")
                c.inputStream.bufferedReader().use { it.readText() }
            }
            val parsed = withContext(Dispatchers.Default) { M3uParser.parse(body) }
            require(parsed.isNotEmpty()) { "Nenhum item M3U válido encontrado." }
            val p = Playlist(name = name.ifBlank { "Minha lista" }, source = url, itemCount = parsed.size)
            _playlists.value = _playlists.value + p
            _entries.value = parsed
            savePlaylists()
            saveEntries(parsed)
        }.onFailure { _error.value = it.message ?: "Não foi possível importar a lista." }
        _busy.value = null
    }

    private fun downloadPlaylist(rawUrl: String): String {
        val original = rawUrl.trim()
        require(original.startsWith("http://", true) || original.startsWith("https://", true)) {
            "A URL deve começar com http:// ou https://"
        }

        var current = original
        repeat(6) {
            try {
                val connection = (URL(current).openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false
                    connectTimeout = 15000
                    readTimeout = 45000
                    requestMethod = "GET"
                    setRequestProperty("User-Agent", "Mozilla/5.0 (Android) StreamPlayer/1.1")
                    setRequestProperty("Accept", "*/*")
                    setRequestProperty("Accept-Encoding", "identity")
                    setRequestProperty("Connection", "close")
                }

                val code = connection.responseCode
                if (code in 200..299) {
                    return connection.inputStream.bufferedReader().use { it.readText() }
                }

                if (code in 300..399) {
                    val location = connection.getHeaderField("Location")
                        ?: error("O servidor redirecionou a lista sem informar o novo endereço.")
                    val redirected = URI(current).resolve(location).toString()
                    val from = URI(current)
                    val to = URI(redirected)
                    current = if (
                        from.scheme.equals("http", true) &&
                        to.scheme.equals("https", true) &&
                        from.host.equals(to.host, true) &&
                        effectivePort(from) == effectivePort(to)
                    ) {
                        redirected.replaceFirst(Regex("^https://", RegexOption.IGNORE_CASE), "http://")
                    } else {
                        redirected
                    }
                    return@repeat
                }

                val errorText = connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                error("Servidor retornou HTTP " + code + if (errorText.isNotBlank()) ": " + errorText.take(160) else "")
            } catch (e: SSLException) {
                if (current.startsWith("https://", true)) {
                    current = current.replaceFirst(Regex("^https://", RegexOption.IGNORE_CASE), "http://")
                    return@repeat
                }
                throw e
            } catch (e: java.io.IOException) {
                val msg = e.message.orEmpty()
                if (
                    current.startsWith("https://", true) &&
                    (msg.contains("TLS", true) || msg.contains("SSL", true) || msg.contains("packet header", true))
                ) {
                    current = current.replaceFirst(Regex("^https://", RegexOption.IGNORE_CASE), "http://")
                    return@repeat
                }
                throw e
            }
        }
        error("Muitos redirecionamentos ao tentar baixar a lista.")
    }

    private fun effectivePort(uri: URI): Int =
        if (uri.port != -1) uri.port else if (uri.scheme.equals("https", true)) 443 else 80

    fun addFile(name: String, uri: Uri) = viewModelScope.launch {
        _busy.value = "Processando arquivo..."
        runCatching {
            val body = withContext(Dispatchers.IO) {
                getApplication<Application>().contentResolver.openInputStream(uri)!!.bufferedReader().use { it.readText() }
            }
            val parsed = withContext(Dispatchers.Default) { M3uParser.parse(body) }
            require(parsed.isNotEmpty()) { "Nenhum item M3U válido encontrado." }
            val p = Playlist(name = name.ifBlank { "Lista importada" }, source = uri.toString(), isFile = true, itemCount = parsed.size)
            _playlists.value = _playlists.value + p
            _entries.value = parsed
            savePlaylists()
            saveEntries(parsed)
        }.onFailure { _error.value = it.message ?: "Falha ao ler o arquivo." }
        _busy.value = null
    }

    fun deletePlaylist(id: Long) {
        _playlists.value = _playlists.value.filterNot { it.id == id }
        if (_playlists.value.isEmpty()) {
            _entries.value = emptyList()
            prefs.edit().remove("entries").apply()
        }
        savePlaylists()
    }

    fun loadCached() {
        if (_entries.value.isEmpty()) _entries.value = loadEntries()
    }

    private fun savePlaylists() {
        val a = JSONArray()
        _playlists.value.forEach { p ->
            a.put(JSONObject().put("id", p.id).put("name", p.name).put("source", p.source).put("file", p.isFile).put("count", p.itemCount))
        }
        prefs.edit().putString("playlists", a.toString()).apply()
    }

    private fun loadPlaylists(): List<Playlist> = runCatching {
        val a = JSONArray(prefs.getString("playlists", "[]"))
        List(a.length()) { i ->
            val o = a.getJSONObject(i)
            Playlist(o.getLong("id"), o.getString("name"), o.getString("source"), o.optBoolean("file"), o.optInt("count"))
        }
    }.getOrDefault(emptyList())

    private fun saveEntries(list: List<MediaEntry>) {
        val a = JSONArray()
        list.take(5000).forEach { e ->
            a.put(JSONObject().put("n", e.name).put("u", e.url).put("l", e.logo).put("g", e.group).put("t", e.tvgId).put("c", e.channelNumber))
        }
        prefs.edit().putString("entries", a.toString()).apply()
    }

    private fun loadEntries(): List<MediaEntry> = runCatching {
        val a = JSONArray(prefs.getString("entries", "[]"))
        List(a.length()) { i ->
            val o = a.getJSONObject(i)
            MediaEntry(
                o.getString("n"),
                o.getString("u"),
                o.optString("l").ifBlank { null },
                o.optString("g", "Outros"),
                o.optString("t").ifBlank { null },
                o.optString("c").ifBlank { null }
            )
        }
    }.getOrDefault(emptyList())
}
