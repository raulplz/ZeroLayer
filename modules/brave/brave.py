"""Ajustes de Brave para ZerØLayer. Uso: python3 brave.py <carpeta de Brave>

Solo cambia preferencias que Brave no protege con firma (protection.macs).
El tema de color no se puede fijar desde aquí: Brave lo restaura al arrancar.
"""

import json
import sys
from pathlib import Path

PROFILE_CHANGES = {
    "brave": {
        # Pestañas verticales plegadas a iconos; se despliegan al pasar el ratón.
        "tabs": {
            "vertical_tabs_enabled": True,
            "vertical_tabs_collapsed": True,
            "vertical_tabs_floating_enabled": True,
            "vertical_tabs_show_title_on_window": False,
        },
        # Nueva pestaña: fondo Frost, reloj y nada más.
        "new_tab_page": {
            "background": {"random": False, "selected_value": "#080b10", "type": "color"},
            "show_branded_background_image": False,
            "show_sponsored_sites": False,
            "show_brave_news": False,
            "show_rewards": False,
            "show_brave_vpn": False,
            "show_together": False,
            "show_stats": False,
            "show_clock": True,
        },
        # Barra sin botones de Leo, Wallet, Rewards ni News (Leo sigue en la barra de direcciones).
        "ai_chat": {"show_toolbar_button": False},
        "wallet": {"show_wallet_icon_on_toolbar": False},
        "rewards": {"show_brave_rewards_button_in_location_bar": False},
        "show_brave_rewards_button": False,
        "today": {"should_show_toolbar_button": False},
        "location_bar_is_wide": True,
    },
}

# Ahorro de memoria conservador: duerme las pestañas que llevan tiempo sin usarse.
LOCAL_STATE_CHANGES = {
    "performance_tuning": {"high_efficiency_mode": {"state": 2, "aggressiveness": 0}},
}


def merge(target: dict, changes: dict) -> None:
    for key, value in changes.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            merge(target[key], value)
        else:
            target[key] = value


def apply(path: Path, changes: dict) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    merge(data, changes)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def main() -> None:
    base = Path(sys.argv[1])
    apply(base / "Default" / "Preferences", PROFILE_CHANGES)
    apply(base / "Local State", LOCAL_STATE_CHANGES)


if __name__ == "__main__":
    main()
