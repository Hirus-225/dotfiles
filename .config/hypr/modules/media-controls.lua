---------------------------
---- MEDIA CONTROLS ----
---------------------------

-- Rappel de correspondance avec l'ancienne syntaxe :
--   bindel -> { locked = true, repeating = true }
--   bindl  -> { locked = true }

local osd    = { locked = true, repeating = true }
local locked = { locked = true }

-- --- Volume (Style GNOME avec SwayOSD) ---
-- Augmenter, Diminuer, Muet
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"),       osd)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),       osd)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), locked)

-- --- Luminosité écran (Spécifique MacBook Air) ---
-- Utilise SwayOSD pour le retour visuel ; --device est obligatoire ici.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --device intel_backlight --brightness raise"), osd)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --device intel_backlight --brightness lower"), osd)

-- --- Rétroéclairage du clavier (F5 et F6) ---
-- brightnessctl pilote la LED smc::kbd_backlight ; le script affiche l'OSD SwayOSD.
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_backlight.sh up"),   osd)
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/kbd_backlight.sh down"), osd)

-- --- Contrôles Media (F7, F8, F9) ---
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"),   locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),       locked)
