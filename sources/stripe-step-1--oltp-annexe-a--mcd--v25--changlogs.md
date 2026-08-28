*STRIPE* PROJECT
===

# 1. Modèle de Données OLTP
## Annexes
### 1.A. Modèle conceptuel de données

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D2 : OLPT - Annexe A / v25 - 2026/10/13.*   

---

#### 1.A.7. Changelogs

#### Changelog v6 → v7

> **Note de version (v7)** - Correction de six cardinalités minimales
> erronées côté entités de référence/parentes (`PAYS`, `DEVISE`,
> `MARCHAND`), qui imposaient à tort l'existence préalable d'au moins une
> occurrence liée pour que l'entité puisse exister. Voir section 7 pour
> le détail du changement et sa justification.

**Problème identifié** : six associations donnaient une cardinalité
minimale de `1` au côté "plusieurs" d'une relation avec une entité de
référence ou parente (`SITUER`, `TARIFER`, `REGLER` côté `DEVISE`/`PAYS` ;
`POSSEDER`, `CATALOGUER`, `RECEVOIR` côté `MARCHAND`). Cela imposait par
exemple qu'un marchand ne puisse exister sans déjà posséder un client - une
contrainte circulaire et non fondée sur une règle de gestion réelle. Elle
contredisait par ailleurs la règle de gestion #1 elle-même ("un pays *peut*
accueillir plusieurs marchands").

**Correction appliquée** : passage de `1,n` à `0,n` sur le côté entité de
référence/parente pour les six associations concernées. La cardinalité
`1,1` côté `MARCHAND` dans `Situer` (un marchand est établi dans un seul
pays) et les cardinalités `1,1` côté entité "fille" (`CLIENT` dans
`Posséder`, `PRODUIT` dans `Cataloguer`, `TRANSACTION` dans `Recevoir`)
restent inchangées : elles étaient correctes.

#### Changelog v7 → v8

