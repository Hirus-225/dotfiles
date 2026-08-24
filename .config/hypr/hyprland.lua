-- Point d'entrée de la configuration Hyprland (syntaxe Lua, Hyprland >= 0.55).
--
-- Ce fichier ne fait que charger les modules dans un ordre fixe : l'ordre compte,
-- les couleurs Pywal doivent être chargées avant les modules qui les consomment.
--
-- L'ancienne configuration hyprlang est conservée dans backups/ (et hyprland.conf
-- reste sur le disque, inerte : Hyprland préfère hyprland.lua au démarrage).

require("modules.monitors")
require("modules.my_programs")
require("modules.autostart")
require("modules.variables")
require("modules.permissions")
require("modules.colors")
require("modules.apparence")
require("modules.animations")
require("modules.input")
require("modules.raccourcis-clavier")
require("modules.media-controls")
require("modules.workspaces")
