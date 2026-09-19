package com.streamplayer.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

private val Bg=Color(0xFF05070D); private val Panel=Color(0xFF0B111C); private val Primary=Color(0xFF008CFF); private val Muted=Color(0xFF9AA8BA)

class MainActivity:ComponentActivity(){
    private val vm:AppViewModel by viewModels()
    override fun onCreate(savedInstanceState:Bundle?){
        super.onCreate(savedInstanceState);enableEdgeToEdge();vm.loadCached()
        setContent{MaterialTheme(colorScheme=darkColorScheme(primary=Primary,background=Bg,surface=Panel)){StreamApp(vm)}}
    }
}
private enum class Screen{HOME,CONTENT,LISTS,PLAYER}

@Composable private fun StreamApp(vm:AppViewModel){
    var screen by remember{mutableStateOf(Screen.HOME)};var type by remember{mutableStateOf(MediaType.LIVE)};var playing by remember{mutableStateOf<MediaEntry?>(null)}
    val playlists by vm.playlists.collectAsState();val entries by vm.entries.collectAsState();val busy by vm.busy.collectAsState();val error by vm.error.collectAsState()
    Surface(Modifier.fillMaxSize(),color=Bg){
        when(screen){
            Screen.HOME->HomeScreen(playlists.isEmpty(),{type=it;screen=Screen.CONTENT},{screen=Screen.LISTS})
            Screen.CONTENT->ContentScreen(type,entries.filter{it.mediaType==type},{screen=Screen.HOME},{playing=it;screen=Screen.PLAYER})
            Screen.LISTS->PlaylistScreen(vm){screen=Screen.HOME}
            Screen.PLAYER->playing?.let{PlayerScreen(it){screen=Screen.CONTENT}}
        }
        if(busy!=null)Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.65f)),contentAlignment=Alignment.Center){Column(horizontalAlignment=Alignment.CenterHorizontally){CircularProgressIndicator();Spacer(Modifier.height(12.dp));Text(busy!!)}}
        error?.let{AlertDialog(onDismissRequest=vm::clearError,confirmButton={TextButton(onClick=vm::clearError){Text("OK")}},title={Text("Não foi possível concluir")},text={Text(it)})}
    }
}

@Composable private fun HomeScreen(empty:Boolean,onType:(MediaType)->Unit,onLists:()->Unit){
    Column(Modifier.fillMaxSize().padding(24.dp)){
        Row(verticalAlignment=Alignment.CenterVertically){Icon(Icons.Default.PlayCircle,null,tint=Primary,modifier=Modifier.size(42.dp));Spacer(Modifier.width(10.dp));Column{Text("STREAM PLAYER",fontWeight=FontWeight.Bold,style=MaterialTheme.typography.headlineSmall);Text("Seu conteúdo. Seu player.",color=Muted)};Spacer(Modifier.weight(1f));IconButton(onClick=onLists){Icon(Icons.Default.Settings,"Listas")}}
        Spacer(Modifier.height(28.dp));Text("Início",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold);Spacer(Modifier.height(16.dp))
        LazyRow(horizontalArrangement=Arrangement.spacedBy(12.dp)){item{HeroCard("TV AO VIVO",Icons.Default.LiveTv){onType(MediaType.LIVE)}};item{HeroCard("FILMES",Icons.Default.Movie){onType(MediaType.MOVIE)}};item{HeroCard("SÉRIES",Icons.Default.VideoLibrary){onType(MediaType.SERIES)}}}
        Spacer(Modifier.height(28.dp))
        if(empty)Card(colors=CardDefaults.cardColors(containerColor=Panel),modifier=Modifier.fillMaxWidth()){Column(Modifier.padding(24.dp)){Icon(Icons.Default.PlaylistAdd,null,tint=Primary,modifier=Modifier.size(44.dp));Spacer(Modifier.height(12.dp));Text("Nenhuma lista adicionada",fontWeight=FontWeight.Bold,style=MaterialTheme.typography.titleLarge);Text("Adicione sua própria lista M3U/M3U8 para começar.",color=Muted);Spacer(Modifier.height(16.dp));Button(onClick=onLists){Icon(Icons.Default.Add,null);Spacer(Modifier.width(6.dp));Text("ADICIONAR LISTA")}}}
        else{Text("Acesso rápido",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold);Spacer(Modifier.height(8.dp));Text("Abra TV, Filmes ou Séries usando os cards acima.",color=Muted)}
    }
}
@Composable private fun HeroCard(title:String,icon:androidx.compose.ui.graphics.vector.ImageVector,onClick:()->Unit){Card(modifier=Modifier.width(210.dp).height(120.dp).clickable(onClick=onClick),colors=CardDefaults.cardColors(containerColor=Color(0xFF111A28))){Column(Modifier.fillMaxSize().padding(18.dp),verticalArrangement=Arrangement.SpaceBetween){Icon(icon,null,tint=Primary,modifier=Modifier.size(38.dp));Text(title,fontWeight=FontWeight.Bold)}}}

