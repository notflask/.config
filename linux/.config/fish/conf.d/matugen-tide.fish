# Tide merkt sich einige Farben beim Start der Shell (Trenner, Git-Zweig).
# Ändert theme.sh sie (Universal-Variablen), hier neu einlesen, damit offene
# Shells die neuen Farben sofort zeigen.
status is-interactive || exit
function _matugen_tide_refresh --on-variable tide_character_color
    functions -q _tide_cache_variables && _tide_cache_variables
    commandline -f repaint 2>/dev/null
end