> **Note de version (v8)** - Renommage de l'association `Effectuer` en
> `Concerner` pour lever une ambiguïté sémantique (le verbe "effectuer"
> suggérait une initiative volontaire du client, fausse dans le cas d'un
> prélèvement d'abonnement), et ajout d'une règle de gestion explicitant
> comment l'initiative d'une transaction (client ou marchand) se déduit
> du modèle sans attribut redondant. Voir section 8.

**Problème identifié** : l'association `Effectuer` (`CLIENT 0,n -
TRANSACTION 1,1`) suggérait par son verbe une initiative volontaire du
client, ce qui est inexact pour une transaction générée automatiquement par
un prélèvement d'abonnement (`Générer`). Les cardinalités elles-mêmes
étaient correctes ; seul le nom de l'association induisait en erreur.

**Correction appliquée** :
- Renommage de `Effectuer` en `Concerner`, sans modification des
  cardinalités ni des entités liées.
- Ajout de la règle de gestion #11, qui explicite comment l'initiative
  d'une transaction (client ou marchand) se déduit de la présence ou de
  l'absence du lien à `Générer`, sans nécessiter d'attribut redondant au
  niveau conceptuel - conformément au principe de non-redondance Merise.
- Ajout d'une ligne dans le tableau de la section 6 pour documenter
  explicitement ce cas de figure (attribut dérivable d'un lien conceptuel,
  matérialisable au MLD pour des raisons de performance).

#### Changelog v8 → v9

> **Note de version (v9)** - Ajout du lien manquant entre `Souscrire` et
> `MOYEN_PAIEMENT` (le MLD porte `Subscription.payment_method_id`, absent
> jusqu'ici du MCD), via une nouvelle association `Autoriser`, et ajout
> d'une règle de gestion sur la cohérence du client entre les deux chemins
> du modèle. Voir section 9.

**Problème identifié** : le MLD porte `Subscription.payment_method_id`
(moyen de paiement autorisé pour le prélèvement récurrent), sans
équivalent au niveau conceptuel. `Souscrire` ne portait aucun lien vers
`MOYEN_PAIEMENT`.

**Correction appliquée** :
- Ajout de l'association `Autoriser` reliant `Souscrire` (1,1) à
  `Moyen_paiement` (0,n) : chaque souscription est obligatoirement
  autorisée sur un seul moyen de paiement, et un moyen de paiement peut
  autoriser plusieurs souscriptions ou aucune.
- Choix explicite d'une association binaire `Souscrire`-`Moyen_paiement`
  plutôt qu'une association ternaire `Client`-`Produit`-`Moyen_paiement`,
  pour éviter la redondance introduite par la dépendance fonctionnelle
  `Moyen_paiement` → `Client` déjà portée par `Enregistrer` (voir section 5
  pour le détail du raisonnement).
- Ajout de la règle de gestion #12, qui énonce la contrainte de cohérence
  (le moyen de paiement autorisé doit appartenir au même client que celui
  qui souscrit) que les cardinalités seules ne peuvent pas exprimer, et qui
  devra être portée par une contrainte d'intégrité au niveau logique ou
  physique.
- Ajout d'une ligne dans le tableau de la section 6 pour documenter la
  transformation de cette nouvelle association au MLD.

#### Changelog v9 → v10

> **Note de version (v10)** - Traitement des deux derniers écarts
> MCD/MLD identifiés en review : `Transaction.is_merchant_initiated` ne
> nécessite aucun changement (déjà couvert par la règle #11, dont le texte
> est complété pour le dire explicitement) ; `Subscription.canceled_at`,
> en revanche, correspondait à une vraie omission - l'attribut
> `date_demande_resiliation` est ajouté à `Souscrire`, avec une règle de
> gestion qui le distingue de `fin_periode`. Voir section 10.

**Problèmes identifiés** : deux attributs du MLD n'avaient pas
d'équivalent explicite au MCD - `Transaction.is_merchant_initiated` et
`Subscription.canceled_at`. Une analyse séparée était nécessaire, les deux
cas n'étant pas de même nature.

**`is_merchant_initiated`** : ne nécessite **aucun changement structurel**.
La règle de gestion #11 (introduite en v8) couvre déjà entièrement cette
donnée - elle se déduit de la présence ou de l'absence du lien à
`Générer`, sans redondance. Le texte de la règle #11 est complété pour le
dire explicitement et nommer l'attribut MLD correspondant, afin que la
traçabilité MCD → MLD soit immédiatement visible à la lecture.

**`canceled_at`** : correspondait à une **vraie omission**. Contrairement
à `is_merchant_initiated`, cette donnée n'est dérivable d'aucun autre
attribut ou lien du modèle : `fin_periode` indique la fin de la période
déjà payée, mais pas la date à laquelle le client a demandé la
résiliation - deux informations indépendantes qui peuvent être très
éloignées dans le temps.

**Correction appliquée** :
- Ajout de l'attribut `date_demande_resiliation` aux propriétés de
  `Souscrire`.
- Ajout de la règle de gestion #13, qui distingue explicitement
  `date_demande_resiliation` de `fin_periode` et précise qu'une
  souscription résiliée reste active jusqu'à la fin de la période déjà
  facturée.
- Ajout d'une ligne dans le tableau de la section 6 pour documenter la
  transformation directe d'une propriété d'association *n,n* en colonne
  de la table issue de cette association.

#### Revue de cohérence v10 → v11

> **Note de version (v11)** - Revue de cohérence complète du document
> après les corrections v7 à v10 : diagramme, dictionnaire des
> associations, règles de gestion et mapping MLD confirmés mutuellement
> cohérents. Deux coquilles de formatage sans impact structurel corrigées.
> Voir section 11.

**Objectif** : après quatre séries de corrections successives (v7 à v10),
vérifier qu'aucune incohérence ne s'est introduite entre les différentes
sections du document.

**Points vérifiés** :
- Chaque arête du diagramme Mermaid (section 1) correspond exactement à sa
  ligne dans le dictionnaire des associations (section 3) - cardinalités,
  sens des liens et étiquettes identiques des deux côtés.
- Les propriétés listées sur le nœud `Souscrire` du diagramme
  (`statut`, `cycle_facturation`, `montant`, `date_debut`, `fin_periode`,
  `date_demande_resiliation`) correspondent à la liste de la section 3.
- Les règles de gestion #11 (`Concerner`/`Générer`), #12 (`Autoriser`) et
  #13 (`date_demande_resiliation`) correspondent aux associations et
  attributs effectivement présents dans le diagramme et le dictionnaire.
- Le tableau de passage au MLD (section 6) référence chacun des cas
  particuliers introduits en v8, v9 et v10, sans doublon ni omission.
- Les quatre changelogs (sections 7 à 10) décrivent fidèlement les
  changements effectivement présents dans le document final.

**Résultat** : aucune incohérence structurelle détectée. Deux coquilles de
formatage sans impact sur le fond ont été corrigées :
- une double astérisque Markdown parasite dans la section 5 (résidu de la
  version d'origine, jamais corrigé jusqu'ici) ;
- une faute de frappe ("imédiatement" → "immédiatement") introduite dans le
  changelog v10.

**Écarts restants, hors périmètre de cette review** : ce MCD couvre le
cœur transactionnel (paiements, abonnements, remboursements, litiges,
fraude) mais pas le volet conformité/audit (`ConsentRecord`,
`DataSubjectRequest`, `SecurityIncident`), déjà présent au MLD. Comme noté
lors de la review initiale, ce point est probablement traité dans un MCD
dédié compte tenu du nom de fichier ("step-1") ; à confirmer avant la
soutenance.

#### Changelog v11 → v12

> **Note de version (v12)** - Fermeture du manque le plus important
> identifié lors de la review du MLD/DBML : aucune donnée ne permettait de
> tracer la commission Stripe (`fee_amount_eur` en OLAP n'avait pas de
> source en OLTP). Ajout de l'entité `PLAN_TARIFAIRE` et des associations
> `Bénéficier` (marchand → plan, historisé) et `Facturer` (transaction →
> plan, traçabilité), avec trois nouvelles règles de gestion. Voir
> section 12.

**Problème identifié** : lors de l'analyse initiale du MLD/DBML OLTP-OLAP
(hors de ce document), il avait été relevé que `fee_amount_eur`,
`stripe_revenue_eur` et `merchant_net_revenue_eur` existaient côté OLAP
sans aucune source traçable côté OLTP - aucune table ni colonne ne
capturait la commission Stripe. Ce manque n'avait pas encore été reporté
au niveau conceptuel.

**Correction appliquée** :
- Ajout de l'entité `PLAN_TARIFAIRE` (`taux_commission`, `frais_fixe`,
  `date_effet`, `date_fin`), qui modélise la grille tarifaire appliquée à
  un marchand, versionnée dans le temps.
- Ajout de l'association `Bénéficier` (`MARCHAND` 0,n - `PLAN_TARIFAIRE`
  1,1) : un marchand bénéficie de plusieurs plans tarifaires successifs au
  fil du temps, ou d'aucun s'il vient d'être onboardé.
- Ajout de l'association `Facturer` (`TRANSACTION` 1,1 - `PLAN_TARIFAIRE`
  0,n) : chaque transaction est facturée selon un plan précis, choix de
  conception identique à celui retenu pour `Autoriser` en v9 (lien
  explicite plutôt que dérivation implicite, pour la traçabilité).
- Complément de la règle de gestion #10 pour couvrir l'existence
  indépendante d'un plan tarifaire.
- Ajout des règles de gestion #14 (non-chevauchement temporel des plans
  d'un même marchand), #15 (justification du choix de traçabilité
  explicite, par analogie avec le taux de change de référence de l'OLAP)
  et #16 (contrainte de cohérence entre `Facturer` et `Bénéficier`, et
  non-stockage du montant de commission comme attribut).
- Ajout d'une nouvelle sous-section en section 5 et de trois lignes dans
  le tableau de la section 6, sur le même modèle que les extensions
  précédentes.
- Hypothèse explicite : `frais_fixe` est exprimé dans la devise de la
  transaction concernée ; `PLAN_TARIFAIRE` n'est pas relié à `DEVISE`. Une
  modélisation plus fine reste possible si une itération future le
  justifie.

#### Changelog v12 → v13

> **Note de version (v13)** - Extension du périmètre à la conformité et à
> la sécurité (`AuditActorType`, `AuditAction`, `DataAccessLog`,
> `ChangeAuditLog`, `ConsentRecord`, `DataSubjectRequest`,
> `SecurityIncident` au MLD) : six nouvelles entités, huit nouvelles
> associations, sept nouvelles règles de gestion. Voir section 13.

**Demande** : étendre le périmètre du MCD à la conformité et à la sécurité,
pour couvrir les tables déjà présentes au MLD (`AuditActorType`,
`AuditAction`, `DataAccessLog`, `ChangeAuditLog`, `ConsentRecord`,
`DataSubjectRequest`, `SecurityIncident`).

**Correction appliquée** :
- Ajout de six entités : `ACTEUR`, `ACCES`, `MODIFICATION`,
  `CONSENTEMENT`, `DEMANDE_DROIT`, `INCIDENT_SECURITE`.
- Ajout de huit associations : `Consulter` et `Modifier` (acteur → accès /
  modification), `Cibler` et `Viser` (accès → marchand / client,
  optionnels), `Toucher` (modification → marchand, optionnel),
  `Consentir` et `Exercer` (client → consentement / demande de droit),
  `Affecter` (incident → marchand, optionnel).
- Décision de ne **pas** relier `CONSENTEMENT` et `DEMANDE_DROIT` à
  `MARCHAND` au niveau conceptuel : contrairement au plan tarifaire ou au
  moyen de paiement autorisé, ce lien est purement redondant avec
  `Posséder` (le marchand d'un client ne varie jamais), sans justification
  de traçabilité historique. Voir règle #20 et la sous-section dédiée en
  section 5.
- Ajout des règles de gestion #17 à #23, couvrant notamment : la nature
  externe de l'identité `ACTEUR`, l'optionnalité des liens marchand/client
  sur les événements d'audit, et surtout la clarification que la note
  "append-only" du MLD ne s'applique en réalité qu'aux journaux `ACCES`/
  `MODIFICATION` - `DEMANDE_DROIT` et `INCIDENT_SECURITE` sont des workflows
  mutables (règle #23), point qui n'était pas explicite dans la
  formulation d'origine du MLD.
- Ajout d'une sous-section en section 5 justifiant trois choix de
  modélisation : absence de table `Actor` nécessaire au MLD, séparation de
  `ACCES` et `MODIFICATION` malgré leur fusion ultérieure en un seul fait
  côté OLAP, et asymétrie du lien vers `MARCHAND` selon les entités.
- Ajout de trois lignes dans le tableau de la section 6.

#### Changelog v13 → v14

> **Note de version (v14)** - Correction de deux écarts trouvés lors de la
> revue de cohérence de la v13 : ajout de la règle de gestion #24, qui
> comblait un trou de cohérence entre `Cibler` et `Viser` (un accès
> pourrait sinon cibler un marchand et viser un client d'un autre
> marchand) ; et correction du titre de la section 5, qui annonçait
> "quatre différences" alors que le document en compte sept - erreur déjà
> présente dès la version d'origine (v6) et jamais repérée jusqu'ici. Voir
> section 14.

**Problèmes identifiés lors de la revue de cohérence de la v13** :

1. **Trou logique introduit en v13** : `Cibler` (`ACCES` → `MARCHAND`) et
   `Viser` (`ACCES` → `CLIENT`) sont deux associations indépendantes et
   toutes deux optionnelles. Rien n'empêchait, tel que modélisé, qu'un
   accès cible un marchand tout en visant un client d'un autre marchand -
   alors qu'un client appartient à un seul marchand de façon permanente
   (règle #2). Ce type de trou avait pourtant déjà été traité deux fois
   dans ce document (règles #12 et #16), mais avait été manqué pour cette
   paire d'associations lors de la rédaction de la v13.
2. **Erreur préexistante depuis la v6, jamais repérée** : le titre de la
   section 5 annonçait "quatre différences", alors que le document en
   comptait déjà cinq dès la version d'origine, et en compte sept depuis
   les ajouts v12/v13. Aucune des revues précédentes (y compris la revue
   de cohérence dédiée en v11) ne l'avait relevé.

**Correction appliquée** :
- Ajout de la règle de gestion #24, qui impose la cohérence entre `Cibler`
  et `Viser` lorsque les deux sont renseignés sur un même accès.
- Remplacement de "Quatre différences" par "Plusieurs différences" en
  section 5 - formulation délibérément non chiffrée, pour ne pas
  reproduire la même dérive à la prochaine extension du document.

**Non corrigé à ce stade, signalé mais laissé en l'état** : la quasi-
homonymie entre l'entité `MODIFICATION` et l'association `Modifier`, et
l'absence d'un énoncé généralisant regroupant toutes les entités
dépendantes du document (sur le modèle de la règle #9) - ces deux points
sont d'ordre rédactionnel, sans impact sur la validité du modèle.

#### Changelog v14 → v15

> **Note de version (v15)** - Renommage de l'entité `MODIFICATION` en
> `CHANGEMENT` et de l'association `Modifier` en `Consigner`, pour lever
> une quasi-homonymie signalée en review, et corriger au passage une
> imprécision sémantique : l'acteur ne modifie pas l'enregistrement
> d'audit (il est en écriture seule, règle #23), il consigne un
> changement survenu ailleurs. Voir section 15.

**Problème identifié** : l'entité `MODIFICATION` et l'association
`Modifier` (introduites en v13) partageaient la même racine lexicale,
source de confusion possible à l'oral entre l'entité et l'association qui
y mène. Au-delà de l'homonymie, `Modifier` était aussi légèrement imprécis
sémantiquement : il suggérait que l'acteur modifie l'enregistrement
d'audit, alors que celui-ci est en écriture seule (règle #23) - l'acteur
consigne un changement survenu ailleurs, il ne modifie pas la trace elle-
même.

**Correction appliquée** :
- Renommage de l'entité `MODIFICATION` en `CHANGEMENT`, y compris sa clé
  (`num_modification` → `num_changement`). Bénéfice secondaire : ce nom se
  rapproche du nom réel de la table au MLD (`ChangeAuditLog`).
- Renommage de l'association `Modifier` en `Consigner`, qui décrit plus
  fidèlement la relation réelle (l'acteur consigne un changement, il ne le
  modifie pas).
- Mise à jour de toutes les occurrences vivantes du document (diagramme,
  dictionnaires, règles #17, #19, #23, sous-section dédiée en section 5) -
  à l'exception des changelogs v13 et v14, qui décrivent fidèlement l'état
  du document à ce moment-là et conservent donc les noms d'origine, exactement
  comme le changelog v8 conserve `Effectuer` en décrivant son propre
  renommage.
- Les attributs `table_modifiee` et `enregistrement_modifie` restent
  inchangés : ils décrivent en langage courant ce qui a été modifié
  ailleurs dans le système, sans plus entrer en collision avec le nom de
  l'entité une fois celle-ci renommée.
- Ajout d'un paragraphe dédié en section 5 justifiant ce double
  renommage.

#### Changelog v15 → v16

> **Note de version (v16)** - Ajout de la règle de gestion #25, qui
> généralise le principe des "entités dépendantes" (règle #9) aux entités
> introduites en v12/v13 - en distinguant deux nuances plutôt qu'en les
> assimilant toutes à la règle #9 : `CONSENTEMENT`/`DEMANDE_DROIT` sont de
> purs dépendants comme les trois de la règle #9 ; `PLAN_TARIFAIRE`,
> `ACCES` et `CHANGEMENT` sont dépendants pour leur existence mais jouent
> aussi un second rôle ailleurs dans le modèle. Voir section 16.

**Problème identifié** : la règle #9 nomme explicitement
`REMBOURSEMENT`, `LITIGE` et `SCORE_FRAUDE` comme "entités dépendantes" de
`TRANSACTION`, mais les entités dépendantes introduites en v12/v13
(`PLAN_TARIFAIRE`, `CONSENTEMENT`, `DEMANDE_DROIT`, `ACCES`, `CHANGEMENT`)
suivaient le même principe sans énoncé généralisant équivalent.

**Analyse préalable à la correction** : une généralisation naïve
assimilant toutes ces entités à la règle #9 aurait été inexacte.
L'examen des associations a montré deux sous-cas réellement distincts :
`CONSENTEMENT` et `DEMANDE_DROIT` sont de purs dépendants, ne participant
à aucune autre association - comme les trois entités de la règle #9, à la
différence près que leur parent (`CLIENT`) en porte `0,n` plutôt que `0,1`
(historique répétable, pas extension ponctuelle). `PLAN_TARIFAIRE`,
`ACCES` et `CHANGEMENT`, en revanche, jouent chacun un second rôle dans le
modèle (référencés par `Facturer`, ou porteurs de liens optionnels
`Cibler`/`Viser`/`Toucher`) : leur dépendance existentielle ne les réduit
pas à de simples extensions isolées. `PRODUIT` et `MOYEN_PAIEMENT`
partagent la même forme de cardinalité (`1,1` côté propre) mais
participent chacun à plusieurs associations : ils ne sont donc dépendants
d'aucun parent unique et sont exclus à bon droit de cette généralisation.

**Correction appliquée** :
- Ajout de la règle de gestion #25, qui généralise le principe de la
  règle #9 en distinguant explicitement les deux sous-cas ci-dessus,
  plutôt que de les fondre en un énoncé unique imprécis.
- Ajout d'un renvoi croisé à la fin de la règle #9 vers la règle #25.

#### Changelog v16 → v17

> **Note de version (v17)** - Traduction des 17 noms d'entités en anglais
> (diagramme, dictionnaires, règles de gestion, section 5, section 6),
> pour s'aligner sur la nomenclature déjà anglaise du MLD/DBML. Attributs,
> noms d'associations et texte des règles restent en français. Voir
> section 17 pour la table de correspondance complète.

**Demande** : traduire les noms des entités en anglais, pour s'aligner sur
la nomenclature déjà anglaise du MLD/DBML produit par ailleurs.

**Périmètre retenu** : seuls les 17 **noms d'entités** sont traduits - pas
les attributs, pas les noms d'associations (`Situer`, `Souscrire`,
`Facturer`...), pas le texte des règles de gestion. Ce choix reste
volontairement strict par rapport à la demande ; une traduction complète
(attributs et associations compris) reste possible sur demande.

**Table de correspondance** :

| Nom d'origine (FR) | Nom traduit (EN) |
|---|---|
| `PAYS` | `COUNTRY` |
| `DEVISE` | `CURRENCY` |
| `MARCHAND` | `MERCHANT` |
| `CLIENT` | `CUSTOMER` |
| `MOYEN_PAIEMENT` | `PAYMENT_METHOD` |
| `PRODUIT` | `PRODUCT` |
| `TRANSACTION` | `TRANSACTION` *(inchangé)* |
| `REMBOURSEMENT` | `REFUND` |
| `LITIGE` | `CHARGEBACK` |
| `SCORE_FRAUDE` | `FRAUD_SCORE` |
| `PLAN_TARIFAIRE` | `PRICING_PLAN` |
| `ACTEUR` | `ACTOR` |
| `ACCES` | `ACCESS` |
| `CHANGEMENT` | `CHANGE` |
| `CONSENTEMENT` | `CONSENT` |
| `DEMANDE_DROIT` | `DATA_SUBJECT_REQUEST` |
| `INCIDENT_SECURITE` | `SECURITY_INCIDENT` |

Chaque nom anglais a été choisi, quand c'était possible, pour correspondre
exactement au nom de table déjà utilisé côté MLD/DBML (`Country`,
`Merchant`, `Customer`, `Refund`, `Chargeback`, `Actor`,
`DataSubjectRequest`, `SecurityIncident`...), afin que le MCD et le MLD
partagent le même vocabulaire lors du passage de l'un à l'autre.

**Correction appliquée** :
- Traduction des 17 libellés d'entités dans le diagramme Mermaid - les
  identifiants internes des nœuds (ex. `PAYS`, `MOYEN`, `DEMANDE`) restent
  inchangés, seul le texte affiché dans chaque encadré change ; cela évite
  de retoucher les arêtes du diagramme, qui référencent les identifiants,
  pas les libellés.
- Mise à jour des sections 2 (dictionnaire des entités), 3 (dictionnaire
  des associations, colonnes Entité A/B), 4 (règles de gestion), 5 (ce qui
  distingue le MCD du MLD) et 6 (passage au MLD) - chaque référence
  encadrée de backticks à un nom d'entité a été traduite.
- Une occurrence composée (`` `PLAN_TARIFAIRE.taux_commission` `` en
  section 6) avait échappé au remplacement automatique, qui ciblait des
  noms encadrés de backticks isolés ; détectée et corrigée en relecture.
- Les notes de version (v7 à v16) et les changelogs historiques
  (sections 7 à 16) conservent les noms français d'origine, puisqu'ils
  décrivent fidèlement l'état du document à chaque étape passée - même
  principe que pour les renommages `Effectuer`→`Concerner` (v8) et
  `MODIFICATION`/`Modifier`→`CHANGEMENT`/`Consigner` (v15).

#### Changelog v17 → v18

> **Note de version (v18)** - Traduction des 27 noms d'associations en
> anglais, avec traçabilité du nom français d'origine à chaque ligne du
> dictionnaire. Deux résidus non détectés en v17 corrigés au passage :
> des références en casse mixte (`Client`, `Moyen_paiement`, `Produit`)
> échappées au remplacement automatique, et une référence incorrecte à
> une table MLD (`Client.merchant_id` au lieu de `Customer.merchant_id`).
> Voir section 18.

**Demande** : traduire les noms des associations en anglais, dans la
continuité de la traduction des entités en v17.

**Table de correspondance** :

| Nom d'origine (FR) | Nom traduit (EN) |
|---|---|
| Situer | IsLocatedIn |
| Résider | ResidesIn |
| Posséder | Owns |
| Cataloguer | Catalogs |
| Tarifer | IsPricedIn |
| Enregistrer | Registers |
| Souscrire | Subscribes |
| Autoriser | Authorizes |
| Bénéficier | BenefitsFrom |
| Recevoir | Receives |
| Concerner | Bears |
| Utiliser | IsUsedIn |
| Régler | IsSettledIn |
| Facturer | IsRatedUnder |
| Générer | Generates |
| Acheter | Purchases |
| Rembourser | Triggers |
| Contester | Disputes |
| Évaluer | Evaluates |
| Consulter | Consults |
| Consigner | Logs |
| Cibler | Targets |
| Viser | Involves |
| Toucher | Touches |
| Consentir | Declares |
| Exercer | Exercises |
| Affecter | Affects |

**Choix de traduction méritant explication** :
- `Rembourser` → `Triggers` plutôt que `Refunds` : `Refunds` aurait
  reproduit, avec l'entité `REFUND`, exactement le problème d'homonymie
  corrigé en v15 pour `MODIFICATION`/`Modifier`. Même raisonnement pour
  `Consulter` → `Consults` (évite `Accesses`/`ACCESS`) et `Consentir` →
  `Declares` (évite `Consents`/`CONSENT`).
- `Toucher` → `Touches` et `Affecter` → `Affects` restent deux noms
  distincts malgré leur proximité sémantique (les deux relient une entité
  d'audit à `MERCHANT`), pour respecter l'unicité des noms d'association
  qu'impose Merise.
- Les noms retirés (`Effectuer`, `Modifier`) ne sont pas traduits : ils
  n'apparaissent plus que comme repères historiques dans les annotations
  et le texte explicatif, jamais comme noms courants.

**Correction appliquée** :
- Traduction des 27 libellés d'association dans le diagramme Mermaid,
  identifiants internes des nœuds inchangés - même principe qu'en v17.
- Réécriture complète de la table de la section 3, avec mention `(ex-Nom
  français)` sur chaque ligne pour la traçabilité.
- Mise à jour de toutes les références encadrées de backticks dans les
  sections 4, 5 et 6.
- La référence à `SOUSCRIRE` comme pseudo-entité (dans les lignes
  `Authorizes` et `Generates` du dictionnaire) devient `SUBSCRIBES`.
- Une forme composée (`` `Souscrire.date_demande_resiliation` `` en
  section 6) avait échappé au remplacement automatique ; détectée et
  corrigée, comme la forme composée équivalente déjà rencontrée en v17.

**Deux résidus de la v17 détectés et corrigés à cette occasion** :
- Des références à trois entités en casse "Titre_soulignée"
  (`` `Client` ``, `` `Moyen_paiement` ``, `` `Produit` ``) dans la prose
  des sections 4 et 5 avaient échappé à la traduction de v17, qui ne
  ciblait que la forme MAJUSCULES. Corrigées en `` `Customer` ``,
  `` `PaymentMethod` ``, `` `Product` ``.
- La table de la section 6 référençait `Client.merchant_id`, alors que la
  table réelle du MLD/DBML s'appelle `Customer` - incohérence présente
  depuis la version d'origine (v6), jamais repérée jusqu'ici. Corrigée en
  `Customer.merchant_id`.

#### Changelog v18 → v19

> **Note de version (v19)** - Traduction de tous les attributs en
> anglais, alignés sur les noms de colonnes réels du MLD/DBML
> (`merchant_id`, `legal_name`, `occurred_at`...) plutôt que sur une
> traduction littérale du français. Le MCD partage désormais
> intégralement le vocabulaire du MLD - entités, associations et
> attributs. Voir section 19 pour la table de correspondance complète.

**Demande** : traduire les attributs/propriétés en anglais, dans la
continuité de la traduction des entités (v17) et des associations (v18).

**Principe retenu** : plutôt qu'une traduction littérale du français
(`raison_sociale` → *"corporate name"*), chaque attribut est aligné sur le
nom de colonne réel du MLD/DBML quand il existe (`raison_sociale` →
`legal_name`, qui correspond exactement à `Merchant.legal_name`). Pour les
attributs sans équivalent direct au MLD (le volet `PRICING_PLAN`, entité
introduite en v12), un nom conventionnel a été choisi par cohérence avec
le reste du modèle.

**Principe de simplification conservé** : conformément à ce que la
section 5 énonce depuis la version d'origine (*"aucune table de référence
d'énumérés... au niveau conceptuel, `statut` est simplement une
propriété"*), les attributs correspondant à des clés étrangères vers des
tables de référence au MLD perdent leur suffixe `_code` une fois traduits
- `statut` devient `status` (et non `status_code`), `type_action` devient
`action_type` (et non `action_code`) - sauf lorsque le "code" fait partie
intégrante du concept métier lui-même : `code_motif` devient `reason_code`
et non simplement `reason`, car les réseaux de cartes définissent
réellement des codes normalisés (voir le MLD `ChargebackReasonCode`).

**Table de correspondance complète** (regroupée par entité) :

| Entité | Attributs FR → EN |
|---|---|
| `COUNTRY` | `code_pays`→`country_code`, `nom`→`name` |
| `CURRENCY` | `code_devise`→`currency_code`, `nom`→`name`, `decimales`→`decimals` |
| `MERCHANT` | `num_marchand`→`merchant_id`, `raison_sociale`→`legal_name`, `statut`→`status`, `date_creation`→`created_at` |
| `CUSTOMER` | `num_client`→`customer_id`, `date_creation`→`created_at` |
| `PAYMENT_METHOD` | `num_moyen`→`payment_method_id`, `marque`→`brand`, `quatre_derniers`→`card_last4`, `expiration`→`expiry` |
| `PRODUCT` | `num_produit`→`product_id`, `libelle`→`name`, `prix_unitaire`→`unit_price`, `actif`→`active` |
| `TRANSACTION` | `num_transaction`→`transaction_id`, `montant`→`amount`, `date_heure`→`created_at`, `statut`→`status`, `geolocalisation`→`ip_geolocation`, `type_appareil`→`device_type` |
| `REFUND` | `num_remboursement`→`refund_id`, `montant`→`amount`, `motif`→`reason`, `date_heure`→`created_at` |
| `CHARGEBACK` | `num_litige`→`chargeback_id`, `code_motif`→`reason_code`, `statut`→`status`, `date_heure`→`created_at`, `date_resolution`→`resolved_at` |
| `FRAUD_SCORE` | `num_score`→`fraud_score_id`, `score_anomalie`→`anomaly_score`, `niveau_risque`→`risk_level`, `date_evaluation`→`evaluated_at` |
| `PRICING_PLAN` | `num_plan`→`pricing_plan_id`, `taux_commission`→`commission_rate`, `frais_fixe`→`fixed_fee`, `date_effet`→`effective_from`, `date_fin`→`effective_to` |
| `ACTOR` | `identifiant_acteur`→`actor_id`, `type_acteur`→`actor_type`, `est_humain`→`is_human` |
| `ACCESS` | `num_acces`→`access_log_id`, `type_action`→`action_type`, `type_ressource`→`resource_type`, `id_ressource`→`resource_id`, `adresse_source`→`source_ip`, `agent_utilisateur`→`user_agent`, `autorise`→`was_authorized`, `date_heure`→`occurred_at` |
| `CHANGE` | `num_changement`→`change_log_id`, `table_modifiee`→`table_name`, `enregistrement_modifie`→`record_id`, `type_action`→`action_type`, `champs_modifies`→`changed_fields`, `date_heure`→`occurred_at` |
| `CONSENT` | `num_consentement`→`consent_id`, `finalite`→`purpose`, `est_accorde`→`is_granted`, `base_legale`→`legal_basis`, `canal`→`source`, `date_heure`→`recorded_at` |
| `DATA_SUBJECT_REQUEST` | `num_demande`→`request_id`, `type_demande`→`request_type`, `reglementation`→`regulation`, `statut`→`status`, `date_reception`→`received_at`, `date_echeance`→`due_at`, `date_traitement`→`fulfilled_at`, `motif_rejet`→`rejection_reason` |
| `SECURITY_INCIDENT` | `num_incident`→`incident_id`, `type_incident`→`incident_type`, `gravite`→`severity`, `nb_enregistrements_affectes`→`affected_record_count`, `date_detection`→`detected_at`, `date_notification`→`notified_at`, `date_resolution`→`resolved_at`, `statut`→`status` |
| Propriétés de `Subscribes` | `statut`→`status`, `cycle_facturation`→`billing_cycle`, `montant`→`amount`, `date_debut`→`started_at`, `fin_periode`→`current_period_end`, `date_demande_resiliation`→`canceled_at` |

Attributs déjà identiques dans les deux langues (non listés ci-dessus) :
`email`, `type`, `justification`, `description`, `source`.

**Remarque sur la convergence MCD/MLD** : la ligne de la section 6
documentant `Souscrire.date_demande_resiliation` → `Subscription.canceled_at`
devient, une fois traduite, `Subscribes.canceled_at` →
`Subscription.canceled_at` - les deux côtés affichent désormais légitimement
le même nom. Ce n'est pas une erreur ni une redondance à corriger : c'est
la preuve que la traduction a atteint son objectif de convergence
terminologique entre les deux modèles.

**Correction appliquée** :
- Traduction de tous les attributs des 17 entités et des 6 propriétés
  portées par `Subscribes`, dans le diagramme Mermaid, le dictionnaire des
  entités (section 2), la ligne `Subscribes` du dictionnaire des
  associations (section 3), et toutes les références encadrées de
  backticks dans les sections 4, 5 et 6.
- Traitement contextuel de `date_heure`, qui se traduisait différemment
  selon l'entité porteuse (`created_at` pour `TRANSACTION`/`REFUND`/
  `CHARGEBACK`, `occurred_at` pour `ACCESS`/`CHANGE`, `recorded_at` pour
  `CONSENT`) - chaque occurrence vérifiée individuellement plutôt que
  remplacée globalement.
- Deux formes composées (`` `Subscribes.date_demande_resiliation` `` et
  `` `PRICING_PLAN.taux_commission` `` en section 6) avaient échappé au
  remplacement automatique par correspondance exacte ; détectées et
  corrigées, comme lors des deux passes de traduction précédentes.
- Les notes de version et changelogs historiques (sections 7 à 18)
  conservent les attributs français d'origine, pour les mêmes raisons de
  fidélité historique que pour les traductions précédentes.

#### Changelog v19 → v20

> **Note de version (v20)** - Restructuration du document pour
> intégration dans un livrable plus large ("STRIPE PROJECT") : en-têtes
> renumérotés hiérarchiquement, glossaire ajouté, diagramme scindé en deux
> blocs Mermaid distincts (cœur transactionnel / conformité-sécurité).
> Note rédigée rétroactivement en v21, cette transition n'ayant pas été
> documentée au moment des faits - voir section v21 pour le détail des
> problèmes que cette revue a permis d'identifier.

**Changements identifiés a posteriori** (non exhaustif, la v20 n'ayant pas
été accompagnée de son propre changelog) :
- Restructuration hiérarchique des en-têtes (`# 1. Modèle de Données
  OLTP` / `## 1.1. Modèle conceptuel de données` / `#### 1.A.x. ...`) pour
  intégration dans un document plus large.
- Ajout d'un glossaire (MCD/CDM, MLD/LDM, DEA/ERD, KYB/KYC).
- Scission du diagramme unique en deux blocs Mermaid autonomes.
- Correction grammaticale bienvenue : ajout du préfixe `Is` aux
  associations construites sur un participe passé (`IsLocatedIn`,
  `IsPricedIn`, `IsUsedIn`, `IsSettledIn`, `IsBilledUnder`), qui en
  avaient besoin pour former une proposition verbale complète - les
  associations déjà à la voix active (`ResidesIn`, `Owns`, `Concerns`...)
  n'ont pas été touchées, à raison.
- Perte de la plupart des annotations `(ajouté vX)` / `(renommé vX,
  ex-NomFrançais)` dans le dictionnaire des associations, et des
  `(corrigé v7)` sur les cardinalités.
- Coquille introduite en règle #8 (double astérisque parasite).

#### Changelog v20 → v21

> **Note de version (v21)** - Analyse de cohérence de la v20 : un bug de
> rendu (arêtes orphelines dans le premier diagramme, dupliquées du second
> sans leurs définitions de nœuds) et une coquille de formatage corrigés.
> Application des trois changements validés en discussion : `Concerns` →
> `Bears`, `IsBilledUnder` → `IsRatedUnder`, et l'option retenue pour
> rendre `fixed_fee` indépendant de la devise du client - nouvelle
> association porteuse `IsQuotedIn` entre `PRICING_PLAN` et `CURRENCY`.
> Voir ci-dessous.

**Problèmes identifiés en review** :
1. Le premier diagramme Mermaid contenait des arêtes vers `ACTEUR`,
   `CONSULTER`, `ACCES`, `CONSIGNER`, `CHANGEMENT`, `CIBLER`, `VISER`,
   `TOUCHER`, `CONSENTIR`, `CONSENTEMENT`, `EXERCER`, `DEMANDE`,
   `INCIDENT`, `AFFECTER`, sans que ces nœuds y soient définis (ils ne le
   sont que dans le second diagramme, autonome) - Mermaid aurait affiché
   des nœuds par défaut, sans leur libellé riche.
2. Règle #8 : double astérisque parasite avant "évaluation".
3. La v20 n'avait pas d'entrée de changelog documentant sa propre
   restructuration - rupture de la discipline de versionnement suivie
   depuis la v7, comblée rétroactivement ci-dessus.

**Correction appliquée** :
- Retrait des arêtes orphelines du premier diagramme (désormais uniquement
  présentes, correctement, dans le second).
- Correction de la coquille en règle #8.
- Renommage de `Concerns` en **`Bears`** : traçabilité restaurée
  (`renommé v21, ex-Concerner, ex-Concerns`) dans le dictionnaire des
  associations, mise à jour de la règle #11 et de la section 5.
- Renommage de `IsBilledUnder` en **`IsRatedUnder`** : traçabilité
  restaurée (`renommé v21, ex-Facturer, ex-IsBilledUnder`), mise à jour
  des règles #15/#16, de la section 5 et du tableau de la section 6.
- **Frais fixe indépendant de la devise du client** (option retenue :
  grille de frais par devise) :
  - Retrait de `fixed_fee` comme attribut scalaire de `PRICING_PLAN`
    (diagramme et dictionnaire des entités).
  - Ajout de l'association porteuse `IsQuotedIn` (`PRICING_PLAN` 0,n -
    `CURRENCY` 0,n), portant `fixed_fee` : chaque plan peut désormais être
    libellé dans plusieurs devises, chacune avec son propre frais fixe,
    sans conversion de change nécessaire pour l'appliquer.
  - Ajout de la règle de gestion #26, qui justifie la distinction
    `commission_rate` (indépendant de la devise) / `fixed_fee` (dépendant
    de la devise), et pose la contrainte de cohérence entre `IsQuotedIn`
    et `IsSettledIn` (le frais appliqué à une transaction doit être celui
    de sa propre devise de règlement).
  - Mise à jour de la règle #25 : `PRICING_PLAN` joue désormais deux rôles
    secondaires (`IsRatedUnder` et `IsQuotedIn`), pas un seul.
  - Réécriture de la sous-section "La commission Stripe est un paramètre"
    en section 5, remplaçant l'ancienne hypothèse simplificatrice
    (devise unique) par la description du nouveau mécanisme.
  - Ajout d'une ligne dans le tableau de la section 6 pour la
    transformation MLD de `IsQuotedIn` (table de jonction
    `PricingPlanFee`).

