# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 — "AI final project BETA" — jeu 3D FPS en GDScript avec Patrick (SpongeBob) comme personnage. Moteur physique : Jolt Physics. Renderer : Forward Plus.

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

> `freefly` n'est **pas** dans `project.godot`. Le paramètre `can_freefly` de `patrick.gd` est `false` par défaut, donc ce n'est pas nécessaire.

## Architecture

### État actuel des scènes

Le projet contient actuellement **3 scènes jouables** précédées d'un menu principal, plus une scène de bar instanciable :

```text
main_menu  →  scene_1_underwater  →  scene_2_plage  →  scene_3_gpu  →  (à créer : scene_4…)
```

- `scenes/main_menu.tscn` — menu principal (bouton START). Scène de démarrage du jeu. Pilotée par `scripts/main_menu.gd`.
- `scenes/scene_1_underwater.tscn` — scène sous-marine complète avec terrain CSG, crabes, clé, HUD, particules, décor procédural, transitions eau/plage. Pilotée par `scripts/scene_1.gd`.
- `scenes/scene_2_plage.tscn` — scène très basique (un seul CSGBox3D sol 100×100, Patrick posé dessus). Aucun script, aucun HUD, aucun gameplay — juste un passage.
- `scenes/scene_3_gpu.tscn` — scène thématique GPU géant (PCB 160×2×100) dans un environnement sombre façon espace. Pilotée par `scripts/scene_3.gd`. Voir section dédiée ci-dessous.
- `scenes/beach_bar.tscn` — scène de bar intérieur complète avec assets dungeon_assets texturés et collision complète (voir section dédiée ci-dessous).
- `scenes/plage.tscn` — doublon/brouillon de scene_2, ignoré en jeu.
- `scenes/transition.tscn` — overlay de fondu noir (autoload `SceneTransition`).
- `scenes/crab.tscn` — scène instanciable du crabe (CSG, pas de GLB).
- `scenes/algue.tscn` — scène instanciable d'une plante marine animée (CSGCylinder + CSGSphere + AnimationPlayer). Pilotée par `scripts/algue.gd`.
- `scenes/key_pickup.tscn` — pickup de clé (CSG + AnimationPlayer).
- `scenes/barrel.tscn` — baril décoratif (StaticBody3D + ConcavePolygonShape3D, GLB).
- `scenes/patrick_player.tscn` — le joueur.
- `scenes/skeleton_mage.tscn` — instance du GLB skeleton_mage avec pose de bones adjustée (non utilisé en jeu).
- `scenes/zombie.tscn` — instance du GLB zombie avec animations retravaillées ("move", etc.) (non utilisé en jeu).

### Menu principal (`scenes/main_menu.tscn` + `scripts/main_menu.gd`)

- `Control` plein écran avec un `TextureRect` (fond) et un `Button` "START" centré
- Au `_ready()` : libère la souris (`MOUSE_MODE_VISIBLE`)
- Bouton START → `Global.change_scene("res://scenes/scene_1_underwater.tscn")`

### Progression automatique de scènes (`scene_1.gd` et `scene_3.gd`)

`scene_1.gd` et `scene_3.gd` partagent le même pattern : au déclenchement de `NextSceneArea`, ils lisent le dossier `res://scenes/`, cherchent le fichier `scene_N+1_*.tscn`, et appellent `Global.change_scene()`. Il suffit d'ajouter un fichier `scene_4_*.tscn` etc. pour étendre le jeu.

Différences entre les deux :

- `scene_1.gd` est plus riche : gère le mode sous-marin de Patrick, les transitions de fog/lumière, les particules bulles/splash, et passe `Engine.time_scale = 0.5` lors du passage à la scène suivante.
- `scene_3.gd` est minimal : enregistre le `current_scene_path`, remet `Engine.time_scale = 1.0` au `_ready()`, et écoute `NextSceneArea`. Pas de mode sous-marin, pas de HUD subtitle.

### Singleton Global (`scripts/Global.gd`)

Unique source de vérité partagée entre scènes :

