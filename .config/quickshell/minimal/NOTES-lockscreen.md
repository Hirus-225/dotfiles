# Écran de verrouillage Quickshell — ce qui a été mesuré

**Statut : abandonné.** `Lock.qml` a existé, fonctionnait, et a été retiré le
2026-09-09. hyprlock reste l'écran de verrouillage de cette machine.

Il a fonctionné **sur la vraie session**, pas seulement au banc. Le journal de
l'instance de production (PID 1726, `minimal/shell.qml`, sortie `wayland-1`)
garde la trace de trois cycles complets, déclenchés à la main :

```
2026-09-09 20:56:11.710 DEBUG qml: Lock: secure=true
2026-09-09 20:56:19.560 DEBUG qml: Lock: secure=false
2026-09-09 20:56:22.627 DEBUG qml: Lock: secure=true
2026-09-09 20:56:44.436 DEBUG qml: Lock: secure=false
2026-09-09 20:58:13.035 DEBUG qml: Lock: secure=true
2026-09-09 20:58:36.103 DEBUG qml: Lock: secure=false
```

`secure=true` signifie que le compositeur a **accordé** le verrou ; le retour à
`false` signifie qu'il a été rendu, ce qui exige une authentification PAM
réussie sur la pile `login`. Huit, vingt-deux et vingt-trois secondes : le temps
de regarder l'écran et de taper un mot de passe. Le chemin nominal complet —
verrouiller, saisir, déverrouiller — a donc été validé sur le matériel réel,
avec le vrai mot de passe, ce qu'aucun banc ne pouvait faire.

Ce fichier n'est pas une trace sentimentale : c'est ce qui reste de mesures
qu'il faudrait refaire à zéro pour les retrouver, dont **quatre pièges dont
trois se paient en session perdue**. Plusieurs valent pour hyprlock, donc
aujourd'hui, sans rien reprendre.

Contexte des mesures : Quickshell 0.3.1 (Arch), Hyprland 0.56.2, pam 1.7,
EndeavourOS, eDP-1 1440x900 scale 1. Tous les essais de verrouillage ont eu
lieu dans un **Hyprland imbriqué**, jamais sur la session.

---

## 1. `WlSessionLock.locked` ne notifie pas — un binding posé dessus est mort-né

`WlSessionLock` (module `Quickshell.Wayland`) déclare la propriété `locked` avec
un signal de notification `lockStateChanged`. **Ce signal n'est jamais émis
quand on affecte la propriété.**

Conséquence : la lecture directe est juste, mais tout binding QML reste figé sur
sa valeur initiale — et annoncerait donc « déverrouillé » sur une session
verrouillée. C'est la panne signature de cet écosystème : pas une erreur
bruyante, une valeur plausible et fausse.

### La sonde exacte

```qml
// shell.qml d'une config jetable, lancée dans un Hyprland imbriqué
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: r
    readonly property bool viaBinding: sl.locked

    WlSessionLock {
        id: sl
        onLockStateChanged: console.log("S> lockStateChanged -> sl.locked=" + sl.locked)
        onSecureChanged: console.log("S> secure=" + sl.secure
                                     + " lectureDirecte=" + sl.locked
                                     + " viaBinding=" + r.viaBinding)
        WlSessionLockSurface { color: "#202030" }
    }
    onViaBindingChanged: console.log("S> le binding a change -> " + r.viaBinding)

    Timer {
        interval: 1500; running: true
        onTriggered: {
            sl.locked = true;
            console.log("S> juste apres affectation : lectureDirecte=" + sl.locked
                        + " viaBinding=" + r.viaBinding);
            fin.start();
        }
    }
    Timer {
        id: fin; interval: 2500
        onTriggered: console.log("S> t+2.5s : lectureDirecte=" + sl.locked
                                 + " viaBinding=" + r.viaBinding)
    }
}
```

### La sortie, en entier

