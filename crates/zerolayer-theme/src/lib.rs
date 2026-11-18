//! Lector del contrato `~/.config/zerolayer/theme.json` de ZeroLayer.
//!
//! Implementa lo descrito en `docs/theme-json.md`:
//!
//! - valores por defecto Frost cuando falta el archivo o un campo;
//! - solo se aceptan colores `#rrggbb`; cualquier otro valor se ignora campo a campo;
//! - los nombres de fuente se sanean porque acaban en el CSS de la aplicación;
//! - las claves desconocidas se ignoran.
//!
//! El análisis ([`Theme::from_json`], [`Theme::css_variables`]) no toca el sistema de archivos, así que
//! el crate compila a `wasm32`. La lectura ([`Theme::load`]) existe solo fuera de wasm, y la vigilancia
//! ([`watch`]) además requiere la feature `watch`.

use std::fmt;

use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;

#[cfg(not(target_arch = "wasm32"))]
mod fs;
#[cfg(not(target_arch = "wasm32"))]
pub use fs::{config_path, config_path_from};

#[cfg(all(feature = "watch", not(target_arch = "wasm32")))]
mod watcher;
#[cfg(all(feature = "watch", not(target_arch = "wasm32")))]
pub use watcher::{watch, ThemeWatcher, WatchHandle};

/// Un color del tema o una de las dos fuentes, para nombrar su variable CSS.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Key {
    Fondo,
    Superficie,
    Borde,
    Texto,
    Tenue,
    Acento,
    Acento2,
    Ok,
    Aviso,
    Peligro,
    Sans,
    Mono,
}

impl Key {
    /// Todas las claves, en el orden del esquema.
    pub const ALL: [Key; 12] =
        [Key::Fondo, Key::Superficie, Key::Borde, Key::Texto, Key::Tenue, Key::Acento, Key::Acento2, Key::Ok, Key::Aviso, Key::Peligro, Key::Sans, Key::Mono];

    /// Nombre de la clave en `theme.json` (`colores.*` o `fuentes.*`).
    pub fn json_name(self) -> &'static str {
        match self {
            Key::Fondo => "fondo",
            Key::Superficie => "superficie",
            Key::Borde => "borde",
            Key::Texto => "texto",
            Key::Tenue => "tenue",
            Key::Acento => "acento",
            Key::Acento2 => "acento2",
            Key::Ok => "ok",
            Key::Aviso => "aviso",
            Key::Peligro => "peligro",
            Key::Sans => "sans",
            Key::Mono => "mono",
        }
    }
}

/// Los diez colores del tema, siempre `#rrggbb` en minúsculas.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Colors {
    pub fondo: String,
    pub superficie: String,
    pub borde: String,
    pub texto: String,
    pub tenue: String,
    pub acento: String,
    pub acento2: String,
    pub ok: String,
    pub aviso: String,
    pub peligro: String,
}

impl Default for Colors {
    /// Paleta Frost de respaldo.
    fn default() -> Self {
        Self {
            fondo: "#080b10".into(),
            superficie: "#111923".into(),
            borde: "#1c2a3a".into(),
            texto: "#d5dfeb".into(),
            tenue: "#8292a6".into(),
            acento: "#4da3ff".into(),
            acento2: "#75c4e8".into(),
            ok: "#8fbea0".into(),
            aviso: "#e6bf79".into(),
            peligro: "#ef7180".into(),
        }
    }
}

impl Colors {
    fn slot(&mut self, key: Key) -> Option<&mut String> {
        Some(match key {
            Key::Fondo => &mut self.fondo,
            Key::Superficie => &mut self.superficie,
            Key::Borde => &mut self.borde,
            Key::Texto => &mut self.texto,
            Key::Tenue => &mut self.tenue,
            Key::Acento => &mut self.acento,
            Key::Acento2 => &mut self.acento2,
            Key::Ok => &mut self.ok,
            Key::Aviso => &mut self.aviso,
            Key::Peligro => &mut self.peligro,
            Key::Sans | Key::Mono => return None,
        })
    }

    /// Valor de un color; `None` para las fuentes.
    pub fn get(&self, key: Key) -> Option<&str> {
        Some(match key {
            Key::Fondo => &self.fondo,
            Key::Superficie => &self.superficie,
            Key::Borde => &self.borde,
            Key::Texto => &self.texto,
            Key::Tenue => &self.tenue,
            Key::Acento => &self.acento,
            Key::Acento2 => &self.acento2,
            Key::Ok => &self.ok,
            Key::Aviso => &self.aviso,
            Key::Peligro => &self.peligro,
            Key::Sans | Key::Mono => return None,
        })
    }
}

/// Nombres de fuente ya saneados.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Fonts {
    pub sans: String,
    pub mono: String,
}

impl Default for Fonts {
    fn default() -> Self {
        Self { sans: "Inter Tight".into(), mono: "JetBrainsMono Nerd Font".into() }
    }
}

