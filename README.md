# Bibliothèque IP Verilog

Une collection de modules IP (Intellectual Property) Verilog pour FPGA, conçus pour la synchronisation et la gestion de données.

## 📋 Table des matières

- [Modules disponibles](#modules-disponibles)
- [Pipeline](#pipeline)
- [Buffered FIFO](#buffered-fifo)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Structure du projet](#structure-du-projet)

## 🔧 Modules disponibles

### 1. Pipeline
Un module de synchronisation simple qui retarde les données pour assurer la synchronisation.

### 2. Buffered FIFO
Une FIFO avancée utilisant deux FIFO en cascade : une FIFO à registres et une FIFO à mémoire (BSRAM).

---

## 📊 Pipeline

### Description
Le module `pipeline` est un élément de synchronisation basique qui introduit un délai configurable sur les données d'entrée. Il est particulièrement utile pour :
- Synchroniser des signaux avec des chemins de données différents
- Aligner des données dans le temps
- Créer des étapes de pipeline dans des architectures plus complexes

### Caractéristiques
- ✅ Délai configurable
- ✅ Synchronisation simple
- ✅ Faible consommation de ressources
- ✅ Interface standard

### Fichiers
- `pipeline/pipeline.v` - Module principal

---

## 🚀 Buffered FIFO

### Description
La `Buffered FIFO` est une FIFO sophistiquée qui utilise une architecture à deux niveaux pour optimiser les performances en gérant intelligemment la latence de lecture :

1. **FIFO à registres** (`FIFO_registers.v`) - Cache rapide pour accès immédiat aux données
2. **FIFO à mémoire BSRAM** (`FIFO_BSRAM.v`) - Stockage principal avec latence de lecture

### Architecture
```
Données d'entrée → FIFO_registers → FIFO_BSRAM → Données de sortie
                      ↑                ↑
                   Accès immédiat    Latence de lecture
                   (0 cycle)         (plusieurs cycles)
```

### Principe de fonctionnement
- **Cache FIFO_registers** : Permet un accès immédiat (0 cycle de latence) aux données les plus récentes
- **FIFO_BSRAM** : Stockage principal optimisé pour la capacité, mais avec une latence de lecture inhérente à l'utilisation de mémoire matérielle
- **Avantage** : Le cache évite d'avoir à attendre la latence de lecture de la BSRAM pour les 1ère données arrivés

### Composants
- `Buffered_FIFO.v` - Module principal de contrôle
- `FIFO_registers.v` - FIFO basée sur des registres
- `FIFO_BSRAM.v` - FIFO utilisant la mémoire BSRAM
- `BSRAM.v` - Interface mémoire BSRAM
- `Credit_box.v` - Gestion des crédits et contrôle de flux

### Caractéristiques
- ✅ Double tampon pour optimiser les performances
- ✅ Gestion intelligente de la mémoire
- ✅ Contrôle de flux avec système de crédits
- ✅ Interface mémoire BSRAM optimisée
- ✅ Gestion des débordements et sous-débordements

### Avantages
- **Performance** : Accès immédiat (0 cycle) aux données via le cache registres
- **Évitement de latence** : Le cache évite la latence de lecture de la BSRAM
- **Capacité** : Stockage de grandes quantités via la mémoire BSRAM
- **Optimisation** : Meilleur compromis entre vitesse d'accès et capacité de stockage
- **Fiabilité** : Contrôle de flux robuste avec système de crédits

---

## 🛠 Installation

### Prérequis
- Outil de synthèse FPGA (Quartus, Vivado, etc.)
- Simulateur Verilog (ModelSim, VCS, etc.)

### Utilisation
1. Clonez ce dépôt :
```bash
git clone https://github.com/Mate-bert/Bibliotheque_IP_Verilog.git
```

2. Intégrez les modules dans votre projet FPGA
3. Instanciez les modules selon vos besoins

---

## 📁 Structure du projet

```
Bibliotheque_IP_Verilog/
├── README.md
├── .gitignore
├── pipeline/
│   └── pipeline.v
└── Buffered_FIFO/
    ├── Buffered_FIFO.v
    ├── FIFO_registers.v
    ├── FIFO_BSRAM.v
    ├── BSRAM.v
    └── Credit_box.v
```

---

## 🎯 Utilisation

### Pipeline
```verilog
pipeline #(
    .DELAY_CYCLES(2)  // Nombre de cycles de délai
) pipeline_inst (
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .data_out(data_out)
);
```

### Buffered FIFO
```verilog
Buffered_FIFO #(
    .DATA_WIDTH(32),
    .FIFO_DEPTH(1024)
) fifo_inst (
    .clk(clk),
    .rst(rst),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty)
);
```

---

## 📝 Notes

- Les modules sont conçus pour être compatibles avec la plupart des outils FPGA
- Testez toujours vos implémentations avant utilisation en production
- Consultez les commentaires dans le code pour plus de détails techniques

---

## 👨‍💻 Auteur

**Mateo Bertolelli** - Développeur FPGA

---

## 📄 Licence

Ce projet est sous licence libre. Voir le fichier LICENSE pour plus de détails.