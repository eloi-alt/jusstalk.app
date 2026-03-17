#!/bin/bash

echo "🛠 Cloaky - Génération du projet Xcode"
echo "======================================"
echo ""

# Vérifier si Homebrew est installé
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew n'est pas installé."
    echo "📥 Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Vérifier si XcodeGen est installé
if ! command -v xcodegen &> /dev/null; then
    echo "📥 Installation de XcodeGen..."
    brew install xcodegen
else
    echo "✅ XcodeGen est déjà installé"
fi

echo ""
echo "🔨 Génération du fichier Cloak.xcodeproj..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Projet Xcode généré avec succès!"
    echo ""
    echo "🚀 Pour ouvrir le projet :"
    echo "   open Cloak.xcodeproj"
    echo ""
    echo "Ou double-cliquez sur le fichier Cloak.xcodeproj dans le Finder."
else
    echo ""
    echo "❌ Erreur lors de la génération du projet"
    exit 1
fi
