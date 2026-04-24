# Étude de besoin — Application iOS de signature de présence

**Projet episign** — Solution native iOS pour la gestion des émargements
Projet pédagogique Master 1 — Cours de développement iOS — SwiftUI
Durée : 3 jours

---

## 1. Contexte et problématique

### 1.1 Contexte

La gestion de l'émargement constitue une obligation légale et administrative centrale pour tout organisme de formation. Dans le cadre des formations initiales et professionnelles, les feuilles de présence doivent être signées par les apprenants pour chaque demi-journée de formation (matin et après-midi), et conservées pendant plusieurs années à des fins de contrôle (OPCO, certifications Qualiopi, contrôles URSSAF).

Aujourd'hui, de nombreux établissements utilisent des solutions web de type Edusign reposant sur un principe simple : l'apprenant scanne un QR code projeté par le formateur, remplit une signature via une fenêtre web, et valide. Cette approche fonctionne mais présente des limites opérationnelles et des vulnérabilités qui justifient la réflexion autour d'une solution native.

### 1.2 Problématique identifiée

Les solutions web actuelles souffrent de trois catégories de limites qui motivent ce projet :

- **Faiblesses anti-fraude** : un QR code affiché est facilement photographiable et partageable à distance. Un apprenant absent peut signer depuis son domicile si un camarade lui transmet le code. Aucun lien fort n'existe entre la signature et la présence physique effective dans les locaux.
- **Expérience utilisateur dégradée** : la navigation web sur mobile pour signer, puis la fermeture de l'onglet, puis la réouverture l'après-midi, représente une friction inutile. L'apprenant oublie régulièrement la signature de l'après-midi, ce qui génère des relances manuelles et des régularisations administratives.
- **Absence de valeur ajoutée native** : aucune exploitation des capacités modernes des smartphones (notifications contextuelles, widgets, authentification biométrique, signature stylet précise, géolocalisation) pour fluidifier l'expérience et renforcer la traçabilité.

### 1.3 Opportunité et angle retenu

Le projet episign remplace le QR code d'Edusign par une **preuve de présence acoustique** : le poste du formateur émet en continu un signal ultrasonique (17–20 kHz, inaudible) qui encode le code TOTP de la session. L'iPhone de l'apprenant écoute la salle, décode le signal via la bibliothèque **ggwave**, et transmet la signature au backend qui valide le TOTP serveur-side.

L'ultrason est un canal à portée courte qui ne traverse pas les murs : il crée un lien physique fort entre la signature et la présence effective dans la salle, là où un QR code se photographie et se partage. Cet angle répond simultanément aux trois limites ci-dessus.

---

## 2. Objectifs du projet

### 2.1 Objectif principal

Concevoir et développer une application iOS native, en SwiftUI, permettant à un apprenant de signer sa présence aux sessions de formation (matin et après-midi) avec un niveau de traçabilité et de fiabilité supérieur à une solution web classique, et présentable à la direction de l'école comme solution opérationnelle envisageable.

### 2.2 Objectifs secondaires

- Démontrer la maîtrise des spécificités de l'écosystème iOS (SwiftUI, SwiftData, PencilKit, AVAudioEngine, vDSP, Keychain) sur un projet court mais complet.
- Produire une solution dont les choix techniques (TOTP, ultrason, chiffrement, device binding) sont défendables face à une direction non technique.
- Livrer un pitch et une documentation de qualité professionnelle, utilisables comme base de négociation réelle avec l'établissement.
- Exposer les étudiants à un cycle produit complet : analyse de besoin, conception, implémentation, pitch, confrontation au réel.

### 2.3 Critères de succès

| Critère | Description | Mesure |
|---|---|---|
| Fonctionnel | Un apprenant peut signer matin et après-midi, les données remontent au backend. | Démo end-to-end |
| Sécurité | Le code TOTP ne peut être réutilisé hors fenêtre temporelle. Device binding actif. Secret TOTP jamais exposé côté client. | Tests de contournement |
| Native feel | Au moins deux features exploitent des API exclusivement iOS (PencilKit + ultrason + visualiseur temps réel + Live Activity ou Widget). | Grille de notation |
| Présentation | Pitch de 5 minutes convaincant face à un panel simulant la direction. | Vote du panel |

---

## 3. Acteurs et parties prenantes

### 3.1 Utilisateurs finaux

