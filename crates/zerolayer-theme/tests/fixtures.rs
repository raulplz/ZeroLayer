use std::path::PathBuf;

use zerolayer_theme::{config_path_from, CssMap, Key, Theme};

fn fixture(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures").join(name)
}

#[test]
fn valido() {
    let t = Theme::load_from(&fixture("valido.json"));
    assert_eq!(t.id, "zero-corp");
    assert_eq!(t.nombre, "ZERØ Corp");
    assert!(t.zerolayer && !t.is_light());
    assert_eq!(t.colores.acento, "#e8182c");
    assert_eq!(t.colores.texto, "#e6e9ee", "se normaliza a minúsculas");
    assert_eq!(t.kanji, "企");
    assert_eq!(t.fondo_pantalla, "/home/x/fondo.png");
    assert_eq!(t.actualizado, "2026-11-17T22:06:49+01:00");
}

#[test]
fn parcial_completa_con_frost() {
    let t = Theme::load_from(&fixture("parcial.json"));
    let frost = Theme::default();
    assert_eq!(t.colores.acento, "#00ffaa");
    assert_eq!(t.colores.fondo, "#000000");
    assert_eq!(t.colores.texto, frost.colores.texto);
    assert_eq!(t.colores.peligro, frost.colores.peligro);
    assert_eq!(t.fuentes, frost.fuentes);
    assert_eq!(t.nombre, "zero-neon", "sin nombre se usa el id");
    assert_eq!(t.kanji, "光");
    assert_eq!(t.glifo, "Ø");
}

#[test]
fn invalido_cae_campo_a_campo() {
    let t = Theme::load_from(&fixture("invalido.json"));
    let mut esperado = Theme::default().colores;
    esperado.ok = "#8fbea0".into();
    assert_eq!(t.colores, esperado);
    assert_eq!(t.modo, "dark");
    assert_eq!(t.fuentes.sans, "Inter Tight bodydisplaynone");
    assert_eq!(t.fuentes.mono, Theme::default().fuentes.mono);
    assert_eq!(t.glifo, "Ø");
    assert_eq!(t.kanji, "零");
    for (_, valor) in t.css_variables(&CssMap::default()) {
        assert!(!valor.contains(['{', '}', ';', '<', '>']), "{valor}");
    }
}

#[test]
fn ausente_o_ilegible_es_frost() {
    assert_eq!(Theme::load_from(&fixture("no_existe.json")), Theme::default());
    assert_eq!(Theme::load_from(&fixture("no_objeto.json")), Theme::default());
    assert_eq!(Theme::load_from(&PathBuf::from(env!("CARGO_MANIFEST_DIR"))), Theme::default(), "una carpeta no es un tema");
}

#[test]
fn tema_no_zero() {
    let t = Theme::load_from(&fixture("omarchy.json"));
    assert!(!t.zerolayer && t.is_light());
    assert_eq!(t.id, "catppuccin");
    assert_eq!(t.colores.fondo, "#fafafa");
    assert_eq!(t.fuentes.sans, "sans-serif");
}

#[test]
fn variables_css_con_mapeo() {
    let t = Theme::load_from(&fixture("valido.json"));
    let todas = t.css_variables(&CssMap::default());
    assert_eq!(todas.len(), 12);
    assert!(todas.contains(&("--acento", "#e8182c".to_string())));
    assert!(todas.contains(&("--sans", "\"Inter Tight\", system-ui, sans-serif".to_string())));

    let mapa = CssMap::default()
        .rename(Key::Superficie, "--panel-2")
        .rename(Key::Peligro, "--rojo")
        .without(Key::Mono)
        .fallbacks("\"Noto Sans\", sans-serif", "monospace");
    let v = t.css_variables(&mapa);
    assert_eq!(v.len(), 11);
    assert!(v.contains(&("--panel-2", "#14181f".to_string())));
    assert!(v.contains(&("--rojo", "#ff5470".to_string())));
    assert!(v.contains(&("--sans", "\"Inter Tight\", \"Noto Sans\", sans-serif".to_string())));
    assert!(!v.iter().any(|(k, _)| *k == "--superficie" || *k == "--mono"));
}

#[test]
fn serde_ida_y_vuelta_y_tolerante() {
    let t = Theme::load_from(&fixture("valido.json"));
    let json = serde_json::to_string(&t).unwrap();
    assert_eq!(serde_json::from_str::<Theme>(&json).unwrap(), t);
    let sucio: Theme = serde_json::from_str(r##"{"colores":{"acento":"x; y"}}"##).unwrap();
    assert_eq!(sucio.colores.acento, "#4da3ff");
}

#[test]
fn ruta_xdg() {
    let o = |s: &str| Some(std::ffi::OsString::from(s));
    let con = |x, h| config_path_from(x, h).map(|p| p.display().to_string());
    assert_eq!(con(o("/x/cfg"), o("/home/u")).as_deref(), Some("/x/cfg/zerolayer/theme.json"));
    assert_eq!(con(o(""), o("/home/u")).as_deref(), Some("/home/u/.config/zerolayer/theme.json"), "vacío = no definido");
    assert_eq!(con(o("relativa"), o("/home/u")).as_deref(), Some("/home/u/.config/zerolayer/theme.json"));
    assert_eq!(con(None, o("/home/u")).as_deref(), Some("/home/u/.config/zerolayer/theme.json"));
    assert_eq!(con(None, None), None);
}

#[cfg(feature = "watch")]
#[test]
fn vigilancia_detecta_renombrado() {
    use zerolayer_theme::ThemeWatcher;
    let dir = std::env::temp_dir().join(format!("zl-theme-test-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let ruta = dir.join("theme.json");
    let mut w = ThemeWatcher::at(ruta.clone());
    assert_eq!(w.poll(), Some(Theme::default()), "primera lectura, sin archivo");
    assert_eq!(w.poll(), None);
    let escribir = |acento: &str| {
        let tmp = dir.join("theme.json.tmp");
        std::fs::write(&tmp, format!(r##"{{"colores":{{"acento":"{acento}"}}}}"##)).unwrap();
        std::fs::rename(&tmp, &ruta).unwrap();
    };
    escribir("#111111");
    assert_eq!(w.poll().unwrap().colores.acento, "#111111");
    assert_eq!(w.poll(), None);
    escribir("#222222"); // mismo tamaño: lo delata el inodo
    assert_eq!(w.poll().unwrap().colores.acento, "#222222");
    std::fs::remove_file(&ruta).unwrap();
    assert_eq!(w.poll(), Some(Theme::default()));
    std::fs::remove_dir_all(&dir).unwrap();
}