```
 DEBUG qml: S> juste apres affectation : lectureDirecte=true viaBinding=false
 DEBUG qml: S> secure=true lectureDirecte=true viaBinding=false
 DEBUG qml: S> t+2.5s : lectureDirecte=true viaBinding=false
```

Ce qui compte autant que ces trois lignes, c'est **ce qui n'y est pas** :
ni `S> lockStateChanged`, ni `S> le binding a change`. Aucun des deux n'a jamais
été appelé. `secure` (lecture seule, émis par le compositeur) fonctionne
normalement, lui — c'est bien `locked` seul qui est en cause.

### Ce qu'il faut faire à la place

Tenir l'état soi-même dans une propriété écrite à la main, aux seuls endroits
qui la font changer, et ne jamais binder sur `sl.locked`. La lecture directe
dans le corps d'une fonction reste fiable (elle est réévaluée à chaque appel et
lit la valeur C++ vivante) — c'est seulement le binding déclaratif qui est mort.

---

## 2. Deux clients de verrouillage sur une session = erreur de protocole fatale

`ext-session-lock-v1` n'admet **qu'un seul** client de verrouillage par session.
Un second qui tente de verrouiller reçoit une erreur de protocole Wayland, et une
erreur de protocole n'est pas rattrapable : elle **tue tout le processus
Quickshell** — donc la barre, le tray, tout.

### La trace

```
wl_display#1: error 0: invalid object 46
  WARN: The Wayland connection experienced a fatal error: Argument invalide
```

Reproduit dans le Hyprland imbriqué : une sonde avait verrouillé puis était
morte en laissant le verrou posé ; la sonde suivante s'est prise ça au
démarrage.

### Les deux corollaires

- **Ne jamais poser un `WlSessionLock` dans le `Variants` de `shell.qml`.**
  Ce serait un verrou par moniteur ; le premier verrouille, les suivants tuent le
  processus. `WlSessionLock` crée déjà lui-même une surface par écran et suit les
  branchements — sa propriété `surface` est une `QQmlComponent`, pas un objet.
- **Ne jamais faire cohabiter un verrou Quickshell avec hyprlock.** Voir §5.

### Et la propriété volontaire du protocole, qui rend tout ça grave

Si le client de verrouillage meurt **après** avoir verrouillé, le compositeur
**garde la session verrouillée** et peint un écran vide. Il ne déverrouille pas.
Vérifié dans le Hyprland imbriqué : après la mort de la sonde, le compositeur
restait verrouillé, et il a fallu le relancer.

C'est pour ça que tout essai passe par un compositeur imbriqué : une fenêtre
bloquée se ferme, une session non.

---

## 3. La pile PAM, mesurée

### Le composant

`PamContext`, module `Quickshell.Services.Pam`.

Il n'y a **pas de `.so`** dans `/usr/lib/qt6/qml/Quickshell/Services/Pam/` — que
`qmldir` et `qmltypes`. Le greffon est lié en statique dans `/usr/bin/quickshell`,
qui tire bien `libpam.so.0` et annonce `Pam: ON` dans ses options de compilation.
Chercher un fichier de greffon pour savoir si PAM est disponible ne marche donc
pas ; il faut regarder `ldd` et les chaînes du binaire.

### L'API, relevée dans `quickshell-service-pam.qmltypes`

| | |
|---|---|
| Propriétés | `active`, `config`, `configDirectory`, `user` |
| Lecture seule | `message`, `messageIsError`, `responseRequired`, `responseVisible` |
| Méthodes | `start(): bool`, `abort()`, `respond(string)` |
| Signaux | `completed(PamResult)`, `error(PamError)`, `pamMessage()` |
| `PamResult` | `Success`, `Failed`, `Error`, `MaxTries` |
| `PamError` | `StartFailed`, `TryAuthFailed`, `InternalError` |

