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
| `Global` | `res://scripts/global.gd` |
| `SceneTransition` | `res://scenes/transition.tscn` |

Sans ces autoloads, les appels à `Global.has_key`, `Global.change_scene()` et les transitions de scènes planteront.

## Input Actions configurées (project.godot)

| Action | Touches |
| --- | --- |
| `ui_left` | Flèche gauche **ou A** |
| `ui_right` | Flèche droite **ou D** |
| `ui_up` | Flèche haut **ou W** |
| `ui_down` | Flèche bas **ou S** |
| `ui_accept` | Espace (par défaut Godot) |
| `interact` | E |
| `sprint` | Shift |

> `freefly` n'est **pas** dans `project.godot`. Le paramètre `can_freefly` est absent de `sophia.gd` — il n'existe plus.

## Architecture

### État actuel des scènes

Le projet contient **5 scènes jouables** précédées d'un menu principal. La progression est **linéaire** : après le réseau de neurones, Sophia arrive dans une salle finale avec le coffre, l'ouverture affiche l'écran de fin.

```text
main_menu → scene_1_data → scene_2_gpu → scene_3_llm → scene_4_neuralnet → scene_5_data_end → end_screen
```

- `scenes/main_menu.tscn` — menu principal (bouton START). Scène de démarrage du jeu. Pilotée par `scripts/main_menu.gd`.
- `scenes/scene_1_data.tscn` — salle de data center (béton sombre). Grille 8×4 de racks serveurs CSG. Grand PC RGB au fond. CeilingStairs (structure escalier vers plafond). Pilotée par `scripts/scene_1_data.gd`.
- `scenes/scene_2_gpu.tscn` — scène thématique GPU géant (PCB 160×2×100) dans un environnement sombre façon espace. Pilotée par `scripts/scene_2_gpu.gd`. Voir section dédiée ci-dessous.
- `scenes/scene_3_llm.tscn` — puzzle LLM : ranger des blocs-mots sur des panneaux pour compléter 3 phrases. Pilotée par `scripts/scene_3_llm.gd`. Voir section dédiée ci-dessous.
- `scenes/scene_4_neuralnet.tscn` — puzzle réseau de neurones : panneau de boutons sur I1 (poids W=1/x par chemin), activer les chemins (vert=valide, rouge=croisé+deadly), traverser les neurones jusqu'à Output pour ramasser la clé. Minimap temps réel sur I3. **Pas de NextSceneArea.** Pilotée par `scripts/scene_4_neuralnet.gd`. Voir section dédiée ci-dessous.
- `scenes/scene_5_data_end.tscn` — salle finale : data center avec skybox extérieure (HDR automne), beach bar instancié, PC avec ventilateurs, coffre, CeilingStairs. `Global.has_key` est posé à `true` au `_ready()`. Pilotée par `scripts/scene_5_data_end.gd`. Voir section dédiée ci-dessous.
- `scenes/chest_gold.tscn` — coffre interactif (instance de `chest_gold.glb` + AnimationPlayer "open"). Piloté par `scripts/chest.gd`. Ouvrir le coffre charge `ui/end_screen.tscn`.
- `scenes/beach_bar.tscn` — scène de bar intérieur instanciable avec assets dungeon_assets texturés et collision complète (voir section dédiée ci-dessous). Utilisée dans scene_5_data_end.
- `scenes/transition.tscn` — overlay de fondu noir (autoload `SceneTransition`). Script : `scripts/scene_transition.gd`.
- `scenes/key_pickup.tscn` — pickup de clé (CSG + AnimationPlayer). Export `next_scene_override: String` : si renseigné, appelle `Global.change_scene()` après ramassage.
- `scenes/barrel.tscn` — baril décoratif (StaticBody3D + ConcavePolygonShape3D, GLB).
- `scenes/sophia_player.tscn` — le joueur actif dans toutes les scènes (Sophia). Référencé dans les scènes par le nœud `$Sophia`. Piloté par `scripts/sophia.gd`.
- `scenes/patrick_player.tscn` — ancien joueur (Patrick/SpongeBob), remplacé par Sophia dans les scènes jouables. Non utilisé en jeu.
- `scenes/skeleton_mage.tscn` — instance du GLB skeleton_mage avec pose de bones adjustée (non utilisé en jeu).
- `scenes/zombie.tscn` — instance du GLB zombie avec animations retravaillées ("move", etc.) (non utilisé en jeu).
- `ui/end_screen.tscn` — écran de fin (CanvasLayer). AnimationPlayer "blind" + BlindTimer + EndPanel (boutons Restart / Menu). Script : `scripts/end_screen.gd`.

