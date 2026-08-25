# Usage4Claude

[English](../README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Deutsch](README.de.md)

<div align="center">

<img src="images/icon@2x.png" width="256" alt="icon">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](../LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)
[![Downloads (all assets, all releases)](https://img.shields.io/github/downloads/f-is-h/Usage4Claude/total)](https://github.com/f-is-h/Usage4Claude/releases)

**Suivez vos quotas d'abonnement Claude (et Codex) avec élégance, directement dans la barre des menus.**

✨ **Surveille toutes les plateformes Claude : Web • Claude Code • Desktop • App Mobile • Cowork** ✨

[Fonctionnalités](#-fonctionnalités) • [Installation](#-installation) • [Guide d'utilisation](#-guide-dutilisation) • [FAQ](#-faq) • [Soutien](#-soutenir-le-projet)

</div>

---

## ✨ Fonctionnalités

### 🎯 Fonctionnalités principales

- **📊 Surveillance en temps réel** - Affiche le quota d'utilisation de l'abonnement Claude (Free/Pro/Team/Max) dans la barre des menus, avec surveillance Codex optionnelle
- **🎯 Support multi-limites** - Claude prend en charge les limites 5h / 7j / Extra Usage ainsi que l'utilisation hebdomadaire par modèle pour un nombre illimité de modèles (p. ex. Opus, Sonnet, Fable), Codex prend en charge 5h, 7j et Extra Usage/credits
- **🎨 Mode d'affichage intelligent** - Détection et affichage automatiques de tous les types de limites avec données disponibles
- **⚙️ Affichage personnalisé** - Sélection manuelle des types de limites à afficher, toute combinaison possible
- **🎨 Couleurs intelligentes** - Changement automatique des couleurs selon l'utilisation, chaque type de limite a son propre schéma
- **🔔 Notifications d'utilisation** - Avertissement à 90 % d'utilisation, notification lors de la réinitialisation du quota
- **👥 Gestion multi-comptes** - Support de plusieurs comptes Claude / plusieurs organisations par compte, avec gestion de comptes Codex indépendante et changement rapide
- **🧩 Support Codex** - Surveillance optionnelle des quotas Codex ; utilisez Codex seul ou aux côtés de Claude en vue à deux colonnes
- **🌐 Connexion via navigateur intégré** - Claude extrait automatiquement la Session Key ; Codex utilise le navigateur intégré pour se connecter à ChatGPT
- **🎨 Réglages d'apparence** - Support du mode système / clair / sombre
- **🕐 Format horaire** - Support du format système / 12h / 24h
- **⏰ Minuterie précise** - Heure de réinitialisation du quota affichée à la minute près
- **🔄 Actualisation intelligente** - Rafraîchissement adaptatif intelligent à 4 niveaux ou intervalles fixes (1/3/5/10 min)
- **⚡ Actualisation manuelle** - Cliquez sur le bouton d'actualisation pour mettre à jour instantanément (protection anti-rebond de 10 s)
- **💻 Expérience native** - Application macOS 100 % native, légère et élégante

### 🌐 Support multiplateforme

Fonctionne avec tous les produits Claude :
- 🌐 **Claude.ai** (Interface web)
- 💻 **Claude Code** (Outil CLI pour développeurs)
- 🖥️ **Application de bureau** (macOS/Windows)
- 📱 **Application mobile** (iOS/Android)
- 🤝 **Cowork** (Agent IA)

Toutes les plateformes partagent le même quota d'utilisation, surveillé en un seul endroit !

### 🧩 Support Codex

- Surveillez Codex seul ou avec Claude
- Prend en charge les informations Codex 5h, 7j et Extra Usage/credits
- Ajoutez un compte Codex en vous connectant à ChatGPT dans le navigateur intégré
- Les utilisateurs Claude-only n'ont rien à configurer ; l'expérience reste inchangée tant qu'aucun compte Codex n'est ajouté

### 🎨 Personnalisation

- **🕓 Modes d'affichage multiples**
  - Pourcentage uniquement - Épuré et intuitif, visible en un coup d'œil
  - Icône uniquement - Discret et élégant, détails au clic
  - Icône + Pourcentage - Information complète, identification visuelle rapide

- **🌍 Support multilingue**
  - English
  - 日本語
  - 简体中文
  - 繁体中文
  - 한국어
  - Français (contribution de [@mtreize](https://github.com/mtreize))
  - Deutsch (contribution de [@schaitl](https://github.com/schaitl))
  - D'autres langues à venir... (Les PR de localisation sont les bienvenues !)

### 🔧 Fonctions pratiques

- **⚙️ Réglages visuels** - Configurez toutes les options graphiquement, sans modifier le code
- **🆕 Alertes de mise à jour intelligentes** - Badge dans la barre des menus et animation arc-en-ciel pour signaler les nouvelles versions
- **🚀 Lancement à l'ouverture de session** - Démarrage automatique optionnel avec le système
- **⌨️ Raccourcis clavier** - Les opérations courantes disposent de raccourcis (⌘R | ⌘, | ⌘Q)
- **👋 Accueil convivial** - Assistant de configuration détaillé au premier lancement
- **… Affichage du menu** - Plusieurs façons d'ouvrir le menu : fenêtre de détail et clic droit
- **🔔 Notifications d'utilisation** - Avertissements et notifications de réinitialisation Claude, activables dans les réglages
- **🛠️ Mode debug** - Options développeur : données de test Claude/Codex, mise à jour simulée, actualisation instantanée

### 🔒 Sécurité et confidentialité

- 🏠 **Stockage local uniquement** - Toutes les données sont stockées localement, aucune collecte ni envoi d'informations personnelles
- 🔐 **Protection Keychain** - Session Key Claude et jeton d'authentification Codex sécurisés dans le trousseau, pas de clés en clair
- 📖 **Open source transparent** - Code entièrement public, auditable par tous
- 🛡️ **Protection Sandbox** - App Sandbox activée pour une sécurité renforcée

---

## 📸 Captures d'écran

### Affichage dans la barre des menus

- Les icônes et indicateurs de limites Claude et Codex sont présentés ci-dessous
- La forme et la couleur servent de double indicateur, lisible même avec le thème monochrome

| Icône | 5h | 7j | Extra | 7j Opus | 7j Sonnet | Monochrome (adaptatif) |
|:---:|:---:|:---:|:---:|:---:|:---:|-----|
| <img src="images/bar.icon@2x.png" width="40" height="40" alt="icon"> | <img src="images/bar.5h@2x.png" width="45" height="45" alt="5h ring"> | <img src="images/bar.7d@2x.png" width="45" height="45" alt="7d ring"> | <img src="images/bar.ex@2x.png" width="45" height="45" alt="extra ring"> | <img src="images/bar.7do@2x.png" width="45" height="45" alt="7d opus ring"> | <img src="images/bar.7ds@2x.png" width="45" height="45" alt="7d sonnet ring"> | <img src="images/bar.mono.b@2x.png" width="auto" height="35" alt="mono black"></br> <img src="images/bar.mono.w@2x.png" width="auto" height="35" alt="mono white"> |
| <img src="images/bar.icon.codex@2x.png" width="40" height="40" alt="codex icon"> | <img src="images/bar.5h.codex@2x.png" width="45" height="45" alt="codex 5h ring"> | <img src="images/bar.7d.codex@2x.png" width="45" height="45" alt="codex 7d ring"> | <img src="images/bar.ex.codex@2x.png" width="45" height="45" alt="codex extra ring"> | — | — | <img src="images/bar.mono.b.codex@2x.png" width="auto" height="35" alt="codex mono black"></br> <img src="images/bar.mono.w.codex@2x.png" width="auto" height="35" alt="codex mono white"> |

**Indicateurs de couleur** :

Couleurs Claude actuelles :

- **Limite 5h (fenêtre de détail incluse)** : ![Vert macOS](https://img.shields.io/badge/Vert_macOS-34C759) → ![Orange macOS](https://img.shields.io/badge/Orange_macOS-FF9500) → ![Rouge macOS](https://img.shields.io/badge/Rouge_macOS-FF3B30)
- **Limite 7j (fenêtre de détail incluse)** : ![Violet clair](https://img.shields.io/badge/Violet_clair-C084FC) → ![Violet](https://img.shields.io/badge/Violet-B450F0) → ![Violet foncé](https://img.shields.io/badge/Violet_fonce-B41EA0)
- **Extra Usage** : ![Rose](https://img.shields.io/badge/Rose-FF9ECD) → ![Rose vif](https://img.shields.io/badge/Rose_vif-EC4899) → ![Magenta](https://img.shields.io/badge/Magenta-D946EF)
- **Limite 7j Opus** : ![Orange clair](https://img.shields.io/badge/Orange_clair-FFC864) → ![Ambre](https://img.shields.io/badge/Ambre-FBBF24) → ![Orange rouge](https://img.shields.io/badge/Orange_rouge-FF6432)
- **Limite 7j Sonnet** : ![Bleu clair](https://img.shields.io/badge/Bleu_clair-64C8FF) → ![Bleu](https://img.shields.io/badge/Bleu-007AFF) → ![Indigo](https://img.shields.io/badge/Indigo-4F46E5)

Couleurs Codex actuelles :

- **Limite Codex 5h** : ![Sarcelle clair](https://img.shields.io/badge/Sarcelle_clair-2DD4BF) → ![Sarcelle foncé](https://img.shields.io/badge/Sarcelle_fonce-0D9488) → ![Sarcelle très foncé](https://img.shields.io/badge/Sarcelle_tres_fonce-134E4A)
- **Limite Codex 7j** : ![Bleu ciel](https://img.shields.io/badge/Bleu_ciel-60A5FA) → ![Bleu](https://img.shields.io/badge/Bleu-2563EB) → ![Bleu foncé](https://img.shields.io/badge/Bleu_fonce-1E3A8A)
- **Codex Extra Usage / credits** : ![Or](https://img.shields.io/badge/Or-F59E0B) → ![Or foncé](https://img.shields.io/badge/Or_fonce-D97706) → ![Ambre très foncé](https://img.shields.io/badge/Ambre_tres_fonce-78350F)

### Fenêtre de détail

<table border="0">
<tr>
<td align="top" valign="top">
<img src="images/detail.claude.fr@2x.png" width="280" alt="Mode Claude seul">
<br/>
<sub><i>Mode Claude seul</i></sub>
</td>
<td align="center" valign="top">
<img src="images/detail.codex.fr@2x.png" width="280" alt="Mode Codex seul">
<br/>
<sub><i>Mode Codex seul</i></sub>
</td>
</tr>
<tr>
<td align="center" valign="top" colspan="2">
<img src="images/detail.both.fr@2x.png" width="560" alt="Mode Claude et Codex">
<br/>
<sub><i>Mode Claude + Codex</i></sub>
</td>
</tr>
<tr>
<td align="center" valign="top" colspan="2">
<img src="images/detail@2x.gif" width="280" alt="Animation de bascule du temps restant">
<br/>
<sub><i>Animation de bascule du temps restant</i></sub>
</td>
</tr>
</table>



### Réglages

**Réglages généraux** - Options d'affichage, thème de la barre des menus, notifications, apparence (système/clair/sombre), mode d'actualisation, format horaire, langue, lancement à l'ouverture de session
**Authentification** - Gestion des comptes Claude/Codex (ajout/suppression/changement/alias), connexion via le navigateur intégré, saisie manuelle pour Claude, diagnostic de connexion
**À propos** - Informations de version et liens utiles

### Écran de bienvenue

**Configurer l'authentification** - Claude propose la connexion en un clic via le navigateur intégré (recommandé) ou la saisie manuelle de la Session Key ; l'Organization ID est récupéré automatiquement et plusieurs organisations sous une même Session Key sont créées automatiquement. Codex s'ajoute dans les réglages via la connexion à ChatGPT dans le navigateur intégré
**Configurer les options d'affichage** - Choix du thème de la barre des menus, du contenu affiché et du mode d'affichage (intelligent/personnalisé) avec aperçu en direct
**Configurer plus tard** - Fermez la fenêtre de bienvenue et configurez plus tard dans les réglages

---

## 💾 Installation

### Option 1 : Télécharger le binaire (recommandé)

1. Rendez-vous sur la [page des Releases](https://github.com/f-is-h/Usage4Claude/releases)
2. Téléchargez le dernier fichier `.dmg`
3. Double-cliquez pour ouvrir, glissez l'application dans le dossier Applications
4. Faites un clic droit sur l'app et sélectionnez « Ouvrir » au premier lancement (autoriser l'app non signée)
5. Autorisez l'accès au trousseau pour les informations d'authentification (une nouvelle autorisation peut être demandée après une mise à jour ; la fenêtre indique le jeton concerné)

### Option 2 : Compiler depuis les sources

#### Prérequis
- macOS 13.0 ou ultérieur
- Xcode 15.0 ou ultérieur
- Git

#### Étapes de compilation

```bash
# Cloner le dépôt
git clone https://github.com/f-is-h/Usage4Claude.git
cd Usage4Claude

# Ouvrir dans Xcode
open Usage4Claude.xcodeproj

# Appuyez sur Cmd + R pour lancer dans Xcode
```

---

## 📖 Guide d'utilisation

### Configuration initiale

1. **Lancer l'application**
   L'écran de bienvenue apparaît au premier lancement

2. **Configurer l'authentification**
   - **Claude option 1 : Connexion via le navigateur (recommandé)**
     - Cliquez sur le bouton « Connexion via le navigateur »
     - Connectez-vous à votre compte Claude dans le navigateur intégré
     - La Session Key sera extraite automatiquement après la connexion
   - **Claude option 2 : Saisie manuelle**
     - Ouvrez votre navigateur et visitez la page d'utilisation de Claude
     - Ouvrez les outils de développement (F12 ou Cmd + Option + I)
     - Allez dans l'onglet « Réseau », rechargez la page
     - Trouvez la requête `usage`, extrayez `sessionKey=sk-ant-...` depuis le Cookie
     - Collez dans le champ de saisie
   - **Compte Codex (facultatif)**
     - Ouvrez Réglages → Authentification
     - Cliquez sur « Connexion via le navigateur » pour Codex
     - Connectez-vous à votre compte ChatGPT dans la fenêtre intégrée
     - Les informations d'authentification sont enregistrées automatiquement
     - Codex ne prend actuellement pas en charge la saisie manuelle de Session Key

### Utilisation quotidienne

- **Affichage par défaut** - L'icône de la barre des menus affiche le pourcentage d'utilisation
- **Voir les détails** - Cliquez sur l'icône de la barre des menus ; avec Claude/Codex seul, une colonne Claude/Codex est affichée, et avec les deux fournisseurs la vue passe en deux colonnes
- **Actualisation manuelle** - Cliquez sur le bouton d'actualisation ou utilisez le raccourci ⌘R ; en vue à deux colonnes, Claude et Codex peuvent aussi être actualisés séparément
- **Changer de compte** - Menu « … » dans la fenêtre de détail ou clic droit sur l'icône pour choisir un compte Claude / Codex
- **Raccourcis clavier**
  - ⌘R - Actualiser les données
  - ⌘, - Ouvrir les réglages généraux
  - ⌘⇧A - Ouvrir les réglages d'authentification
  - ⌘U - Vérifier les mises à jour
  - ⌘Q - Quitter l'application
- **Rappel de mise à jour** - Lorsqu'une nouvelle version est disponible, l'icône de la barre des menus affiche un badge et l'élément de menu un texte arc-en-ciel
- **Vérifier les mises à jour** - Menu → Vérifier les mises à jour

### Mode d'actualisation

**Fréquence intelligente (recommandé)**
- Ajuste automatiquement l'intervalle selon l'activité
- Mode actif (1 min) - Actualisation rapide pendant l'utilisation de Claude ou Codex
- Modes inactifs (3/5/10 min) - Ralentissement progressif lorsque l'utilisation est stable
- Réduit fortement les appels API pendant les périodes inactives (jusqu'à 10×)
- Retour automatique à 1 minute lorsqu'une activité est détectée
- Actualisation automatique après la sortie de veille du système

**Fréquence fixe**
- **1 minute** - Recommandé pour une surveillance continue
- **3 minutes** - Surveillance équilibrée
- **5 minutes** - Surveillance à basse fréquence
- **10 minutes** - Appels API minimaux

---

## ❓ FAQ

<details>
<summary><b>Q : Que faire si l'application affiche « Session expirée » ?</b></summary>

R : La Session Key Claude ou le jeton d'authentification Codex expire périodiquement (généralement des semaines à des mois), il faut se reconnecter :
1. Ouvrez Réglages → Authentification
2. Pour Claude, cliquez sur « Connexion via le navigateur » (recommandé), ou obtenez manuellement une nouvelle Session Key
3. Pour Codex, cliquez sur la connexion navigateur Codex et reconnectez-vous à ChatGPT dans la fenêtre intégrée
4. C'est fait, la surveillance reprendra

</details>

<details>
<summary><b>Q : Comment activer le lancement automatique au démarrage ?</b></summary>

R : Deux méthodes :

**Méthode 1 : Option intégrée (recommandé)**
1. Ouvrez Réglages → Général
2. Cochez « Démarrer automatiquement à la connexion »

**Méthode 2 : Via les Réglages Système**
1. Ouvrez Réglages Système → Général → Ouverture
2. Cliquez sur « + » pour ajouter Usage4Claude

</details>

<details>
<summary><b>Q : Combien de ressources système sont utilisées ?</b></summary>

R : Très léger :
- Utilisation CPU : < 0,1 % (au repos)
- Mémoire : ~20 Mo
- Réseau : Actualisation selon la fréquence configurée ; avec Claude et Codex, chaque service est appelé séparément

</details>

<details>
<summary><b>Q : Quelles versions de macOS sont supportées ?</b></summary>

R : Nécessite macOS 13.0 (Ventura) ou ultérieur. Supporte les puces Intel et Apple Silicon (M1/M2/M3/M4/M5).

</details>

<details>
<summary><b>Q : Pourquoi l'application demande-t-elle l'accès au trousseau ?</b></summary>

R :
- Le trousseau est le gestionnaire de mots de passe au niveau système de macOS
- La Session Key Claude et le jeton d'authentification Codex sont chiffrés dans le trousseau
- L'Organization ID Claude est stocké dans la configuration locale (identifiant non sensible)
- C'est la méthode de stockage sécurisé recommandée par Apple
- Seule cette application peut accéder aux informations, les autres applications ne peuvent pas les consulter

</details>

<details>
<summary><b>Q : Mes données sont-elles en sécurité ? Comment la confidentialité est-elle protégée ?</b></summary>

**Entièrement sécurisé !**

**Stockage des données :**
- Toutes les données sont stockées **uniquement** sur votre Mac local
- Aucune collecte, aucun suivi, aucune statistique
- Aucune requête réseau en dehors des appels aux API Claude et Codex
- Aucun service tiers utilisé

**Sécurité de l'authentification :**
- Session Key Claude et jeton d'authentification Codex chiffrés via le trousseau macOS (chiffrement au niveau système)
- Le trousseau utilise le chiffrement AES-256 + protection matérielle (T2 / Secure Enclave)
- Seule cette application peut accéder à vos identifiants
- Vous pouvez révoquer l'accès à tout moment via l'application « Trousseaux d'accès »

**Transparence du code :**
- 100 % open source
- Pas d'obfuscation ni de fonctionnalités cachées
- La communauté peut auditer et vérifier

**Protection supplémentaire :**
- App Sandbox activée (accès système restreint)
- Aucun accès à vos fichiers, contacts ou autres applications
- Permissions minimales (réseau + trousseau uniquement)

Vous pouvez vérifier tout cela en consultant le code source sur GitHub !

</details>

<details>
<summary><b>Q : L'application fonctionne-t-elle avec Claude Code / l'app de bureau / l'app mobile ?</b></summary>

R : **Oui, elle fonctionne avec toutes les plateformes Claude !**

Puisque tous les produits Claude (Web, Claude Code, Application de bureau, Application mobile, Cowork) partagent le même quota d'utilisation, Usage4Claude surveille votre utilisation combinée sur toutes les plateformes.

Que vous soyez en train de :
- programmer avec `claude code` dans le terminal
- discuter sur claude.ai
- utiliser l'application de bureau
- utiliser l'application mobile
- collaborer avec Cowork

Vous voyez l'utilisation totale en temps réel dans la barre des menus. Aucune configuration spécifique à la plateforme n'est nécessaire !

</details>

<details>
<summary><b>Q : Comment activer Codex ? Peut-on utiliser Codex seul ?</b></summary>

R : Oui. Ouvrez Réglages → Authentification, cliquez sur la connexion navigateur Codex, puis connectez-vous à ChatGPT dans la fenêtre intégrée.

- Codex seul : la barre des menus et la fenêtre de détail affichent l'utilisation Codex
- Claude + Codex : la fenêtre de détail affiche les deux fournisseurs côte à côte
- Codex prend actuellement en charge uniquement la connexion via navigateur, pas la saisie manuelle de Session Key

</details>

<details>
<summary><b>Q : Que faire si l'icône n'apparaît pas dans la barre des menus ?</b></summary>

R : macOS ou des logiciels tiers (Bartender, Hidden Bar, etc.) masquent parfois automatiquement les icônes de la barre des menus.

**Solution :**
1. Maintenez la touche **Command (⌘)** enfoncée
2. Faites glisser les icônes de la barre des menus avec la souris
3. Déplacez l'icône Usage4Claude vers la zone visible à droite de la barre des menus
4. Relâchez la souris

**Astuce :**
- macOS Sonoma (14.0+) déplace automatiquement les icônes peu utilisées vers le « Centre de contrôle »
- Vous pouvez ajuster l'affichage des icônes de la barre des menus dans Réglages Système → Centre de contrôle

</details>

<details>
<summary><b>Q : Comment gérer plusieurs comptes ?</b></summary>

R : Usage4Claude prend en charge plusieurs comptes Claude, plusieurs organisations sous un même compte Claude, ainsi que des comptes Codex indépendants :
- **Ajouter un compte** - Connexion navigateur Claude, saisie manuelle Claude ou connexion navigateur Codex dans Réglages → Authentification
- **Changer de compte** - Menu « … » dans la fenêtre de détail ou clic droit sur l'icône de la barre des menus
- **Modifier l'alias** - Donnez à chaque compte un nom facile à reconnaître
- **Supprimer un compte** - Supprimez les comptes inutiles depuis la liste des comptes

</details>

<details>
<summary><b>Q : Comment activer les notifications d'utilisation ?</b></summary>

R : Les notifications d'utilisation Claude se règlent dans Réglages → Général :
- **Avertissement d'utilisation** - Notification système lorsque l'utilisation Claude atteint 90 %
- **Notification de réinitialisation** - Notification lorsque le quota Claude est réinitialisé
- Une autorisation macOS est requise à la première activation

</details>

---

## 🛠 Stack technique

Ce projet est construit avec des technologies macOS natives modernes :

- **Langage** : Swift 5.0+
- **Framework UI** : SwiftUI + AppKit hybride
- **Architecture** : MVVM
- **Réseau** : URLSession
- **Réactif** : Combine Framework
- **Localisation** : prise en charge i18n intégrée
- **Plateforme** : macOS 13.0+

---

## 🗺 Feuille de route

### ✅ Terminé
- [x] Fonctions de surveillance de base
- [x] Affichage en temps réel dans la barre des menus
- [x] Indicateur de progression circulaire
- [x] Alertes de couleur intelligentes
- [x] Compte à rebours en temps réel
- [x] Plusieurs modes d'affichage de la barre des menus
- [x] Interface de réglages visuelle
- [x] Support multilingue
- [x] Assistant de première ouverture
- [x] Vérification des mises à jour avec alertes visuelles
- [x] Stockage des informations d'authentification dans le trousseau
- [x] Packaging DMG automatique via shell
- [x] Publication automatique avec GitHub Actions
- [x] Optimisation de l'affichage des réglages
- [x] Option de lancement à l'ouverture de session
- [x] Prise en charge des raccourcis clavier
- [x] Actualisation manuelle
- [x] Adaptation du menu à trois points au mode sombre
- [x] Support du double mode de limite (5 heures + 7 jours)
- [x] Icône de barre des menus à double anneau
- [x] Gestion unifiée des schémas de couleur
- [x] Mode debug (fausses données, mises à jour simulées)
- [x] Suppression de l'état Focus dans la fenêtre de détail
- [x] Support de plusieurs types de limites (5 types)
- [x] Mode d'affichage intelligent/personnalisé
- [x] Récupération automatique de l'Organization ID
- [x] Parcours d'accueil optimisé
- [x] Affichage des icônes en thème monochrome
- [x] Support de la langue coréenne
- [x] Vérification de la version en ligne avec GitHub Actions
- [x] Réglages d'apparence (système/clair/sombre)
- [x] Authentification automatique avec navigateur intégré
- [x] Configuration automatique des identifiants
- [x] Notifications d'utilisation
- [x] Gestion multi-comptes
- [x] Réglages de format horaire unifiés
- [x] Adaptation de l'interface des réglages au mode sombre
- [x] Support de la surveillance d'utilisation Codex
- [x] Mode Codex seul
- [x] Fenêtre de détail Claude + Codex à deux colonnes
- [x] Gestion des comptes Codex et connexion navigateur
- [x] Localisation française
- [x] Actualisation automatique après la sortie de veille du système

### Plans à moyen terme
1. **Ajout de fonctionnalités**
    - Plus de localisations linguistiques

### Vision à long terme
2. **Plus de modes d'affichage**
   - Widgets de bureau
   - Affichage de l'utilisation dans une icône d'extension de navigateur

3. **Analyse des données**
   - Historique d'utilisation
   - Graphiques de tendance

4. **Support multiplateforme**
   - Version iOS / iPadOS
   - Version Apple Watch
   - Version Windows

---

## 🤝 Contribution

Toutes les contributions sont les bienvenues, qu'il s'agisse de nouvelles fonctionnalités, de corrections de bugs ou d'améliorations de la documentation.

Pour les consignes détaillées de contribution, consultez [CONTRIBUTING.md](../CONTRIBUTING.md).

### Comment contribuer

1. Forkez ce dépôt
2. Créez votre branche de fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commitez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Poussez la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

### Contributeurs

Merci à toutes les personnes qui ont contribué à ce projet !

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- La liste des contributeurs sera générée automatiquement ici -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 📝 Journal des modifications

Pour l'historique détaillé des versions et des mises à jour, consultez [CHANGELOG.md](../CHANGELOG.md).

---

## 💖 Soutenir le projet

Si ce projet vous aide, vous pouvez le soutenir des façons suivantes :

### ⭐ Donner une Star au projet
Une Star est le meilleur encouragement !

### ☕ M'offrir un café

<!-- GitHub Sponsors -->
<a href="https://github.com/sponsors/f-is-h?frequency=one-time">
  <img src="https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge&logo=github" alt="GitHub Sponsor">
</a>

<!-- Ko-fi -->
<a href="https://ko-fi.com/1attle">
  <img src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi" alt="Ko-fi">
</a>

<!-- Buy Me A Coffee -->
<!-- <a href="https://buymeacoffee.com/fish_">
  <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee">
</a> -->

### 📢 Partager le projet
Si vous aimez ce projet, partagez-le avec davantage de personnes !

---

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](../LICENSE) pour plus de détails

```
MIT License

Copyright (c) 2025-2026 f-is-h

Vous êtes libre d'utiliser, de copier, de modifier, de fusionner, de publier,
de distribuer, de sous-licencier et/ou de vendre des copies de ce logiciel.
```

---

## 🙏 Remerciements

- Merci à Claude/Codex - La majeure partie du code a été écrite par l'IA
- Merci à tous les contributeurs et utilisateurs pour leur soutien
- Le design des icônes s'inspire des marques officielles Claude/Codex

---

## 📞 Contact

- **Issues** : [Soumettre un problème ou une suggestion](https://github.com/f-is-h/Usage4Claude/issues)
- **Discussions** : [Rejoindre les discussions](https://github.com/f-is-h/Usage4Claude/discussions)
- **GitHub** : [@f-is-h](https://github.com/f-is-h)

---

## ⚖️ Avertissement

Ce projet est un outil tiers indépendant sans affiliation officielle avec Anthropic, Claude AI, OpenAI ou Codex. Veuillez respecter les conditions d'utilisation des services concernés lors de l'utilisation de ce logiciel.

---

<div align="center">

**Si ce projet vous aide, n'hésitez pas à lui donner une ⭐ Star !**

Fait avec ❤️ par [f-is-h](https://github.com/f-is-h)

[⬆ Retour en haut](#usage4claude)

</div>
