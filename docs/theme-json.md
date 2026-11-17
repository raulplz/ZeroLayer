# theme.json

`~/.config/zerolayer/theme.json` es la paleta del tema activo de Omarchy, escrita para que las aplicaciones la lean. Lo genera `modules/theme/theme-sync.sh`; no hace falta editarlo a mano, porque se reescribe en cada cambio de tema.

Quién lo lee:

- **ZeroStudy** (la aplicación).
- **ZeroAgents** (su interfaz gráfica, `gui/`).
- Los widgets ZERØ de Serpantinum (`modules/serpantinum/faces/zerolayer/ZlTheme.qml`).
- El módulo `gtk`: `theme-sync.sh` recolorea su CSS con la misma paleta.
- La paleta de Serpantinum (`theme.colors` de su `settings.json`): `modules/theme/serp-palette.py` la deriva de los mismos colores, con copia de la original para deshacerla.

## Cuándo se escribe

- Al cambiar de tema de Omarchy, por cualquier vía: `zerolayer theme`, el menú nativo de Omarchy o `omarchy-theme-set`. Lo hace el hook `~/.config/omarchy/hooks/theme-set.d/zerolayer-theme.hook`, que instala el módulo `theme`.
- Si el archivo no existe, las aplicaciones deben usar la paleta Frost.
- La escritura es atómica: se escribe un archivo temporal y se renombra sobre el definitivo. Un lector ve siempre el archivo completo, el anterior o el nuevo.

## Esquema

Versión 1. Las claves de nivel superior son las que siempre están; `glifo`, `kanji` y `fuentes` tienen valor por defecto.

| Clave | Tipo | Significado |
|---|---|---|
| `version` | número | Versión del esquema. Hoy, `1`. |
| `id` | texto | Nombre del tema de Omarchy (`zero-frost`, `catppuccin`…), tomado de `~/.local/state/omarchy/current/theme.name`. |
| `nombre` | texto | Nombre para mostrar. Si el tema no trae `zerolayer.toml`, se deriva del `id`. |
| `modo` | `"dark"` o `"light"` | `light` solo si `colors.toml` tiene `mode = "light"`; en otro caso, `dark`. |
| `zerolayer` | booleano | `true` si el tema tiene `zerolayer.toml` (es un tema ZERØ). |
| `colores` | objeto | Diez colores, ver abajo. |
| `fondo_pantalla` | texto | Ruta real del fondo actual (`~/.local/state/omarchy/current/background`). Vacío si no hay. |
| `glifo` | texto | Emblema. Por defecto `Ø`. |
| `kanji` | texto | Kanji del tema. Por defecto `零`. |
| `fuentes` | objeto | `sans` y `mono`: nombres de fuente. |
| `actualizado` | texto | Fecha y hora ISO 8601 de la escritura. |

Claves de `colores`:

| Clave | Uso habitual |
|---|---|
| `fondo` | Fondo de la aplicación. |
| `superficie` | Tarjetas, paneles. |
| `borde` | Bordes y separadores. |
| `texto` | Texto principal. |
| `tenue` | Texto secundario, etiquetas. |
| `acento` | Color de acción principal. |
| `acento2` | Segundo acento, detalles. |
| `ok` | Estado correcto. |
| `aviso` | Estado de atención. |
| `peligro` | Error o estado crítico. |

## Ejemplo

Salida de `theme-sync.sh` para `zero-frost` (la ruta del fondo y la fecha son de ejemplo, abreviadas):

```json
{"version":1,"id":"zero-frost","nombre":"ZERØ Frost","modo":"dark","zerolayer":true,
 "colores":{"fondo":"#080b10","superficie":"#111923","borde":"#1c2a3a","texto":"#d5dfeb","tenue":"#8292a6","acento":"#4da3ff","acento2":"#75c4e8","ok":"#8fbea0","aviso":"#e6bf79","peligro":"#ef7180"},
 "fondo_pantalla":"/home/tu-usuario/.../zero-frost-1920x1080.png","glifo":"Ø","kanji":"零",
 "fuentes":{"sans":"Inter Tight","mono":"JetBrainsMono Nerd Font"},
 "actualizado":"2026-11-17T22:06:49+01:00"}
```

## De dónde sale cada color

Hay dos casos. Los temas ZERØ traen su propio `zerolayer.toml`; el resto de temas de Omarchy se derivan de su `colors.toml`.

### Tema ZERØ

Los colores base salen de `colors.toml` (`background`, `foreground`, `accent`, etc.) y la sección `[colores]` de `zerolayer.toml` sustituye `superficie`, `borde`, `tenue`, `acento2`, `ok`, `aviso` y `peligro` cuando trae un valor válido. Las fuentes salen de `[fuentes]`.

### Tema de Omarchy sin ZERØ

Se calcula así (en `theme-sync.sh`, función `cargar_paleta`). Si falta la clave de `colors.toml`, se usa el valor de la columna «Si falta».

