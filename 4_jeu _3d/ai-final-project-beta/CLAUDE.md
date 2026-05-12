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

Deux singletons doivent être enregistrés pour que le jeu fonctionne :

| Nom | Fichier |
|---|---|
| `Global` | `res://scripts/Global.gd` |
| `SceneTransition` | `res://scenes/transition.tscn` |

Sans ces autoloads, les appels à `Global.has_key`, `Global.change_scene()` et les transitions de scènes planteront.

## Input Actions requises (Project Settings > Input Map)

| Action | Touche suggérée |
|---|---|
| `ui_left/right/up/down` | Flèches (par défaut) |
| `ui_accept` | Espace (par défaut) |
| `interact` | E |
| `sprint` | Shift |
| `freefly` | F |

## Architecture

### Flux de scènes

```
scene_1_underwater → scene_2_beach → scene_3_bar → scene_4_treasure
```

Chaque scène instancie `patrick_player.tscn` et `ui/hud.tscn` directement dans son arbre. La progression est linéaire : chaque scène connecte des `Area3D` triggers pour déclencher `Global.change_scene()` vers la suivante.

### Singleton Global (`scripts/Global.gd`)

Unique source de vérité partagée entre scènes :
- `has_key: bool` — Patrick a-t-il ramassé la clé (scène 3) ?
- `current_scene_path: String` — utilisé par `reload_current_scene()` pour le respawn après mort
- `change_scene(path)` — passe par `SceneTransition` si disponible, sinon change directement

### Joueur (`scenes/patrick_player.tscn` + `scripts/patrick.gd`)

`patrick.gd` est une extension directe de `addons/proto_controller/proto_controller.gd` (Brackeys, CC0) avec ces ajouts :
- Mode sous-marin (`underwater: bool`) : vitesse × `underwater_speed_factor`, gravité × `underwater_gravity_factor`
- Signal `interact_pressed` (touche E) — écouté par `key_pickup.gd` et `chest_interactive.gd`
- Méthode `die()` — appelée par les crabes, recharge la scène via `Global.reload_current_scene()`
- La souris est capturée automatiquement au `_ready()`

La scène joueur contient : `CharacterBody3D` > `Collider` (capsule) + `PatrickMesh` (instance de `patrick_3d.glb`) + `Head` > `Camera3D` + `InteractRay`.

### Système d'interaction (touche E)

Pattern utilisé par `key_pickup.gd` et `chest_interactive.gd` :
1. `Area3D.body_entered` → connecte `patrick.interact_pressed` à `_on_interact()`
2. `Area3D.body_exited` → déconnecte le signal
3. `_on_interact()` → vérifie `Global.has_key`, agit, appelle `get_tree().current_scene.victory()` si besoin

### HUD (`ui/hud.tscn` + `scripts/hud.gd`)

Trois méthodes publiques :
- `show_message(text, duration)` — message temporaire (haut écran)
- `set_subtitle(text)` — instruction permanente (bas écran)
- Mise à jour automatique de l'icône clé via `Global.has_key` à chaque frame

Chaque scène récupère le HUD avec `$HUD` et appelle ces méthodes directement.

### Layers de collision

| Layer | Usage |
|---|---|
| 2 | Patrick |
| 4 | Crabes + `InteractRay` mask |

### Assets

- `patrick_3d.glb` + `patrick_3d_Patrick_texture.png` — modèle joueur (racine du projet)
- `assets/dungeon_assets/` — props de la scène 3 (bar) et 4 (trésor)
- `assets/skeleton/`, `assets/zombie/` — assets non encore utilisés dans les scènes
- `addons/proto_controller/` — contrôleur FPS de base (ne pas modifier, source upstream CC0)