/// El tema activo. Nunca contiene valores sin validar: un `Theme` se puede volcar al CSS tal cual.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Theme {
    pub version: u32,
    pub id: String,
    pub nombre: String,
    /// `"dark"` o `"light"`.
    pub modo: String,
    /// `true` si es un tema ZERØ (trae `zerolayer.toml`).
    pub zerolayer: bool,
    pub colores: Colors,
    pub fondo_pantalla: String,
    pub glifo: String,
    pub kanji: String,
    pub fuentes: Fonts,
    pub actualizado: String,
}

impl Default for Theme {
    /// Tema ZERØ Frost.
    fn default() -> Self {
        Self {
            version: 1,
            id: "zero-frost".into(),
            nombre: "ZERØ Frost".into(),
            modo: "dark".into(),
            zerolayer: true,
            colores: Colors::default(),
            fondo_pantalla: String::new(),
            glifo: "Ø".into(),
            kanji: "零".into(),
            fuentes: Fonts::default(),
            actualizado: String::new(),
        }
    }
}

/// Nombres de las variables CSS que genera [`Theme::css_variables`].
///
/// Cada aplicación elige los suyos con [`CssMap::rename`]; una clave quitada con [`CssMap::without`]
/// no se emite.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CssMap {
    names: Vec<(Key, &'static str)>,
    /// Pila de respaldo detrás del nombre de la fuente sans, p. ej. `system-ui, sans-serif`.
    pub sans_fallback: &'static str,
    /// Pila de respaldo detrás del nombre de la fuente mono.
    pub mono_fallback: &'static str,
}

impl Default for CssMap {
    /// `--fondo`, `--superficie`, `--borde`, `--texto`, `--tenue`, `--acento`, `--acento2`, `--ok`,
    /// `--aviso`, `--peligro`, `--sans` y `--mono`.
    fn default() -> Self {
        let names = [
            (Key::Fondo, "--fondo"),
            (Key::Superficie, "--superficie"),
            (Key::Borde, "--borde"),
            (Key::Texto, "--texto"),
            (Key::Tenue, "--tenue"),
            (Key::Acento, "--acento"),
            (Key::Acento2, "--acento2"),
            (Key::Ok, "--ok"),
            (Key::Aviso, "--aviso"),
            (Key::Peligro, "--peligro"),
            (Key::Sans, "--sans"),
            (Key::Mono, "--mono"),
        ];
        Self { names: names.to_vec(), sans_fallback: "system-ui, sans-serif", mono_fallback: "monospace" }
    }
}

impl CssMap {
    /// Cambia el nombre de la variable de una clave.
    pub fn rename(mut self, key: Key, name: &'static str) -> Self {
        match self.names.iter_mut().find(|(k, _)| *k == key) {
            Some(entry) => entry.1 = name,
            None => self.names.push((key, name)),
        }
        self
    }

    /// Deja de emitir la variable de una clave.
    pub fn without(mut self, key: Key) -> Self {
        self.names.retain(|(k, _)| *k != key);
        self
    }

    /// Pilas de respaldo de las fuentes.
    pub fn fallbacks(mut self, sans: &'static str, mono: &'static str) -> Self {
        self.sans_fallback = sans;
        self.mono_fallback = mono;
        self
    }
}

/// `true` solo para `#` seguido de seis dígitos hexadecimales.
pub fn is_hex_color(value: &str) -> bool {
    let b = value.as_bytes();
    b.len() == 7 && b[0] == b'#' && b[1..].iter().all(u8::is_ascii_hexdigit)
}

/// Deja un nombre de fuente seguro para ir entre comillas en CSS: conserva letras, números, espacios
/// y `- _ . +`, recorta y colapsa espacios. Devuelve `None` si no queda nada o pasa de 64 caracteres.
pub fn sanitize_font(name: &str) -> Option<String> {
    let kept: String = name.chars().filter(|c| c.is_alphanumeric() || " -_.+".contains(*c)).collect();
    let clean = kept.split_whitespace().collect::<Vec<_>>().join(" ");
    (!clean.is_empty() && clean.chars().count() <= 64).then_some(clean)
}

fn text_field(obj: &serde_json::Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key).and_then(Value::as_str).map(str::trim).filter(|s| !s.is_empty()).map(str::to_owned)
}

fn short_text(s: String, max: usize) -> String {
    s.chars().filter(|c| !c.is_control()).take(max).collect()
}

impl Theme {
    /// Interpreta el contenido de un `theme.json`.
    ///
    /// Devuelve `None` si no es JSON o no es un objeto (en ese caso la aplicación usa
    /// [`Theme::default`]). Si lo es, cada campo inválido o ausente cae a su valor Frost.
    pub fn from_json(text: &str) -> Option<Theme> {
        let value: Value = serde_json::from_str(text).ok()?;
        value.is_object().then(|| Theme::from_value(&value))
    }

