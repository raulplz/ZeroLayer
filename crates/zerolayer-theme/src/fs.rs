use std::ffi::OsString;
use std::path::PathBuf;

/// Ruta de `theme.json` según XDG: `$XDG_CONFIG_HOME/zerolayer/theme.json` o `~/.config/zerolayer/theme.json`.
///
/// Una `XDG_CONFIG_HOME` vacía o relativa cuenta como no definida (así lo manda la especificación XDG).
/// `None` si tampoco hay `HOME`.
pub fn config_path() -> Option<PathBuf> {
    config_path_from(std::env::var_os("XDG_CONFIG_HOME"), std::env::var_os("HOME"))
}

/// Como [`config_path`] pero con los valores de las variables ya leídos (útil en pruebas).
pub fn config_path_from(xdg_config_home: Option<OsString>, home: Option<OsString>) -> Option<PathBuf> {
    let base =
        xdg_config_home.map(PathBuf::from).filter(|p| p.is_absolute()).or_else(|| home.filter(|h| !h.is_empty()).map(|h| PathBuf::from(h).join(".config")))?;
    Some(base.join("zerolayer").join("theme.json"))
}
