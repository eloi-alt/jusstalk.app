# Plan d'Amélioration - CloakyApp

Cinq catégories pour optimiser l'app, dans l'ordre d'exécution recommandé.

---

## 1. Correction Bugs Bloquants

Ces items bloquent la mise en production. Rien d'autre ne doit démarrer avant que tous soient résolus.

- **Fixer la typo product ID** : `com.claokyy` → `com.cloakyy` dans StoreManager.swift, StoreKitConfig.storekit, Info.plist et entitlements — les achats ne fonctionnent JAMAIS en production sans ce fix [5 min]
- **Prix PaywallView hardcodé** : remplacer la string "Payer 4,99 €" par `product.displayPrice` retourné par StoreKit 2, avec fallback si product est nil — à faire en même temps que la typo, coût quasi nul [30 min]
- **Corriger le compteur de pages** onboarding : 4 cercles affichés mais `totalPages = 3` — aligner les deux [15 min]
- **Nettoyage repo Git** :
  - Ajouter `.DS_Store` au `.gitignore` global et supprimer les fichiers déjà trackés avec `git rm --cached **/.DS_Store` (présents à la racine ET dans CloakyApp/)
  - Supprimer les fichiers parasites à la racine : 7 PNG Gemini (5–10MB chacun) + `IMG_1304 copie copy.png` (10MB) — du bruit pur dans l'historique Git, sans impact sur l'app [10 min]

> ⚠️ Note sécurité paiement : la server-side receipt validation est délibérément absente de cette phase. StoreKit 2 avec `checkVerified()` est suffisant contre la majorité des attaques pour une app en early stage. Monter une infra backend complète avant de valider le produit est une perte de temps — ce point est déplacé en Phase 4.

---

## 2. Refactor Onboarding

- **Ajouter un bouton Skip** en haut à droite (style texte secondaire, opacity 0.7) avec handler `hasCompletedOnboarding = true` — mesure le taux de completion APRÈS ce fix avant de faire quoi que ce soit d'autre sur l'onboarding [1 jour]
- **Remplacer les cercles** par un indicateur de progression linéaire (ProgressView .linear ou custom) avec label "Page X / 4" [1 jour]
- **Créer des composants séparés** pour chaque page dans des fichiers distincts : `HeroPageView`, `DemoPageView`, `PremiumPositioningPageView`, `CTAPageView` — le fichier actuel fait 463 lignes [2 jours]
- **Passer StoreManager par injection** via `@EnvironmentObject` au lieu de `@StateObject` dupliqué dans chaque vue — injecter une seule instance au niveau App root [1 jour]
- **Lazy loading des pages** non visibles : remplacer le TabView qui charge tout simultanément par des sous-vues lazy, et remplacer `ForEach(..., id: \.self)` par des enums Hashable [2 jours]

> ⚠️ Note A/B testing : ne pas implémenter de tests A/B avant d'avoir mesuré le taux de completion post-skip button.
>
> **Données de référence :**
> - Les onboardings avec étapes skippables ont en moyenne **+25% de taux de completion** (UserIQ / Monetizely, 2025)
> - Les apps B2C devraient viser **90–95% de completion** sur l'onboarding (Adapty, 2026) — un taux de 40% signale un problème fondamental de flux, pas un problème de variante CTA
> - Un A/B test valide requiert des milliers de sessions par variante pour atteindre la significativité statistique ; avec un taux de completion actuel de 40%, le volume est insuffisant pour détecter des effets réels sans plusieurs semaines de données
> - Les indicateurs de progression visuels réduisent les drop-offs de **28%** et peuvent booster la completion de **35%** (Sidekick Interactive, 2025)
>
> **Conclusion** : le skip button + la progress bar linéaire représentent 2 jours de travail et peuvent à eux seuls faire passer la completion de 40% à ~65–70%. Mesure l'impact réel sur 2 semaines, puis investis dans une infra A/B testing seulement si tu as le volume utilisateur nécessaire.

---

## 3. Performance & Fluidité

- **Fix concurrence CacheManager** : remplacer `@unchecked Sendable` + `NSLock` par un `actor CacheManager` — c'est un vrai risque de crash concurrentiel, ne pas laisser en Phase 4 [1 jour]
- **Réduire les limites cache** : object cache 100MB → 50MB, image cache 200MB → 100MB, ajouter une politique d'expiration TTL 24h [2h]
- **Déplacer le processing** image en arrière-plan avec `Task.detached(priority: .userInitiated)` — ajouter aperçu basse résolution pendant le traitement, et traitement par tiles pour images > 12MP [3 jours]
- **Ajouter memoization** avec `.equatable()` sur les vues statiques, et `.drawingGroup()` sur AnimatedBackground pour composer sur GPU [1 jour]
- **Optimiser AnimatedBackground** : arrêter l'animation `.repeatForever` quand la vue n'est pas visible (`.onAppear`/`.onDisappear`) [1 jour]
- **Collecter les métriques en production** : FPS, mémoire, temps de launch, taux de completion onboarding, drop-off points [2 jours]

---

## 4. Sécurité Paiements (post-validation produit)

Cette phase est volontairement après la validation marché. StoreKit 2 protège contre l'essentiel ; la complexité backend ne se justifie qu'une fois le produit validé.

- **Server-side receipt validation** : envoyer la transaction à un endpoint backend avant d'activer l'accès premium [2 jours]
- **Gérer les états pending** correctement dans PaywallView (achat en attente de validation parentale) [1 jour]
- **Stocker les transactions** en local pour audit et permettre un accès grace period [1 jour]
- **Logging des tentatives d'achat** échouées avec messages d'erreur différenciés selon le type d'échec (réseau, annulé, déjà acheté) [1 jour]
- **Détecter jailbreak/proxy** comme anti-fraude additionnel [2 jours]

---

## 5. Allègement de l'App

- **Vectoriser les assets** : convertir AppIcon en PDF vectoriel avec `preservesVectorRepresentation` [1 jour]
- **Compresser les images** non-vectorisables avec WebP ou HEIC [1 jour]
- **Activer App Thinning** explicitement dans les build settings [1 jour]
- **Passer à iOS 15+** comme deployment target minimum — supprime le support iOS 11–14 [30 min]
- **Activer WMO** (Whole Module Optimization) pour les builds Release [30 min]
- **Strip Debug Symbols During Copy** : YES en Release [15 min]

---

## Ordre d'Exécution

**1 → 2 → 3 → 4 → 5**

La catégorie 1 est indispensable avant tout déploiement.  
La catégorie 4 (server-side validation) est intentionnellement après la 3 — valider le produit d'abord, puis sécuriser l'infrastructure.