- `has_key: bool` — Patrick a-t-il ramassé la clé ?
- `current_scene_path: String` — utilisé par `reload_current_scene()` pour le respawn après mort
- `change_scene(path)` — passe par `SceneTransition` si disponible, sinon change directement
- `reload_current_scene()` — recharge la scène courante (appelé par `die()`)
- `reset_game()` — remet `has_key = false` et `current_scene_path = ""`

### Joueur (`scenes/patrick_player.tscn` + `scripts/patrick.gd`)

`patrick.gd` étend **directement `CharacterBody3D`** (pas `proto_controller.gd` — le contrôleur a été réécrit de zéro). Fonctionnalités :

- Mouvement FPS complet avec rotation souris, saut, sprint optionnel
- Mode sous-marin (`underwater: bool`) : vitesse × `underwater_speed_factor`, gravité × `underwater_gravity_factor`
- Signal `interact_pressed` (touche E) — écouté par `key_pickup.gd`
- Méthode `die()` — appelée par les crabes, recharge la scène via `Global.reload_current_scene()`
- La souris est capturée directement au `_ready()` ; `_notification(WM_WINDOW_FOCUS_IN)` la re-capture si la fenêtre reprend le focus. Échap la relâche, clic gauche la recapture.

Paramètres exportés clés : `can_move`, `has_gravity`, `can_jump`, `can_sprint`, `can_freefly`, `underwater`, vitesses.

> `addons/proto_controller/` existe encore dans le dépôt mais n'est **plus utilisé** par `patrick.gd`.

### Crabe (`scenes/crab.tscn` + `scripts/crab.gd`)

- `CharacterBody3D` construit entièrement en CSG (corps, pinces, yeux, pattes)
- Patrouille entre deux points selon `patrol_axis` et `patrol_distance` (exportés)
- `face_patrol_axis: bool` — si `true`, se tourne vers la direction de marche
- Signal `_on_attack_area_body_entered` : si le corps entrant a `die()`, il l'appelle
- Désynchronisation aléatoire au démarrage (`randf() * 0.5` secondes)

### Clé (`scenes/key_pickup.tscn` + `scripts/key_pickup.gd`)

- `Area3D` avec visuel CSG (anneau + tige + dents + lumière) et `AnimationPlayer`
- Pattern d'interaction :
  1. `body_entered` → connecte `patrick.interact_pressed` à `_on_interact()`
  2. `body_exited` → déconnecte le signal, remet le sous-titre
  3. `_on_interact()` → `Global.has_key = true`, animation de disparition (tween montée + scale 0)

### HUD (`ui/hud.tscn` + `scripts/hud.gd`)

Trois méthodes publiques :

- `show_message(text, duration)` — message temporaire en haut de l'écran
- `set_subtitle(text)` — instruction permanente en bas de l'écran
- Mise à jour automatique de l'icône clé (🔑 ✅ / ❌) via `Global.has_key` à chaque frame

Les scènes récupèrent le HUD avec `$HUD`.

### Décor sous-marin — scène 1

La scène 1 combine deux couches de décor :

**Objets statiques (`OceanObjects` dans la scène)** — placés à la main, avec opérations CSG :

- Rochers (Rock1–3, RocksExtra avec RockLentille/RockArche/RockCreux) — `use_collision = true`
- Coraux (Coral, CorauxExtra : CoralBuisson/CoralTube/CoralFan/CoralBranche/CoralDome/CoralMosaic) — couleurs violet, sarcelle, jaune, rouge
- Baril (StaticBody3D GLB), Ancre, MatBrise, Boulets, Planches — zone proche du spawn
- Algues animées (`AlguesVivantes`) — 6 plants Node3D avec AnimationPlayer "sway"

**Décor procédural (`OceanPopulator` + `scripts/ocean_populator.gd`)** — généré au runtime :