- **L'apprenant** : utilisateur principal de l'application iOS. Il consulte ses sessions, signe matin et après-midi, consulte son historique. C'est l'acteur dont l'expérience doit être optimisée.
- **Le formateur** : ouvre une page web dédiée sur son ordinateur de classe. La page affiche le TOTP courant et l'émet en continu en ultrason via ggwave-wasm. Aucune action par apprenant.
- **L'administration pédagogique** : consulte les émargements, exporte les feuilles de présence au format PDF pour archivage et contrôles externes. Accès via le dashboard Supabase dans le cadre pédagogique ; un tableau de bord web dédié est hors scope MVP.

### 3.2 Contraintes liées aux utilisateurs

L'étude préalable a révélé qu'une partie des apprenants ne dispose pas d'un iPhone personnel. Cette contrainte est prise en compte dans l'architecture :

- Le **site formateur est une page web**, pas une app iOS : n'importe quel laptop de classe fait l'affaire pour émettre le signal.
- L'app étudiante propose toujours un **fallback de saisie manuelle du TOTP** (6 chiffres au clavier) en parallèle du canal ultrason, pour les cas où le micro est indisponible, l'environnement trop bruyant, ou la démo réalisée sur simulateur Xcode (qui ne traite pas l'audio de manière fiable à 19 kHz).

---

## 4. Besoins fonctionnels

### 4.1 Parcours apprenant

| # | Étape | Détail |
|---|---|---|
| 1 | Authentification | Connexion via email + magic link Supabase Auth. Le device est lié au compte au premier lancement (device_id UUID persisté, token JWT stocké dans le Keychain). |
| 2 | Consultation | Liste des sessions du jour et de la semaine. Statut visible : non signée, signée matin, signée après-midi, complète. Cache SwiftData pour le mode hors-ligne. |
| 3 | Écoute ultrason | Sur l'écran de signature, l'app ouvre le micro et écoute le signal du formateur. Un visualiseur spectral (Canvas SwiftUI + vDSP FFT) montre la bande 17–21 kHz en temps réel. |
| 4 | Décodage du code | ggwave décode le payload ultrason, extrait le TOTP à 6 chiffres, pré-remplit automatiquement le champ. Fallback manuel toujours disponible. |
| 5 | Signature | Capture de la signature manuscrite via PencilKit (support Apple Pencil, pression, inclinaison). Validation minimum de tracé requise. |
| 6 | Transmission | Appel de l'Edge Function `sign` : image signature PNG base64, TOTP, slot, device_id, timestamp, géoloc optionnelle, hash SHA-256. |
| 7 | Confirmation | Feedback visuel et haptique. La session passe au statut signé. Historique consultable à tout moment. Si offline, la signature est mise en file et retentée à la reconnexion. |

### 4.2 Parcours formateur

Le formateur ouvre une page web légère sur son ordinateur de classe. La page :

- Récupère le secret TOTP de la session en cours (authentification minimale, secret jamais affiché en clair).
- Génère en continu le TOTP courant (RFC 6238, fenêtre 30 secondes).
- Émet le TOTP en boucle via ggwave-wasm dans la bande 17–20 kHz, avec répétition toutes les quelques secondes.
- Affiche en grand le TOTP courant comme filet de sécurité pour la saisie manuelle par les apprenants.

Aucune action apprenant par apprenant. Le formateur laisse simplement la page ouverte pendant la demi-journée.

### 4.3 Parcours administration

Dans le cadre pédagogique, l'administration utilise le **dashboard Supabase** pour :

- Visualiser en temps réel les signatures remontées par session (table `signatures`).
- Télécharger les images de signature depuis Supabase Storage.
- Invalider manuellement une signature litigieuse (flag `invalidated_at` + motif).

Un tableau de bord web dédié avec export PDF est identifié comme évolution post-MVP, hors scope des 3 jours.

---

## 5. Besoins techniques et architecture

### 5.1 Stack technique retenue

| Composant | Choix technique |
|---|---|
| Application iOS | SwiftUI (iOS 17+), SwiftData pour la persistance locale, PencilKit pour la signature, AVAudioEngine + Accelerate/vDSP pour l'audio. |
| Décodage ultrason iOS | ggwave en binding C, wrappé dans un SwiftPM local exposant un actor `GGWave`. |
| Backend | Supabase : Auth (magic link), Postgres managé, Storage pour les PNG, Edge Function Deno/TypeScript pour la validation TOTP. |
| Site formateur | HTML + JavaScript + ggwave-wasm + Web Audio API. Génération TOTP côté client via `otplib` ou `otpauth`. |
| Protocole auth | TOTP conforme RFC 6238 (HMAC-SHA1, fenêtre 30 secondes, secret par session). Validation **exclusivement côté Edge Function**. |
| Stockage secrets iOS | Keychain pour le JWT Supabase. Device ID en SwiftData. |
| Outils | Xcode 15+, Swift 5.9+, Deno pour les Edge Functions, simulateur iOS 17+ accepté pour démo avec fallback manuel. |

### 5.2 Architecture fonctionnelle

Le système repose sur trois composants, Supabase étant la source de vérité unique :

- **Application iOS apprenant** : consomme PostgREST pour la lecture des sessions (protégée par RLS), appelle l'Edge Function `sign` pour soumettre les signatures.
- **Supabase** : Auth, Postgres + RLS, Storage, Edge Functions. La seule partie qui manipule le secret TOTP et valide les codes.
- **Page web formateur** : lit le secret TOTP de la session en cours, génère le code courant, l'émet en ultrason en boucle.

### 5.3 Modèle de données (Postgres/Supabase)

| Table | Champs clés | Rôle |
|---|---|---|
| `students` | id (UUID, = auth.uid()), email, name, device_id | Référentiel des apprenants. Lié à `auth.users`. |
| `teachers` | id, name, totp_secret | Secret TOTP unique par formateur. **RLS ferme la lecture aux clients**, accessible uniquement par l'Edge Function avec la `service_role_key`. |
| `courses` | id, title, date, slot, room, teacher_id, starts_at, ends_at | Planning. `starts_at`/`ends_at` définissent la fenêtre de signature. |
| `signatures` | id, student_id, course_id, slot, image_path, timestamp, device_id, latitude, longitude, sha256, invalidated_at, invalidation_reason | Trace horodatée. `image_path` pointe vers Supabase Storage. |

**Policies RLS principales** :

- `students` : SELECT/UPDATE où `id = auth.uid()`.
- `courses` : SELECT ouvert aux étudiants authentifiés (planning public pour eux).
- `signatures` : SELECT où `student_id = auth.uid()`. INSERT interdit depuis le client — **uniquement via l'Edge Function**.
- `teachers` : aucune policy client. Accessible uniquement en service_role.

### 5.4 API exposée

**Côté PostgREST (lecture directe, authentifiée JWT)** :

- `GET /rest/v1/courses` : sessions de l'apprenant.
- `GET /rest/v1/signatures?student_id=eq.<uuid>` : historique des signatures.

**Côté Edge Functions** :

- `POST /functions/v1/sign` : reçoit `{ session_id, totp, signature_png_base64, slot, device_id, timestamp, latitude?, longitude?, sha256 }`. La fonction :
  1. Vérifie le JWT et récupère l'utilisateur.
  2. Charge la session et le secret TOTP associé.
  3. Valide le TOTP (fenêtre temporelle, unicité par étudiant/session/slot).
  4. Vérifie la fenêtre horaire du cours et le device binding.
  5. Upload la PNG dans Storage.
  6. Insert dans `signatures` avec la `service_role_key`.
  7. Renvoie `{ ok: true, signature_id }` ou une erreur typée.

**Côté Supabase Auth** : magic link via `supabase.auth.signInWithOtp({ email })`.

---

## 6. Sécurité et conformité

### 6.1 Couches de sécurité anti-fraude

Le système combine plusieurs couches de défense pour garantir qu'une signature correspond à une présence réelle :

- **Canal ultrason à portée courte** : le signal ne traverse pas les murs, ne peut être partagé à distance comme un QR. Une capture d'écran est inutilisable (le son ne se capture pas).
- **Code TOTP rotatif** : le code change toutes les 30 secondes. Un enregistrement audio rejoué hors fenêtre est refusé par l'Edge Function.
- **Fenêtre temporelle serveur** : une signature n'est acceptée que dans les plages horaires définies pour chaque session (`starts_at`/`ends_at`).
- **Unicité par étudiant/session/slot** : une contrainte unique `(student_id, course_id, slot)` empêche la réutilisation d'un TOTP capturé pour re-signer.
- **Device binding** : un apprenant ne peut signer que depuis le device enregistré au premier lancement. Tout changement nécessite une réinitialisation administrative.
- **Rate limiting** : limitation côté Edge Function des tentatives par compte pour prévenir le brute-force TOTP.
- **Secret TOTP isolé** : jamais exposé côté client. RLS ferme l'accès à la table `teachers`. Seule l'Edge Function avec la `service_role_key` y accède.
- **Hash d'intégrité** : chaque image de signature est associée à son empreinte SHA-256 pour prouver l'absence de modification a posteriori.
- **Géofencing (optionnel)** : vérification serveur de la cohérence géographique au moment de la signature.

### 6.2 Conformité RGPD

Le traitement des données respecte le cadre légal applicable aux organismes de formation :

- **Base légale** : exécution du contrat de formation et obligation légale d'assiduité.
- **Consentement explicite** recueilli lors de l'onboarding pour les données facultatives (géolocalisation, accès micro).
- **Justification utilisateur claire** dans l'Info.plist pour `NSMicrophoneUsageDescription` et `NSLocationWhenInUseUsageDescription`.
- **Durée de conservation** alignée sur les obligations des organismes de formation (5 ans).
- **Droits d'accès, rectification, suppression** accessibles via demande administration.
- Une signature manuscrite n'est pas une donnée biométrique au sens du RGPD : devoir général de sécurité mais pas d'obligation renforcée spécifique.
- **Hébergement** : Supabase (UE disponible) dans le cadre pédagogique ; à questionner pour un déploiement réel.

---

## 7. Livrables attendus

### 7.1 Livrables techniques

- Code source de l'application iOS sur dépôt Git, avec README d'installation et de lancement.
- Code source du site formateur (page HTML + JS + ggwave-wasm).
- Code source des Edge Functions Supabase.
- Script SQL de création du schéma + policies RLS + données de seed pour la démo.
- Démonstration fonctionnelle end-to-end sur device iPhone physique (fallback simulateur avec saisie manuelle).

### 7.2 Livrables documentaires

- Fiche de décisions produit (1 page) : choix effectués, angle produit retenu, arbitrages.
- Schéma d'architecture (1 page) — voir `architecture.md`.
- Pitch de présentation (slides, 5 minutes).
- Démonstration vidéo courte (2 minutes, facultatif mais valorisé).

### 7.3 Pitch final

Chaque équipe présente son travail devant un panel jouant le rôle de la direction de l'école (enseignant + invités). Format : 5 minutes de pitch incluant démo live, suivies de 3 minutes de questions-réponses. Le panel évalue la clarté du pitch, la pertinence des choix techniques, la gestion des questions sur la sécurité et le RGPD, et la faisabilité opérationnelle.

---

## 8. Planning et organisation

| Jour | Phase | Contenu |
|---|---|---|
| Jour 1 | Fondations | Briefing projet, formation SwiftUI intensive sans assistance IA, mise en place du MVP : setup projet Supabase (schéma + RLS + seed), auth magic link, liste sessions, canvas signature, Edge Function `sign` sans TOTP. Page web formateur affichant un TOTP fixe. |
| Jour 2 | Approfondissement | Intégration ggwave iOS et web, validation TOTP côté Edge Function, visualiseur audio spectral, deux features iOS natives au choix (Widget sessions du jour, Live Activity signature en cours, App Intent, géofencing). |
| Jour 3 | Finition & pitch | Polish UX, mode offline avec retry, device binding, gestion erreurs, préparation pitch et supports, passage devant le panel l'après-midi, remise des livrables. |

---

## 9. Risques identifiés et parades

| Risque | Impact | Parade |
|---|---|---|
| Hétérogénéité du matériel (étudiants sans iPhone) | Blocage potentiel sur la démonstration | Site formateur web (pas iOS), fallback manuel TOTP toujours présent, équipes mixées pour répartir les iPhones. |
| Ultrason non détecté en démo (bruit ambiant, haut-parleur faible) | Pitch cassé | Fallback manuel visible et promu dans l'UI, pas relégué. Le visualiseur confirme visuellement que le micro écoute. |
| Dérive de scope | MVP non livré | MVP cadré fin de jour 1, Supabase retire tout le travail backend, focus préservé sur iOS et ultrason. |
| Dépendance excessive à l'IA générative | Code non maîtrisé, incapacité à répondre au panel | Interdiction de l'IA sur la formation SwiftUI du jour 1. Questions techniques au pitch final. |
| Problèmes d'environnement Xcode ou Deno | Perte de temps initiale | Prérequis d'installation communiqués en amont. Buffer jour 1 matin. |
| Wi-Fi indisponible le jour du pitch | Démo impossible | Mode offline : session cachée en SwiftData, signature stockée localement, retry à la reconnexion. Démontrable en avion mode. |
| Secret TOTP fuité côté client | Compromission complète du système | Secret jamais renvoyé par PostgREST (RLS + pas de policy SELECT), page web formateur authentifiée, secret injecté côté Edge Function uniquement. |
