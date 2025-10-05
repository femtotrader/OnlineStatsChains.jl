# OnlineStatsChains Monitoring Dashboard

Application de monitoring en temps réel pour visualiser et surveiller les DAGs (Directed Acyclic Graphs) créés avec **OnlineStatsChains.jl**.

## 📊 Fonctionnalités

- **Visualisation DAG interactive** avec Cytoscape.js
  - Layouts multiples (hiérarchique, force-directed, circulaire, grille)
  - Zoom, pan, sélection de nœuds et arêtes
  - Thèmes clair/sombre

- **Monitoring en temps réel**
  - Streaming de données vers les nœuds source
  - Mise à jour automatique de la visualisation
  - Statistiques temps réel (nombre de nœuds, arêtes, mises à jour)

- **Interface utilisateur réactive**
  - Construit avec Stipple.jl et Vue.js
  - Interface responsive (desktop, tablette, mobile)
  - Contrôles interactifs pour le streaming

## 🚀 Installation

### Prérequis

- Julia 1.10 ou supérieur
- OnlineStatsChains.jl installé

### Installation des dépendances

```bash
cd apps/dashboard
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Cela installera automatiquement :
- Stipple.jl
- StippleUI.jl
- Genie.jl
- OnlineStats.jl
- JSON3.jl
- NanoDates.jl
- Colors.jl

## 📖 Utilisation

### Démarrage rapide

#### 1. Lancer avec un DAG d'exemple

```bash
cd apps/dashboard
julia --project=. app.jl
```

Cette commande :
- Crée un DAG d'exemple avec 5 nœuds
- Lance le serveur sur `http://127.0.0.1:8000`
- Ouvre automatiquement le navigateur

#### 2. Lancer depuis Julia REPL

```julia
# Naviguer vers le répertoire
cd("apps/dashboard")

# Activer le projet
using Pkg
Pkg.activate(".")

# Charger l'application
include("app.jl")

# Créer un DAG personnalisé
using OnlineStatsChains, OnlineStats

dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :volumes, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :prices, :variance)

# Lancer le dashboard avec le DAG
app_model, route = launch_monitoring_app(dag=dag, port=8080)
```

#### 3. Charger un DAG existant dans le dashboard

```julia
# Créer un nouveau DAG
new_dag = StatDAG()
add_node!(new_dag, :sensor1, Mean())
add_node!(new_dag, :sensor2, Variance())
connect!(new_dag, :sensor1, :sensor2)

# Charger dans le dashboard en cours
load_dag!(app_model, new_dag)
```

## 🎮 Utilisation de l'interface

### Panneau de contrôle (gauche)

#### DAG Controls
- **Layout Algorithm** : Sélectionner l'algorithme de mise en page
  - Hierarchical : Disposition hiérarchique (par défaut)
  - Force-Directed : Simulation physique
  - Circular : Disposition circulaire
  - Grid : Grille régulière
  - COSE : Compound Spring Embedder

- **Theme** : Basculer entre mode clair et sombre

- **Display Options** :
  - Show Values : Afficher les valeurs actuelles des nœuds
  - Show Filters : Mettre en évidence les arêtes filtrées
  - Show Transforms : Mettre en évidence les transformations

#### Data Streaming
- **Stream to Node** : ID du nœud source pour recevoir les données (ex: `prices`)
- **Rate (Hz)** : Fréquence de streaming (1-100 Hz)
- **Start/Stop Streaming** : Boutons pour contrôler le streaming

### Panneau principal (centre/droite)

#### DAG Visualization
- **Interactions** :
  - Clic sur un nœud : Afficher les détails
  - Clic sur une arête : Afficher les métadonnées
  - Molette de souris : Zoom
  - Glisser-déposer : Déplacer la vue

- **Couleurs** :
  - 🟢 Vert (hexagone) : Nœuds source
  - 🔵 Bleu (diamant) : Nœuds sink (feuilles)
  - 🔵 Bleu clair : Nœuds intermédiaires
  - 🟠 Orange : Arêtes avec transformation
  - 🔲 Pointillés : Arêtes avec filtre

#### Statistics
- **Nodes** : Nombre total de nœuds dans le DAG
- **Edges** : Nombre total d'arêtes
- **Updates** : Compteur de mises à jour

#### Details
Affiche les informations sur le nœud ou l'arête sélectionné.

## 🔧 Configuration