#### Changelog v21 → v22

> **Note de version (v22)** - Vérification de cohérence entre le MCD et
> le modèle OLTP physique (`stripe-step-1--oltp-model--v06.dbml`) :
>  extension du DBML pour combler l'écart `PRICING_PLAN` (tables `PricingPlan` et
> `PricingPlanFee`, colonnes `Transaction.pricing_plan_id`/`fee_amount`
> ajoutées en v7 du DBML), correction d'une incohérence de nommage
> (`MerchantPricingPlan` → `PricingPlan`), et ajout au MCD des attributs
> et de l'association identifiés comme manquants par rapport au DBML.

**Problèmes identifiés en review** :
1. `PRICING_PLAN` (introduit en MCD v12) n'avait jamais de contrepartie
   dans le DBML : `Transaction.pricing_plan_id`, `Transaction.fee_amount`,
   `MerchantPricingPlan` et `PricingPlanFee`, tous référencés en section 5
   du MCD, n'existaient dans aucune table physique.
2. Incohérence de nommage : la section 5 annonçait `MerchantPricingPlan`
   comme table cible, rompant le motif de transformation suivi par toutes
   les autres entités (`FRAUD_SCORE`→`FraudScore`, etc.).
3. Quatre attributs réels du DBML n'avaient pas de contrepartie au MCD,
   sans qu'aucune règle ne documente pourquoi : `PaymentMethod.is_default`,
   `PaymentMethod.created_at`, `Product.created_at`, `FraudScore.model_version`.
