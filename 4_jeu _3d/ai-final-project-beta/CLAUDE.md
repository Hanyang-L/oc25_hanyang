# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 — "AI final project BETA" — jeu 3D FPS en GDScript avec Patrick (SpongeBob) comme personnage. Moteur physique : Jolt Physics. Renderer : Forward Plus.

## Lancer le jeu

Ce projet s'ouvre et se lance depuis l'éditeur **Godot 4.6**. Il n'y a pas de CLI de build — tout passe par l'éditeur.

- Scène principale de test : `scenes/scene_1_underwater.tscn`
- Pour lancer : F5 dans Godot (ou bouton Play)
- Pour lancer une scène spécifique : F6

Il n'y a pas de tests automatisés ni de linter configuré.

## Autoloads requis (Project Settings > Autoload)

Deux singletons sont déjà enregistrés dans `project.godot` :

| Nom | Fichier |
|---|---|
| `Global` | `res://scripts/Global.gd` |
| `SceneTransition` | `res://scenes/transition.tscn` |

Sans ces autoloads, les appels à `Global.has_key`, `Global.change_scene()` et les transitions de scènes planteront.

## Input Actions configurées (project.godot)

| Action | Touche |
|---|---|
| `ui_left/right/up/down` | Flèches (par défaut Godot) |
| `ui_accept` | Espace (par défaut Godot) |
| `interact` | E |
| `sprint` | Shift |

> `freefly` n'est **pas** dans `project.godot`. Le paramètre `can_freefly` de `patrick.gd` est `false` par défaut, donc ce n'est pas nécessaire.

## Architecture

### État actuel des scènes

Le projet contient actuellement **2 scènes jouables** :

```
scene_1_underwater  →  scene_2_plage  →  (à créer : scene_3, scene_4…)
```

- `scenes/scene_1_underwater.tscn` — scène complète avec terrain CSG, crabes, clé, HUD, particules, transitions eau/plage. Pilotée par `scripts/scene_1.gd`.
- `scenes/scene_2_plage.tscn` — scène très basique (un seul CSGBox3D), pas encore de gameplay.
- `scenes/plage.tscn` — doublon/brouillon de scene_2, ignoré en jeu.
- `scenes/transition.tscn` — overlay de fondu noir (autoload `SceneTransition`).
- `scenes/crab.tscn` — scène instanciable du crabe (CSG, pas de GLB).
- `scenes/key_pickup.tscn` — pickup de clé (CSG + AnimationPlayer).
- `scenes/patrick_player.tscn` — le joueur.

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
- La souris est capturée automatiquement au `_ready()` ; Échap la relâche

Paramètres exportés clés : `can_move`, `can_jump`, `can_sprint`, `can_freefly`, `underwater`, vitesses.

> `addons/proto_controller/` existe encore dans le dépôt mais n'est **plus utilisé** par `patrick.gd`.

### Crabe (`scenes/crab.tscn` + `scripts/crab.gd`)

- `CharacterBody3D` construit entièrement en CSG (corps, pinces, yeux, pattes)
- Patrouille entre deux points selon `patrol_axis` et `patrol_distance` (exportés)
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

### Layers de collision

| Layer | Usage |
|---|---|
| 2 | Patrick |
| 4 | Crabes + `InteractRay` mask |

### Assets

- `patrick_3d.glb` + `patrick_3d_Patrick_texture.png` — modèle joueur (racine du projet)
- `assets/dungeon_assets/` — pièces de bâtiment (murs, sols, piliers) + props (coffre, clés, tonneaux, chandelles…) pour futures scènes
- `assets/skeleton/skeleton_mage.glb` — squelette mage (non utilisé)
- `assets/zombie/zombie.glb` + `zombie_idle.glb`, `zombie_run.glb`, `zombie_jump.glb` — zombie avec animations séparées (non utilisé)
- `assets/import_examples/` — exemples barrel et chest_gold avec matériaux
- `addons/proto_controller/` — contrôleur FPS de référence CC0 (ne plus modifier, plus utilisé en jeu)