### Options de lancement

```julia
launch_monitoring_app(
    port = 8080,           # Port du serveur
    host = "127.0.0.1",    # Adresse d'écoute (localhost par défaut)
    dag = nothing          # DAG optionnel à charger
)
```

⚠️ **Sécurité** : Par défaut, le serveur n'écoute que sur `127.0.0.1` (localhost).
Pour permettre l'accès depuis d'autres machines :

```julia
launch_monitoring_app(host="0.0.0.0", port=8080)
```

Un avertissement de sécurité s'affichera avec un délai de 3 secondes pour annuler (Ctrl+C).

## 🐳 Déploiement Docker

### Construction de l'image

```bash
cd apps/dashboard
docker build -t onlinestats-monitor .
```

### Lancement avec docker-compose

```bash
docker-compose up -d
```

Accès : `http://localhost:8080`

### Arrêt du conteneur

```bash
docker-compose down
```

## 📡 API REST

### Endpoints

#### `GET /`
Interface utilisateur principale.

#### `GET /api/export_dag`
Exporter le DAG actuel au format JSON Cytoscape.

**Réponse** :
```json
{
  "nodes": [
    {
      "data": {
        "id": "source",
        "label": "source: Mean",
        "type": "Mean",
        "value": 42.5,
        "is_source": true,
        "is_sink": false
      }
    }
  ],
  "edges": [
    {
      "data": {
        "id": "source_variance",
        "source": "source",
        "target": "variance",
        "has_filter": false,
        "has_transform": false
      }
    }
  ]
}
```

#### `POST /api/load_dag`
Charger un DAG depuis JSON (non implémenté).

## 🏗️ Architecture

```
apps/dashboard/
├── Project.toml              # Dépendances du projet
├── app.jl                    # Point d'entrée principal
├── README.md                 # Cette documentation
├── Dockerfile                # Image Docker
├── docker-compose.yml        # Configuration Docker Compose
├── models/
│   └── AppModel.jl           # Modèle réactif Stipple
├── views/
│   └── main_layout.jl        # Interface utilisateur
├── components/
│   └── cytoscape_component.jl # Composant Cytoscape
└── public/
    ├── css/
    │   └── custom.css        # Styles personnalisés
    └── js/
        └── cytoscape_handler.js # Logique Cytoscape.js
```

## 🛠️ Développement

### Ajout de fonctionnalités

#### Ajouter un nouveau panneau de visualisation

1. Créer un fichier dans `views/` (ex: `chart_panel.jl`)
2. Définir la fonction de rendu UI
3. Inclure dans `main_layout.jl`

#### Modifier le modèle de données

Éditer `models/AppModel.jl` et ajouter des champs réactifs :

```julia
Base.@kwdef mutable struct DashboardModel <: ReactiveModel
    # ... champs existants ...

    # Nouveau champ
    my_new_field::R{String} = "default"
end
```

#### Personnaliser les styles Cytoscape

Éditer `public/js/cytoscape_handler.js`, fonction `getStyleSheet()`.

## 🐛 Dépannage

### Le serveur ne démarre pas

**Erreur** : `Port 8080 is already in use`

**Solution** : Utiliser un autre port
```julia
launch_monitoring_app(port=8081)
```

### La visualisation ne s'affiche pas

**Vérifications** :
1. Ouvrir la console développeur du navigateur (F12)
2. Vérifier que Cytoscape.js est chargé
3. Vérifier les erreurs JavaScript
4. Vérifier que le DAG n'est pas vide

### Le streaming ne fonctionne pas

**Vérifications** :
1. Le champ "Stream to Node" doit contenir un ID de nœud source valide
2. Le nœud doit exister dans le DAG
3. Vérifier les logs Julia pour les erreurs

## 📚 Références

- [OnlineStatsChains.jl](https://github.com/username/OnlineStatsChains.jl)
- [Stipple.jl Documentation](https://github.com/GenieFramework/Stipple.jl)
- [Cytoscape.js](https://js.cytoscape.org/)
- [Genie.jl Framework](https://genieframework.com/)

## 📄 Licence

Ce projet utilise la même licence que OnlineStatsChains.jl.

## 🙏 Contributions

Les contributions sont les bienvenues ! Veuillez :
1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📞 Support

Pour toute question ou problème :
- Ouvrir une issue sur GitHub
- Consulter la documentation OnlineStatsChains.jl