### Menu principal (`scenes/main_menu.tscn` + `scripts/main_menu.gd`)

- `Control` plein écran avec un `TextureRect` (fond) et un `Button` "START" centré
- Au `_ready()` : libère la souris (`MOUSE_MODE_VISIBLE`)
- Bouton START → `Global.change_scene("res://scenes/scene_1_data.tscn")`

### Progression des scènes

**scene_1_data** : Sophia interagit avec `$Display` (écran PC, touche E) → animation Sophia aspirée vers le GPU (tween position + scale 0) → `Global.change_scene("res://scenes/scene_2_gpu.tscn")`. **Pas de NextSceneArea** pour aller en scene_2.

**scene_2, scene_3** utilisent `NextSceneArea.body_entered` + scan `scene_N+1_*.tscn` → `Global.change_scene()`.

**scene_4_neuralnet** : pas de `NextSceneArea`. La sortie se fait via `KeyPickup` sur le neurone Output (`next_scene_override = "res://scenes/scene_5_data_end.tscn"`). Quand Sophia appuie E, `key_pickup.gd` pose `Global.has_key = true` puis appelle `Global.change_scene()`.

**scene_5_data_end** : `has_key = true` dès le `_ready()`. Sophia ouvre le coffre → `chest.gd` instancie `ui/end_screen.tscn` → écran de fin avec Restart / Menu.

Différences script par script :

- `scene_1_data.gd` : crée les ventilateurs PC au runtime (`_setup_fans()`), crée une `Area3D` de proximité autour de `$Display` (`_setup_display()`). Quand Sophia appuie E près de l'écran : `can_move=false`, tween vers `$PC/GPU/GpuBody`, puis `Global.change_scene("scene_2_gpu")`. Si `Global.has_key=true` au `_ready()` : Sophia spawn près du coffre (`Vector3(3.5, 1.0, -11.0)`).
- `scene_2_gpu.gd` : gère zones de danger sur les traces, étincelles, ventilateurs rotatifs, et caps. La `NextSceneArea` est **désactivée au démarrage** et ne s'active que quand tous les caps sont placés. `_on_trace_body_entered` appelle `_moving_cap.on_cap_entered_trace()` pour les RigidBody3D (caps).
- `scene_4_neuralnet.gd` : système de puzzle complet — boutons (32), poids W (1/x), croisements algorithmiques, chemins off/vert/rouge, indicateurs de bord cyan, minimap via SubViewport. Gère uniquement la kill zone — **pas de `_on_next_scene_area_body_entered`**.
- `scene_3_llm.gd` : puzzle de blocs-mots (3 phrases × 5 slots). Gère `NextSceneArea` activée quand `_correct_count >= 15`. Fallback sur `main_menu.tscn` si aucune scène suivante trouvée.
- `scene_5_data_end.gd` : quasi-identique à `scene_1_data.gd` mais avec skybox HDR, `has_key = true` forcé, et `beach_bar.tscn` instancié dans la scène.

### Singleton Global (`scripts/global.gd`)

Unique source de vérité partagée entre scènes :

- `has_key: bool` — Sophia a-t-elle ramassé la clé ? (posé à `true` par `key_pickup.gd` en scene_4, ou au `_ready()` de scene_5)
- `current_scene_path: String` — utilisé par `reload_current_scene()` pour le respawn après mort
- `change_scene(path)` — passe par `SceneTransition` si disponible, sinon change directement
- `reload_current_scene()` — recharge la scène courante (appelé par `die()`)
- `reset_game()` — remet `has_key = false` et `current_scene_path = ""`

### Joueur actif — Sophia (`scenes/sophia_player.tscn` + `scripts/sophia.gd`)

`sophia.gd` étend **directement `CharacterBody3D`**. Fonctionnalités :

