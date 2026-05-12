# 🌊 Patrick — Jeu d'Aventure 3D Godot

Un jeu en 4 scènes où Patrick sort de l'eau, traverse une plage piégée, explore un bar mystérieux, et trouve un trésor.

## 📂 Structure du projet

```
patrick_game/
├── scripts/
│   ├── Global.gd              ← Singleton (autoload)
│   ├── SceneTransition.gd     ← Fade noir entre scènes (autoload)
│   ├── patrick.gd             ← Joueur FPS (modifié pour interaction)
│   ├── crab.gd                ← IA des crabes
│   ├── key_pickup.gd          ← Pickup de la clé
│   ├── chest_interactive.gd   ← Coffre interactif final
│   ├── hud.gd                 ← Interface utilisateur
│   ├── scene_1_underwater.gd
│   ├── scene_2_beach.gd
│   ├── scene_3_bar.gd
│   └── scene_4_treasure.gd
├── scenes/
│   ├── transition.tscn        ← Autoload
│   ├── patrick_player.tscn    ← Joueur réutilisable
│   ├── crab.tscn              ← Crabe en CSG
│   ├── key_pickup.tscn        ← Clé qui flotte
│   ├── scene_1_underwater.tscn ← 🌊 Scène 1
│   ├── scene_2_beach.tscn     ← 🦀 Scène 2
│   ├── scene_3_bar.tscn       ← 🍻 Scène 3
│   └── scene_4_treasure.tscn  ← 💰 Scène 4
└── ui/
    └── hud.tscn               ← HUD réutilisable
```

## 🚀 Installation dans ton projet Godot

### 1. Copier les fichiers
Copie les dossiers `scripts/`, `scenes/`, `ui/` à la racine de ton projet Godot
(à côté de tes dossiers `assets/` et `addons/`).

### 2. Configurer les autoloads
Dans Godot : `Project → Project Settings → Autoload`

Ajoute ces deux entrées dans cet ordre :

| Path                              | Node Name        | Enabled |
|-----------------------------------|------------------|---------|
| `res://scripts/Global.gd`         | `Global`         | ✅      |
| `res://scenes/transition.tscn`    | `SceneTransition`| ✅      |

### 3. Configurer les Input Actions
Dans `Project → Project Settings → Input Map`, vérifie que ces actions existent :

| Action      | Touche        | Note                              |
|-------------|---------------|-----------------------------------|
| `ui_left`   | A / Flèche ←  | (existe par défaut)               |
| `ui_right`  | D / Flèche →  | (existe par défaut)               |
| `ui_up`     | W / Flèche ↑  | (existe par défaut)               |
| `ui_down`   | S / Flèche ↓  | (existe par défaut)               |
| `ui_accept` | Espace        | (existe par défaut)               |
| `interact`  | E             | **À CRÉER** (pour ramasser/ouvrir)|
| `sprint`    | Shift gauche  | Optionnel                         |

Pour créer `interact` : tape `interact` dans le champ "Add New Action", clique +,
puis clique le + à droite pour ajouter la touche **E**.

### 4. Lancer le jeu
- Définir la scène principale : `Project → Project Settings → Application/Run/Main Scene` → `res://scenes/scene_1_underwater.tscn`
- Appuie sur **F5** pour jouer ! 🎮

## 🎮 Contrôles

- **WASD** : se déplacer
- **Souris** : regarder
- **Espace** : sauter
- **Shift** : courir
- **E** : interagir (clé, coffre)
- **Échap** : libérer la souris

## 🎬 Déroulement du jeu

1. **🌊 Scène 1 — Sous l'eau**
   Patrick commence dans l'eau (effet bleu, particules de bulles).
   Il doit nager vers la plage (-Z). Quand il atteint le sable → scène 2.

2. **🦀 Scène 2 — La plage**
   6 crabes patrouillent sur la plage. Si l'un touche Patrick, la scène recharge.
   Patrick doit atteindre la cabane en bois au fond (-Z).

3. **🍻 Scène 3 — Le bar**
   Cabane à l'ambiance feutrée (bougies, torches, déco).
   Trouver la clé 🔑 sur une petite table puis l'escalier dans le coin.

4. **💰 Scène 4 — La salle du trésor**
   Grande salle de pierre avec coffre doré sur un piédestal.
   Sans clé : "Verrouillé". Avec la clé : E pour ouvrir → 🎉 victoire !

## 🛠️ Améliorations possibles

- 🎵 Ajouter des sons (vagues, pas, ambiance, ouverture du coffre)
- 🏃 Faire courir les crabes vers Patrick s'il est proche (au lieu de patrouille fixe)
- ✨ Ajouter des particules d'or qui jaillissent du coffre à l'ouverture
- 🎨 Remplacer les CSG par tes assets `.glb` (ex: utiliser `wall.glb` au lieu des CSGBox)
- 💡 Faire vaciller les bougies (animation de l'intensité de la lumière)
- 🗺️ Ajouter une mini-map ou une boussole

## 🔧 Dépannage

**"Autoload Global is not loaded"**
→ Vérifie que tu as bien ajouté `Global.gd` ET `transition.tscn` en autoload.

**Patrick ne se déplace pas**
→ Vérifie les Input Actions (`ui_left`, `ui_right`, etc.)

**E ne fait rien**
→ L'action `interact` n'est probablement pas configurée. Voir étape 3.

**Les crabes ne tuent pas Patrick**
→ Vérifie que Patrick a bien `collision_layer = 2`.

Bon jeu ! 🦀🔑💰
