#!/bin/sh
# check-env.sh — Verifie l'environnement de build (vcpkg + CMake + toolchain) sur macOS.
# Usage : sh check-env.sh

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # reset

ok()   { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
warn() { printf "${YELLOW}[!]${NC}    %s\n" "$1"; }
err()  { printf "${RED}[X]${NC}    %s\n" "$1"; }

problems=0

echo "=== Diagnostic environnement build OpenGL/vcpkg/CMake ==="
echo

# --- Xcode Command Line Tools (fournit clang) ---
if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode Command Line Tools installes ($(xcode-select -p))"
else
    err "Xcode Command Line Tools manquants -> lance : xcode-select --install"
    problems=$((problems + 1))
fi

# --- Compilateur C++ ---
if command -v clang++ >/dev/null 2>&1; then
    ok "clang++ trouve ($(clang++ --version | head -n1))"
else
    err "clang++ introuvable (depend des Command Line Tools)"
    problems=$((problems + 1))
fi

# --- CMake ---
if command -v cmake >/dev/null 2>&1; then
    ok "cmake trouve ($(cmake --version | head -n1))"
else
    err "cmake introuvable -> brew install cmake"
    problems=$((problems + 1))
fi

# --- Ninja (recommande) ---
if command -v ninja >/dev/null 2>&1; then
    ok "ninja trouve ($(ninja --version))"
else
    warn "ninja introuvable (optionnel mais recommande) -> brew install ninja"
fi

# --- VCPKG_ROOT defini ? ---
if [ -n "$VCPKG_ROOT" ]; then
    ok "VCPKG_ROOT defini : $VCPKG_ROOT"

    # Le repertoire existe-t-il ?
    if [ -d "$VCPKG_ROOT" ]; then
        ok "Le repertoire VCPKG_ROOT existe"
    else
        err "VCPKG_ROOT pointe vers un repertoire inexistant : $VCPKG_ROOT"
        problems=$((problems + 1))
    fi

    # Le toolchain file existe-t-il ?
    TOOLCHAIN="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
    if [ -f "$TOOLCHAIN" ]; then
        ok "Toolchain vcpkg trouve : $TOOLCHAIN"
    else
        err "Toolchain vcpkg INTROUVABLE : $TOOLCHAIN"
        problems=$((problems + 1))
    fi

    # Le binaire vcpkg existe-t-il (bootstrap fait) ?
    if [ -x "$VCPKG_ROOT/vcpkg" ]; then
        ok "Binaire vcpkg present (bootstrap fait)"
    else
        err "Binaire vcpkg absent -> lance : $VCPKG_ROOT/bootstrap-vcpkg.sh"
        problems=$((problems + 1))
    fi
else
    err "VCPKG_ROOT n'est PAS defini"
    echo "       -> Ajoute a ton ~/.zshrc :  export VCPKG_ROOT=\"\$HOME/dev/vcpkg\""
    echo "       -> Puis :  source ~/.zshrc"
    problems=$((problems + 1))
fi

# --- vcpkg dans le PATH (optionnel) ---
if command -v vcpkg >/dev/null 2>&1; then
    ok "vcpkg dans le PATH ($(command -v vcpkg))"
else
    warn "vcpkg pas dans le PATH (pas bloquant si VCPKG_ROOT est bon)"
fi

# --- Fichiers projet attendus dans le repertoire courant ---
echo
echo "--- Fichiers du projet (repertoire courant) ---"
for f in CMakeLists.txt vcpkg.json; do
    if [ -f "$f" ]; then
        ok "$f present"
    else
        warn "$f absent dans $(pwd)"
    fi
done

# --- Resume ---
echo
if [ "$problems" -eq 0 ]; then
    printf "${GREEN}Tout est bon. Tu peux configurer :${NC}\n"
    echo "  rm -rf build"
    echo "  cmake -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=\$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
else
    printf "${RED}%d probleme(s) a corriger avant de configurer le build.${NC}\n" "$problems"
fi

exit "$problems"