# Conception de dknr-alexa

Document de conception rédigé avant le développement (novembre 2026). Il réunit les décisions prises et les éléments techniques déjà vérifiés, pour démarrer la construction sans rien perdre.


## Objectif

Partager vers et depuis Amazon Alexa les entités gérées par les projets DKNR, en choisissant depuis une interface ce qui est partagé, au lieu de configurer un nœud Node-RED par appareil.


## Décisions

* **Passerelle Alexa** : [Virtual Smart Home](https://github.com/csuermann/node-red-contrib-virtual-smart-home) (VSH), avec l'abonnement PRO (200 appareils, état lisible par Alexa).
  * Pas de Matter : les Echo de la maison sont anciens et ne sont pas contrôleurs Matter. À reconsidérer plus tard (voir *Evolutions*).
  * Pas de skill Alexa personnelle : pas d'accès HTTPS entrant vers le docker, et on limite ce qui vient de l'extérieur.
  * Pas d'émulation Hue : limitée aux lumières.
* **Projet DKNR autonome** : même structure que les autres dépôts dknr (Node-RED en mode projet, docker, workflows). Il ne dépend pas de dknr-domotic : il lit et pilote les entités sur MQTT, toutes sources confondues.
* **Nom et pièce Alexa saisis dans dknr-alexa** (et non repris de dknr-domotic, qui ne publie pas pièces et éléments).
* **Nouvelle connexion VSH** (option « repartir proprement ») : les appareils seront nouveaux pour Alexa. Les anciens appareils seront supprimés dans l'application Alexa, pièces, groupes et routines refaits.
* **Types d'appareils** :

  | Usage | Template VSH | État VSH |
  |---|---|---|
  | lumière, prise, VMC, climatisation (interrupteur Daikin `daikin/<id>/state`), enceintes... | `SWITCH` | `powerState`: `ON` / `OFF` |
  | ouverture (porte, fenêtre, baie) | `CONTACT_SENSOR` | `detectionState`: `DETECTED` / `NOT_DETECTED` |
  | mouvement | `MOTION_SENSOR` | `detectionState`: `DETECTED` / `NOT_DETECTED` |
  | température | `TEMPERATURE_SENSOR` | `temperature` (nombre), `scale`: `CELSIUS` |
  | volet | `BLINDS` | `percentage` (0-100) |

  Pas d'humidité (VSH n'a pas de capteur d'humidité), pas de scène (la clim passe par l'interrupteur Daikin).
* **Variateurs** : un ordre Alexa « allume » envoie `99` sur `dknr/set` pour une entité en `%`, `1` pour un binaire. Les scènes de dknr-domotic corrigent ensuite le niveau (latence et léger scintillement acceptés).
* **Appareils groupés** : un appareil Alexa peut regrouper plusieurs entités DKNR (ex : « lumière leds » = leds gauche + leds droite). Un ordre est envoyé à toutes, l'état vient de la première.


## Fonctionnement prévu

### Entités DKNR

* Catalogue construit depuis `dknr/discovery/<source>/<parent>/<entité>` (nom, groupe, type, unité, options) et valeurs depuis `dknr/get/<source>/<parent>/<entité>`.
* Commandes publiées sur `dknr/set/<source>/<parent>/<entité>`.
* Rappels du format DKNR : identifiant `source/parent/id`, binaires `1` / `0`, listes par clé d'option, `rb` = binaire inversé (pour les ouvertures, `1` = ouvert sauf unité `rb`).

### Page Alexa (tableau de bord)

* Liste des appareils Alexa : nom, pièce, type, entités DKNR associées (une ou plusieurs), actif ou non.
* Choix des entités par source (sélecteur de source, comme la page Entités de dknr-domotic, la liste complète est trop longue).
* État de la connexion VSH et bouton de connexion à Amazon.
* Sauvegarde et restauration de la configuration, comme dans les autres projets.

### Génération des nœuds VSH

