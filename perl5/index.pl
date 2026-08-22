#!/usr/bin/perl
# index.html — portiert nach perl5
# Quelle: html, Projects@Telegram-Monitor:web/index.html
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use CGI qw(:standard);
use HTML::Entities;

# Erzeuge das HTML-Dokument dynamisch
my $cgi = CGI->new;
print $cgi->header(-type => 'text/html', -charset => 'utf-8');

# Hilfsfunktionen für HTML-Ausgabe
sub esc {
    my ($str) = @_;
    return defined $str ? encode_entities($str, '<>&"') : '';
}

# Ausgabedatei-Parameter
my $output_file = $ARGV[0] || 'index.html';

open(my $fh, '>', $output_file) or die "Konnte Datei '$output_file' nicht öffnen: $!";

# HTML-Struktur beginnen
print $fh doctype('html');
print $fh start_html(
    -lang  => 'de',
    -head  => [
        meta({-charset => 'utf-8'}),
        meta({-name => 'viewport', -content => 'width=device-width, initial-scale=1'}),
        title('Telegram Monitor'),
        style(<<'CSS_END')
  :root{
    --bg:#f6f7f9; --card:#fff; --line:#e3e6ea; --text:#16191d; --muted:#6b7280;
    --accent:#2481cc; --accent-soft:#e8f2fb; --discord:#5865f2; --discord-soft:#eceefe;
    --ok:#15803d; --warn:#b45309; --err:#b91c1c;
    color-scheme: light;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);
       font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
  header{background:var(--card);border-bottom:1px solid var(--line);padding:14px 20px;
         display:flex;align-items:center;gap:14px;flex-wrap:wrap;position:sticky;top:0;z-index:5}
  header h1{font-size:17px;margin:0;font-weight:650}
  .pill{font-size:11px;padding:2px 8px;border-radius:99px;background:var(--accent-soft);
        color:var(--accent);font-weight:600;white-space:nowrap}
  .pill.off{background:#f1f2f4;color:var(--muted)}
  .pill.dc{background:var(--discord-soft);color:var(--discord)}
  nav{display:flex;gap:4px;padding:0 20px;background:var(--card);border-bottom:1px solid var(--line)}
  nav button{border:0;background:none;padding:11px 14px;font:inherit;font-weight:550;
             color:var(--muted);cursor:pointer;border-bottom:2px solid transparent}
  nav button.active{color:var(--accent);border-bottom-color:var(--accent)}
  main{padding:20px;max-width:1080px;margin:0 auto}
  .panel{display:none} .panel.active{display:block}
  .row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:14px}
  input,select{padding:9px 11px;border:1px solid var(--line);border-radius:8px;font:inherit;
               background:var(--card);min-width:180px}
  input:focus,select:focus{outline:2px solid var(--accent-soft);border-color:var(--accent)}
  button.go{background:var(--accent);color:#fff;border:0;border-radius:8px;padding:9px 16px;
            font:inherit;font-weight:600;cursor:pointer}
  button.go.sec{background:var(--card);color:var(--text);border:1px solid var(--line)}
  button.go.dc{background:var(--discord)}
  button.go:disabled{opacity:.5;cursor:default}
  .card{background:var(--card);border:1px solid var(--line);border-radius:12px;
        padding:14px 16px;margin-bottom:10px}
  .card h3{margin:0 0 2px;font-size:15px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
  .card .meta{color:var(--muted);font-size:13px}
  .card .desc{margin-top:7px;font-size:13.5px;white-space:pre-wrap}
  .avatar{width:34px;height:34px;border-radius:50%;object-fit:cover;background:#eceff3;flex:none}
  .head{display:flex;gap:11px;align-items:flex-start}
  .score{font-variant-numeric:tabular-nums;font-size:12px;color:var(--muted);
         border:1px solid var(--line);border-radius:6px;padding:1px 6px}
  .tag{font-size:11px;padding:2px 7px;border-radius:5px;background:#f1f2f4;color:var(--muted);font-weight:600}
  .tag.ok{background:#e7f6ec;color:var(--ok)} .tag.no{background:#fdeceb;color:var(--err)}
  .post{border-left:3px solid var(--accent-soft);padding:6px 0 6px 11px;margin:9px 0;font-size:13.5px}
  .post .when{color:var(--muted);font-size:12px}
  .post .txt{white-space:pre-wrap;margin-top:2px}
  a{color:var(--accent);text-decoration:none} a:hover{text-decoration:underline}
  .empty{color:var(--muted);padding:22px;text-align:center;border:1px dashed var(--line);border-radius:12px}
  .err{background:#fdeceb;border:1px solid #f5c6c2;color:var(--err);padding:10px 13px;
       border-radius:8px;margin-bottom:12px;font-size:13.5px}
  .spin{color:var(--muted);padding:16px 0}
  table{width:100%;border-collapse:collapse;font-size:13.5px}
  th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top}
  th{color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.03em}
  code{background:#f1f2f4;padding:1px 5px;border-radius:4px;font-size:12.5px}
  .hint{color:var(--muted);font-size:13px;margin:-4px 0 14px}
  .stream{max-height:460px;overflow:auto;border:1px solid var(--line);border-radius:10px;
          padding:6px 12px;margin-top:10px;background:var(--card)}
  .post.fresh{border-left-color:var(--ok);background:#f3fbf5}
  .post.fresh .when::after{content:" NEU";color:var(--ok);font-weight:700}
  .dot{width:8px;height:8px;border-radius:50%;background:var(--ok);display:inline-block;
       margin-right:6px;animation:pulse 2s infinite}
  @keyframes pulse{0%,100%{opacity:1}50%{opacity:.35}}
  .idle{background:var(--muted)!important;animation:none}
  .tt-live{background:#fe2c55;color:#fff;font-weight:700;font-size:11px;
           padding:2px 9px;border-radius:99px}
  .tt-off{background:#f1f2f4;color:var(--muted);font-weight:700;font-size:11px;
          padding:2px 9px;border-radius:99px}
  .tt-player{position:relative;width:100%;max-width:340px;aspect-ratio:9/16;background:#000;
             border-radius:10px;overflow:hidden;margin-top:10px;border:1px solid var(--line)}
  .tt-player iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
  .ev{display:flex;gap:10px;padding:7px 0;border-bottom:1px solid var(--line);font-size:13.5px}
  .ev:last-child{border-bottom:0}
  .ev .k{font-weight:650;white-space:nowrap}
  .ev .k.start{color:#fe2c55} .ev .k.end{color:var(--muted)}
CSS_END
        link({-rel => 'manifest', -href => '/manifest.webmanifest'}),
        meta({-name => 'theme-color', -content => '#2481cc'}),
        link({-rel => 'icon', -href => '/icons/monitor-192.png'}),
        meta({-name => 'apple-mobile-web-app-capable', -content => 'yes'}),
        meta({-name => 'apple-mobile-web-app-title', -content => 'Monitor'}),
        link({-rel => 'apple-touch-icon', -href => '/icons/monitor-192.png'})
    ]
);

# Header-Bereich
print $fh start_div({-id => 'header'});
print $fh h1('Telegram Monitor');
print $fh span({-id => 'statusPills', -class => 'row', -style => 'margin:0;gap:6px'}, '');
print $fh button(
    {-id => 'notifyBtn', -style => 'margin-left:auto;font:inherit;font-weight:600;border:1px solid var(--line);background:var(--bg);color:var(--text);border-radius:8px;padding:6px 12px;cursor:pointer'},
    'Meldungen erlauben'
);
print $fh button(
    {-id => 'installBtn', -hidden => undef, -style => 'font:inherit;font-weight:600;border:1px solid #2481cc;background:#2481cc;color:#fff;border-radius:8px;padding:6px 12px;cursor:pointer'},
    'Als App installieren'
);
print $fh end_div();

# Navigation
print $fh start_nav();
print $fh button({-data_tab => 'live', -class => 'active'}, 'Live');
print $fh button({-data_tab => 'search'}, 'Suche');
print $fh button({-data_tab => 'watch'}, 'Watchlist');
print $fh button({-data_tab => 'tiktok'}, 'TikTok');
print $fh button({-data_tab => 'discord'}, 'Discord');
print $fh button({-data_tab => 'status'}, 'Status');
print $fh end_nav();

# Main-Bereich
print $fh start_main();

# Panel Live
print $fh start_section({-class => 'panel active', -id => 'panel-live'});
print $fh div(
    {-class => 'row'},
    label({-class => 'hint', -style => 'margin:0'}, 'Aktualisierung alle'),
    popup_menu(
        -id       => 'liveEvery',
        -values   => ['30', '60', '300', '0'],
        -labels   => {'30' => '30 Sekunden', '60' => '1 Minute', '300' => '5 Minuten', '0' => 'nur manuell'},
        -default  => '60'
    ),
    button({-class => 'go sec', -id => 'btnPollNow'}, 'Jetzt abrufen'),
    span({-class => 'hint', -id => 'liveState', -style => 'margin:0'}, '')
);
print $fh p({-class => 'hint'}, 'Zeigt den fortlaufenden Verlauf aller Kanaele auf der Watchlist. Der Server fragt im Hintergrund selbstaendig ab; diese Ansicht holt den gesammelten Verlauf. Neue Beitraege werden markiert.');
print $fh div({-id => 'liveOut'}, '');
print $fh end_section();

# Panel Search
print $fh start_section({-class => 'panel', -id => 'panel-search'});
print $fh div(
    {-class => 'row'},
    textfield(
        -id          => 'q',
        -placeholder => 'Suchbegriff oder @name, z.B. creator',
        -style       => 'flex:1;min-width:240px'
    ),
    popup_menu(
        -id       => 'limit',
        -values   => ['10', '20', '40'],
        -labels   => {'10' => '10', '20' => '20', '40' => '40'},
        -default  => '20'
    ),
    button({-class => 'go', -id => 'btnSearch'}, 'Suchen')
);
print $fh p({-class => 'hint'}, 'Sucht ueber alle aktiven Methoden gleichzeitig: oeffentliche t.me-Vorschau, Namensvarianten, Websuche, optional Bot-API / MTProto sowie Discord-Invites.');
print $fh div({-id => 'searchOut'}, '');
print $fh end_section();

# Panel Watchlist
print $fh start_section({-class => 'panel', -id => 'panel-watch'});
print $fh div(
    {-class => 'row'},
    popup_menu(
        -id       => 'wPlatform',
        -values   => ['telegram', 'discord'],
        -labels   => {'telegram' => 'Telegram', 'discord' => 'Discord'},
        -default  => 'telegram'
    ),
    textfield(
        -id          => 'wTarget',
        -placeholder => '@name / Invite-Code / Kanal-ID'
    ),
    textfield(
        -id          => 'wNote',
        -placeholder => 'Notiz (optional)'
    ),
    button({-class => 'go', -id => 'btnAdd'}, 'Hinzufuegen'),
    button({-class => 'go sec', -id => 'btnScan'}, 'Uebersicht laden')
);
print $fh div({-id => 'watchOut'}, '');
print $fh end_section();

# Panel TikTok
print $fh start_section({-class => 'panel', -id => 'panel-tiktok'});
print $fh div(
    {-class => 'row'},
    textfield(
        -id          => 'ttUser',
        -placeholder => '@name, z.B. creator',
        -style       => 'min-width:200px'
    ),
    button({-class => 'go', -id => 'btnTtCheck'}, 'Status prüfen'),
    button({-class => 'go sec', -id => 'btnTtWatch'}, 'Beobachten'),
    label(
        {-class => 'hint', -style => 'margin:0'},
        checkbox(
            -id       => 'ttEmbed',
            -checked  => 1,
            -label    => ''
        ) . 'Player einblenden, wenn live'
    )
);
print $fh p({-class => 'hint'}, 'Zeigt Live-Status, laufende Sendung und die letzten Sendungen. Der Player ist der offizielle TikTok-Embed — ohne Anmeldung, ohne Geschenk- und Kauf-Oberfläche. Beobachtete Konten meldet der Poller beim Livegang.');
print $fh div({-id => 'ttOut'}, '');
print $fh h3({-style => 'font-size:13px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted);margin:22px 0 8px'}, 'Ereignisse');
print $fh div({-id => 'ttEvents'}, '');
print $fh end_section();

# Panel Discord
print $fh start_section({-class => 'panel', -id => 'panel-discord'});
print $fh div(
    {-class => 'row'},
    textfield(
        -id          => 'dInvite',
        -placeholder => 'discord.gg/code oder nur der Code',
        -style       => 'flex:1;min-width:240px'
    ),
    button({-class => 'go dc', -id => 'btnInvite'}, 'Invite pruefen'),
    button({-class => 'go sec', -id => 'btnGuilds'}, 'Server des Bots')
);
print $fh p({-class => 'hint'}, 'Invite-Pruefung funktioniert ohne Token. Server, Kanaele und Nachrichten brauchen einen Bot-Token (<code>DISCORD_BOT_TOKEN</code>).');
print $fh div({-id => 'discordOut'}, '');
print $fh end_section();

# Panel Status
print $fh start_section({-class => 'panel', -id => 'panel-status'});
print $fh div({-id => 'statusOut'}, '');
print $fh end_section();

print $fh end_main();

# JavaScript-Bereich
print $fh script(<<'JS_END');
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const num = n => n == null ? '?' : n.toLocaleString('de-DE');
const when = d => { if(!d) return ''; const t = new Date(d);
  return isNaN(t) ? d : t.toLocaleString('de-DE',{dateStyle:'medium',timeStyle:'short'}); };

async function api(path, opts){
  const r = await fetch(path, opts);
  const data = await r.json().catch(() => ({error:'Antwort war kein JSON'}));
  if(!r.ok || (data && data.error)) throw new Error(data.error || ('HTTP '+r.status));
  return data;
}
function busy(el, text){ el.innerHTML = '<div class="spin">'+esc(text)+'</div>'; }
function fail(el, e){ el.innerHTML = '<div class="err">'+esc(e.message)+'</div>'; }

document.querySelectorAll('nav button').forEach(b => b.onclick = () => {
  document.querySelectorAll('nav button').forEach(x => x.classList.toggle('active', x === b));
  document.querySelectorAll('.panel').forEach(p =>
    p.classList.toggle('active', p.id === 'panel-' + b.dataset.tab));
});

function channelCard(c, extraHtml){
  const dc = c.platform === 'discord';
  const tags = [];
  tags.push('<span class="tag">'+esc(c.kind)+'</span>');
  if(c.readable) tags.push('<span class="tag ok">lesbar</span>');
  else tags.push('<span class="tag no">nicht lesbar</span>');
  if(c.verified) tags.push('<span class="tag ok">verifiziert</span>');
  const av = c.avatar_url ? '<img class="avatar" src="'+esc(c.avatar_url)+'" alt="">'
                          : '<div class="avatar"></div>';
  const online = c.online != null ? ' &middot; '+num(c.online)+' online' : '';
  return '<div class="card"><div class="head">'+av+'<div style="flex:1">'+
    '<h3>'+esc(c.title || c.username || c.id)+
      '<span class="pill'+(dc?' dc':'')+'">'+esc(c.platform)+'</span>'+tags.join('')+
      (c.confidence != null ? '<span class="score">'+c.confidence.toFixed(2)+'</span>' : '')+'</h3>'+
    '<div class="meta">'+(c.username ? '@'+esc(c.username)+' &middot; ' : '')+
      num(c.members)+' Mitglieder'+online+' &middot; via '+esc(c.source)+
      (c.url ? ' &middot; <a href="'+esc(c.url)+'" target="_blank" rel="noopener">oeffnen</a>' : '')+'</div>'+
    (c.description ? '<div class="desc">'+esc(c.description.slice(0,400))+'</div>' : '')+
    (c.extra && c.extra.note ? '<div class="meta" style="margin-top:6px">'+esc(c.extra.note)+'</div>' : '')+
    (extraHtml || '')+
    '</div></div></div>';
}
function postsHtml(posts){
  if(!posts || !posts.length) return '';
  return posts.map(p => '<div class="post"><div class="when">'+esc(when(p.date))+
    (p.views ? ' &middot; '+num(p.views)+' Aufrufe' : '')+
    (p.author ? ' &middot; '+esc(p.author) : '')+
    (p.url ? ' &middot; <a href="'+esc(p.url)+'" target="_blank" rel="noopener">Link</a>' : '')+
    '</div><div class="txt">'+esc((p.text || '(kein Text)').slice(0,600))+'</div>'+
    (p.media && p.media.length ? '<div class="when">Medien: '+
      esc(p.media.map(m => m.type).join(', '))+'</div>' : '')+'</div>').join('');
}

$('#btnSearch').onclick = async () => {
  const out = $('#searchOut'), q = $('#q').value.trim();
  if(!q) return;
  busy(out, 'Suche laeuft - pruefe Namensvarianten und oeffentliche Vorschauen ...');
  try{
    const r = await api('/api/search?q='+encodeURIComponent(q)+'&limit='+$('#limit').value);
    let html = '<p class="hint">'+r.count+' Treffer &middot; Methoden: '+
      esc(r.methods_used.join(', '))+'</p>';
    r.errors.forEach(e => html += '<div class="err">'+esc(e.method+': '+e.error)+'</div>');
    html += r.results.length
      ? r.results.map(c => channelCard(c,
          '<div class="row" style="margin:10px 0 0">'+
          (c.readable ? '<button class="go sec" data-posts="'+esc(c.username||c.id)+
            '" data-platform="'+esc(c.platform)+'">Beitraege laden</button>' : '')+
          '<button class="go sec" data-watch="'+esc(c.username||c.id)+
            '" data-platform="'+esc(c.platform)+'">Zur Watchlist</button></div>'+
          '<div class="postbox"></div>')).join('')
      : '<div class="empty">Keine Treffer.</div>';
    out.innerHTML = html;
  }catch(e){ fail(out, e); }
};
$('#q').addEventListener('keydown', e => { if(e.key === 'Enter') $('#btnSearch').click(); });

document.addEventListener('click', async ev => {
  const b = ev.target.closest('button[data-posts]');
  if(b){
    const box = b.closest('.card').querySelector('.postbox');
    box.innerHTML = '<div class="spin">Lade Beitraege ...</div>';
    try{
      const r = await api('/api/posts?target='+encodeURIComponent(b.dataset.posts)+
        '&platform='+b.dataset.platform+'&limit=8');
      box.innerHTML = r.posts.length ? postsHtml(r.posts)
        : '<div class="meta">Keine Beitraege abrufbar.</div>';
    }catch(e){ box.innerHTML = '<div class="err">'+esc(e.message)+'</div>'; }
  }
  const w = ev.target.closest('button[data-watch]');
  if(w){
    w.disabled = true; w.textContent = 'gemerkt';
    await api('/api/watchlist', {method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({action:'add', platform:w.dataset.platform, target:w.dataset.watch})});
    loadWatch();
  }
  const rm = ev.target.closest('button[data-remove]');
  if(rm){
    await api('/api/watchlist', {method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({action:'remove', platform:rm.dataset.platform, target:rm.dataset.remove})});
    loadWatch();
  }
  const ch = ev.target.closest('button[data-guild]');
  if(ch){
    const box = ch.closest('.card').querySelector('.postbox');
    box.innerHTML = '<div class="spin">Lade Kanaele ...</div>';
    try{
      const list = await api('/api/discord/channels?guild_id='+encodeURIComponent(ch.dataset.guild));
      box.innerHTML = '<table><tr><th>Kanal</th><th>Typ</th><th>Thema</th><th></th></tr>'+
        list.map(c => '<tr><td>#'+esc(c.title)+'</td><td>'+esc(c.extra.type)+'</td>'+
          '<td>'+esc((c.description||'').slice(0,90))+'</td><td>'+
          (c.readable ? '<button class="go sec" data-msg="'+esc(c.id)+'">Nachrichten</button>' : '')+
          '</td></tr>').join('')+'</table><div class="msgbox"></div>';
    }catch(e){ box.innerHTML = '<div class="err">'+esc(e.message)+'</div>'; }
  }
  const mg = ev.target.closest('button[data-msg]');
  if(mg){
    const box = mg.closest('.postbox').querySelector('.msgbox');
    box.innerHTML = '<div class="spin">Lade Nachrichten ...</div>';
    try{
      const list = await api('/api/discord/messages?channel_id='+encodeURIComponent(mg.dataset.msg)+'&limit=10');
      box.innerHTML = postsHtml(list) || '<div class="meta">Keine Nachrichten.</div>';
    }catch(e){ box.innerHTML = '<div class="err">'+esc(e.message)+'</div>'; }
  }
});

async function loadWatch(){
  const out = $('#watchOut');
  try{
    const items = await api('/api/watchlist');
    out.innerHTML = items.length
      ? '<table><tr><th>Plattform</th><th>Ziel</th><th>Notiz</th><th></th></tr>'+
        items.map(i => '<tr><td>'+esc(i.platform)+'</td><td>'+esc(i.target)+'</td>'+
          '<td>'+esc(i.note||'')+'</td><td><button class="go sec" data-remove="'+esc(i.target)+
          '" data-platform="'+esc(i.platform)+'">entfernen</button></td></tr>').join('')+'</table>'
      : '<div class="empty">Watchlist ist leer. Kanaele aus der Suche hinzufuegen.</div>';
  }catch(e){ fail(out, e); }
}
$('#btnAdd').onclick = async () => {
  const t = $('#wTarget').value.trim(); if(!t) return;
  await api('/api/watchlist', {method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({action:'add', platform:$('#wPlatform').value, target:t, note:$('#wNote').value})});
  $('#wTarget').value = ''; $('#wNote').value = ''; loadWatch();
};
$('#btnScan').onclick = async () => {
  const out = $('#watchOut');
  busy(out, 'Hole aktuelle Daten fuer alle Eintraege ...');
  try{
    const r = await api('/api/scan?limit=5');
    out.innerHTML = r.entries.length ? r.entries.map(e => {
      if(e.error) return '<div class="err">'+esc(e.platform+'/'+e.target+': '+e.error)+'</div>';
      if(!e.channel) return '<div class="card"><b>'+esc(e.target)+'</b>'+
        '<div class="meta">nicht gefunden</div></div>';
      return channelCard(e.channel, postsHtml(e.posts));
    }).join('') + '<div class="row"><button class="go sec" onclick="loadWatch()">Zurueck zur Liste</button></div>'
      : '<div class="empty">Watchlist ist leer.</div>';
  }catch(e){ fail(out, e); }
};

$('#btnInvite').onclick = async () => {
  const out = $('#discordOut'), v = $('#dInvite').value.trim(); if(!v) return;
  busy(out, 'Frage Discord-Invite ab ...');
  try{
    const c = await api('/api/discord/invite?code='+encodeURIComponent(v));
    out.innerHTML = c ? channelCard(c, '<div class="meta" style="margin-top:8px">Invite-Kanal: '+
      esc((c.extra && c.extra.invite_channel) || '?')+'</div>')
      : '<div class="empty">Invite ungueltig oder abgelaufen.</div>';
  }catch(e){ fail(out, e); }
};
$('#btnGuilds').onclick = async () => {
  const out = $('#discordOut');
  busy(out, 'Lade Server des Bots ...');
  try{
    const list = await api('/api/discord/guilds');
    out.innerHTML = list.length ? list.map(g => channelCard(g,
      '<div class="row" style="margin:10px 0 0"><button class="go sec" data-guild="'+
      esc(g.id)+'">Kanaele anzeigen</button></div><div class="postbox"></div>')).join('')
      : '<div class="empty">Der Bot ist auf keinem Server. Einladungslink: '+
        '<code>python cli.py discord invite-url &lt;CLIENT_ID&gt;</code></div>';
  }catch(e){ fail(out, e); }
};

let liveTimer = null, liveCountdown = null, seenIds = new Set(), firstLiveLoad = true;

function renderLive(entries, poller){
  const out = document.getElementById('liveOut');
  if(!entries.length){
    out.innerHTML = '<div class="empty">Watchlist ist leer - Kanaele im Reiter Suche hinzufuegen.</div>';
    return;
  }
  out.innerHTML = entries.map(e => {
    const posts = e.posts || [];
    const head = '<h3><span class="dot'+(posts.length?'':' idle')+'"></span>'+
      esc(e.target)+'<span class="pill'+(e.platform==='discord'?' dc':'')+'">'+
      esc(e.platform)+'</span></h3>'+
      '<div class="meta">'+e.total+' Beitraege gesammelt &middot; '+e.polls+' Abrufe &middot; '+
      'zuletzt geprueft '+esc(when(e.last_poll))+
      (e.last_new ? ' &middot; letzter neuer Beitrag '+esc(when(e.last_new)) : '')+'</div>'+
      (e.errors && e.errors.length ? '<div class="err" style="margin-top:8px">'+
        esc(e.errors[0].error)+'</div>' : '');
    const body = posts.length
      ? '<div class="stream">'+posts.map(p => {
          const fresh = !firstLiveLoad && !seenIds.has(p.id);
          return '<div class="post'+(fresh?' fresh':'')+'"><div class="when">'+esc(when(p.date))+
            (p.views ? ' &middot; '+num(p.views)+' Aufrufe' : '')+
            (p.author ? ' &middot; '+esc(p.author) : '')+
            (p.url ? ' &middot; <a href="'+esc(p.url)+'" target="_blank" rel="noopener">Link</a>' : '')+
            '</div><div class="txt">'+esc((p.text || '(kein Text)').slice(0,800))+'</div>'+
            (p.media && p.media.length ? '<div class="when">Medien: '+
              esc(p.media.map(m=>m.type).join(', '))+'</div>' : '')+'</div>';
        }).join('')+'</div>'
      : '<div class="meta" style="margin-top:8px">Noch keine Beitraege gesammelt. '+
        'Entweder gibt es keine oeffentliche Vorschau oder der Kanal hat nichts veroeffentlicht.</div>';
    return '<div class="card">'+head+body+'</div>';
  }).join('');
  entries.forEach(e => (e.posts||[]).forEach(p => seenIds.add(p.id)));
  firstLiveLoad = false;
  const st = document.getElementById('liveState');
  st.textContent = poller && poller.running
    ? 'Hintergrund-Abfrage aktiv (alle '+poller.interval+' s, '+poller.cycles+' Durchlaeufe)'
    : 'Hintergrund-Abfrage inaktiv';
}

async function loadLive(){
  try{
    const [data, poller] = await Promise.all([
      api('/api/live/all?limit=30'), api('/api/poller').catch(() => null)]);
    renderLive(data.entries || [], poller);
  }catch(e){ fail(document.getElementById('liveOut'), e); }
}

function scheduleLive(){
  if(liveTimer) clearInterval(liveTimer);
  if(liveCountdown) clearInterval(liveCountdown);
  const every = parseInt(document.getElementById('liveEvery').value, 10);
  if(!every) return;
  let left = every;
  liveTimer = setInterval(() => { left = every; loadLive(); }, every * 1000);
  liveCountdown = setInterval(() => {
    left = Math.max(0, left - 1);
    const st = document.getElementById('liveState');
    if(st && st.textContent) st.dataset.base = st.dataset.base || '';
  }, 1000);
}
document.getElementById('liveEvery').addEventListener('change', scheduleLive);
document.getElementById('btnPollNow').onclick = async () => {
  const btn = document.getElementById('btnPollNow');
  btn.disabled = true; btn.textContent = 'Rufe ab ...';
  try{
    const items = await api('/api/watchlist');
    await Promise.all(items.map(i => api('/api/live/poll?platform='+i.platform+
      '&target='+encodeURIComponent(i.target)).catch(() => null)));
    await loadLive();
  }finally{ btn.disabled = false; btn.textContent = 'Jetzt abrufen'; }
};


/* --------------------------------------------------------------- TikTok --- */
function ttCard(st){
  const live = st.live === true;
  const player = (live && document.getElementById('ttEmbed').checked)
    ? '<div class="tt-player"><iframe src="' + esc(st.embed_url) +
      '" allow="autoplay; encrypted-media; picture-in-picture" referrerpolicy="origin" ' +
      'title="TikTok Live von @' + esc(st.username) + '"></iframe></div>' : '';
  const streams = (st.streams || []).slice(0, 8).map(x =>
    '<div class="post' + (x.is_live ? ' fresh' : '') + '"><div class="when">' +
    esc(x.day) + ' ' + esc(x.time || '') + (x.duration ? ' · ' + esc(x.duration) : '') +
    (x.is_live ? ' · läuft' : '') + '</div><div class="txt">' +
    esc(x.title || '(ohne Titel)') + '</div></div>').join('');
  return '<div class="card"><h3>@' + esc(st.username) +
    (live ? '<span class="tt-live">LIVE</span>' : '<span class="tt-off">offline</span>') +
    '<span class="pill">tiktok</span></h3>' +
    '<div class="meta">' +
      (st.title ? esc(st.title) + ' · ' : '') +
      (st.started_at ? 'Beginn ' + esc(st.started_at.replace('T', ' ')) : '') +
      (st.since ? ' · seit ca. ' + esc(st.since) : '') +
      (st.last_seen ? ' · zuletzt gesehen ' + esc(st.last_seen) : '') + '</div>' +
    '<div class="meta">' + (st.streams_total || '?') + ' Sendungen · ' +
      esc(st.airtime || '?') + ' Sendezeit · ' + (st.active_days || '?') + ' aktive