| Campo de `colores` | Clave de `colors.toml` | Si falta |
|---|---|---|
| `fondo` | `background` | `#080b10` |
| `texto` | `foreground` | `#d5dfeb` |
| `acento` | `accent` | `blue`, o `#4da3ff` |
| `superficie` | `lighter_background` | 6 % de mezcla de `fondo` hacia `texto` |
| `borde` | `hyprland_inactive_border` | `selection`, o 15 % de mezcla |
| `tenue` | `dark_foreground` | `muted`, o 40 % de mezcla de `texto` hacia `fondo` |
| `acento2` | `cyan` | el propio `acento` |
| `ok` | `green` | `#8fbea0` |
| `aviso` | `yellow` | `#e6bf79` |
| `peligro` | `red` | `#ef7180` |

En estos temas, `fuentes.sans` es `sans-serif` y `fuentes.mono` es la fuente actual de Omarchy (`omarchy-font-current`), y `zerolayer` vale `false`.

Ejemplo de la derivación con un `colors.toml` mínimo (`mode = "light"`, `background = "#fafafa"`, `foreground = "#222222"`, `accent = "#0066cc"`, `cyan = "#00aaaa"`, `lighter_background = "#eeeeee"`, `hyprland_inactive_border = "#cccccc"`, `dark_foreground = "#666666"`): `superficie` sale `#eeeeee`, `borde` sale `#cccccc`, `tenue` sale `#666666`, `acento2` sale `#00aaaa`, `ok` sale `#8fbea0` (no había `green`) y `modo` sale `light`.

## Cómo leerlo desde una aplicación

Reglas:

1. Lee `$XDG_CONFIG_HOME/zerolayer/theme.json` (o `~/.config/zerolayer/theme.json`).
2. Si el archivo no existe, no se puede parsear o no es un objeto, usa la paleta Frost completa.
3. Para cada color, acepta solo cadenas `#rrggbb` (seis dígitos hexadecimales). Cualquier otro valor se ignora y se usa el color Frost de esa clave. Así una clave mal escrita no deja la interfaz sin color.
4. Para vigilar cambios, no te fíes solo de la notificación del sistema de archivos: la escritura cambia el inodo al renombrar. Compara el inodo, el tamaño y la fecha de modificación en cada sondeo, o vuelve a observar la carpeta.
5. Ignora las claves que no conozcas. El campo `version` te dice si el esquema cambió.

Frost de respaldo (de `ZlTheme.qml`): `fondo #080b10`, `superficie #111923`, `borde #1c2a3a`, `texto #d5dfeb`, `tenue #8292a6`, `acento #4da3ff`, `acento2 #75c4e8`, `ok #8fbea0`, `aviso #e6bf79`, `peligro #ef7180`; fuentes `Inter Tight` y `JetBrainsMono Nerd Font`.

Ejemplo en Python estándar, sin dependencias:

```python
import json, os, re, time
from pathlib import Path

FROST = {
    "fondo": "#080b10", "superficie": "#111923", "borde": "#1c2a3a", "texto": "#d5dfeb",
    "tenue": "#8292a6", "acento": "#4da3ff", "acento2": "#75c4e8", "ok": "#8fbea0",
    "aviso": "#e6bf79", "peligro": "#ef7180",
}
FUENTES_FROST = {"sans": "Inter Tight", "mono": "JetBrainsMono Nerd Font"}
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
RUTA = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "zerolayer" / "theme.json"


def leer_tema():
    colores, fuentes = dict(FROST), dict(FUENTES_FROST)
    try:
        datos = json.loads(RUTA.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return colores, fuentes
    if not isinstance(datos, dict):
        return colores, fuentes
    for clave, valor in (datos.get("colores") or {}).items():
        if clave in colores and isinstance(valor, str) and HEX.match(valor):
            colores[clave] = valor.lower()
    for clave in fuentes:
        valor = (datos.get("fuentes") or {}).get(clave)
        if isinstance(valor, str) and valor:
            fuentes[clave] = valor
    return colores, fuentes


def vigilar(al_cambiar, cada=2.0):
    """Llama a al_cambiar(colores, fuentes) al empezar y cada vez que cambie el archivo."""
    firma_previa = None
    while True:
        try:
            st = RUTA.stat()
            firma = (st.st_ino, st.st_size, st.st_mtime_ns)
        except OSError:
            firma = None
        if firma != firma_previa:
            firma_previa = firma
            al_cambiar(*leer_tema())
        time.sleep(cada)
```

Una aplicación de escritorio suele preferir un temporizador de su propio bucle o un observador de archivos en lugar de `time.sleep`; la idea es la misma.

## Probar sin tocar tu configuración

El script acepta rutas por variables de entorno, así que puedes generar el JSON en una carpeta temporal:

```bash
ZEROLAYER_THEME_DIR=/ruta/al/tema ZEROLAYER_THEME_JSON=/tmp/prueba.json \
  bash modules/theme/theme-sync.sh mi-tema
```

`ZEROLAYER_THEME_DIR` debe apuntar a una carpeta con `colors.toml` (y `zerolayer.toml` si es un tema ZERØ). Ten en cuenta que `theme-sync.sh` también recolorea GTK si el módulo `gtk` está instalado; para una prueba aislada, usa un `HOME` de prueba.
