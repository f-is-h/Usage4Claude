# Usage4Claude

[English](../README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [Français](README.fr.md)

<div align="center">

<img src="images/icon@2x.png" width="256" alt="icon">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](../LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)
[![Downloads (all assets, all releases)](https://img.shields.io/github/downloads/f-is-h/Usage4Claude/total)](https://github.com/f-is-h/Usage4Claude/releases)

**Suivez vos quotas d'abonnement Claude (et Codex en option) avec elegance, directement dans la barre des menus.**

✨ **Surveille toutes les plateformes Claude : Web • Claude Code • Desktop • App Mobile • Cowork** ✨

[Fonctionnalites](#-fonctionnalites) • [Installation](#-installation) • [Guide d'utilisation](#-guide-dutilisation) • [FAQ](#-faq) • [Support](#-support)

</div>

---

## ✨ Fonctionnalites

### 🎯 Fonctionnalites principales

- **📊 Surveillance en temps reel** - Affiche le quota d'utilisation de l'abonnement Claude (Free/Pro/Team/Max) dans la barre des menus
- **🎯 Support multi-limites** - Affiche jusqu'a 5 limites simultanement (5h/7j/Extra/7j Opus/7j Sonnet)
- **🎨 Mode d'affichage intelligent** - Detection et affichage automatiques de tous les types de limites avec donnees disponibles
- **⚙️ Affichage personnalise** - Selection manuelle des types de limites a afficher, toute combinaison possible
- **🎨 Couleurs intelligentes** - Changement automatique des couleurs selon l'utilisation, chaque type de limite a son propre schema
- **🔔 Notifications d'utilisation** - Avertissement a 90 % d'utilisation, notification lors de la reinitialisation du quota
- **👥 Gestion multi-comptes** - Support de plusieurs comptes / plusieurs organisations par compte, changement rapide
- **✨ Support Codex** - Surveillance optionnelle des quotas Codex aux cotes de Claude, avec une vue a deux colonnes lorsque les deux fournisseurs sont configures
- **🌐 Connexion via navigateur integre** - Navigateur integre pour extraire automatiquement la Session Key, sans copie manuelle
- **🎨 Reglages d'apparence** - Support du mode systeme / clair / sombre
- **🕐 Format horaire** - Support du format systeme / 12h / 24h
- **⏰ Minuterie precise** - Heure de reinitialisation du quota affichee a la minute pres
- **🔄 Actualisation intelligente** - Rafraichissement adaptatif intelligent a 4 niveaux ou intervalles fixes (1/3/5/10 min)
- **⚡ Actualisation manuelle** - Cliquez sur le bouton d'actualisation pour mettre a jour instantanement (protection anti-rebond de 10 s)
- **💻 Experience native** - Application macOS 100 % native, legere et elegante

### 🌐 Support multiplateforme

Fonctionne avec tous les produits Claude :
- 🌐 **Claude.ai** (Interface web)
- 💻 **Claude Code** (Outil CLI pour developpeurs)
- 🖥️ **Application de bureau** (macOS/Windows)
- 📱 **Application mobile** (iOS/Android)
- 🤝 **Cowork** (Agent IA)

Toutes les plateformes partagent le meme quota d'utilisation, surveille en un seul endroit !

### 🎨 Personnalisation

- **🕓 Modes d'affichage multiples**
  - Pourcentage uniquement - Epure et intuitif, visible en un coup d'oeil
  - Icone uniquement - Discret et elegant, details au clic
  - Icone + Pourcentage - Information complete, identification visuelle rapide

- **🌍 Support multilingue**
  - English
  - 日本語
  - 简体中文
  - 繁体中文
  - 한국어
  - Français
  - D'autres langues a venir...

### 🔒 Securite et confidentialite

- 🏠 **Stockage local uniquement** - Toutes les donnees sont stockees localement, aucune collecte ni envoi d'informations personnelles
- 🔐 **Protection Keychain** - Informations sensibles securisees dans le trousseau, pas de cles en clair
- 📖 **Open source transparent** - Code entierement public, auditable par tous
- 🛡️ **Protection Sandbox** - App Sandbox activee pour une securite renforcee

---

## 💾 Installation

### Option 1 : Telecharger le binaire (recommande)

1. Rendez-vous sur la [page des Releases](https://github.com/f-is-h/Usage4Claude/releases)
2. Telechargez le dernier fichier `.dmg`
3. Double-cliquez pour ouvrir, glissez l'application dans le dossier Applications
4. Faites un clic droit sur l'app et selectionnez « Ouvrir » au premier lancement (autoriser l'app non signee)
5. Autorisez l'acces au trousseau pour les informations d'authentification

### Option 2 : Compiler depuis les sources

#### Prerequis
- macOS 13.0 ou ulterieur
- Xcode 15.0 ou ulterieur
- Git

#### Etapes de compilation

```bash
# Cloner le depot
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
   L'ecran de bienvenue apparait au premier lancement

2. **Configurer l'authentification**
   - **Option 1 : Connexion via le navigateur (recommande)**
     - Cliquez sur le bouton « Connexion via le navigateur »
     - Connectez-vous a votre compte Claude dans le navigateur integre
     - La Session Key sera extraite automatiquement apres la connexion
   - **Option 2 : Saisie manuelle**
     - Ouvrez votre navigateur et visitez la page d'utilisation de Claude
     - Ouvrez les outils de developpement (F12 ou Cmd + Option + I)
     - Allez dans l'onglet « Reseau », rechargez la page
     - Trouvez la requete `usage`, extrayez `sessionKey=sk-ant-...` depuis le Cookie
     - Collez dans le champ de saisie
   - **Compte Codex (facultatif)**
     - Ouvrez Reglages → Authentification
     - Cliquez sur « Ajouter un compte Codex »
     - Connectez-vous a votre compte ChatGPT dans la fenetre integree

### Utilisation quotidienne

- **Affichage par defaut** - L'icone de la barre des menus affiche le pourcentage d'utilisation
- **Voir les details** - Cliquez sur l'icone de la barre des menus
- **Vue Claude + Codex** - Si des comptes Claude et Codex sont configures, la fenetre de detail affiche les deux fournisseurs cote a cote
- **Actualisation manuelle** - Cliquez sur le bouton d'actualisation ou utilisez le raccourci ⌘R
- **Changer de compte** - Menu « … » dans la fenetre de detail ou clic droit sur l'icone
- **Raccourcis clavier**
  - ⌘R - Actualiser les donnees
  - ⌘, - Ouvrir les reglages generaux
  - ⌘⇧A - Ouvrir les reglages d'authentification
  - ⌘Q - Quitter l'application

---

## ❓ FAQ

<details>
<summary><b>Q : Que faire si l'application affiche « Session expiree » ?</b></summary>

R : Les Session Keys expirent periodiquement (generalement des semaines a des mois), il faut en obtenir une nouvelle :
1. Ouvrez Reglages → Authentification
2. Cliquez sur « Connexion via le navigateur » (recommande), ou obtenez manuellement une nouvelle Session Key
3. C'est fait, la surveillance reprendra

</details>

<details>
<summary><b>Q : Comment activer le lancement automatique au demarrage ?</b></summary>

R : Deux methodes :

**Methode 1 : Option integree (recommande)**
1. Ouvrez Reglages → General
2. Cochez « Demarrer automatiquement a la connexion »

**Methode 2 : Via les Reglages Systeme**
1. Ouvrez Reglages Systeme → General → Ouverture
2. Cliquez sur « + » pour ajouter Usage4Claude

</details>

<details>
<summary><b>Q : Combien de ressources systeme sont utilisees ?</b></summary>

R : Tres leger :
- Utilisation CPU : < 0,1 % (au repos)
- Memoire : ~20 Mo
- Reseau : Seulement 1 requete par minute

</details>

<details>
<summary><b>Q : Quelles versions de macOS sont supportees ?</b></summary>

R : Necessite macOS 13.0 (Ventura) ou ulterieur. Supporte les puces Intel et Apple Silicon (M1/M2/M3).

</details>

<details>
<summary><b>Q : Pourquoi l'application demande-t-elle l'acces au trousseau ?</b></summary>

R :
- Le trousseau est le gestionnaire de mots de passe au niveau systeme de macOS
- Votre Session Key est chiffree dans le trousseau
- L'Organization ID est stocke dans la configuration locale (identifiant non sensible)
- C'est la methode de stockage securise recommandee par Apple
- Seule cette application peut acceder aux informations, les autres applications ne peuvent pas les consulter

</details>

<details>
<summary><b>Q : Mes donnees sont-elles en securite ? Comment la confidentialite est-elle protegee ?</b></summary>

**Entierement securise !**

**Stockage des donnees :**
- Toutes les donnees sont stockees **uniquement** sur votre Mac local
- Aucune collecte, aucun suivi, aucune statistique
- Aucune requete reseau en dehors des appels aux API Claude et Codex
- Aucun service tiers utilise

**Securite de l'authentification :**
- Session Key chiffree via le trousseau macOS (chiffrement au niveau systeme)
- Le trousseau utilise le chiffrement AES-256 + protection materielle (T2 / Secure Enclave)
- Seule cette application peut acceder a vos identifiants
- Vous pouvez revoquer l'acces a tout moment via l'application « Trousseaux d'acces »

**Transparence du code :**
- 100 % open source
- Pas d'obfuscation ni de fonctionnalites cachees
- La communaute peut auditer et verifier

</details>

<details>
<summary><b>Q : L'application fonctionne-t-elle avec Claude Code / l'app de bureau / l'app mobile ?</b></summary>

R : **Oui, elle fonctionne avec toutes les plateformes Claude !**

Puisque tous les produits Claude (Web, Claude Code, Application de bureau, Application mobile, Cowork) partagent le meme quota d'utilisation, Usage4Claude surveille votre utilisation combinee sur toutes les plateformes.

</details>

---

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](../LICENSE) pour plus de details

---

## 📞 Contact

- **Issues** : [Soumettre un probleme ou une suggestion](https://github.com/f-is-h/Usage4Claude/issues)
- **Discussions** : [Rejoindre les discussions](https://github.com/f-is-h/Usage4Claude/discussions)
- **GitHub** : [@f-is-h](https://github.com/f-is-h)

---

## ⚖️ Avertissement

Ce projet est un outil tiers independant sans affiliation officielle avec Anthropic, Claude AI, OpenAI ou Codex. Veuillez respecter les conditions d'utilisation des services concernes lors de l'utilisation de ce logiciel.

---

<div align="center">

**Si ce projet vous aide, n'hesitez pas a lui donner une ⭐ Star !**

Fait avec ❤️ par [f-is-h](https://github.com/f-is-h)

[⬆ Retour en haut](#usage4claude)

</div>
