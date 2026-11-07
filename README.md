# README

[![Release](https://img.shields.io/docker/v/jcpd/dknr-alexa?sort=semver)](https://img.shields.io/docker/v/jcpd/dknr-alexa?sort=semver)
[![Pull](https://img.shields.io/docker/pulls/jcpd/dknr-alexa)](https://img.shields.io/docker/pulls/jcpd/dknr-alexa)
[![Issue](https://img.shields.io/github/issues/jcdenis/dknr-alexa)](https://img.shields.io/github/issues/jcdenis/dknr-alexa)
[![License](https://img.shields.io/github/license/jcdenis/dknr-alexa)](https://github.com/JcDenis/dknr-alexa/blob/master/LICENSE)


## A propos

**dknr-alexa** partage vers et depuis Amazon Alexa les entités publiées sur MQTT par les autres projets DKNR (Zigbee, Z-Wave, RFXCom, Daikin...). Les appareils Alexa sont choisis et nommés depuis le tableau de bord, sans configurer un nœud Node-RED par appareil. Le lien avec Alexa passe par [Virtual Smart Home](https://github.com/csuermann/node-red-contrib-virtual-smart-home) (VSH) : aucune connexion entrante depuis internet n'est nécessaire.


## Fonctionnalités

- **Toutes les sources DKNR** : les entités sont lues depuis la discovery DKNR, sans dépendre de dknr-domotic.
- **Types d'appareils** : interrupteur (lumière, prise, VMC, climatisation...), ouverture (porte, fenêtre, baie), mouvement, température, volet.
- **Appareils groupés** : un appareil Alexa peut piloter plusieurs entités (ex : « guirlande » = deux prises).
- **Pilotage vocal** : « Alexa, allume la lumière de l'atelier », « Alexa, ouvre le volet de la véranda », routines Alexa sur les ouvertures, mouvements et températures.
- **Connexion à Amazon depuis le tableau de bord**, sans passer par l'éditeur Node-RED.
- **Import d'un ancien flow VSH** pour reprendre noms et types des appareils.
- **Sauvegarde et restauration** de la configuration.


## Matériel requis

* un serveur MQTT, partagé avec les autres projets DKNR.
* au moins un projet DKNR publiant des entités (ex : [DKNR Zigbee](https://github.com/JcDenis/dknr-zigbee)).
* un compte Amazon avec des appareils Echo et un abonnement [Virtual Smart Home](https://github.com/csuermann/node-red-contrib-virtual-smart-home) (PRO : 200 appareils).
* une machine exécutant le logiciel docker, avec un accès sortant à internet.


## Installation

Des images Docker prêtes à l'emploi sont disponibles.
Utilisez le fichier docker-compose.yaml à la racine du dépôt en fournissant les variables d'environnement suivantes :

* **DKNR_USERNAME** : login de l'interface node-red.
* **DKNR_PASSWORD** : mot de passe de l'interface node-red.
* **DKNR_SECRET**   : un mot secret pour encrypter les credits, dont les certificats de la connexion Amazon. Le changer impose de refaire la connexion à Amazon.

Le tableau de bord DKNR est disponible sur `http://<ip du serveur docker>/` et l'éditeur Node-RED sur `http://<ip du serveur docker>/admin`.


## Configuration

### MQTT

Dans la page **Configurer** : **adresse IP**, **port**, **utilisateur** et **mot de passe** du serveur MQTT, le même que celui des autres projets DKNR, et **topic** racine des topics DKNR (`dknr` par défaut).

La page **Connexion** liste les sources DKNR reçues, avec leurs nombres d'appareils et d'entités.

### Connexion à Amazon

Dans la page **Connexion**, cliquez sur **Connecter à Amazon** : un code s'affiche. Ouvrez l'adresse indiquée (amazon.com/code) sur un téléphone ou un ordinateur connecté au compte Amazon des Echo et saisissez le code. La connexion est établie dès la validation.

Activez ensuite la skill **Virtual Smart Home** dans l'application Alexa (une seule fois), puis demandez « Alexa, recherche des appareils » si les appareils n'apparaissent pas.

Une même connexion ne doit pas tourner sur deux installations à la fois : arrêtez l'ancien flow VSH avant de connecter dknr-alexa.

Le bouton **Reconnecter à Amazon** refait la connexion, par exemple si VSH la refuse (connexion hors ligne plus de 30 jours, mise à jour exigée par VSH).

### Appareils

Dans la page **Appareils** :

1. **Nouvel appareil**, ou cliquez sur un appareil de la liste : la fenêtre de modification s'ouvre.
2. Choisissez le **type**, puis une **source** et ajoutez une ou plusieurs **entités** (seules les entités compatibles avec le type sont proposées, avec leur identifiant entre parenthèses). Cliquez sur une entité pour la retirer.
3. Saisissez le **nom Alexa** (celui utilisé à la voix) et la **pièce**, puis **Enregistrer** : la fenêtre se ferme.

La pièce sert à classer les appareils : rangez-les aussi dans la même pièce de l'application Alexa (VSH ne transmet pas les pièces).

Les entités d'un appareil sont prises en compte dès l'enregistrement. Un nouvel appareil, un changement de nom ou de type, une activation ou une suppression sont envoyés à Alexa avec le bouton **Appliquer les modifications** de la page **Connexion** (la connexion à Amazon redémarre). Un appareil supprimé ou désactivé disparaît d'Alexa.

### Importer un ancien flow VSH

Dans la page **Configurer**, importez le fichier d'export du flow contenant les anciens nœuds VSH. Les noms et types sont repris, la pièce est devinée depuis le nom (« lumière de la véranda » : « véranda ») et les anciens topics sont traduits en entités DKNR :

* Z-Wave : `zwave_5_37_0_currentValue` : `zwave/5/37_0_currentValue`.
* Zigbee : `zigbee_Garage_Prise_state` : appareil Zigbee nommé `Garage_Prise`, entité `state` (ou l'entité habituelle du type, ex : `contact` pour une ouverture).
* RFXCom : `rfxcom_0x5C02_temperature` : `rfxcom/5C02/temperature`, `rfxcom_0x00A1B2C3_1_command` : `rfxcom/00A1B2C3/command1`.
* Appareils groupés : les topics trouvés dans la fonction qui utilisait l'ancien topic.
* Scène : interrupteur sur les entités `state` des unités Daikin.

Le rapport d'import indique pour chaque appareil le résultat. Les appareils dont une entité est introuvable sont importés inactifs, à compléter dans la page **Appareils**. Les appareils sont nouveaux pour Alexa : supprimez les anciens dans l'application Alexa et refaites pièces, groupes et routines.


## Fonctionnement

### DKNR vers Alexa

L'état d'un appareil Alexa vient de sa première entité (`dknr/get/<source>/<parent>/<entité>`) :

| Type | Entité DKNR | Etat Alexa |
|---|---|---|
| Interrupteur | binaire, ou nombre (variateur) | allumé si `1` ou supérieur à 0 |
| Ouverture | binaire | ouvert si `1` (`0` pour l'unité `rb`) |
| Mouvement | binaire | mouvement si `1` |
| Température | nombre | °C, au dixième |
| Volet | nombre (0-99 ou 0-100) ou binaire | pourcentage d'ouverture |

Pour limiter le trafic (conditions d'utilisation de VSH), une température n'est envoyée que si elle change d'au moins 0,5 °C ou toutes les 15 minutes au plus, les autres états seulement s'ils changent.

### Alexa vers DKNR

Un ordre Alexa est publié sur `dknr/set/<source>/<parent>/<entité>` pour chaque entité de l'appareil :

* Interrupteur : `1` / `0` pour une entité binaire. Pour un variateur (nombre), « allume » envoie `99` (sauf s'il est déjà allumé, son niveau est conservé) et « éteins » `0`.
* Volet : le pourcentage demandé, `99` au plus (ouverture complète Z-Wave).

### Node-RED

Les nœuds VSH sont générés dans l'onglet `alexa - devices` par l'API d'administration de Node-RED, à l'application des modifications et au démarrage. Cet onglet n'est pas à modifier ni à commiter : il est reconstruit depuis la configuration. L'identifiant d'un appareil Alexa est celui de son nœud, il ne change jamais.


## A faire

* Pont Matter alimenté par la même configuration, quand les Echo seront compatibles.
* Annonces vocales depuis la domotique.


## Contribuer

Ce projet est **open-source**, vous pouvez participer en créant des [tickets](https://github.com/JcDenis/dknr-alexa/issues) ou en proposant de [requêtes](https://github.com/JcDenis/dknr-alexa/pulls) sur le dépôt github du projet.


## Voir aussi

- [DKNR Domotic](https://github.com/JcDenis/dknr-domotic)
- [DKNR Zigbee](https://github.com/JcDenis/dknr-zigbee)
- [DKNR Z-Wave](https://github.com/JcDenis/dknr-zwave)
- [DKNR RFXCom](https://github.com/JcDenis/dknr-rfxcom)
- [DKNR Daikin](https://github.com/JcDenis/dknr-daikin)
- [Virtual Smart Home](https://github.com/csuermann/node-red-contrib-virtual-smart-home)
