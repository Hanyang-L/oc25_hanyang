# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 — "AI final project BETA" — jeu 3D FPS en GDScript avec Sophia comme personnage jouable. Moteur physique : Jolt Physics. Renderer : Forward Plus.

## Lancer le jeu

Ce projet s'ouvre et se lance depuis l'éditeur **Godot 4.6**. Il n'y a pas de CLI de build — tout passe par l'éditeur.

- Scène principale (point d'entrée) : `scenes/main_menu.tscn`
- Pour lancer : F5 dans Godot (ou bouton Play) → démarre sur le menu principal
- Pour lancer une scène spécifique : F6

Il n'y a pas de tests automatisés ni de linter configuré.

## Autoloads requis (Project Settings > Autoload)

Deux singletons sont déjà enregistrés dans `project.godot` :

| Nom | Fichier |
| --- | --- |
| `Global` | `res://scripts/Global.gd` |
| `SceneTransition` | `res://scenes/transition.tscn` |

Sans ces autoloads, les appels à `Global.has_key`, `Global.change_scene()` et les transitions de scènes planteront.

## Input Actions configurées (project.godot)

| Action | Touche |
| --- | --- |
| `ui_left/right/up/down` | Flèches (par défaut Godot) |
| `ui_accept` | Espace (par défaut Godot) |
| `interact` | E |
| `sprint` | Shift |

> `freefly` n'est **pas** dans `project.godot`. Le paramètre `can_freefly` de `sophia.gd` est `false` par défaut, donc ce n'est pas nécessaire.

## Architecture

### État actuel des scènes

Le projet contient actuellement **4 scènes jouables** précédées d'un menu principal, plus une scène de bar instanciable. La progression est **non-linéaire** : scene_4 renvoie dans scene_1 avec la clé pour ouvrir le coffre final.

```text
main_menu → scene_1_data → scene_2_gpu → scene_3_llm → scene_4_neuralnet
                ↑                                              │ (clé)
                └──────────────────────────────────────────────┘
```

- `scenes/main_menu.tscn` — menu principal (bouton START). Scène de démarrage du jeu. Pilotée par `scripts/main_menu.gd`.
- `scenes/scene_1_data.tscn` — salle de data center (22×4.5×34 m, béton sombre). Grille 8×4 de racks serveurs CSG. Grand PC RGB au fond (Z=−13.5). **Coffre chest_gold (X=3.5, Z=−13.5)** ouvrable avec la clé. Pilotée par `scripts/scene_1.gd`.
- `scenes/scene_2_gpu.tscn` — scène thématique GPU géant (PCB 160×2×100) dans un environnement sombre façon espace. Pilotée par `scripts/scene_2.gd`. Voir section dédiée ci-dessous. **Double jump activé** (`can_double_jump = true`).
- `scenes/scene_3_llm.tscn` — puzzle LLM : ranger des blocs-mots sur des panneaux pour compléter 3 phrases. Pilotée par `scripts/scene_3_llm.gd`. Voir section dédiée ci-dessous.
- `scenes/scene_4_neuralnet.tscn` — puzzle réseau de neurones : panneau de boutons sur I1 (poids W=1/x par chemin), activer les chemins (vert=valide, rouge=croisé+deadly), traverser les neurones jusqu'à Output pour ramasser la clé. Minimap temps réel sur I3. **Pas de NextSceneArea.** Pilotée par `scripts/scene_4_neuralnet.gd`. Voir section dédiée ci-dessous.
- `scenes/chest_gold.tscn` — coffre interactif (instance de `chest_gold.glb` + AnimationPlayer "open"). Utilisé dans scene_1_data. Piloté par `scripts/chest.gd`.
- `scenes/beach_bar.tscn` — scène de bar intérieur complète avec assets dungeon_assets texturés et collision complète (voir section dédiée ci-dessous).
- `scenes/transition.tscn` — overlay de fondu noir (autoload `SceneTransition`).
- `scenes/key_pickup.tscn` — pickup de clé (CSG + AnimationPlayer). Export `next_scene_override: String` : si renseigné, appelle `Global.change_scene()` après ramassage.
- `scenes/barrel.tscn` — baril décoratif (StaticBody3D + ConcavePolygonShape3D, GLB).
- `scenes/sophia_player.tscn` — le joueur actif dans toutes les scènes (Sophia). Référencé dans les scènes par le nœud `$Sophia`. Piloté par `scripts/sophia.gd`.
- `scenes/patrick_player.tscn` — ancien joueur (Patrick/SpongeBob), remplacé par Sophia dans les scènes jouables. Non utilisé en jeu.
- `scenes/skeleton_mage.tscn` — instance du GLB skeleton_mage avec pose de bones adjustée (non utilisé en jeu).
- `scenes/zombie.tscn` — instance du GLB zombie avec animations retravaillées ("move", etc.) (non utilisé en jeu).

### Menu principal (`scenes/main_menu.tscn` + `scripts/main_menu.gd`)

- `Control` plein écran avec un `TextureRect` (fond) et un `Button` "START" centré
- Au `_ready()` : libère la souris (`MOUSE_MODE_VISIBLE`)
- Bouton START → `Global.change_scene("res://scenes/scene_1_data.tscn")`

### Progression des scènes

Les scènes 1–3 utilisent un pattern commun : `NextSceneArea.body_entered` → lecture de `res://scenes/` → `scene_N+1_*.tscn` → `Global.change_scene()`.

**Exception scene_4_neuralnet** : pas de `NextSceneArea`. La sortie se fait via `KeyPickup` sur le neurone Output (`next_scene_override = "res://scenes/scene_1_data.tscn"`). Quand Sophia appuie E, `key_pickup.gd` pose `Global.has_key = true` puis appelle `Global.change_scene()`.

Différences script par script :

- `scene_1.gd` : crée au runtime les ventilateurs du PC RGB (`_setup_fans()` — 9 ventilateurs face Z+ + 3 ventilateurs dessus), les anime via `_process` (`rotate_z` pour côté, `rotate_y` pour dessus). Affiche le sous-titre "Trouve la sortie du data center".
- `scene_2.gd` : gère les zones de danger sur les traces, les étincelles électriques, les ventilateurs rotatifs et le mécanisme des caps à placer. La `NextSceneArea` est **désactivée au démarrage** et ne s'active que quand tous les caps sont placés.
- `scene_4_neuralnet.gd` (utilisé par **scene_4_neuralnet**) : système de puzzle complet — boutons (32, un par chemin), poids W (1/x), détection de croisements algorithmique, visibilité dynamique des chemins (off/vert/rouge), minimap via SubViewport. Gère uniquement la kill zone — **pas de `_on_next_scene_area_body_entered`**.
- `scene_3_llm.gd` (utilisé par **scene_3_llm**) : puzzle de blocs-mots (3 phrases × 5 slots). Gère `NextSceneArea` activée quand `_correct_count >= 15`.

### Singleton Global (`scripts/Global.gd`)

Unique source de vérité partagée entre scènes :

- `has_key: bool` — Sophia a-t-elle ramassé la clé ? (posé à `true` par `key_pickup.gd` en scene_4_neuralnet, lu par `chest.gd` en scene_1)
- `current_scene_path: String` — utilisé par `reload_current_scene()` pour le respawn après mort
- `change_scene(path)` — passe par `SceneTransition` si disponible, sinon change directement
- `reload_current_scene()` — recharge la scène courante (appelé par `die()`)
- `reset_game()` — remet `has_key = false` et `current_scene_path = ""`

### Joueur actif — Sophia (`scenes/sophia_player.tscn` + `scripts/sophia.gd`)

`sophia.gd` étend **directement `CharacterBody3D`**. Fonctionnalités :

- Mouvement FPS complet avec rotation souris, saut, sprint optionnel
- **Air momentum** : en l'air sans input, `air_drag = 0.5` u/s² (élan conservé) ; en l'air avec input, `air_acceleration = 4.0` u/s² (guidage limité). Au sol : décélération instantanée comme avant.
- Mode sous-marin (`underwater: bool`) : vitesse × `underwater_speed_factor`, gravité × `underwater_gravity_factor`
- Signal `interact_pressed` (touche E) — écouté par `key_pickup.gd`
- Signal `left_click_pressed` (clic gauche souris quand capturée) — utilisé dans `scene_3_llm.gd` (pick up blocs) et `scene_4_neuralnet.gd` (raycast boutons). Clic gauche quand souris **non** capturée → re-capture la souris sans émettre le signal.
- Méthode `die()` — recharge la scène via `Global.reload_current_scene()`
- La souris est capturée au `_ready()` ; `_notification(WM_WINDOW_FOCUS_IN)` la re-capture. Échap la relâche, clic gauche la recapture (sans émettre `left_click_pressed`).
- **Animations** : `AnimationPlayer` récupéré à `$SophiaMesh/AnimationPlayer`. 8 animations disponibles dans `sophia.glb` : `EdgeGrab`, `Fall`, `Idle`, `Jump`, `Run`, `RunTiltL`, `RunTiltR`, `WallSlide`. `_update_animation()` appelé chaque frame : Idle/Run/RunTiltL/RunTiltR au sol, Jump/Fall en l'air.
- **Angle de vue vertical** : `look_rotation.x` clampé entre −80° et +80° (limite haute étendue de 45° à 80°).
- **Caméra double** : Tab bascule entre la caméra FPS (`$Head/Camera3D`, `cull_mask=1`) et la caméra top-down (`$TopDownCamera`, `cull_mask=3`). Le mesh de Sophia (`VisualInstance3D` enfants de `$SophiaMesh`) est mis à `layers=2` au `_ready()` → invisible en FPS, visible en top-down.

**Structure de `sophia_player.tscn` :**

```text
Sophia (CharacterBody3D) — script sophia.gd, collision_mask=3
├── Collider (CollisionShape3D, CapsuleShape3D)
├── CollisionShape3D (SphereShape3D)
├── SophiaMesh (Node3D, instance sophia.glb) — VisualInstance3D enfants mis layers=2 au runtime
├── TopDownCamera (Camera3D, cull_mask=3) — vue 3/4 dessus
├── Head (Node3D)
│   └── Camera3D (Camera3D, cull_mask=1, current=true) — vue FPS
└── InteractRay (RayCast3D, mask=4)
```

Paramètres exportés clés : `can_move`, `has_gravity`, `can_jump`, `can_double_jump`, `can_sprint`, `can_freefly`, `underwater`, `air_drag`, `air_acceleration`, vitesses.

**Double jump (`can_double_jump: bool = false`) :**

- Désactivé par défaut — activé dans scene_2 et scene_4.
- Premier saut : `velocity.y = jump_velocity * 1.2` (boost léger).
- Deuxième saut (en l'air) : `velocity.y = jump_velocity`, consomme `_double_jump_available`.
- `_double_jump_available` est reset à `true` chaque frame où Sophia est au sol.

> `scenes/patrick_player.tscn` + `scripts/patrick.gd` existent encore mais ne sont plus utilisés en jeu.

### Clé (`scenes/key_pickup.tscn` + `scripts/key_pickup.gd`)

- `Area3D` avec visuel CSG (anneau + tige + dents + lumière) et `AnimationPlayer`
- Export `next_scene_override: String = ""` — si renseigné, appelle `Global.change_scene(next_scene_override)` après disparition
- Pattern d'interaction :
  1. `body_entered` → connecte `sophia.interact_pressed` à `_on_interact()`
  2. `body_exited` → déconnecte le signal, remet le sous-titre
  3. `_on_interact()` → `Global.has_key = true`, animation de disparition (tween montée + scale 0), puis `Global.change_scene()` si `next_scene_override != ""`

### HUD (`ui/hud.tscn` + `scripts/hud.gd`)

Trois méthodes publiques :

- `show_message(text, duration)` — message temporaire en haut de l'écran
- `set_subtitle(text)` — instruction permanente en bas de l'écran
- Mise à jour automatique de l'icône clé (🔑 ✅ / ❌) via `Global.has_key` à chaque frame

Les scènes récupèrent le HUD avec `$HUD`.

### Scène 1 — Data Center (`scenes/scene_1_data.tscn` + `scripts/scene_1.gd`)

Environnement thématique : salle de data center sombre (béton gris, 22×4.5×34 m). Tout le décor est en CSG.

**Structure de la scène :**

```text
DataCenter (Node3D) — script scene_1.gd
├── WorldEnvironment — fond noir, ambient bleu-gris, glow, fog (density 0.008)
├── DirectionalLight3D — lumière bleutée (energy 0.3)
├── Room (Node3D) — Floor/Ceiling/WallBack/WallL/WallR (CSGBox3D béton)
├── ServerRacks (Node3D) — 32 racks en grille 8×4
│   └── Row{1-4}Col{1-8} (Node3D) — chaque rack contient :
│       ├── Body (CSGBox3D 0.9×3.5×2.0, mat_rack)
│       ├── Panel (CSGBox3D 0.06×3.4×1.9, mat_rack_panel — face X+)
│       ├── LedGreen (CSGBox3D, émissif vert, en haut du panel)
│       ├── LedYellow (CSGBox3D, émissif jaune)
│       └── LedRed (CSGBox3D, émissif rouge, point indicateur)
├── PC (Node3D, Z=−13.5) — grand PC RGB au fond
│   ├── CaseBody (CSGBox3D 2×2×1.5, boîtier noir)
│   ├── GlassPanel (CSGBox3D transparent, face Z+)
│   ├── GPU / GpuBody / GpuLed / GpuFan1-3 (CSGCylinder3D)
│   ├── Radiator, CablePurple (émissif violet), CableWhite
│   ├── FanRings (9 CSGCylinder3D statiques, grille 3×3 face Z+)
│   ├── TopFanRings (3 CSGCylinder3D, dessus)
│   ├── Fans / TopFans (Node3D vides — remplis par scene_1.gd)
│   └── PCLights / RgbYellow / RgbPurple (OmniLight3D)
├── AmbientLights — ServerGlowF/B (vert), CeilingL/R (bleu), PCGlow (jaune-vert)
├── Chest (Node3D, X=3.5, Z=−13.5, script chest.gd) — coffre final
│   ├── ChestMesh (instance chest_gold.tscn — lid animé)
│   ├── ChestBody (StaticBody3D)
│   └── InteractArea (Area3D, mask=1) — détection E + clé
├── NextSceneArea (Area3D, Z=−15.5)
├── Sophia (sophia_player.tscn, spawn Z=+13)
└── HUD (ui/hud.tscn)
```

**Disposition des racks :**

- Grille 8 colonnes × 4 rangées : X ∈ {−8.75, −6.25, −3.75, −1.25, +1.25, +3.75, +6.25, +8.75}, Z ∈ {+9, +4, −1, −6}
- Racks tournés 90° sur Y : corps 0.9m en X, 2m en Z — **panel face X+**
- 4m de couloir entre chaque rangée (Z) pour circuler
- Sophia entre par Z=+13, traverse les rangées, atteint le PC au fond (Z=−13.5)

**Ventilateurs PC (créés au runtime par `scene_1.gd._setup_fans()`) :**

- 9 ventilateurs face Z+ (grille 3×3) : lames jaune-vert émissives, hub métallique, 8 bras à 45°. Pivots à X∈{−0.62, 0, +0.62}, Y∈{0.35, 0.97, 1.59}, Z=0.76 relatif au PC. Rotation via `rotate_z(480°/s)`.
- 3 ventilateurs dessus : X∈{−0.62, 0, +0.62}, Y=2.02. Rotation via `rotate_y(360°/s)`.

**Matériaux définis en sub_resource dans le .tscn :** `mat_concrete`, `mat_rack`, `mat_rack_panel`, `mat_led_green`, `mat_led_yellow`, `mat_led_red`, `mat_case`, `mat_glass` (transparent 15%), `mat_gpu`, `mat_gpu_led`, `mat_cable_purple`, `mat_cable_white`, `mat_fan_ring`.

### Scène 2 — GPU géant (`scenes/scene_2_gpu.tscn` + `scripts/scene_2.gd`)

Environnement thématique : Sophia marche sur un GPU géant dans le vide spatial. Tout le décor est en CSG.

**Structure globale de la scène (niveau racine) :**

```text
Scene2GPU (Node3D) — script scene_2.gd
├── GPU (Node3D) — tout le décor du GPU
├── Lighting (Node3D) — OmniLights
├── SparkParticles (GPUParticles3D) — étincelles ambiantes cyan
├── NextSceneArea (Area3D) — désactivée au démarrage, s'active quand tous les caps sont placés
├── CSGCombiner3D — 4 murs encadrant l'espace GPU (gauche/droite/avant/arrière)
└── MovingCap (Node3D) — 7 caps physiques poussables (script moving_cap.gd)
```

**Structure du nœud `GPU` :**

```text
GPU (Node3D)
├── PCB (CSGBox3D, 160×2×100, vert PCB, use_collision)
├── CircuitTraces (Node3D) — Trace1–8 (horizontales) + TraceZ1–8 (verticales) + Stub1–8 (jonctions)
│   — matériau doré émissif. DANGER : contact = mort de Sophia + étincelles cyan (créés au runtime)
├── GPUCore (Node3D)
│   ├── Die (CSGBox3D, 50×0.3×50, sombre émissif bleu)
│   ├── HeatSink (Node3D) — 16 fins CSGBox3D aluminium (48×22×1.2 chacune)
│   └── VRAM (Node3D) — 16 chips CSGBox3D (ChipL1–8, ChipR1–8, 7×0.5×7, émissif vert)
├── Fans (Node3D)
│   └── FanHole (CSGBox3D, 161×5.5×102, plafond) — 3 trous cylindriques (operation=2) :
│       ├── Fan2Housing (rayon 23, hauteur 6, centre)
│       ├── Fan2Housing3 (rayon 23, hauteur 6, gauche X=−51)
│       └── Fan2Housing2 (rayon 23, hauteur 9.5, droite X=+54)
│   — 3 hélices à 8 pales créées au runtime par scene_2.gd (rotation 300°/s)
├── PowerConnector (CSGBox3D, 14×10×6, connecteur noir)
├── DisplayOutputs (Node3D) — 4 ports CSGBox3D (5×4×2, Port1–4)
├── PCIeSlot (CSGBox3D, 80×3×4, doré)
├── VRMZone (Node3D) — 6 chokes CSGCylinder3D (rayon 1.8, hauteur 3.5)
├── CapBanks (Node3D) — 8 caps VRM (rayon 1.2) + caps CapV petits (rayon 0.7), matériau brun
└── SMDComponents (Node3D) — résistances décoratives CSGBox3D
```

**Environnement et éclairage :**

- `WorldEnvironment` : fond noir spatial, ambient bleu-gris (energy 0.9), glow activé (bloom 0.5), fog sombre (density 0.003)
- `DirectionalLight3D` : lumière bleutée (energy 1.4, angle 45°)
- `Lighting` (Node3D) : AmbientBlue (range 160), CoreHeat orange (range 80), EdgeRGB violet (range 95), PCBLeft/Right vert (range 65×2), PCBFront/Back bleu (range 55×2)
- `SparkParticles` (GPUParticles3D) : 30 particules cyan ambiantes

**Mécaniques de gameplay (scene_2.gd) :**

- **Traces électriques dangereuses** : `_setup_trace_hazards()` ajoute au runtime pour chaque des 24 `CSGBox3D` de `CircuitTraces` : une `Area3D` kill zone (mask=1) + `GPUParticles3D` d'étincelles cyan émissives (bloom). Contact → `body.die()`.
- **Ventilateurs** : `_setup_fans()` crée 3 pivots `Node3D` dans `$GPU/Fans`, chacun avec 8 `MeshInstance3D` bras (BoxMesh 25×0.6×5, rotation_degrees.x=30°) + hub `CylinderMesh`. Rotation via `rotate_y(deg_to_rad(300) * delta)` dans `_process`.
- **NextSceneArea conditionnelle** : désactivée (`monitoring=false`, CollisionShape disabled) au `_ready()`. S'active via `_on_all_caps_placed()` quand `$MovingCap` émet `all_placed`. `_on_all_caps_placed()` affiche aussi un message HUD : "Tous les composants placés ! Rejoins la sortie !" (6 s) + subtitle "Rejoins la sortie au bord avant du GPU !"

**Transition :** `NextSceneArea` à Z=−47 (bord avant du PCB), box 40×8×4. **Verrouillée jusqu'au placement de tous les caps.**

**Sophia** spawn à Y=2, Z=40 (au fond du PCB). `Engine.time_scale` remis à 1.0 au `_ready()`.

### MovingCap (`scenes/scene_2_gpu.tscn` > nœud MovingCap + `scripts/moving_cap.gd`)

7 `RigidBody3D` dans `MovingCap` (layer=1, mask=1, mass=5, linear_damp=2, angular_damp=3) — caps électroniques à pousser sur les traces du circuit imprimé :

| Nœud | Position | Rayon visuel | Hauteur |
| --- | --- | --- | --- |
| Cap9 | (−1.5, 2.4, −31.4) | 1.2 | 2.8 |
| Cap10 | (−4.6, 2.4, −37.3) | 1.886 | 3.398 |
| Cap12 | (44.5, 2.25, −44.2) | 1.109 | 2.508 |
| Choke2 | (−50.2, 2.75, 33.6) | 1.8 | 3.5 |
| Cap11 | (−58.4, 2.4, −46.0) | 1.2 | 2.8 |
| Cap8 | (50.5, 2.4, 32.2) | 1.2 | 2.8 |
| Cap1 | (71.3, 2.4, 45.5) | 1.2 | 2.8 |

Chaque cap a : `CollisionShape3D` (CylinderShape3D, rayon = rayon_visuel × 0.5) + `MeshInstance3D` (CylinderMesh rayon complet + matériau).

**`moving_cap.gd` (extends Node3D) :**

- `_ready()` : collecte les 7 `RigidBody3D` enfants dans `_cap_bodies`, collecte les positions XZ des 24 traces, récupère `$"../Sophia"`. Pour chaque RigidBody3D : `axis_lock_linear_y=true`, `axis_lock_angular_x/z=true`, `linear_damp=14`, `angular_damp=14`, `PhysicsMaterial(friction=1.0, rough=true)`.
- `_process()` : pour chaque cap non-freezé → `_apply_push()` + `_check_snap()`.
- `_apply_push(rb)` : si Sophia est à ≤ `PUSH_RANGE` (1.5 u), applique `apply_central_impulse` de `PUSH_FORCE` (15 N) en direction opposée à Sophia (Y ignoré).
- `_check_snap(rb)` : si vitesse < 2 m/s ET distance XZ au trace le plus proche < `SNAP_THRESHOLD` (2.5 u) → `rb.freeze = true`, centre le cap sur la trace, incrémente `_placed_count`. Quand tous placés → `all_placed.emit()`.
- Signal `all_placed` → `scene_2.gd` réactive la NextSceneArea.

### Scène 3 — LLM puzzle (`scenes/scene_3_llm.tscn` + `scripts/scene_3_llm.gd`)

Environnement thématique : puzzle de blocs-mots. Sophia ramasse des blocs et les classe dans les bons panneaux pour compléter 3 phrases. Quand les 3 phrases sont résolues, la `NextSceneArea` s'active.

**`scene_3_llm.gd` — mécanique :**

- 3 phrases × 5 mots, 15 blocs `RigidBody3D` créés au runtime (couleur par phrase)
- Sophia ramasse un bloc (**E ou clic gauche**), le tient devant la caméra, le place (1–5) dans le rack le plus proche. E/clic gauche à nouveau → lâcher.
- `_try_validate_phrase()` : si les 5 mots sont dans le bon ordre → blocs verts, `_solved_phrases++`
- `_check_all_complete()` : quand `_correct_count >= 15` → active `$NextSceneArea`

**Transition :** `NextSceneArea` → `scene_4_neuralnet` (scan auto `scene_N+1_*.tscn`).

### Scène 4 — Réseau de neurones (`scenes/scene_4_neuralnet.tscn` + `scripts/scene_4_neuralnet.gd`)

Puzzle platformer dans le vide spatial violet. Sophia active les chemins depuis un panneau de boutons sur I1, choisit la combinaison correcte (W=1/x le plus élevé, sans croisements) et traverse les neurones jusqu'à la clé sur Output.

**Structure de la scène :**

```text
Scene4NeuralNet (Node3D) — script scene_4_neuralnet.gd
├── WorldEnvironment — fond noir-violet, ambient violet, glow, fog (density 0.002)
├── DirectionalLight3D / LightInput / LightHidden / LightOutput / UnderGlow1-3
├── InputLayer  — I1 (X=−16), I2 (X=0), I3 (X=+16) — CSGCylinder3D r=4, Z=80
├── HiddenLayer1 — H1–H4 (X=−24/−8/8/24, Z=20)
├── HiddenLayer2 — H5–H8 (X=−24/−8/8/24, Z=−40)
├── OutputLayer — O (X=0, Z=−95)
├── Paths (Node3D)
│   ├── L1 (CSGCombiner3D) — 12 CSGBox3D I→H1
│   ├── L2 (CSGCombiner3D) — 16 CSGBox3D H1→H2
│   └── L3 (CSGCombiner3D) — 4 CSGBox3D H2→O
│   (démarrent INVISIBLES ; collision/kill gérées dynamiquement par script)
├── ButtonPanel (CSGBox3D 7.5×7×0.2, centré sur I1 à Z=84) — panneau de boutons
│   └── Btn_XXXX (Node3D × 32) — un par chemin :
│       ├── Mesh  (CSGBox3D 1.1×1.1×0.18, mat gris→vert→rouge selon état)
│       ├── Zone  (Area3D mask=1) — interact_pressed → toggle chemin
│       └── Info  (Label3D billboard, pixel_size=0.02, "I2→H2\nW=1/2")
├── MapScreen (CSGBox3D 7×0.1×7 plat sur I3) — ViewportTexture minimap
├── MinimapViewport (SubViewport 512×512, own_world_3d=false)
│   └── MinimapCamera (Camera3D Y=120, orthogonal, regarde vers −Y)
├── KillZone (Area3D, Y=−29) — mort si tombée dans le vide
├── Sophia — spawn (0, 4, 80), can_double_jump=true, jump_velocity=5.5
│   underwater=true, underwater_speed_factor=1.0, underwater_gravity_factor=0.55
├── HUD (ui/hud.tscn)
└── KeyPickup (key_pickup.tscn, pos (0, 3.5, −95))
    next_scene_override = "res://scenes/scene_1_data.tscn"
```

**Neurones :** CSGCylinder3D r=4, h=1, 16 côtés. `use_collision = true`.

**32 chemins (`$Paths`) :** Organisés dans L1/L2/L3 (CSGCombiner3D avec transforms inversés pour orientation correcte). Nommés `I1H2`, `H3H7`, `H6O`, etc. (convention `from+to`).

**Système de poids W (fractions 1/x) :**

Stockés dans `PATH_DENOM` (dict `name → dénominateur x`). Plus petit dénominateur = W plus élevé. La solution correcte : `I2H2` (W=1/2) → `H2H6` (W=1/2) → `H6O` (W=1/2) — les 3 ont le W le plus élevé de leur couche et ne se croisent pas.

**Détection de croisements :**

`_paths_cross(a, b)` : deux chemins de la même couche se croisent si l'ordre X de leurs neurones s'inverse : `(xa−xb)*(ya−yb) < 0`. Positions X dans `NEURON_X` : I1=−16, I2=0, I3=16 ; H1=H5=−24, H2=H6=−8, H3=H7=8, H4=H8=24. L3 : aucun croisement (convergence vers O).

**États des chemins :**

- INACTIF → matériau transparent (alpha=0), aucune collision
- ACTIF VALIDE (vert) → matériau vert émissif + `StaticBody3D` ajouté dynamiquement (praticable)
- ACTIF CROISÉ (rouge) → matériau rouge + `StaticBody3D` + `Area3D` kill zone (contact = `die()`)

**`scene_4_neuralnet.gd` — fonctions clés :**

- `_init_paths()` : `$Paths.find_children("*","CSGBox3D")` + filtre `PATH_DENOM.has()` → rend invisibles.
- `_init_buttons()` : lit les `Btn_XXXX/Zone` sous `$ButtonPanel`, connecte `body_entered/exited.bind(path_name)`. Zones ont `collision_layer = 4`.
- `_init_minimap()` : applique `ViewportTexture` du `$MinimapViewport` sur `$MapScreen.material`.
- `_on_btn_interact(path_name)` : toggle `_path_active[path_name]` → `_update_all_paths()`.
- `_update_all_paths()` : recalcule tous les croisements (`_paths_cross` pairwise), appelle `_set_path_state()` + met à jour couleurs boutons.
- `_set_path_state(name, "off"|"green"|"red")` : matériau chemin + création/suppression `StaticBody3D` et `Area3D` kill via `_path_bodies[name]` et `_path_kills[name]` (`queue_free` pour retirer).
- `_on_raycast_interact()` : raycast depuis la caméra (range 15 u, `collision_mask=4`) → détecte les `Area3D` boutons, appelle `_on_btn_interact(path_name)`. Connecté à `left_click_pressed`.

**Interaction boutons — double mode :**

1. **Proximité (E)** : `body_entered` → connect `_sophia.interact_pressed` à `_on_btn_interact.bind(path_name)` ; `body_exited` → disconnect. Un seul callable actif à la fois via `_current_btn_callable`.
2. **Clic gauche à distance** : `left_click_pressed` → `_on_raycast_interact()` → raycast mask=4 → toggle le chemin pointé sans nécessiter de proximité.

**Minimap :** `MinimapViewport` (`own_world_3d=false`) + `MinimapCamera` (orthogonale Y=120, regarde vers −Y). Texture sur `MapScreen` (dalle plate sur I3).

**Sophia dans cette scène :** `underwater_gravity_factor=0.55` → gravité réduite (sauts plus longs). `jump_velocity=5.5`. Double jump activé.

**Transition :** Ramasser la clé sur O (E) → `Global.has_key = true` → `Global.change_scene("res://scenes/scene_1_data.tscn")`. Kill zone à Y=−29.

### Coffre (`scenes/chest_gold.tscn` + `scripts/chest.gd`)

Coffre final accessible depuis scene_1_data une fois la clé récupérée en scene_4_neuralnet.

**Structure de `chest_gold.tscn` :**

```text
Chest_gold (Node3D — instance chest_gold.glb)
├── chest_gold
│   └── chest_gold_lid (transform fermé par défaut — rotation identité)
└── AnimationPlayer (animation "open" : rotation_degrees:x de 0→−90° en ~2s)
```

**`chest.gd` (extends Node3D) :**

- `_ready()` : connecte `$InteractArea.body_entered/exited`
- `_on_body_entered()` : si Sophia + `!_opened` → subtitle "E : ouvrir le coffre" (ou "Il te faut la clé") + connecte `interact_pressed`
- `_on_interact()` : si `Global.has_key` → `_opened = true`, HUD "Coffre ouvert ! Félicitations !", joue `$ChestMesh/AnimationPlayer.play("open")`

**Position dans scene_1 :** `Chest (Node3D, X=3.5, Y=0, Z=−13.5)` — à droite du PC.

### Layers de collision

| Layer | Usage |
| --- | --- |
| 1 | Sophia (layer) + sol/terrain + objets statiques + caps `MovingCap` |
| 2 | Mesh de rendu de Sophia (`VisualInstance3D.layers=2`) — invisible pour la caméra FPS (`cull_mask=1`), visible pour la caméra top-down (`cull_mask=3`) |
| 4 | `InteractRay` mask |

Sophia a `collision_mask = 3` (layers 1 et 2) — elle voit les objets des deux layers.
Les `Area3D` kill zones des traces ont `collision_layer=0, collision_mask=1` — détectent Sophia (layer 1) mais pas les caps (aussi layer 1, mais sans `die()` → inoffensif).

### Beach Bar (`scenes/beach_bar.tscn`)

Scène instanciable d'un bar intérieur (10×8×3.2 m) construite avec les assets `dungeon_assets`. Pas de script propre — tout est déclaratif dans le .tscn.

**Structure de la scène :**

```text
BeachBar (Node3D)
├── Structure (Node3D)
│   ├── Floor (CSGCombiner3D, use_collision) — sol avec trou circulaire
│   ├── WallBack/WallLeft/WallRight (CSGBox3D, use_collision)
│   ├── Ceiling (CSGBox3D, use_collision)
│   ├── Counter (CSGBox3D, use_collision) — comptoir central
│   └── WallDeco (Node3D) — piliers, arches, étagère, panneaux
├── Props (Node3D) — tables, chaises, barils, caisses, bannière, pièces, torches
├── Particles (Node3D) — flammes GPUParticles3D (torches + bougies)
└── Lights (Node3D) — OmniLight3D (torches orange + bougies jaunes + AmbientFill)
```

**Texture dungeon_assets — pattern important :**

Tous les GLB de `assets/dungeon_assets/` partagent une unique texture atlas : `assets/dungeon_assets/dungeon_albedo.png`. Le matériau externe est `assets/dungeon_assets/DungeonMat.tres` (StandardMaterial3D, roughness 0.85).

- Les `.glb.import` de chaque asset doivent avoir dans `_subresources` la clé `"DungeonMat"` (ou `"texture"` pour `chair.glb`) pointant vers `DungeonMat.tres` via `uid://dnkfdyy7f0n5w`.
- Si un asset GLB apparaît blanc/gris sans texture : ouvrir son `.glb.import`, vérifier que `_subresources` n'est pas `{}`, y ajouter la config DungeonMat, puis laisser Godot re-importer.
- Les CSG (murs, sol…) utilisent `mat_dungeon` défini en sub_resource inline dans le .tscn (même texture, même roughness).

**Collision :**

Chaque GLB instancié possède un enfant `StaticBody3D > CollisionShape3D` (BoxShape3D) ajouté directement dans le .tscn. Les formes sont définies en sub_resource dans le .tscn (`shape_pillar`, `shape_table_med`, `shape_chair`, etc.). Tous les objets ont une collision : piliers, arches, étagère, panneaux, tables, chaises, barils, caisses, bougies, assiettes, bannière, pièces, torches.

**Structure interne des GLB dungeon_assets :**

Chaque GLB a une scène glTF avec `"Scene"` comme root Node3D et un enfant MeshInstance3D nommé d'après le mesh. Godot importe donc chaque GLB comme `Node3D (root) > MeshInstance3D (mesh)`. Le `surface_material_override` sur le root Node3D n'a aucun effet — le matériau doit être configuré via `DungeonMat.tres` dans le `.glb.import`.

### Assets

- `patrick_3d.glb` + `patrick_3d_Patrick_texture.png` — modèle joueur (racine du projet)
- `assets/dungeon_assets/` — pièces de bâtiment (murs, sols, piliers) + props (coffre, clés, tonneaux, chandelles…). Texture atlas : `dungeon_albedo.png`. Matériau partagé : `DungeonMat.tres`.
- `assets/skeleton/skeleton_mage.glb` — squelette mage. Scène wrappée : `scenes/skeleton_mage.tscn` (instance GLB avec pose de bones ajustée, non utilisé en jeu).
- `assets/zombie/zombie.glb` + `zombie_idle.glb`, `zombie_run.glb`, `zombie_jump.glb` — zombie avec animations séparées. Scène wrappée : `scenes/zombie.tscn` (animations "move" retravaillées, non utilisé en jeu).
- `assets/import_examples/` — exemples barrel et chest_gold avec matériaux
- `assets/sky_background/autumn_field_puresky_4k.hdr` — skybox HDR scène 1

## Workflow Godot

- **Avant tout renommage ou déplacement de fichier** (.tscn, .gd, .glb, .import) : demander à l'utilisateur de fermer l'éditeur Godot. L'éditeur écrase silencieusement les fichiers renommés s'il est ouvert.
- **Après toute modification de `project.godot`** (autoloads, input map) : rappeler que l'éditeur doit être rechargé manuellement (Project > Reload) pour que les changements prennent effet.
- **Par défaut, utiliser uniquement des CSG** (CSGBox3D, CSGCylinder3D, CSGSphere3D…) pour construire le décor — ne jamais mélanger avec des instances GLB sauf demande explicite.
- **Avant de proposer un fix**, relire le fichier concerné (.tscn, .import, .tres) directement — ne pas se fier à la mémoire de contexte ou à des UIDs copiés depuis l'extérieur.

## Gotchas connus

Ces erreurs ont causé des redos — ne pas les répéter :

| Problème | À ne pas faire | À faire |
| --- | --- | --- |
| Transparence invisible | `alpha = 0` sur un mesh (Forward Plus l'ignore) | `layers = 0` pour rendre invisible ; `collision_layer/mask = 0` pour les Area3D |
| Matériau GLB sans effet | `surface_material_override` sur le Node3D racine | Configurer via `DungeonMat.tres` dans le `.glb.import` (clé `"DungeonMat"`) |
| Physique Jolt incompatible | Conversion runtime StaticBody3D → RigidBody3D | Déclarer le type correct dès le `.tscn` ; Jolt ne supporte pas la conversion runtime |
| Grille mal interprétée | Deviner l'axe d'une spec "8 en X, 4 en Z" | Reformuler l'interprétation à l'utilisateur **avant** de générer le code |
| Ventilateur mauvais axe | `rotate_z` pour un ventilateur face Y+ | Vérifier l'orientation : face Z+ → `rotate_z`, face Y+ → `rotate_y` |
| Autoload casse-sensitive | Corriger le nom dans `project.godot` sans recharger | Toujours rappeler Project > Reload après tout changement dans `project.godot` |
| `layers` sur Node3D ignoré | Mettre `layers = 2` sur un Node3D (instance GLB) dans le .tscn | Itérer les enfants `VisualInstance3D` en script : `find_children("*", "VisualInstance3D")` puis `vi.layers = 2` |

## Pipeline import GLB

Pour tout nouvel asset GLB dans `assets/dungeon_assets/` :

1. Placer le `.glb` dans `assets/dungeon_assets/`
2. Laisser Godot créer le `.glb.import` automatiquement
3. Ouvrir le `.glb.import` et ajouter dans `_subresources` :

   ```ini
   "materials/0/use_external/enabled": true,
   "materials/0/use_external/path": "res://assets/dungeon_assets/DungeonMat.tres"
   ```

4. Sauvegarder — Godot re-importe automatiquement
5. Si l'asset apparaît blanc/gris en scène → vérifier que `_subresources` n'est pas `{}`

Structure interne attendue : `Node3D (root) > MeshInstance3D (mesh)`. Le `surface_material_override` sur le root **n'a aucun effet** — toujours passer par le `.import`.

Pour les GLBs hors dungeon_assets : créer un `.tres` StandardMaterial3D dédié et le référencer de la même façon.
