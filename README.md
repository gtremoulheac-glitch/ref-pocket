# Ref Pocket : mise en ligne de la version de test

Tout est gratuit : Supabase héberge la base de données et les comptes, Vercel héberge le site. Compte environ 20 minutes la première fois.

## Contenu du dossier

| Fichier | Rôle |
| --- | --- |
| `supabase/schema.sql` | Tables, sécurité et toutes les règles du jeu côté serveur (boosters, marché, échanges, duels) |
| `supabase/catalogue.sql` | Les 5 types et les 40 cartes de départ |
| `supabase/serie-2.sql` | 152 cartes de plus et 4 types (Foot, Politique, Twitch, Télé) |
| `supabase/serie-3.sql` | 76 cartes de plus et le type Sport |
| `supabase/effets.sql` | Donne un pouvoir spécial à chaque carte qui n'en a pas (à relancer après avoir ajouté des cartes) |
| `web/` | Le site à mettre en ligne (appli installable sur téléphone) |
| `web/config.js` | Le seul fichier à modifier : l'adresse et la clé de ton projet Supabase |
| `web/admin.html` | La page admin : créer et modifier les cartes, les types et leurs images |
| `web/cartes.js`, `web/cartes.css` | L'affichage des cartes, partagé par le jeu et la page admin |
| `publier.bat` | Met le site en ligne sur Vercel (double-clic) |

## 1. Créer la base de données (Supabase)

1. Crée un compte sur [supabase.com](https://supabase.com), puis **New project**. Choisis la région la plus proche (Europe ou Canada) et note le mot de passe de la base quelque part.
2. Une fois le projet prêt, ouvre **SQL Editor**, colle tout le contenu de `supabase/schema.sql` et clique sur **Run**.
3. Recommence avec `supabase/catalogue.sql`.
4. Va dans **Authentication > Sign In / Providers > Email** et **désactive « Confirm email »**. Sans ça, chaque inscription attend un e-mail de confirmation, et l'envoi d'e-mails inclus dans l'offre gratuite est très limité.
5. Récupère tes clés : bouton **Connect** en haut (ou **Project Settings > API**). Il te faut la **Project URL** et la clé **anon / public**.

## 2. Relier le site à ta base

Ouvre `web/config.js` avec un éditeur de texte et remplace les deux valeurs :

```js
window.REF_CONFIG = {
  supabaseUrl: "https://abcdefgh.supabase.co",
  supabaseAnonKey: "eyJhbGciOi...",
};
```

La clé anon est faite pour être publique : un joueur ne peut rien modifier directement dans la base, tout passe par les fonctions du serveur.

## 3. Mettre le site en ligne (Vercel)

Une seule fois :
1. Installe **Node.js** (version LTS) depuis [nodejs.org](https://nodejs.org) si ce n'est pas déjà fait.
2. Crée un compte gratuit sur [vercel.com](https://vercel.com) (plan Hobby).

Pour publier, double-clique sur **`publier.bat`** à la racine du dossier `ref-master`. La première fois, Vercel te pose quelques questions dans la fenêtre :

| Question | Réponse |
| --- | --- |
| Log in to Vercel | Choisis ta méthode de connexion, une page s'ouvre dans le navigateur |
| Set up and deploy? | `y` |
| Which scope? | Entrée (ton compte) |
| Link to existing project? | `n` |
| What's your project's name? | `ref-master` |
| In which directory is your code located? | Entrée (`./`) |
| Want to modify these settings? | `n` |

L'adresse du site s'affiche à la fin, du type `ref-master.vercel.app`. Les fois suivantes, un double-clic suffit : plus aucune question.

Pour publier une mise à jour : double-clic sur `publier.bat`, c'est tout.

## 4. Inviter les testeurs

**Crée ton compte en premier** : le tout premier compte inscrit devient automatiquement administrateur.

Envoie ensuite le lien. Chacun crée un compte avec e-mail + mot de passe, choisit un pseudo, et commence avec 3 boosters et 200 Kheys.

Pour l'installer sur téléphone :
- **iPhone** : ouvrir le lien dans Safari > bouton Partager > **Sur l'écran d'accueil**.
- **Android** : ouvrir dans Chrome > menu > **Installer l'application**.

## Gérer le jeu pendant le test

### La page admin

Ouvre `ton-adresse.vercel.app/admin.html`, ou passe par le bouton réglages du jeu > **Ouvrir la page admin**. Elle utilise ton compte du jeu.

- **Nouvelle carte** : nom de la réf, type, rareté, stats, effet spécial, texte d'ambiance. L'aperçu de la vraie carte se met à jour pendant que tu tapes, avec la note calculée et le total de stats conseillé pour la rareté.
- **Image** : choisis une image, fais-la glisser pour la cadrer et zoome avec le curseur (ou la molette, ou deux doigts sur téléphone). Le cadre « Note » montre la zone couverte par la note en haut à gauche. L'image est recadrée au format de la carte et compressée avant l'envoi.
- **Texte d'ambiance** : si tu y mets une année (ex. 2013), elle sert d'indice « Époque » pendant l'ouverture des épiques et légendaires.
- **Retirer une carte** : décoche « Peut sortir dans les boosters ». Les joueurs qui l'ont la gardent.
- **Types** : crée un type (nom, abréviation, couleur) et choisis contre quels types il a l'avantage.

Les joueurs voient les nouveautés en rechargeant l'appli.

- **Admins** : bouton **Admins** de la page admin. Tu ajoutes un admin avec son pseudo et tu peux retirer les droits (il reste toujours au moins un admin).
- **Supprimer une carte** : bouton en bas de la fiche. Les exemplaires disparaissent des collections, chaque propriétaire récupère leur valeur de défausse en Kheys, et les ventes ou échanges qui contenaient la carte sont annulés.

### Dans Supabase (Table Editor)

- **Donner des Kheys ou des boosters à un testeur** : table `profiles`, colonnes `kheys` et `boosters`.
- **Voir d'où viennent les Kheys** : table `ledger`, qui journalise chaque mouvement.
- **Les images** sont rangées dans **Storage > cartes**.

## Mettre à jour la base après une nouvelle version

Quand une mise à jour touche le serveur, relance simplement tout `supabase/schema.sql` dans le SQL Editor. Le fichier est fait pour être relancé : il ajoute ce qui manque sans effacer les joueurs, les cartes ni les collections.

## Limites de cette version de test

- **Pause automatique** : un projet Supabase gratuit est mis en pause après une semaine sans activité. Il se relance en un clic depuis le tableau de bord.
- **Duels** : en ligne contre de vrais joueurs (ami ou adversaire au hasard). Tout le combat est calculé par le serveur. Chaque joueur a 90 secondes par tour, sinon l'autre peut réclamer la victoire. Les récompenses sont plafonnées à 10 duels par jour. L'entraînement contre le bot ne rapporte rien.
- **Pas encore là** : enchères, contre-offres dans les échanges, notifications push quand l'appli est fermée.
- **Mot de passe oublié** : pas de réinitialisation par e-mail pour l'instant. Tu peux supprimer le compte dans **Authentication > Users** et le testeur se réinscrit.