* À l'enregistrement, un onglet dédié (ex : `alexa - devices`) est reconstruit par l'API d'administration de Node-RED ([PUT /flow/:id](https://nodered.org/docs/api/admin/methods/put/flow), [POST /flow](https://nodered.org/docs/api/admin/methods/post/flow/)) avec :
  * le nœud de configuration `vsh-connection` (avec ses identifiants, voir *Connexion*),
  * un nœud `vsh-virtual-device` par appareil Alexa.
* Les nœuds générés ne contiennent que de la configuration. Toute la logique reste dans les flows versionnés.
* **Identifiants de nœuds stables** (calculés à partir de l'identifiant de l'appareil dans dknr-alexa) : VSH identifie un appareil par `'vshd-' + id du nœud` sous la connexion (`thingId`). Changer l'identifiant d'un nœud crée un nouvel appareil dans Alexa.
* Comme dans le flow VSH actuel : **une seule entrée** diffuse les états à tous les nœuds, chaque nœud a `filterTopic: true` et `topic` = identifiant de l'appareil, et toutes les sorties vont vers un traitement commun.
* Champs d'un nœud `vsh-virtual-device` : `name` (nom Alexa), `topic`, `template`, `connection`, `retrievable: true`, `passthrough: false`, `diff: false`, `filter: false`, `filterTopic: true`, `metadata: '{}'`.
* L'onglet est régénéré au démarrage depuis la configuration (en mode projet, il modifie le `flows.json` du projet sans être commité).
* L'API d'administration demande un jeton (`POST /auth/token` avec l'utilisateur de l'éditeur, `DKNR_USERNAME` / `DKNR_PASSWORD`), `httpAdminRoot` est `/admin`.

### Traduction

* **DKNR vers Alexa** : valeur `dknr/get` vers état VSH (tableau des types ci-dessus), envoyée dans l'entrée commune avec `msg.topic` = identifiant de l'appareil.
  * Les conditions d'utilisation de VSH demandent de limiter le trafic, surtout pour les capteurs : température seulement si elle change d'au moins 0,5 °C ou au plus toutes les 15 min (à ajuster), états binaires seulement sur changement.
* **Alexa vers DKNR** : la sortie d'un nœud VSH donne `msg.payload` avec l'état demandé (`powerState`, `percentage`...), `directive`, `name`, `source: 'alexa'`. On publie sur `dknr/set` de chaque entité de l'appareil.

### Connexion à Amazon (sans l'éditeur Node-RED)

Le code de VSH (`connection.html`) fait l'appairage côté navigateur de l'éditeur. Tout se reproduit côté serveur (appels HTTP) et s'affiche sur la page Alexa :

1. Vérification de version : `GET <backendUrl>/check_version?version=<version VSH installée>`.
2. Code d'appairage : `POST https://api.amazon.com/auth/o2/create/codepair` avec `response_type=device_code`, `client_id=<lwaClientId>`, `scope=profile`. Réponse : `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval`.
3. La page affiche `user_code` et `verification_uri` (amazon.com/code), l'utilisateur valide depuis son téléphone.
4. Interrogation : `POST https://api.amazon.com/auth/o2/token` avec `grant_type=device_code`, `device_code`, `user_code`, toutes les `interval` secondes jusqu'à la fin de `authorization_pending`. Réponse : `access_token`, `refresh_token`, `expires_in`.
5. Provisionnement : `POST <backendUrl>/provision` avec `{ accessToken, vshVersion }`. Réponse : `vshJwt`, `email`, `server`, `port`, `cert`, `privateKey`, `caCert`, `thingId`.
6. Création du nœud `vsh-connection` avec ces identifiants dans `credentials` (champs : `vshJwt`, `refreshToken`, `accessToken`, `email`, `cert`, `thingId`, `caCert`, `server`, `privateKey`) et `name` = email, `port`, `backendUrl`, `lwaClientId`, `accessTokenExpiry`, `debug: false`. Les identifiants sont chiffrés par Node-RED (`credentialSecret` = `DKNR_SECRET`), **jamais dans le dépôt**.