- Mouvement FPS complet avec rotation souris, saut, sprint optionnel
- **Pas d'air momentum** — la décélération est instantanée au sol et en l'air (pas de `air_drag`/`air_acceleration`).
- Mode gravité réduite (`lowgravity: bool`) : vitesse × `lowgravity_speed_factor`, gravité × `lowgravity_gravity_factor`
- Signal `interact_pressed` (touche E) — écouté par `key_pickup.gd`, `chest.gd`, scènes
- Signal `left_click_pressed` (clic gauche souris quand capturée) — utilisé dans `scene_3_llm.gd` (pick up blocs) et `scene_4_neuralnet.gd` (raycast boutons). Clic gauche quand souris **non** capturée → re-capture la souris sans émettre le signal.
- Méthode `die()` — recharge la scène via `Global.reload_current_scene()`
- La souris est capturée au `_ready()` ; `_notification(WM_WINDOW_FOCUS_IN)` la re-capture. Échap la relâche, clic gauche la recapture (sans émettre `left_click_pressed`).
- **Animations** : `AnimationPlayer` récupéré à `$SophiaMesh/AnimationPlayer`. 8 animations dans `sophia.glb` : `EdgeGrab`, `Fall`, `Idle`, `Jump`, `Run`, `RunTiltL`, `RunTiltR`, `WallSlide`. `_update_animation()` appelé chaque frame : Idle/Run/RunTiltL/RunTiltR au sol, Jump/Fall en l'air.
- **Angle de vue vertical** : `look_rotation.x` clampé entre −80° et +80°.
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

Paramètres exportés clés : `can_move`, `has_gravity`, `can_jump`, `can_double_jump` (défaut **true**), `can_sprint`, `lowgravity`, `lowgravity_speed_factor`, `lowgravity_gravity_factor`, `look_speed`, `base_speed`, `jump_velocity`, `sprint_speed`.

**Double jump (`can_double_jump: bool = true`) :**