@Composable private fun ContentScreen(type:MediaType,list:List<MediaEntry>,onBack:()->Unit,onPlay:(MediaEntry)->Unit){
    var q by remember{mutableStateOf("")};var group by remember{mutableStateOf("Todos")};val groups=remember(list){list.map{it.group}.distinct().take(200)};val filtered=remember(list,q,group){list.filter{(group=="Todos"||it.group==group)&&it.name.contains(q,true)}}
    Column(Modifier.fillMaxSize().padding(16.dp)){
        Row(verticalAlignment=Alignment.CenterVertically){IconButton(onClick=onBack){Icon(Icons.Default.ArrowBack,"Voltar")};Text(when(type){MediaType.LIVE->"TV ao Vivo";MediaType.MOVIE->"Filmes";MediaType.SERIES->"Séries"},style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold)}
        OutlinedTextField(q,{q=it},label={Text("Pesquisar")},leadingIcon={Icon(Icons.Default.Search,null)},modifier=Modifier.fillMaxWidth());Spacer(Modifier.height(10.dp))
        LazyRow(horizontalArrangement=Arrangement.spacedBy(8.dp)){item{FilterChip(group=="Todos",{group="Todos"},{Text("Todos")})};items(groups){g->FilterChip(group==g,{group=g},{Text(g,maxLines=1)})}}
        Spacer(Modifier.height(8.dp));Text(filtered.size.toString()+" itens",color=Muted)
        LazyColumn(contentPadding=PaddingValues(vertical=8.dp),verticalArrangement=Arrangement.spacedBy(6.dp)){items(filtered,key={it.url}){e->Card(modifier=Modifier.fillMaxWidth().clickable{onPlay(e)},colors=CardDefaults.cardColors(containerColor=Panel)){Row(Modifier.padding(14.dp),verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(48.dp).background(Color(0xFF111A28)),contentAlignment=Alignment.Center){Icon(Icons.Default.PlayArrow,null,tint=Primary)};Spacer(Modifier.width(12.dp));Column(Modifier.weight(1f)){Text(e.name,fontWeight=FontWeight.SemiBold);Text(e.group,color=Muted,style=MaterialTheme.typography.bodySmall)};Icon(Icons.Default.ChevronRight,null)}}}}
    }
}

@Composable private fun PlaylistScreen(vm:AppViewModel,onBack:()->Unit){
    val playlists by vm.playlists.collectAsState();var name by remember{mutableStateOf("")};var url by remember{mutableStateOf("")};var deleteTarget by remember{mutableStateOf<Playlist?>(null)}
    val picker=androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.OpenDocument()){u->if(u!=null)vm.addFile(name,u)}
    Column(Modifier.fillMaxSize().padding(16.dp)){
        Row(verticalAlignment=Alignment.CenterVertically){IconButton(onClick=onBack){Icon(Icons.Default.ArrowBack,"Voltar")};Text("Minhas listas",style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold)}
        Spacer(Modifier.height(8.dp));OutlinedTextField(name,{name=it},label={Text("Nome da lista")},modifier=Modifier.fillMaxWidth());Spacer(Modifier.height(8.dp));OutlinedTextField(url,{url=it},label={Text("URL M3U/M3U8")},modifier=Modifier.fillMaxWidth());Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){Button(onClick={if(url.isNotBlank())vm.addUrl(name,url)},enabled=url.isNotBlank()){Icon(Icons.Default.Link,null);Spacer(Modifier.width(5.dp));Text("ADICIONAR URL")};OutlinedButton(onClick={picker.launch(arrayOf("application/vnd.apple.mpegurl","audio/x-mpegurl","text/plain","*/*"))}){Icon(Icons.Default.FolderOpen,null);Spacer(Modifier.width(5.dp));Text("IMPORTAR ARQUIVO")}}
        Spacer(Modifier.height(18.dp));Text("Listas cadastradas",fontWeight=FontWeight.Bold)
        LazyColumn(verticalArrangement=Arrangement.spacedBy(8.dp),modifier=Modifier.fillMaxWidth()){items(playlists,key={it.id}){p->Card(colors=CardDefaults.cardColors(containerColor=Panel)){Row(Modifier.padding(14.dp),verticalAlignment=Alignment.CenterVertically){Icon(Icons.Default.PlaylistPlay,null,tint=Primary);Spacer(Modifier.width(10.dp));Column(Modifier.weight(1f)){Text(p.name,fontWeight=FontWeight.Bold);Text(p.itemCount.toString()+" itens",color=Muted);Text(if(p.isFile)"Arquivo local" else p.source.take(45)+(if(p.source.length>45)"…" else ""),color=Muted,style=MaterialTheme.typography.bodySmall)};IconButton(onClick={deleteTarget=p}){Icon(Icons.Default.Delete,"Excluir",tint=Color(0xFFFF6B6B))}}}}}
    }
    deleteTarget?.let{p->AlertDialog(onDismissRequest={deleteTarget=null},title={Text("Excluir lista")},text={Text("Tem certeza que deseja excluir a lista atual?")},dismissButton={TextButton(onClick={deleteTarget=null}){Text("CANCELAR")}},confirmButton={Button(onClick={vm.deletePlaylist(p.id);deleteTarget=null}){Text("EXCLUIR")}})}
}

@Composable private fun PlayerScreen(entry:MediaEntry,onBack:()->Unit){
    val ctx=androidx.compose.ui.platform.LocalContext.current;val player=remember(entry.url){ExoPlayer.Builder(ctx).build().apply{setMediaItem(MediaItem.fromUri(entry.url));prepare();playWhenReady=true}}
    DisposableEffect(player){onDispose{player.release()}};BackHandler(onBack=onBack)
    Box(Modifier.fillMaxSize().background(Color.Black)){AndroidView(factory={PlayerView(it).apply{this.player=player;useController=true}},modifier=Modifier.fillMaxSize());Row(Modifier.fillMaxWidth().background(Color.Black.copy(alpha=.55f)).padding(8.dp),verticalAlignment=Alignment.CenterVertically){IconButton(onClick=onBack){Icon(Icons.Default.ArrowBack,"Voltar",tint=Color.White)};Text(entry.name,color=Color.White,fontWeight=FontWeight.Bold,maxLines=1)}}
}
