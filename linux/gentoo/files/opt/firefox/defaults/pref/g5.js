// Firefox-Voreinstellungen –
// nur Vorgaben, in about:config änderbar. setup.sh legt die Datei nach jedem
// Firefox-Update neu ab (/usr/lib/firefox/defaults/pref).
// Hardware-Videodekodierung über VA-API (NVIDIA)
pref("media.ffmpeg.vaapi.enabled", true);
pref("widget.dmabuf.force-enabled", true);
// KDE-Dateidialog statt GTK
pref("widget.use-xdg-desktop-portal.file-picker", 1);
pref("widget.use-xdg-desktop-portal.mime-handler", 1);
// Apple-Emoji statt des mitgelieferten Twemoji
pref("font.name-list.emoji", "Apple Color Emoji");
// userChrome.css aus dem Profil laden (theme.sh, Adressleisten-Vorschläge)
pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Kompakte Leisten (Tabs und Adressleiste schmaler), im Menü
// „Symbolleiste anpassen → Dichte“ wieder umstellbar
pref("browser.compactmode.show", true);
pref("browser.uidensity", 1);
// Webseiten hell oder dunkel wie das System (theme.sh)
pref("layout.css.prefers-color-scheme.content-override", 2);

// ── Tempo (Werte wie Betterfox „Fastfox“) ──
pref("content.notify.interval", 100000);
pref("network.http.max-connections", 1800);
pref("network.http.max-persistent-connections-per-server", 10);
pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
pref("network.http.pacing.requests.enabled", false);
pref("network.dns.disablePrefetch", false);
pref("network.dns.disablePrefetchFromHTTPS", false);
pref("network.prefetch-next", true);
pref("network.http.speculative-parallel-limit", 20);
pref("network.dnsCacheEntries", 1000);
pref("gfx.webrender.precache-shaders", true);
pref("network.dnsCacheExpiration", 3600);
pref("network.ssl_tokens_cache_capacity", 10240);
pref("browser.cache.memory.capacity", 131072);
pref("browser.cache.memory.max_entry_size", 20480);
pref("media.memory_cache_max_size", 65536);
pref("media.cache_readahead_limit", 7200);
pref("media.cache_resume_threshold", 3600);
pref("image.mem.decode_bytes_at_a_time", 32768);
pref("gfx.canvas.accelerated.cache-size", 512);
pref("gfx.content.skia-font-cache-size", 20);
pref("browser.sessionstore.interval", 60000);