**Défauts relevés en exécutant une sonde** (pas dans la doc) :
`config = "login"`, `configDirectory = "/etc/pam.d"`, `user = ""`.

> Piège de nommage : `PamContext` déclare son propre signal `completed`. Dans un
> bloc `PamContext {}`, `onCompleted:` est donc **celui de PAM**, pas celui de
> `Component`. Toute initialisation doit s'écrire `Component.onCompleted:`.

### `/etc/pam.d/login` existe et répond à un processus non privilégié

Rien à créer, aucun `sudo`. `login` vient du paquet `pam` lui-même, donc il est
toujours présent — contrairement à `/etc/pam.d/hyprlock`, qui appartient au
paquet hyprlock et disparaîtrait avec lui. `hyprlock` ne fait d'ailleurs que
rediriger dessus :

```
# /etc/pam.d/hyprlock
auth        include     login
```

Prérequis vérifiés un par un : `/usr/bin/zsh` est dans `/etc/shells` (pam_shells
passe), `/etc/nologin` absent, `/usr/bin/unix_chkpwd` setuid root (c'est lui qui
permet à un processus non privilégié de valider un mot de passe).

Trace d'une tentative réelle, faite depuis un processus utilisateur ordinaire :

```
Starting pam session for user "zogoue_charles" with config "login" in dir "/etc/pam.d"
Relaying pam message: "Mot de passe : " echo: 0 error: 0 responseRequired: 1
Failed to authenticate.                    → completed(Failed)
```

Noter que le message d'invite arrive **localisé** (« Mot de passe : »), donc
inexploitable pour une comparaison de chaîne.

### Les cinq comportements mesurés

1. **`start()` sur une config absente renvoie `false` et n'émet AUCUN signal.**
   Ni `completed`, ni `error`. Seule trace, au journal :
   ```
   ERROR: Cannot start PamContext(0x…) because specified config file
          "/etc/pam.d/ce-fichier-nexiste-pas" is not a file.
   ```
   C'est le même refus synchrone et muet que `connectWithPsk` dans
   `Services.qml` / `WifiMenu.qml`. **Il se traite au retour de `start()`, jamais
   dans un gestionnaire de signal** — sinon le champ de saisie reste désactivé
   pour toujours, sur un écran dont on ne peut pas sortir.

2. **Le contexte se réutilise après `completed`.** `active` retombe à `false`
   tout seul, et `start()` peut être rappelé immédiatement, y compris depuis le
   gestionnaire `completed`. Trois échecs d'affilée vérifiés, sans dégradation.

3. **`abort()` est synchrone, n'émet rien, et ne coûte aucune tentative.**
   Il met `active` à `false` immédiatement, n'émet ni `completed` ni `error`
   (donc tout code de remise en état doit suivre l'appel, pas l'attendre d'un
   signal), et laisse le contexte réutilisable. Abandonner avant de répondre à
   l'invite **n'incrémente pas `pam_faillock`** — vérifié avec `faillock` avant
   et après.

   C'est ce qui rend gratuit un **pré-vol** : `start()` puis `abort()` avant de
   verrouiller, pour refuser de verrouiller quand PAM ne répondrait pas. Fermer
   une porte dont on vient de constater qu'on n'a pas la clé est la seule faute
   vraiment irrattrapable ici.

4. **`pamMessage` n'est pas garanti.** Sur une pile qui refuse d'emblée
   (`pam_deny`), `completed(Failed)` arrive sans qu'aucun message n'ait été
   émis. Ne rien faire dépendre de l'arrivée d'une invite.

