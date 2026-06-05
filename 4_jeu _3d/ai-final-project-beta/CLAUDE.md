# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

Godot 4.6 — "AI final project BETA" — jeu 3D FPS en GDScript avec Sophia comme personnage jouable. Moteur physique : Jolt Physics. Renderer : Forward Plus.

## Lancer le jeu

Ce projet s'ouvre et se lance depuis l'éditeur **Godot 4.6**. Il n'y a pas de CLI de build.

- Scène principale (point d'entrée) : `scenes/main_menu.tscn`
- Lancer : F5 dans Godot → démarre sur le menu principal
- Lancer une scène spécifique : F6

Il n'y a pas de tests automatisés ni de linter configuré.

## Autoloads requis (Project Settings > Autoload)

| Nom | Fichier |
| --- | --- |
| `Global` | `res://scripts/global.gd` |
| `SceneTransition` | `res://scenes/transition.tscn` |

Sans ces autoloads, `Global.change_scene()` et les transitions planteront.

## Input Actions configurées (project.godot)

| Action | Touches |
| --- | --- |
| `ui_left` | Flèche gauche **ou A** |
| `ui_right` | Flèche droite **ou D** |
| `ui_up` | Flèche haut **ou W** |
| `ui_down` | Flèche bas **ou S** |
| `ui_accept` | Espace |
| `interact` | E |
| `sprint` | Shift |

## Architecture — flux des scènes

```text
main_menu → scene_1_data → scene_2_gpu → scene_3_llm → scene_4_neuralnet → scene_5_data_end → end_screen
```

### Fichiers de scènes et scripts

| Scène | Script | Rôle |
| --- | --- | --- |
| `scenes/main_menu.tscn` | `scripts/main_menu.gd` | Menu principal — bouton START |
| `scenes/scene_1_data.tscn` | `scripts/scene_1_data.gd` | Data center — interaction écran PC → scene_2 |
| `scenes/scene_2_gpu.tscn` | `scripts/scene_2_gpu.gd` | GPU géant — pousser les caps sur les traces |
| `scenes/scene_3_llm.tscn` | `scripts/scene_3_llm.gd` | Puzzle LLM — ranger les blocs-mots |
| `scenes/scene_4_neuralnet.tscn` | `scripts/scene_4_neuralnet.gd` | Réseau de neurones — activer les chemins, traverser |
| `scenes/scene_5_data_end.tscn` | `scripts/scene_5_data_end.gd` | Salle finale — ouvrir le coffre, cutscène repas |
| `scenes/sophia_player.tscn` | `scripts/sophia.gd` | Joueur (CharacterBody3D FPS) |
| `scenes/chest_gold.tscn` | `scripts/chest.gd` | Coffre interactif |
| `scenes/key_pickup.tscn` | `scripts/key_pickup.gd` | Pickup de clé |
| `scenes/beach_bar.tscn` | *(pas de script)* | Bar instanciable dungeon_assets |
| `scenes/skeleton.tscn` | *(pas de script)* | Squelette mage (BarSkeleton) |
| `scenes/barrel.tscn` | *(pas de script)* | Baril décoratif |
| `scenes/transition.tscn` | `scripts/scene_transition.gd` | Fondu noir autoload |
| `ui/hud.tscn` | `scripts/hud.gd` | HUD en jeu |
| `ui/end_screen.tscn` | `scripts/end_screen.gd` | Écran de fin |

### Transitions entre scènes

- **scene_1 → scene_2** : Sophia appuie E près de `$Display` → tween aspiration vers le GPU (1.5s) → `Global.change_scene("scene_2_gpu.tscn")`. Pas de NextSceneArea.
- **scene_2 → scene_3** : `NextSceneArea` désactivée au départ, s'active quand tous les caps sont placés (signal `all_placed` de MovingCap).
- **scene_3 → scene_4** : `NextSceneArea` s'active quand `_correct_count >= 15` (tous les blocs-mots corrects).
- **scene_4 → scene_5** : `KeyPickup` sur Output (`next_scene_override = "res://scenes/scene_5_data_end.tscn"`). Pas de NextSceneArea.
- **scene_5 → end_screen** : Coffre ouvert → cutscène repas → instancie `ui/end_screen.tscn`.

scan utilisé par scene_2/scene_3 : `res://scenes/scene_N+1_*.tscn`.

---

## Scripts clés

### Singleton Global (`scripts/global.gd`)

- `has_key: bool` — Sophia a-t-elle la clé ?
- `current_scene_path: String` — pour le respawn après mort
- `change_scene(path)` → appelle `SceneTransition.fade_to_scene(path)` si disponible, sinon change directement
- `reload_current_scene()` — recharge la scène courante (appelé par `die()`)
- `reset_game()` — remet `has_key = false` et `current_scene_path = ""`

### Transition (`scripts/scene_transition.gd`)

`CanvasLayer` avec `ColorRect`. Méthode unique : `fade_to_scene(scene_path: String)` — fade noir (1.2s) → change scène → fade retour.

### Joueur — Sophia (`scripts/sophia.gd`)

Extends `CharacterBody3D`. Paramètres exportés :

```text
can_move, can_look, has_gravity, can_jump, can_double_jump (défaut true),
can_sprint, lowgravity, lowgravity_speed_factor, lowgravity_gravity_factor,
look_speed, base_speed, jump_velocity, sprint_speed
```

Signaux : `interact_pressed` (touche E), `left_click_pressed` (clic gauche souris capturée).

Méthodes publiques : `die()`, `aim_at(target: Vector3)`, `capture_mouse()`, `release_mouse()`.

Comportements clés :

- **Double jump** : premier saut `velocity.y = jump_velocity * 1.2`, second = `jump_velocity`. `_double_jump_available` reset à `true` chaque frame au sol.
- **Animations** : 8 animations dans `sophia.glb` — `Idle/Run/RunTiltL/RunTiltR` au sol, `Jump/Fall` en l'air. AnimationPlayer à `$SophiaMesh/AnimationPlayer`.
- **Caméra double** : Tab bascule FPS (`$Head/Camera3D`, `cull_mask=1`) ↔ top-down (`$TopDownCamera`, `cull_mask=3`). Mesh Sophia sur `layers=2` (invisible FPS, visible top-down).
- Souris capturée au `_ready()`. Échap la relâche, clic gauche la recapture (sans émettre `left_click_pressed`).
- Angle vue vertical clampé ±80°.
- `can_look = false` utilisé par scene_5 pendant la cutscène.

Structure du tscn :

```text
Sophia (CharacterBody3D, collision_mask=3)
├── Collider (CollisionShape3D, CapsuleShape3D)
├── CollisionShape3D (SphereShape3D)
├── SophiaMesh (Node3D, instance sophia.glb) — VisualInstance3D mis layers=2 au runtime
├── TopDownCamera (Camera3D, cull_mask=3)
├── Head (Node3D)
│   └── Camera3D (cull_mask=1, current=true)
└── InteractRay (RayCast3D, mask=4)
```

### HUD (`scripts/hud.gd`)

Méthodes publiques :

- `show_message(text, duration)` — message temporaire en haut
- `set_subtitle(text)` — instruction permanente en bas
- `set_key_visible(val: bool)` — affiche/cache l'icône clé (cachée par défaut, montrée seulement en scene_4 et scene_5)
- `set_cap_counter(placed, total)` — compteur de caps pour scene_2
- `hide_cap_counter()`
- `set_rules(text)` — affiche texte de règles (scene_4)
- `hide_rules()`

Icône clé mise à jour chaque frame via `Global.has_key`.

### Coffre (`scripts/chest.gd`)

Ouverture **automatique au `body_entered`** (pas de touche E requise) :

1. Si `!Global.has_key` → `show_message("Il te faut une clé !")`, return
2. Si `Global.has_key` → `_opened = true`, `body.can_move = false`, joue `$ChestMesh/AnimationPlayer.play("open")`
3. Après animation : si la scène courante a `_on_chest_opening(body)` → l'appelle avant, si elle a `_on_chest_opened(body)` → l'appelle après. Sinon : instancie `ui/end_screen.tscn` directement.

### Clé (`scripts/key_pickup.gd`)

`Area3D` avec visuel CSG. Export `next_scene_override: String = ""`.

Pattern : `body_entered` → connecte `sophia.interact_pressed` → `_on_interact()` → `Global.has_key = true`, animation disparition, puis `Global.change_scene(next_scene_override)` si renseigné.

### Écran de fin (`scripts/end_screen.gd`)

`CanvasLayer` instancié par `chest.gd` (ou `scene_5_data_end.gd`) après la cutscène.

- Joue animation "blind" (fondu) → `EndPanel.visible = true`, libère la souris
- Restart → `Global.reset_game()` + `Global.change_scene("scene_1_data.tscn")`
- Menu → `Global.reset_game()` + `Global.change_scene("main_menu.tscn")`

---

## Scènes détaillées

### Scene 1 — Data Center (`scene_1_data.gd`)

Salle data center avec skybox HDR automne, beach_bar instancié, rack serveurs CSG (grille 8×4), grand PC RGB, squelette au comptoir.

- `_setup_fans()` — crée les ventilateurs PC au runtime (Radiator3/Radiator2/GPU)
- `_setup_display()` — Area3D (BoxShape 5×3×6) autour de `$Display`. E → tween aspiration vers `$PC/GPU/GpuBody` (1.5s) → `Global.change_scene("scene_2_gpu.tscn")`
- `_setup_skeleton()` — lance `Idle` en boucle sur BarSkeleton + zone dialogue (SphereShape r=3). En entrant : message "Bonjour..." + animation `Idle_B` temporaire
- Sous-titre démarrage : `"Rendez vous au comptoir"`
- Chest en scène : si `Global.has_key = true` (retour depuis scene_5), le coffre est accessible directement

Rack layout : X ∈ {±8.75, ±6.25, ±3.75, ±1.25}, Z ∈ {+9, +4, −1, −6}. Racks tournés 90° sur Y.

### Scene 2 — GPU géant (`scene_2_gpu.gd`)

Sophia marche sur un PCB (160×2×100) dans le vide spatial. Décor entièrement CSG.

Mécaniques :

- **Traces dangereuses** : `_setup_trace_hazards()` → Area3D kill + GPUParticles3D étincelles sur chaque trace. Contact Sophia = `die()`. Contact cap (RigidBody3D) = `on_cap_entered_trace()`.
- **Ventilateurs** : 3 pivots dans `$GPU/Fans`, 8 bras BoxMesh chacun, rotation 300°/s.
- **MovingCap** : 7 RigidBody3D dans `$MovingCap` (script `moving_cap.gd`). Sophia les pousse (impulse 100N), ils se snappent quand ils entrent dans une trace. Quand tous placés → `all_placed.emit()` → NextSceneArea s'active.

### Scene 3 — LLM puzzle (`scene_3_llm.gd`)

3 phrases × 5 mots, 15 blocs RigidBody3D créés au runtime. Sophia ramasse (E ou clic), place (touches 1–5), lâche (E ou clic). Quand `_correct_count >= 15` → NextSceneArea active. Fallback `main_menu.tscn` si pas de scene suivante.

### Scene 4 — Réseau de neurones (`scene_4_neuralnet.gd`)

Platformer dans vide violet. 3 couches : Input (I1/I2/I3), Hidden1 (H1–H4), Hidden2 (H5–H8), Output (O).

**Puzzle** : activer les bons chemins sur le ButtonPanel (32 boutons, un par chemin I→H→O). Chemins actifs sans croisement = vert + marchable. Croisés = rouge + deadly.

**Solution correcte** (`CORRECT_PATHS`, 18 chemins) : `I1H1, I1H2, I3H4, I2H3, I2H4, I3H2, H1H5, H1H8, H2H6, H2H8, H3H5, H3H6, H4H6, H4H7, H5O, H6O, H7O, H8O`.

Détection croisements : `_paths_cross(a,b)` → `(xa−xb)*(ya−yb) < 0`. L3 (H→O) : jamais croisé.

Double mode interaction boutons : proximité (E) ou clic gauche à distance (raycast mask=4, range 15u).

Sophia spawn : `(0, 4, 80)`, `can_double_jump=true`, `jump_velocity=5.5`, `lowgravity=true` (factor 0.55). Kill zone Y=−29.

KeyPickup sur Output → `Global.has_key = true` → `Global.change_scene("scene_5_data_end.tscn")`.

Minimap : SubViewport 512×512 sur nœud `$MapScreen` (I3).

### Scene 5 — Data Center final (`scene_5_data_end.gd`)

Identique à scene_1 (même PC, même racks, même beach_bar, même skybox HDR). Différences :

- `Global.has_key = true` forcé au `_ready()`
- `$HUD.set_key_visible(true)` au `_ready()`
- Pas de `_setup_display()` (pas de transition vers scene_2)
- Squelette : `Idle` uniquement, pas de zone de dialogue
- Sous-titre : `"Utilise la clé pour ouvrir le coffre !"`
- `FadeOverlay` (CanvasLayer ColorRect + `FadePlayer` AnimationPlayer) en enfant direct de la scène

**Cutscène coffre (callbacks depuis `chest.gd`) :**

1. `_on_chest_opening(body)` : fade out via `$FadeOverlay/FadePlayer.play("fade_out")`
2. `_on_chest_opened(body)` : attends fin fade → téléporte Sophia à `$BeachBar/PlateMR.global_position + Vector3(0, -0.95, 3.0)`, `body.rotation.y = 0`, `body.can_look = false`, `body.has_gravity = false`, `body.aim_at(skeleton_pos)` → fade in → squelette joue `1H_Ranged_Aiming` → `$BeachBar/PlateMR.visible = true` → dialogue `"Merci beaucoup. Voici votre plat."` → instancie `ui/end_screen.tscn`

`$BeachBar/PlateMR` : instance de `assets/dungeon_assets/props/plate_food.glb`, caché au départ.

---

## Beach Bar (`scenes/beach_bar.tscn`)

Bar intérieur (10×8×3.2 m) en dungeon_assets. Pas de script propre. Instancié dans **scene_1_data** et **scene_5_data_end**.

Structure : `Structure` (murs/sol/plafond/comptoir CSG) + `Props` (tables/chaises/barils) + `Particles` (flammes GPUParticles3D) + `Lights` (OmniLight3D).

Contient `PlateMR` (plate_food.glb) — visible uniquement pendant la cutscène de scene_5.

## Escaliers procéduraux (`scripts/stairs.gd`)

`@tool class_name Stairs`. Génère des CSGBox3D au `_ready()` et à chaque changement d'export.

Exports : `repeat: int = 18`, `size: Vector3`, `transpose: Vector3`, `rotate_3d: Vector3`, `show_node: bool`, `material: BaseMaterial3D`.

Utilisé dans `CeilingStairs/Stairs` de scene_1 et scene_5.

---

## Layers de collision

| Layer | Usage |
| --- | --- |
| 1 | Sophia + sol/terrain + objets statiques + caps MovingCap |
| 2 | Mesh Sophia (VisualInstance3D.layers=2) — invisible FPS (cull_mask=1), visible top-down (cull_mask=3) |
| 4 | Zones boutons scene_4 (raycast + proximity interact) |

Sophia `collision_mask = 3`. Area3D kill zones : `collision_layer=0, collision_mask=1`.

---

## Assets

- `assets/dungeon_assets/` — pièces de bâtiment + props. Texture atlas : `dungeon_albedo.png`. Matériau partagé : `DungeonMat.tres`.
- `assets/skeleton/skeleton_mage.glb` — squelette mage. Animations embarquées dont `Idle` et `1H_Ranged_Aiming`. Scène wrappée : `scenes/skeleton.tscn`.
- `assets/zombie/` — zombie GLB (non utilisé en jeu).
- `assets/sky_background/autumn_field_puresky_4k.hdr` — skybox HDR utilisée dans scene_1 et scene_5.
- `assets/dungeon_assets/props/plate_food.glb` — assiette cutscène scene_5 (`PlateMR`).

---

## Workflow Godot

- **Avant tout renommage/déplacement de fichier** (.tscn, .gd, .glb, .import) : fermer l'éditeur Godot — il écrase silencieusement les fichiers renommés.
- **Après toute modification de `project.godot`** : Project > Reload dans l'éditeur.
- **Décor** : utiliser uniquement des CSG par défaut — ne pas mélanger avec des GLB sauf demande explicite.
- **Avant tout fix** : relire le fichier concerné directement — ne pas se fier à la mémoire de contexte.

---

## Gotchas connus

| Problème | À ne pas faire | À faire |
| --- | --- | --- |
| Transparence invisible | `alpha = 0` sur un mesh (Forward Plus l'ignore) | `layers = 0` pour rendre invisible |
| Matériau GLB sans effet | `surface_material_override` sur le Node3D racine | Configurer via `DungeonMat.tres` dans le `.glb.import` (clé `"DungeonMat"`) |
| Physique Jolt incompatible | Conversion runtime StaticBody3D → RigidBody3D | Déclarer le type correct dès le `.tscn` |
| Ventilateur mauvais axe | `rotate_z` pour un ventilateur face Y+ | Face Z+ → `rotate_z`, face Y+ → `rotate_y` |
| Autoload casse-sensitive | Corriger le nom sans recharger l'éditeur | Project > Reload après tout changement dans `project.godot` |
| `layers` sur Node3D ignoré | `layers = 2` sur un Node3D GLB dans le .tscn | Itérer `find_children("*", "VisualInstance3D")` en script |
| Paramètre inexistant | `can_freefly`, `underwater` dans `sophia.gd` | Utiliser `lowgravity` / `can_look` / `can_move` |
| Cutscène scene_5 — contrôle Sophia | Modifier `can_move` seul | Aussi mettre `can_look = false` + `has_gravity = false` pendant la cutscène |

## Pipeline import GLB (dungeon_assets)

1. Placer le `.glb` dans `assets/dungeon_assets/`
2. Laisser Godot créer le `.glb.import`
3. Ajouter dans `_subresources` :

   ```ini
   "materials/0/use_external/enabled": true,
   "materials/0/use_external/path": "res://assets/dungeon_assets/DungeonMat.tres"
   ```

4. Sauvegarder — Godot re-importe automatiquement
5. Si asset blanc/gris : vérifier que `_subresources` n'est pas `{}`

Structure interne GLB : `Node3D (root) > MeshInstance3D (mesh)`. Le `surface_material_override` sur le root **n'a aucun effet**.