- Seed fixe (modifiable via inspecteur : `rng_seed`)
- Zone couverte : X [−255, 275], Z [−410, −4], Y = −3.0 (surface du sol)
- **Rochers** (`rock_count`, défaut 700) : `StaticBody3D` + `SphereMesh` déformé + `SphereShape3D`
- **Coraux** (`coral_count`, défaut 1000) : 4 formes (ball, tube, dome, branch), 5 couleurs, avec collision
- **Plantes** (`plant_count`, défaut 9000) : instances de `scenes/algue.tscn`
- Matériaux pré-alloués (7 teintes rocher + 5 teintes corail) pour éviter les allocations massives

### Plante marine (`scenes/algue.tscn` + `scripts/algue.gd`)

- Pivot `Node3D` (racine) + `CSGCylinder3D` (tige décalée vers le haut) + `CSGSphere3D` (sommet) + `AnimationPlayer`
- Animation "sway" : rotation:z oscillante, durée 2.5s, loop cubique
- `algue.gd` au `_ready()` :
  - Seek aléatoire → désynchronise chaque instance
  - Scale aléatoire (×0.7–1.6)
  - Rotation Y aléatoire (360°)
  - Couleur aléatoire parmi 7 teintes de vert (vif, foncé, sarcelle, olive, vert profond, cyan-vert, vert-jaune) — tige + sommet légèrement éclairci

### Scène 3 — GPU géant (`scenes/scene_3_gpu.tscn` + `scripts/scene_3.gd`)

Environnement thématique : Patrick marche sur un GPU géant dans le vide spatial. Tout le décor est en CSG.

**Structure du nœud `GPU` :**

```text
GPU (Node3D)
├── PCB (CSGBox3D, 160×2×100, vert PCB, use_collision)
├── CircuitTraces (Node3D) — Trace1–8 (horizontales) + TraceZ1–8 (verticales) + Stub1–8 (jonctions), matériau doré émissif
├── GPUCore (Node3D)
│   ├── Die (CSGBox3D, 50×0.3×50, sombre émissif bleu)
│   ├── HeatSink (Node3D) — 16 fins CSGBox3D aluminium (48×22×1.2 chacune)
│   └── VRAM (Node3D) — 16 chips CSGBox3D (ChipL1–8, ChipR1–8, 7×0.5×7, émissif vert)
├── Fans (Node3D) — 2 cylindres CSGCylinder3D (rayon 12, hauteur 6, 16 côtés)
├── PowerConnector (CSGBox3D, 14×10×6, connecteur noir)
├── DisplayOutputs (Node3D) — 4 ports CSGBox3D (5×4×2, Port1–4)
├── PCIeSlot (CSGBox3D, 80×3×4, doré)
├── VRMZone (Node3D) — 6 chokes CSGCylinder3D (rayon 1.8, hauteur 3.5)
└── CapBanks (Node3D) — 8 caps VRM (rayon 1.2) + 3 CapV petits (rayon 0.7), matériau brun
```

**Environnement et éclairage :**

- `WorldEnvironment` : fond noir spatial, ambient bleu-gris (energy 0.9), glow activé (bloom 0.5), fog sombre (density 0.003)
- `DirectionalLight3D` : lumière bleutée (energy 1.4, angle 45°)
- `Lighting` (Node3D) : CoreHeat orange (OmniLight, range 80), EdgeRGB violet (range 95), PCBLeft/Right vert (range 65×2), PCBFront/Back bleu (range 55×2)
- `SparkParticles` (GPUParticles3D) : 30 particules cyan (sphères 0.04 rayon), vitesse 1–4, légère anti-gravité

**Transition :** `NextSceneArea` à Z=−47 (bord avant du PCB), box 40×8×4.

**Patrick** spawn à Y=2, Z=40 (au fond du PCB). `Engine.time_scale` remis à 1.0 au `_ready()`.

### Layers de collision

| Layer | Usage |
| --- | --- |
| 1 | Patrick (layer + mask) + sol/terrain + objets statiques (défaut Godot) |
| 4 | Crabes + `InteractRay` mask |

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
- `addons/proto_controller/` — contrôleur FPS de référence CC0 (ne plus modifier, plus utilisé en jeu)
