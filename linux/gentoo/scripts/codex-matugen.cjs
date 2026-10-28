// Loaded by the pinned desktop build. Use its native appearance settings so
// Matugen colors reach chats, sidebars, menus, and newly opened windows alike.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const installed = new WeakSet();

module.exports = function installMatugen(store, electron, themeFile = path.join(
  os.homedir(), '.cache', 'matugen', 'chatgpt-theme.json'
)) {
  if (!store || installed.has(store)) return;
  installed.add(store);
  let pending = Promise.resolve();
  let stopped = false;
  const refresh = () => {
    pending = pending.then(async () => {
      if (stopped) return;
      let palette;
      try {
        palette = JSON.parse(await fs.promises.readFile(themeFile, 'utf8'));
      } catch (error) {
        if (error.code === 'ENOENT' || error instanceof SyntaxError) return;
        throw error;
      }
      if (!['light', 'dark'].includes(palette.mode)) return;
      const colors = [palette.accent, palette.surface, palette.ink,
        ...['diffAdded', 'diffRemoved', 'skill'].map(key => palette.semanticColors?.[key])];
      if (!colors.every(color => typeof color === 'string' && /^#[0-9a-fA-F]{6}$/.test(color))) return;
      const key = palette.mode === 'light' ? 'appearanceLightChromeTheme' : 'appearanceDarkChromeTheme';
      const current = store.getEffective(key);
      const theme = {
        accent: palette.accent,
        accentSource: 'custom',
        contrast: current?.contrast ?? (palette.mode === 'light' ? 45 : 60),
        fonts: current?.fonts ?? { code: null, ui: null },
        ink: palette.ink,
        opaqueWindows: current?.opaqueWindows ?? false,
        semanticColors: palette.semanticColors,
        surface: palette.surface,
      };
      if (JSON.stringify(current) !== JSON.stringify(theme)) store.set(key, theme);
      if (store.getEffective('appearanceTheme') !== palette.mode) {
        store.set('appearanceTheme', palette.mode);
      }
      // set() also queues values while the local app-server is initializing.
      await store.flush();
      if (electron.nativeTheme.themeSource !== palette.mode) electron.nativeTheme.themeSource = palette.mode;
    }).catch(error => console.warn('[matugen] Could not apply ChatGPT colors:', error.message));
    return pending;
  };
  const changed = (current, previous) => {
    if (current.mtimeMs !== previous.mtimeMs || current.size !== previous.size) void refresh();
  };
  fs.watchFile(themeFile, { persistent: false, interval: 1000 }, changed);
  const stop = () => {
    stopped = true;
    fs.unwatchFile(themeFile, changed);
    installed.delete(store);
  };
  electron.app.once('will-quit', stop);
  void refresh();
  return stop;
};