5. **Une invite laissée sans réponse bloque la conversation indéfiniment.**
   D'où la nécessité d'un chien de garde (30 s avait été retenu : pam_unix
   impose ~2 s de délai à l'échec, pam_faillock un peu plus).

### Tester le chemin de succès sans mot de passe et sans `sudo`

`configDirectory` est réglable. Une pile `pam_permit` dans un dossier à soi
suffit à vérifier tout le chemin nominal, déverrouillage réel compris :

```sh
mkdir -p /tmp/pamtest
printf 'auth\trequired\tpam_permit.so\naccount\trequired\tpam_permit.so\n' > /tmp/pamtest/toujoursok
printf 'auth\trequired\tpam_deny.so\naccount\trequired\tpam_deny.so\n'     > /tmp/pamtest/toujoursnon
```

`/etc/pam.d/other` (`pam_deny`) sert de banc d'échec déterministe sans rien
créer, et **sans toucher au compteur faillock**. C'est le bon banc pour tester
en boucle un chemin d'échec.

---

## 4. `pam_faillock` — vaut pour hyprlock aussi, dès aujourd'hui

`/etc/security/faillock.conf` **n'a aucune ligne active** sur cette machine : ce
sont les défauts de `pam_faillock` qui s'appliquent.

| | |
|---|---|
| `deny` | **3** |
| `unlock_time` | **600 s (10 min)** |
| Tally | `/run/faillock/<user>`, consultable par `faillock --user "$USER"` |

`system-auth` appelle `pam_faillock` en `preauth` / `authfail` / `authsucc`, et
`login` inclut `system-auth`. Comme `/etc/pam.d/hyprlock` n'est qu'un
`auth include login`, **hyprlock est soumis exactement au même compteur**.

Donc, aujourd'hui, sans rien reprendre : **trois mots de passe ratés sur
l'écran de verrouillage bloquent le compte 10 minutes — `sudo` et la console TTY
compris.** Ce n'est pas théorique, le compteur a été vu s'incrémenter :

```
$ faillock --user "$USER"
When                Type  Source   Valid
2026-09-09 20:30:12 SVC   login        V
```

`faillock --reset` demande root ; il n'y a donc pas d'échappatoire depuis la
session. Il faut attendre les 600 s.

Corollaire de conception : **refuser localement une soumission à champ vide.**
Une touche Entrée égarée ne doit pas coûter un tiers du budget.

---

## 5. Le piège hypridle

`~/.config/hypr/hypridle.conf`, tel qu'il est aujourd'hui (non modifié) :

```
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 1800                      # 30 minutes
    on-timeout = loginctl lock-session
}
```

Le `pidof hyprlock ||` protège contre **deux hyprlock**. Il ne protège
absolument pas contre **un hyprlock plus un autre client de verrouillage**.

Le scénario de collision, si le sujet est repris un jour :

1. Un verrou Quickshell est déclenché à la main → la session est verrouillée.
2. `hypridle` atteint son timeout de 1800 s → `loginctl lock-session` →
   `lock_cmd` → `pidof hyprlock` ne trouve rien → **hyprlock démarre**.
3. hyprlock tente `ext_session_lock_manager_v1.lock` sur une session déjà
   verrouillée → erreur de protocole → **le processus Quickshell est tué**.
4. Le protocole garde la session verrouillée. Sortie par `Ctrl+Alt+F3`.

Le même chemin s'ouvre par `before_sleep_cmd` à la mise en veille, et le
listener à 2700 s (`systemctl suspend`) y mène tout seul.

**Il n'y a pas de moyen de tenir les deux.** Reprendre le sujet impose de
basculer `lock_cmd` sur le nouveau verrou dans le même geste, pas « plus tard,
après rodage ». Il n'y a pas de période de cohabitation sûre.

Accessoirement : le module n'avait **rien à écouter**. `hypridle` passe par
`loginctl lock-session`, qui aboutit à `lock_cmd`, qui lance une commande. Il
n'y a aucun signal logind à surveiller ; il suffit d'être la commande.

---

## 6. Lisibilité du texte sur un fond quelconque — chiffres et méthode

### La question

`StyledText` porte `style: Text.Outline` avec `styleColor: Theme.bg`. Est-ce que
ce contour suffit à garder un texte clair lisible sur une photo claire ?

**Non.** Et un voile plat ne suffit pas non plus.

### La méthode

1. Générer un fond **blanc uni** (le pire cas) et le donner comme fond d'écran.
2. Verrouiller le Hyprland imbriqué, capturer avec
   `WAYLAND_DISPLAY=wayland-2 grim vue.png`.
3. Sur les **pixels réellement rendus** : luminance relative WCAG
   (`0.2126 R + 0.7152 G + 0.0722 B` après linéarisation sRGB), rapport
   `(L_clair + 0.05) / (L_sombre + 0.05)`.
4. Échantillonnage en pire cas : le pixel **le plus clair** du glyphe contre le
   pixel **le plus clair** du fond, dans une bande verticale propre juste à côté
   du texte — pas un point unique, qui tombe trop facilement sur un artefact.

Piège rencontré : le Hyprland imbriqué peint ses propres bandeaux
d'avertissement en haut de l'écran (« You are using the .conf config format… »).
Ils polluent tout échantillon pris là. Vérifier ses zones de mesure sur l'image.

### Les chiffres, sur fond blanc uni

| état | horloge (~52 px) | date (~11 px) |
|---|---|---|
| contour `StyledText` seul + voile plat 0.45 | **2.57:1** | *(non mesuré proprement)* |
| voile 0.32 + bandeau dégradé 0.72 | 4.99:1 | 4.41:1 |
| voile 0.32 + bandeau dégradé 0.80 | **5.73:1** | **4.55:1** |

Seuils WCAG AA : **3.0** pour du gros texte, **4.5** pour du texte normal.

2.57 est donc sous le seuil réservé au *gros* texte. Le contour épaissit le
glyphe mais ne crée **aucun contraste de fond** : sur un fond clair, du texte
clair reste du texte clair.

### Ce qui a marché

Deux voiles plutôt qu'un, et c'est le point de méthode qui se réutilise :

- un **voile global léger** (0.32) qui unifie les fonds très clairs et très
  sombres sans éteindre l'image ;
- un **bandeau dégradé** sur les 30 % supérieurs, opacité 0.80 en haut,
  transparent en bas — là où il y a du texte, et **seulement** là. Le bas de
  l'image reste intact.

Un voile plat unique ne peut pas monter assez haut sans tuer la photo ; c'est la
séparation qui règle le problème, pas l'intensité. Coût : deux quads de mélange
plein écran, statiques, peints une fois. Pas de flou, pas de `clip`, pas
d'animation — tenable sur l'Intel HD 6000 de 2017.

---

## 7. Deux notes annexes, indépendantes du verrouillage

**Le fond d'écran pywal est un JPEG déguisé.**
`~/.cache/wal/current_wallpaper.png` est en réalité un
`JPEG image data … 3840x2160`. Qt le décode au contenu et pas à l'extension,
donc le nom n'est pas un problème — mais la taille en est un : 8,3 Mpx, soit
~33 Mo de RAM et une texture 4K à téléverser. `sourceSize` fait décoder **à
l'échelle** (~5 Mo pour un 1440x900). Le prendre sur `screen.width/height`, pas
sur `width/height` de l'item : ces derniers valent encore 0 à la création, et un
`sourceSize` nul signifie « sans contrainte », donc le décodage 4K qu'on voulait
éviter.

**Un compositeur imbriqué hérite du scale du parent.**
Le Hyprland imbriqué rendait en **scale 2** : fenêtre de 698x837 physiques, donc
surface **logique** de 349x419. Des tailles posées en dur (heure de 91 px,
marges de 56 px) y débordaient et se chevauchaient, alors que le 1440x900 réel en
scale 1 ne montrait rien. C'est un test plus sévère que le réel — le garder.

La leçon générale : borner les largeurs pour que les colonnes ne **puissent
pas** se chevaucher, plutôt que de compter sur des tailles qui tombent juste.
