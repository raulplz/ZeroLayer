# zerolayer-theme

Lee `~/.config/zerolayer/theme.json` desde Rust, tal como lo define [`docs/theme-json.md`](../../docs/theme-json.md) de ZeroLayer. Solo depende de `serde` y `serde_json`.

```toml
[dependencies]
zerolayer-theme = { git = "https://github.com/raulplz/ZeroLayer", tag = "v0.3.1" }
# con vigilancia del archivo:
# zerolayer-theme = { git = "...", tag = "v0.3.1", features = ["watch"] }
```

```rust
use zerolayer_theme::{CssMap, Key, Theme};

let theme = Theme::load(); // Frost si no hay archivo, o campo a campo si falta o es inválido
let css = CssMap::default().rename(Key::Superficie, "--panel-2");
for (nombre, valor) in theme.css_variables(&css) {
    println!("{nombre}: {valor};");
}
```

- Solo se aceptan colores `#rrggbb`; el resto cae al color Frost de esa clave. Los nombres de fuente se sanean.
- `Theme::load()` respeta `XDG_CONFIG_HOME` (vacío o relativo cuenta como no definido).
- Feature `watch`: `watch(intervalo, |tema| ...)` lanza un hilo que sondea inodo, tamaño y fecha (sin `notify`); `ThemeWatcher::poll()` sirve para un bucle propio.
- Compila a `wasm32-unknown-unknown` sin la feature `watch`: allí solo existen el análisis (`Theme::from_json`, `Deserialize`) y `css_variables`, sin acceso a archivos.

```bash
cargo test && cargo test --features watch
cargo build --target wasm32-unknown-unknown
```