Valeurs par défaut (settings de VSH) : `backendUrl` = `https://kfd5m4a21f.execute-api.eu-west-1.amazonaws.com/dev`, `lwaClientId` = `amzn1.application-oa2-client.3f1bb07133854b078261ad43f2484c18`.

Avec `vshJwt` (VSH > 3.0), plus besoin de rafraîchir le jeton Amazon. Revalidation nécessaire si le certificat est révoqué (connexion hors ligne plus de 30 jours) ou si VSH l'exige lors d'une mise à jour : même bouton sur la page. Autres appels utiles du backend avec `Authorization: Bearer <vshJwt>` : `GET /plan` (abonnement), `GET /devices` (appareils connus).

Une même connexion ne doit pas tourner sur deux installations à la fois : arrêter l'ancien flow VSH avant la bascule.


## Migration depuis l'ancienne domotique

Migration faite en novembre 2026 avec un import temporaire (retiré depuis), la configuration est conservée par la sauvegarde de la page Configurer.

L'ancien flow VSH comptait 85 appareils (29 `SWITCH`, 26 `CONTACT_SENSOR`, 18 `TEMPERATURE_SENSOR`, 9 `MOTION_SENSOR`, 2 `BLINDS`, 1 `SCENE`). Son export n'est pas dans le dépôt (noms privés), il faudra le fournir à nouveau. Correspondance des anciens topics vers les identifiants DKNR :

* Z-Wave : `zwave_14_37_1_currentValue` → `zwave/14/37_1_currentValue`.
* Zigbee : `zigbee_Couloir_Prise_state` → `zigbee/<adresse IEEE>/state`, en retrouvant l'appareil par son ancien nom (`Couloir_Prise`) dans les parents de dknr-domotic.
* RFXCom : même principe, par le nom du parent.
* La scène `scene/clim` est remplacée par un interrupteur sur l'entité Daikin `state`.
* L'appareil groupé « lumière leds » (`parents_leds`) devient un appareil avec deux entités Zigbee (leds gauche et droite).

Seuls les noms, types et pièces sont repris, sur une nouvelle connexion.


## Structure attendue du dépôt

Comme les autres dépôts dknr (voir dknr-zigbee) :

* `Dockerfile` (image `nodered/node-red`, clone du dépôt dans `/data/projects/dknr-alexa`), `docker-entrypoint.sh`, `docker-compose.yaml`, `data/settings.js` (`httpAdminRoot: "/admin"`, projets activés).
* `package.json` avec `@flowfuse/node-red-dashboard` et `node-red-contrib-virtual-smart-home`, `flows.json`.
* Pages : configuration MQTT (hôte, port, utilisateur, mot de passe, topic `dknr`), Alexa, réseau / état.
* `.github/workflows` : `release.yaml`, `release_dev.yaml`, `clean_repository.yml`, `update_docker_readme.yml`, `dependabot.yml` (secrets `DOCKER_USERNAME` / `DOCKER_TOKEN` déjà créés).
* `README.md` dans le style des autres projets.


## Réalisation