4. `Subscription.currency_code` et `Subscription.failed_attempt_count`
   n'avaient pas de contrepartie dans les propriétés de `Subscribes`.

**Correction appliquée** :
- **Extension du DBML (v7)** : ajout des tables `PricingPlan`
  (`pricing_plan_id`, `merchant_id`, `commission_rate`, `effective_from`,
  `effective_to`) et `PricingPlanFee` (`pricing_plan_id`, `currency_code`,
  `fixed_fee`, clé composite) ; ajout de `Transaction.pricing_plan_id` et
  `Transaction.fee_amount`, avec notes documentant les deux contraintes
  de cohérence déjà posées par les règles #16 et #28 du MCD (le plan
  facturé doit bénéficier au marchand récepteur ; le frais fixe doit
  correspondre à la devise de règlement).
- Correction de la référence `MerchantPricingPlan` → `PricingPlan` en
  section 5 du MCD, pour aligner sur le nom de table effectivement créé.
- Ajout de `is_default` et `created_at` à `PAYMENT_METHOD`, `created_at`
  à `PRODUCT`, `model_version` à `FRAUD_SCORE` (diagramme et dictionnaire
  des entités).
- Ajout de `failed_attempt_count` aux propriétés de `Subscribes`.
- Ajout de l'association **`IsDenominatedIn`** (`SUBSCRIBES` 1,1 —
  `CURRENCY` 0,n), pour représenter `Subscription.currency_code` — absent
  jusqu'ici de toute forme dans le MCD, alors que le modèle représente
  systématiquement la devise par une association (`IsPricedIn`,
  `IsSettledIn`, `IsQuotedIn`) et jamais par un attribut scalaire.
- Ajout de la règle de gestion #29, qui pose explicitement que la devise
  d'une souscription et celle de ses transactions générées ne sont pas
  structurellement liées dans le modèle actuel — point à surveiller si
  l'hypothèse de stabilité de la devise en cours d'abonnement doit être
  garantie.

#### Changelog v22 → v25

> **Note de version (v25)** - Alignement sans changement sur le numéro de version du modèle physique.

---