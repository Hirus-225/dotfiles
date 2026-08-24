---------------
---- INPUT ----
---------------

-- https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "mac",
        kb_model   = "applealu6",
        kb_options = "nodeadkeys",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- Voir https://wiki.hypr.land/Configuring/Gestures
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Config par périphérique
-- Voir https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
hl.device({
    name       = "casue-usb-kb",
    kb_layout  = "fr",
    kb_variant = "azerty",
    kb_model   = "",
    kb_options = "",
})
