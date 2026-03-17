# Plan d'Amélioration - CloakyApp

Cinq catégories pour optimiser l'app.

---

## 1. Correction Bugs Bloquants

- **Fixer la typo** dans le product ID App Store (`com.claokyy` → `com.cloakyy`)
- **Valider les receipts côté serveur** avant d'activer l'achat
- **Corriger le compteur de pages** onboarding (4 cercles mais `totalPages = 3`)

---

## 2. Refactor Onboarding

- **Ajouter un bouton Skip** en haut à droite
- **Remplacer les cercles** par un indicateur de progression linéaire
- **Créer des composants séparés** pour chaque page (Hero, Demo, Premium, CTA)
- **Passer StoreManager par injection** (via AppState) au lieu de duplicer l'instance
- **Lazy loading** des pages non visibles

---

## 3. Performance & Fluidité

- **Déplacer le processing** en arrière-plan avec `Task.detached`
- **Implémenter un cache LRU** avec limites réduites (50MB objets, 100MB images)
- **Ajouter memoization** avec `.equatable()` sur les vues statiques
- **Optimiser AnimatedBackground** : arrêter l'animation quand pas visible
- **Collecter les métriques** en production (FPS, mémoire, temps de launch)

---

## 4. Sécurité Paiements

- **Implémenter server-side receipt validation** complète
- **Gérer les états pending** correctement dans l'UI
- **Stocker les transactions** en local pour audit
- **Détecter jailbreak/proxy** comme anti-fraude additionnel
- **Logging des tentatives d'achat** échouées

---

## 5. Allègement de l'App

- **Vectoriser les assets** (PDF au lieu de PNG pour AppIcon)
- **Compresser les images** avec WebP/HEIC
- **Activer app thinning** explicitement dans les build settings
- **Passer à iOS 15+** minimum (supprimer ancien support)
- **Activer WMO** (Whole Module Optimization) pour Release

---

## Ordre d'Exécution

1. → 2. → 4. → 3. → 5.

La catégorie 1 est indispensable avant tout déploiement.