Première version (novembre 2026), testée localement (Node-RED 5.0.9 en mode projet, VSH 4.5.2, serveur MQTT et sources DKNR simulés, serveurs Amazon et VSH simulés pour l'appairage). Écarts et précisions par rapport à ce qui précède :

* **Application des modifications par un bouton** (page Connexion) et non à chaque enregistrement : régénérer l'onglet redémarre la connexion Amazon, à éviter 85 fois pendant la mise en place. Seuls les ajouts, suppressions, changements de nom, de type ou d'activation le demandent, les entités d'un appareil sont prises en compte dès l'enregistrement. L'onglet n'est pas réécrit s'il est déjà à jour (démarrage, bouton sans changement).
* **Identifiant de l'onglet généré** : `POST /flow` ignore l'identifiant fourni et en attribue un nouveau. L'onglet est retrouvé par l'identifiant fixe de son nœud `link in` (`d0a1e8a0000000a1`), les identifiants des nœuds, eux, sont conservés.
* **Identifiants Amazon** : `PUT /flow/:id` sans `credentials` conserve ceux déjà enregistrés (et les fusionne s'ils sont fournis), l'appairage envoie donc les 9 champs. Ils survivent aussi à un `flows.json` sans l'onglet (dépôt fraîchement cloné) : l'onglet recréé au démarrage reprend la connexion. Pour qu'ils soient bien chiffrés avec `DKNR_SECRET`, `data/.config.projects.json` déclare le projet `dknr-alexa` avec ce secret (remplacé par `docker-entrypoint.sh`), contrairement aux autres dépôts dknr. Changer `DKNR_SECRET` impose de refaire la connexion.
* **Variateurs** : « allume » n'envoie pas `99` à une entité déjà allumée, son niveau est conservé.
* **Volets** : le pourcentage demandé est envoyé avec `99` au plus, une valeur reçue de `99` ou plus vaut `100` pour Alexa.
* **Etat renvoyé à Alexa** : après un ordre Alexa, l'état demandé est mémorisé, l'état DKNR n'est renvoyé que s'il diffère (appareil qui n'a pas obéi). Après une application, tous les états sont renvoyés (VSH ne transmet à Alexa que les changements).
* **Etat de la connexion** : un nœud `status` de l'onglet généré renvoie l'état des nœuds VSH (en ligne, erreur...) vers la page Connexion, l'abonnement est lu par la route d'administration de VSH (`GET /admin/vsh-connection/<id>`).
* **Import** d'un ancien export de flow VSH (pièces devinées depuis les noms, anciens topics traduits en entités DKNR) : utilisé pour la migration puis retiré (novembre 2026), la configuration est conservée par la sauvegarde.
* **Conteneur de développement** : au démarrage, l'onglet n'est pas créé s'il n'existe pas et qu'il n'y a ni appareil actif ni connexion Amazon (rien à générer, le projet reste propre pour le gestionnaire de révision). `DKNR_ALEXA_GENERATE=false` désactive toute génération (démarrage, application, connexion à Amazon).
* **Onglet supprimé depuis l'éditeur** : les appareils (contexte) sont conservés et l'onglet est recréé au démarrage, mais les identifiants de la connexion Amazon sont supprimés avec le nœud de connexion : refaire la connexion.
* **Liens avec l'onglet généré** : aucun lien statique de l'onglet versionné vers l'onglet généré, l'éditeur supprime les liens vers des nœuds absents (conteneur de développement sans onglet) et le commit casse la production. Les états partent par un `link call` dynamique (`msg.target = 'alexa - devices - in'`), l'onglet généré répond par un `link out` en mode retour. Les liens de l'onglet généré vers l'onglet versionné (ordres Alexa, état de la connexion) restent statiques : ils sont dans l'onglet généré et pointent vers des nœuds toujours présents.
* **Etats après redémarrage** : un onglet recréé (mise à jour de l'image, `flows.json` réinitialisé) reçoit un nouvel identifiant d'onglet, et le contexte des nœuds VSH (leur état) est rangé par identifiant d'onglet : il repart vide. Toutes les sources ne publient pas leurs valeurs avec `retain` (RFXCom, Daikin) : la dernière valeur des entités donnant un état est donc conservée dans le contexte persistant (`last`) et renvoyée aux nœuds VSH après la génération ou au démarrage, les valeurs reçues du serveur MQTT la remplacent.
* **Pages** : Appareils (liste, modification et ajout dans une fenêtre de dialogue), Connexion (Amazon, application, sources DKNR), Configurer (MQTT, sauvegarde).
* VSH plante Node-RED si le certificat fourni par le provisionnement n'est pas un PEM valide (constaté avec un faux serveur seulement).


## Evolutions

* Pont Matter (matter.js) alimenté par la même configuration, le jour où les Echo seront compatibles : seule la sortie change.
* Annonces vocales depuis la domotique (alexa-remote2), si besoin.
