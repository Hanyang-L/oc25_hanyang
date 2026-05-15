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

Le projet contient actuellement **2 scènes jouables** précédées d'un menu principal :

```text
main_menu  →  scene_1_underwater  →  scene_2_plage  →  (à créer : scene_3, scene_4…)
```

- `scenes/main_menu.tscn` — menu principal (bouton START). Scène de démarrage du jeu. Pilotée par `scripts/main_menu.gd`.
- `scenes/scene_1_underwater.tscn` — scène sous-marine complète avec terrain CSG, crabes, clé, HUD, particules, décor procédural, transitions eau/plage. Pilotée par `scripts/scene_1.gd`.
- `scenes/scene_2_plage.tscn` — scène très basique (un seul CSGBox3D), pas encore de gameplay.
- `scenes/plage.tscn` — doublon/brouillon de scene_2, ignoré en jeu.
- `scenes/transition.tscn` — overlay de fondu noir (autoload `SceneTransition`).
- `scenes/crab.tscn` — scène instanciable du crabe (CSG, pas de GLB).
- `scenes/algue.tscn` — scène instanciable d'une plante marine animée (CSGCylinder + CSGSphere + AnimationPlayer). Pilotée par `scripts/algue.gd`.
- `scenes/key_pickup.tscn` — pickup de clé (CSG + AnimationPlayer).
- `scenes/barrel.tscn` — baril décoratif (StaticBody3D + ConcavePolygonShape3D, GLB).
- `scenes/patrick_player.tscn` — le joueur.

### Menu principal (`scenes/main_menu.tscn` + `scripts/main_menu.gd`)

- `Control` plein écran avec un `TextureRect` (fond) et un `Button` "START" centré
- Au `_ready()` : libère la souris (`MOUSE_MODE_VISIBLE`)
- Bouton START → `Global.change_scene("res://scenes/scene_1_underwater.tscn")`

### Progression automatique de scènes (`scene_1.gd`)

`scene_1.gd` détecte automatiquement la prochaine scène par numéro : il lit le dossier `res://scenes/`, cherche le fichier `scene_N+1_*.tscn`, et appelle `Global.change_scene()`. Il suffit d'ajouter un fichier `scene_2_*.tscn`, `scene_3_*.tscn`, etc. pour étendre le jeu.

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

### Layers de collision

| Layer | Usage |
| --- | --- |
| 1 | Patrick (layer + mask) + sol/terrain + objets statiques (défaut Godot) |
| 4 | Crabes + `InteractRay` mask |

### Assets

- `patrick_3d.glb` + `patrick_3d_Patrick_texture.png` — modèle joueur (racine du projet)
- `assets/dungeon_assets/` — pièces de bâtiment (murs, sols, piliers) + props (coffre, clés, tonneaux, chandelles…) pour futures scènes
- `assets/skeleton/skeleton_mage.glb` — squelette mage (non utilisé)
- `assets/zombie/zombie.glb` + `zombie_idle.glb`, `zombie_run.glb`, `zombie_jump.glb` — zombie avec animations séparées (non utilisé)
- `assets/import_examples/` — exemples barrel et chest_gold avec matériaux
- `assets/sky_background/autumn_field_puresky_4k.hdr` — skybox HDR scène 1
- `addons/proto_controller/` — contrôleur FPS de référence CC0 (ne plus modifier, plus utilisé en jeu)
