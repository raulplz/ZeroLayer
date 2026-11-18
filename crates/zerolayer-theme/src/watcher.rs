use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use crate::{config_path, Theme};

type Signature = Option<(u64, u64, Option<std::time::SystemTime>)>;

fn signature(path: &std::path::Path) -> Signature {
    let meta = std::fs::metadata(path).ok()?;
    #[cfg(unix)]
    let inode = std::os::unix::fs::MetadataExt::ino(&meta);
    #[cfg(not(unix))]
    let inode = 0;
    Some((inode, meta.len(), meta.modified().ok()))
}

/// Sondeo manual del archivo, para aplicaciones que ya tienen su propio bucle.
///
/// Compara inodo, tamaño y fecha de modificación (la escritura de ZeroLayer es un renombrado, que
/// cambia el inodo). [`ThemeWatcher::poll`] devuelve el tema la primera vez y en cada cambio posterior,
/// incluida la desaparición del archivo (entonces, el tema por defecto).
#[derive(Debug)]
pub struct ThemeWatcher {
    path: Option<PathBuf>,
    last: Option<Signature>,
}

impl Default for ThemeWatcher {
    fn default() -> Self {
        Self::new()
    }
}

impl ThemeWatcher {
    /// Vigila [`config_path`].
    pub fn new() -> Self {
        Self { path: config_path(), last: None }
    }

    /// Vigila una ruta concreta.
    pub fn at(path: PathBuf) -> Self {
        Self { path: Some(path), last: None }
    }

    pub fn poll(&mut self) -> Option<Theme> {
        let sig = self.path.as_deref().and_then(signature);
        if self.last == Some(sig) {
            return None;
        }
        self.last = Some(sig);
        Some(self.path.as_deref().map(Theme::load_from).unwrap_or_default())
    }
}

/// Control del hilo de [`watch`]. Soltarlo no detiene la vigilancia; llama a [`WatchHandle::stop`].
#[derive(Debug, Clone)]
pub struct WatchHandle(Arc<AtomicBool>);

impl WatchHandle {
    pub fn stop(&self) {
        self.0.store(true, Ordering::Relaxed);
    }
}

/// Lanza un hilo que sondea `theme.json` cada `interval` y llama a `callback` con el tema al empezar y
/// cada vez que el archivo cambia (o desaparece).
pub fn watch<F>(interval: Duration, mut callback: F) -> WatchHandle
where
    F: FnMut(Theme) + Send + 'static,
{
    let stop = Arc::new(AtomicBool::new(false));
    let flag = stop.clone();
    thread::spawn(move || {
        let mut watcher = ThemeWatcher::new();
        while !flag.load(Ordering::Relaxed) {
            if let Some(theme) = watcher.poll() {
                callback(theme);
            }
            thread::sleep(interval);
        }
    });
    WatchHandle(stop)
}