    /// Igual que [`Theme::from_json`] sobre un valor ya leído; un valor que no es objeto da el tema por defecto.
    pub fn from_value(value: &Value) -> Theme {
        let mut theme = Theme::default();
        let Some(obj) = value.as_object() else { return theme };

        if let Some(v) = obj.get("version").and_then(Value::as_u64).and_then(|v| u32::try_from(v).ok()) {
            theme.version = v;
        }
        let id = text_field(obj, "id");
        if let Some(id) = &id {
            theme.id = short_text(id.clone(), 64);
        }
        match text_field(obj, "nombre") {
            Some(n) => theme.nombre = short_text(n, 64),
            None if id.is_some() => theme.nombre = theme.id.clone(),
            None => {}
        }
        theme.modo = match obj.get("modo").and_then(Value::as_str) {
            Some("light") => "light".into(),
            _ => "dark".into(),
        };
        // Sin `zerolayer`, la aplicación no sabe si es ZERØ: un tema explícito de otro tipo lo dice con false.
        theme.zerolayer = obj.get("zerolayer").and_then(Value::as_bool).unwrap_or(false);
        if let Some(colores) = obj.get("colores").and_then(Value::as_object) {
            for key in Key::ALL {
                let valid = colores.get(key.json_name()).and_then(Value::as_str).filter(|s| is_hex_color(s));
                if let (Some(v), Some(slot)) = (valid, theme.colores.slot(key)) {
                    *slot = v.to_ascii_lowercase();
                }
            }
        }
        if let Some(v) = text_field(obj, "fondo_pantalla") {
            theme.fondo_pantalla = v;
        }
        if let Some(v) = text_field(obj, "glifo") {
            theme.glifo = short_text(v, 8);
        }
        if let Some(v) = text_field(obj, "kanji") {
            theme.kanji = short_text(v, 8);
        }
        if let Some(f) = obj.get("fuentes").and_then(Value::as_object) {
            if let Some(v) = f.get("sans").and_then(Value::as_str).and_then(sanitize_font) {
                theme.fuentes.sans = v;
            }
            if let Some(v) = f.get("mono").and_then(Value::as_str).and_then(sanitize_font) {
                theme.fuentes.mono = v;
            }
        }
        if let Some(v) = text_field(obj, "actualizado") {
            theme.actualizado = short_text(v, 40);
        }
        theme
    }

    /// `true` si el tema es claro.
    pub fn is_light(&self) -> bool {
        self.modo == "light"
    }

    /// Pares (variable CSS, valor) listos para `:root`, con los nombres de `map`.
    ///
    /// Los colores salen como `#rrggbb`; las fuentes como `"Nombre", respaldo`.
    pub fn css_variables(&self, map: &CssMap) -> Vec<(&'static str, String)> {
        map.names
            .iter()
            .filter_map(|&(key, name)| {
                let value = match key {
                    Key::Sans => format!("\"{}\", {}", self.fuentes.sans, map.sans_fallback),
                    Key::Mono => format!("\"{}\", {}", self.fuentes.mono, map.mono_fallback),
                    color => self.colores.get(color)?.to_owned(),
                };
                Some((name, value))
            })
            .collect()
    }

    /// Lee el tema de [`config_path`]. Si no hay archivo, no se puede leer o no es un objeto JSON,
    /// devuelve [`Theme::default`].
    #[cfg(not(target_arch = "wasm32"))]
    pub fn load() -> Theme {
        config_path().map(|p| Theme::load_from(&p)).unwrap_or_default()
    }

    /// Como [`Theme::load`], desde una ruta concreta.
    #[cfg(not(target_arch = "wasm32"))]
    pub fn load_from(path: &std::path::Path) -> Theme {
        std::fs::read_to_string(path).ok().and_then(|t| Theme::from_json(&t)).unwrap_or_default()
    }
}

/// La deserialización también es tolerante: un `Theme` que viaja entre procesos (p. ej. de Tauri al
/// frontend) o se lee de un JSON a medias nunca trae valores sin validar.
impl<'de> Deserialize<'de> for Theme {
    fn deserialize<D: Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        Ok(Theme::from_value(&Value::deserialize(d)?))
    }
}

impl fmt::Display for Theme {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} ({})", self.nombre, self.id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex() {
        assert!(is_hex_color("#4da3ff") && is_hex_color("#4DA3FF"));
        for malo in ["4da3ff", "#4da3f", "#4da3ffaa", "#abc", "#ggg000", "red", "", "#4da3ff;", " #4da3ff"] {
            assert!(!is_hex_color(malo), "{malo}");
        }
    }

    #[test]
    fn fuentes() {
        assert_eq!(sanitize_font("Inter Tight\"; x").as_deref(), Some("Inter Tight x"));
        assert_eq!(sanitize_font("  A   B ").as_deref(), Some("A B"));
        assert_eq!(sanitize_font("\"';{}<>"), None);
        assert_eq!(sanitize_font(&"x".repeat(65)), None);
    }

    #[test]
    fn no_objeto() {
        assert!(Theme::from_json("no es json").is_none());
        assert!(Theme::from_json("[1,2]").is_none());
        assert_eq!(Theme::from_value(&Value::Null), Theme::default());
    }
}