- Activé par défaut dans `sophia.gd`.
- Premier saut : `velocity.y = jump_velocity * 1.2` (boost léger).
- Deuxième saut (en l'air) : `velocity.y = jump_velocity`, consomme `_double_jump_available`.
- `_double_jump_available` est reset à `true` chaque frame où Sophia est au sol.

> `scenes/patrick_player.tscn` + `scripts/patrick.gd` existent encore mais ne sont plus utilisés en jeu.

### Clé (`scenes/key_pickup.tscn` + `scripts/key_pickup.gd`)

- `Area3D` avec visuel CSG et AnimationPlayer
- Export `next_scene_override: String = ""` — si renseigné, appelle `Global.change_scene(next_scene_override)` après disparition
- Pattern d'interaction :
  1. `body_entered` → connecte `sophia.interact_pressed` à `_on_interact()`
  2. `body_exited` → déconnecte le signal, sous-titre "Trouve l'escalier qui descend..."
  3. `_on_interact()` → `Global.has_key = true`, HUD "🔑 Clé ramassée !", animation de disparition (tween montée + scale 0), puis `Global.change_scene()` si `next_scene_override != ""`

### HUD (`ui/hud.tscn` + `scripts/hud.gd`)

Trois méthodes publiques :

- `show_message(text, duration)` — message temporaire en haut de l'écran
- `set_subtitle(text)` — instruction permanente en bas de l'écran
- Mise à jour automatique de l'icône clé (🔑 ✅ / ❌) via `Global.has_key` à chaque frame

Les scènes récupèrent le HUD avec `$HUD`.

### Écran de fin (`ui/end_screen.tscn` + `scripts/end_screen.gd`)

`CanvasLayer` ajouté au runtime par `chest.gd` après ouverture du coffre.

- Au `_ready()` : `EndPanel` masqué, joue l'animation "blind" (fondu)
- `BlindTimer` → `EndPanel.visible = true`, libère la souris
- Bouton Restart → `Global.reset_game()` + `Global.change_scene("res://scenes/scene_1_data.tscn")`
- Bouton Menu → `Global.reset_game()` + `Global.change_scene("res://scenes/main_menu.tscn")`

### Scène 1 — Data Center (`scenes/scene_1_data.tscn` + `scripts/scene_1_data.gd`)

Environnement thématique : salle de data center sombre (béton gris). Tout le décor est en CSG.

**Structure de la scène :**

```text
DataCenter (Node3D) — script scene_1_data.gd
├── WorldEnvironment — fond noir, ambient bleu-gris, glow, fog (density 0.008)
├── DirectionalLight3D — lumière bleutée (energy 0.3)
├── Room (Node3D) — Floor/Ceiling/WallBack/WallL/WallR (CSGBox3D béton)
│   └── CeilingStairs (Node3D) — structure d'escalier au plafond avec CSGBox3D/Cylinder,
│       Tube, BigTube, StStair, Barriere + Stairs (Node3D, script stairs.gd)
├── ServerRacks (Node3D) — 32 racks en grille 8×4
│   └── Row{1-4}Col{1-8} (Node3D) — chaque rack contient :
│       ├── Body (CSGBox3D 0.9×3.5×2.0, mat_rack)
│       ├── Panel (CSGBox3D 0.06×3.4×1.9, mat_rack_panel — face X+)
│       ├── LedGreen (CSGBox3D, émissif vert)
│       ├── LedYellow (CSGBox3D, émissif jaune)
│       └── LedRed (CSGBox3D, émissif rouge)
├── PC (Node3D, Z=−13.5) — grand PC RGB au fond
│   ├── CaseBody (CSGBox3D 2×2×1.5, boîtier noir)
│   ├── GPU / GpuBody (GpuFan1-3 en CSG soustraction) / GpuLed / GpuFace
│   ├── Radiator / Radiator2 / Radiator3
│   ├── CablePurple (émissif violet), CableWhite
│   ├── Fans / TopFans (Node3D vides — remplis par scene_1_data.gd)
│   └── PCLights / RgbYellow / RgbPurple (OmniLight3D)
├── Display (Node3D) — écran PC interactif ; `_setup_display()` y ajoute une Area3D
│   └── CSGBox3D — mesh de l'écran
├── AmbientLights — ServerGlowF/B (vert), CeilingL/R (bleu), PCGlow (jaune-vert)
├── Chest (Node3D, X=3.5, Z=−13.5, script chest.gd) — coffre final
│   ├── ChestMesh (instance chest_gold.tscn — lid animé)
│   ├── ChestBody (StaticBody3D)
│   └── InteractArea (Area3D, mask=1)
├── Sophia (sophia_player.tscn, spawn Z=+13 ; ou Z=−11 si has_key=true)
└── HUD (ui/hud.tscn)
```

**Disposition des racks :**

- Grille 8 colonnes × 4 rangées : X ∈ {−8.75, −6.25, −3.75, −1.25, +1.25, +3.75, +6.25, +8.75}, Z ∈ {+9, +4, −1, −6}
- Racks tournés 90° sur Y : corps 0.9m en X, 2m en Z — **panel face X+**

**Transition vers scene_2 — Display interaction (`scene_1_data.gd._setup_display()`) :**

Au `_ready()`, une `Area3D` (BoxShape 5×3×6) est créée et positionnée sur `$Display/CSGBox3D`. Quand Sophia entre dans la zone et appuie E :

1. `can_move = false`, `has_gravity = false`, `velocity = 0`
2. Tween parallèle (1.5s) : position → `$PC/GPU/GpuBody.global_position`, scale → 0
3. Callback : `Global.change_scene("res://scenes/scene_2_gpu.tscn")`

**Ventilateurs PC (créés au runtime par `_setup_fans()`) :**

Mêmes sources que scene_5 :

- `$PC/Radiator3` → ventilateurs dessus (`$PC/TopFans`)
- `$PC/Radiator2` → ventilateurs côté (`$PC/Fans`), force_axis=`Vector3(-1,0,0)`
- `$PC/GPU/GpuBody` → GPU corps (`$PC/TopFans`)
- `$PC/GPU/GpuFace` → GPU face (`$PC/Fans`)

Lames : grands = 0.238×0.014×0.042, Radiator2 = 0.140×0.010×0.028, GPU = 0.170×0.010×0.030. Hub métallique. 8 bras à 45°. Rotation `rotate_object_local(Vector3.UP, 360°/s)`.

### Scène 2 — GPU géant (`scenes/scene_2_gpu.tscn` + `scripts/scene_2_gpu.gd`)

Environnement thématique : Sophia marche sur un GPU géant dans le vide spatial. Tout le décor est en CSG.

**Structure globale de la scène (niveau racine) :**

```text
Scene2GPU (Node3D) — script scene_2_gpu.gd
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
│   — matériau doré émissif. DANGER : contact = mort + étincelles cyan (créés au runtime)
├── GPUCore (Node3D)
│   ├── Die (CSGBox3D, 50×0.3×50, sombre émissif bleu)
│   ├── HeatSink (Node3D) — 16 fins CSGBox3D aluminium
│   └── VRAM (Node3D) — 16 chips CSGBox3D (ChipL1–8, ChipR1–8, émissif vert)
├── Fans (Node3D)
│   └── FanHole (CSGBox3D plafond) — 3 trous cylindriques pour les hélices
│   — 3 hélices à 8 pales créées au runtime par scene_2_gpu.gd (rotation 300°/s)
├── PowerConnector, DisplayOutputs, PCIeSlot, VRMZone, CapBanks, SMDComponents
```

**Mécaniques de gameplay (`scene_2_gpu.gd`) :**

- **Traces électriques dangereuses** : `_setup_trace_hazards()` ajoute pour chaque `CSGBox3D` de `CircuitTraces` : une `Area3D` kill zone (mask=1) + `GPUParticles3D` étincelles. Contact → `body.die()`. Pour les caps (RigidBody3D) : appelle `_moving_cap.on_cap_entered_trace(body, trace_pos)`.
- **Ventilateurs** : `_setup_fans()` crée 3 pivots dans `$GPU/Fans`, chacun avec 8 bras `MeshInstance3D` (BoxMesh 25×0.6×5) + hub `CylinderMesh`. Rotation `rotate_y(deg_to_rad(300) * delta)`.
- **NextSceneArea conditionnelle** : désactivée au `_ready()`. S'active via `_on_all_caps_placed()` quand `$MovingCap` émet `all_placed`.
- **Transition** : scan `scene_N+1_*.tscn` depuis `res://scenes/` → `Global.change_scene()`.

**Sophia** spawn à Y=2, Z=40.

### MovingCap (`scenes/scene_2_gpu.tscn` > nœud MovingCap + `scripts/moving_cap.gd`)

7 `RigidBody3D` dans `MovingCap` — caps électroniques à pousser sur les traces du circuit imprimé :

| Nœud | Position | Rayon visuel | Hauteur |
| --- | --- | --- | --- |
| Cap9 | (−1.5, 2.4, −31.4) | 1.2 | 2.8 |
| Cap10 | (−4.6, 2.4, −37.3) | 1.886 | 3.398 |
| Cap12 | (44.5, 2.25, −44.2) | 1.109 | 2.508 |
| Choke2 | (−50.2, 2.75, 33.6) | 1.8 | 3.5 |
| Cap11 | (−58.4, 2.4, −46.0) | 1.2 | 2.8 |
| Cap8 | (50.5, 2.4, 32.2) | 1.2 | 2.8 |
| Cap1 | (71.3, 2.4, 45.5) | 1.2 | 2.8 |

**`moving_cap.gd` (extends Node3D) :**

- `_ready()` : collecte les `RigidBody3D` enfants dans `_cap_bodies`, lit le `top_radius` de chaque `CylinderMesh` dans `_cap_radii`. Pour chaque RigidBody3D : `axis_lock_linear_y=true`, `axis_lock_angular_x/z=true`, `linear_damp=14`, `angular_damp=14`, `PhysicsMaterial(friction=1.0, rough=true)`.
- `_physics_process()` : pour chaque cap non-freezé → `_apply_push()`.
- `_apply_push(rb, visual_rad)` : `push_range = visual_rad + 0.5`. Si Sophia est dans cette portée → `apply_central_impulse` de `PUSH_FORCE` (**100 N**) en direction opposée (Y ignoré).
- `on_cap_entered_trace(rb, trace_pos)` : **appelé depuis `scene_2_gpu.gd`** quand un cap entre dans une trace Area3D → `rb.freeze = true`, met à jour la CollisionShape, incrémente `_placed_count`. Quand tous placés → `all_placed.emit()`.
- Signal `all_placed` → `scene_2_gpu.gd` réactive la NextSceneArea.

> **Changement notable :** le snap n'est plus basé sur une distance (`_check_snap`). Il est déclenché par la kill zone de la trace (`on_cap_entered_trace`), ce qui évite les faux positifs.

### Scène 3 — LLM puzzle (`scenes/scene_3_llm.tscn` + `scripts/scene_3_llm.gd`)

Environnement thématique : puzzle de blocs-mots. Sophia ramasse des blocs et les classe dans les bons panneaux pour compléter 3 phrases. Quand les 3 phrases sont résolues, la `NextSceneArea` s'active.

**`scene_3_llm.gd` — mécanique :**

- 3 phrases × 5 mots, 15 blocs `RigidBody3D` créés au runtime (couleur par phrase)
- Sophia ramasse un bloc (**E ou clic gauche**), le tient devant la caméra, le place (1–5 au clavier) dans le rack le plus proche. E/clic gauche → lâcher.
- `_try_validate_phrase()` : si les 5 mots sont dans le bon ordre → blocs verts, `_solved_phrases++`
- `_check_all_complete()` : quand `_correct_count >= 15` → active `$NextSceneArea`
- Placement différé dans `_physics_process` (compatible Jolt)

**Transition :** `NextSceneArea` → scan `scene_N+1_*.tscn` → `Global.change_scene()`. Fallback sur `main_menu.tscn`.

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
│       ├── Mesh  (CSGBox3D 1.1×1.1, mat gris→vert→rouge selon état)
│       ├── Zone  (Area3D, collision_layer=4) — interact_pressed → toggle chemin
│       └── Info  (Label3D billboard, "I2→H2\nW=1/2")
├── MapScreen (CSGBox3D plat sur I3) — ViewportTexture minimap
├── MinimapViewport (SubViewport 512×512, own_world_3d=false)
│   └── MinimapCamera (Camera3D Y=120, orthogonal, regarde vers −Y)
├── KillZone (Area3D, Y=−29) — mort si tombée dans le vide
├── Sophia — spawn (0, 4, 80), can_double_jump=true, jump_velocity=5.5
│   lowgravity=true, lowgravity_speed_factor=1.0, lowgravity_gravity_factor=0.55
├── HUD (ui/hud.tscn)
└── KeyPickup (key_pickup.tscn, pos (0, 3.5, −95))
    next_scene_override = "res://scenes/scene_5_data_end.tscn"
```

**Système de poids W :** `PATH_DENOM` dict `name → dénominateur x`. Solution correcte : `I2H2` (W=1/2) → `H2H6` (W=1/2) → `H6O` (W=1/2).

**Détection de croisements :** `_paths_cross(a, b)` : `(xa−xb)*(ya−yb) < 0`. L3 : jamais croisé (convergence vers O).

**États des chemins :**

- INACTIF → `visible=false`, aucune collision
- ACTIF VALIDE (vert) → matériau vert émissif + `StaticBody3D` + indicateurs de bord cyan (`_create_indicators`)
- ACTIF CROISÉ (rouge) → matériau rouge + `StaticBody3D` + `Area3D` kill zone

**Interaction boutons — double mode :**

1. **Proximité (E)** : `body_entered/exited` connecte/déconnecte `interact_pressed` → `_on_btn_interact`. Un seul callable actif (`_current_btn_callable`).
2. **Clic gauche à distance** : raycast `collision_mask=4`, range 15u → toggle le chemin pointé.

**Transition :** Ramasser la clé sur O → `Global.has_key = true` → `Global.change_scene("res://scenes/scene_5_data_end.tscn")`. Kill zone à Y=−29.

### Scène 5 — Data Center final (`scenes/scene_5_data_end.tscn` + `scripts/scene_5_data_end.gd`)

Salle finale : même structure que scene_1_data mais avec éclairage extérieur (skybox HDR automne), `beach_bar.tscn` instancié, et `Global.has_key = true` forcé dès le `_ready()`.

**Différences par rapport à scene_1_data :**

- `WorldEnvironment` : skybox HDR (`autumn_field_puresky_4k.hdr`) au lieu du fond noir
- `Global.has_key = true` posé au `_ready()` — Sophia arrive déjà avec la clé
- `beach_bar.tscn` instancié dans la scène (bar intérieur dungeon_assets)
- `stairs.gd` utilisé pour le nœud `CeilingStairs/Stairs`
- Pas de `_setup_display()` — la transition vers scene_2 ne s'applique pas ici
- Sous-titre au démarrage : "Utilise la clé pour ouvrir le coffre !"

**Ouvrir le coffre** → `chest.gd` instancie `ui/end_screen.tscn` → écran de fin.

### Coffre (`scenes/chest_gold.tscn` + `scripts/chest.gd`)

Coffre final accessible depuis scene_5_data_end (ou scene_1_data si has_key=true).

**Structure de `chest_gold.tscn` :**

```text
Chest_gold (Node3D — instance chest_gold.glb)
├── chest_gold
│   └── chest_gold_lid (transform fermé par défaut)
└── AnimationPlayer (animation "open" : rotation_degrees:x de 0→−90°)
```

**`chest.gd` (extends Node3D) :**

- `_ready()` : connecte `$InteractArea.body_entered/exited`
- `_on_body_entered()` : subtitle "E : ouvrir le coffre" ou "Il te faut la clé pour ouvrir ce coffre"
- `_on_interact()` : si `Global.has_key` → `_opened = true`, joue `$ChestMesh/AnimationPlayer.play("open")`, **instancie `res://ui/end_screen.tscn`** et l'ajoute à la scène courante

### Escaliers procéduraux (`scripts/stairs.gd`)

`@tool` class_name `Stairs`, extends `Node3D`. Crée une volée de marches CSGBox3D au `_ready()` et chaque fois qu'un export change.

Paramètres exportés :

- `repeat: int = 18` — nombre de marches
- `size: Vector3 = (2, 0.5, 4)` — dimensions d'une marche
- `transpose: Vector3 = (1.3, 0.5, 0)` — vecteur de décalage entre marches
- `rotate_3d: Vector3 = (0, 20, 0)` — rotation Euler appliquée à chaque marche
- `show_node: bool` — affiche les nœuds dans l'arbre de scène (éditeur)
- `material: BaseMaterial3D` — matériau des marches

Utilisé dans `scenes/scene_1_data.tscn` et `scenes/scene_5_data_end.tscn` (nœud `CeilingStairs/Stairs`).

### Layers de collision

| Layer | Usage |
| --- | --- |
| 1 | Sophia (layer) + sol/terrain + objets statiques + caps `MovingCap` |
| 2 | Mesh de rendu de Sophia (`VisualInstance3D.layers=2`) — invisible pour la caméra FPS (`cull_mask=1`), visible pour la caméra top-down (`cull_mask=3`) |
| 4 | Zones de boutons dans scene_4 (raycast et proximity interact) |

Sophia a `collision_mask = 3` (layers 1 et 2).
Les `Area3D` kill zones ont `collision_layer=0, collision_mask=1` — détectent Sophia (layer 1).

### Beach Bar (`scenes/beach_bar.tscn`)

Scène instanciable d'un bar intérieur (10×8×3.2 m) construite avec les assets `dungeon_assets`. Pas de script propre — tout est déclaratif dans le .tscn. Utilisée dans `scene_5_data_end.tscn`.

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

- Les `.glb.import` de chaque asset doivent avoir dans `_subresources` la clé `"DungeonMat"` pointant vers `DungeonMat.tres` via `uid://dnkfdyy7f0n5w`.
- Si un asset GLB apparaît blanc/gris sans texture : ouvrir son `.glb.import`, vérifier que `_subresources` n'est pas `{}`, y ajouter la config DungeonMat, puis laisser Godot re-importer.
- Les CSG utilisent `mat_dungeon` défini en sub_resource inline dans le .tscn (même texture, même roughness).

**Collision :**

Chaque GLB instancié possède un enfant `StaticBody3D > CollisionShape3D` (BoxShape3D) ajouté directement dans le .tscn. Formes définies en sub_resource dans le .tscn.

**Structure interne des GLB dungeon_assets :**

`Node3D (root) > MeshInstance3D (mesh)`. Le `surface_material_override` sur le root **n'a aucun effet** — toujours configurer via `DungeonMat.tres` dans le `.glb.import`.

### Assets

- `patrick_3d.glb` + `patrick_3d_Patrick_texture.png` — modèle joueur (racine du projet)
- `assets/dungeon_assets/` — pièces de bâtiment (murs, sols, piliers) + props. Texture atlas : `dungeon_albedo.png`. Matériau partagé : `DungeonMat.tres`.
- `assets/skeleton/skeleton_mage.glb` — squelette mage. Scène wrappée : `scenes/skeleton_mage.tscn` (non utilisé en jeu).
- `assets/zombie/zombie.glb` + `zombie_idle.glb`, `zombie_run.glb`, `zombie_jump.glb` — zombie avec animations. Scène wrappée : `scenes/zombie.tscn` (non utilisé en jeu).
- `assets/import_examples/` — exemples barrel et chest_gold avec matériaux
- `assets/sky_background/autumn_field_puresky_4k.hdr` — skybox HDR (utilisée dans scene_5_data_end)

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
| Paramètre `underwater` | Utiliser `underwater` ou `can_freefly` dans `sophia.gd` | Ces paramètres n'existent plus ; utiliser `lowgravity` / `lowgravity_speed_factor` / `lowgravity_gravity_factor` |

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
