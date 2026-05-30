#!/bin/sh
# setup-opengl.sh — Setup complet d'un projet OpenGL sur macOS (vcpkg + CMake + VS Code).
#
# Ce que fait le script :
#   1. Verifie les outils (CLT, clang, cmake, ninja)
#   2. Installe vcpkg dans ~/dev/vcpkg si absent + bootstrap
#   3. Ajoute VCPKG_ROOT a ~/.zshrc si absent
#   4. Genere les fichiers projet : vcpkg.json, CMakeLists.txt, CMakePresets.json,
#      .vscode/settings.json, .vscode/launch.json, .gitignore, src/main.cpp
#
# A lancer DANS le repertoire de ton projet :  sh setup-opengl.sh
#
# Le script ne PURGE rien : il ne reecrit pas un fichier qui existe deja
# (sauf si tu passes --force).

set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
warn() { printf "${YELLOW}[!]${NC}    %s\n" "$1"; }
err()  { printf "${RED}[X]${NC}    %s\n" "$1"; }
step() { printf "\n${GREEN}==>${NC} %s\n" "$1"; }

FORCE=0
[ "$1" = "--force" ] && FORCE=1

PROJECT_NAME=$(basename "$(pwd)")
VCPKG_DIR="$HOME/dev/vcpkg"

# Ecrit un fichier seulement s'il n'existe pas (ou si --force).
# $1 = chemin, le contenu vient de stdin.
write_file() {
    target="$1"
    if [ -f "$target" ] && [ "$FORCE" -eq 0 ]; then
        warn "$target existe deja (garde tel quel ; --force pour ecraser)"
        cat > /dev/null   # vide le stdin
    else
        cat > "$target"
        ok "$target genere"
    fi
}

# ---------------------------------------------------------------------------
step "1. Verification des outils"
# ---------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
    err "Command Line Tools manquants. Lance : xcode-select --install (puis relance ce script)"
    exit 1
fi
ok "Command Line Tools : $(xcode-select -p)"
command -v clang++ >/dev/null 2>&1 && ok "clang++ : $(clang++ --version | head -n1)" || { err "clang++ absent"; exit 1; }
command -v cmake   >/dev/null 2>&1 && ok "cmake   : $(cmake --version | head -n1)"   || { err "cmake absent -> brew install cmake"; exit 1; }
if command -v ninja >/dev/null 2>&1; then
    ok "ninja   : $(ninja --version)"
else
    warn "ninja absent -> installe-le : brew install ninja"
    warn "Le script continue mais la config CMake utilisera Ninja, donc installe-le avant."
fi

# ---------------------------------------------------------------------------
step "2. vcpkg"
# ---------------------------------------------------------------------------
if [ -x "$VCPKG_DIR/vcpkg" ]; then
    ok "vcpkg deja installe et bootstrappe : $VCPKG_DIR"
elif [ -d "$VCPKG_DIR" ]; then
    warn "Repertoire vcpkg present mais pas bootstrappe -> bootstrap..."
    "$VCPKG_DIR/bootstrap-vcpkg.sh" -disableMetrics
    ok "vcpkg bootstrappe"
else
    warn "vcpkg absent -> clonage dans $VCPKG_DIR"
    mkdir -p "$HOME/dev"
    git clone https://github.com/microsoft/vcpkg "$VCPKG_DIR"
    "$VCPKG_DIR/bootstrap-vcpkg.sh" -disableMetrics
    ok "vcpkg installe et bootstrappe"
fi

# ---------------------------------------------------------------------------
step "3. VCPKG_ROOT dans ~/.zshrc"
# ---------------------------------------------------------------------------
if grep -q 'export VCPKG_ROOT=' "$HOME/.zshrc" 2>/dev/null; then
    ok "VCPKG_ROOT deja dans ~/.zshrc"
else
    printf '\n# vcpkg (ajoute par setup-opengl.sh)\nexport VCPKG_ROOT="%s"\n' "$VCPKG_DIR" >> "$HOME/.zshrc"
    ok "VCPKG_ROOT ajoute a ~/.zshrc"
fi
# Pour la session courante du script
export VCPKG_ROOT="$VCPKG_DIR"

# ---------------------------------------------------------------------------
step "4. Generation des fichiers projet"
# ---------------------------------------------------------------------------
mkdir -p src .vscode

# --- vcpkg.json ---
write_file "vcpkg.json" <<EOF
{
  "name": "$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-')",
  "version": "0.1.0",
  "dependencies": [
    "glfw3",
    "glad",
    "glm"
  ]
}
EOF

# --- CMakeLists.txt ---
write_file "CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.21)
project($PROJECT_NAME CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)  # pour IntelliSense VS Code

find_package(glfw3 CONFIG REQUIRED)
find_package(glad CONFIG REQUIRED)
find_package(glm CONFIG REQUIRED)

add_executable(\${PROJECT_NAME} src/main.cpp)

target_link_libraries(\${PROJECT_NAME} PRIVATE
    glfw
    glad::glad
    glm::glm
)

if(APPLE)
    target_link_libraries(\${PROJECT_NAME} PRIVATE "-framework OpenGL")
endif()
EOF

# --- CMakePresets.json ---
write_file "CMakePresets.json" <<EOF
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default",
      "displayName": "Default (vcpkg + Ninja)",
      "generator": "Ninja",
      "binaryDir": "\${sourceDir}/build",
      "toolchainFile": "$VCPKG_DIR/scripts/buildsystems/vcpkg.cmake"
    }
  ]
}
EOF

# --- .vscode/settings.json ---
write_file ".vscode/settings.json" <<EOF
{
  "cmake.configureSettings": {
    "CMAKE_TOOLCHAIN_FILE": "$VCPKG_DIR/scripts/buildsystems/vcpkg.cmake"
  },
  "C_Cpp.default.compileCommands": "\${workspaceFolder}/build/compile_commands.json"
}
EOF

# --- .vscode/launch.json ---
write_file ".vscode/launch.json" <<EOF
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug",
      "type": "cppdbg",
      "request": "launch",
      "program": "\${workspaceFolder}/build/$PROJECT_NAME",
      "cwd": "\${workspaceFolder}",
      "MIMode": "lldb"
    }
  ]
}
EOF

# --- .gitignore ---
write_file ".gitignore" <<EOF
/build/
/vcpkg_installed/
.DS_Store
EOF

# --- src/main.cpp (triangle de base ou hello window) ---
write_file "src/main.cpp" <<'EOF'
// main.cpp — Fenetre OpenGL minimale : ouvre une fenetre, clear bleu, boucle.
// macOS plafonne a OpenGL 4.1 -> on demande un contexte 4.1 core.

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <cstdio>

int main() {
    if (!glfwInit()) {
        std::fprintf(stderr, "glfwInit a echoue\n");
        return 1;
    }

    // macOS : 4.1 core est le maximum dispo nativement.
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);  // requis sur macOS

    GLFWwindow* window = glfwCreateWindow(800, 600, "WimzeeMac", nullptr, nullptr);
    if (!window) {
        std::fprintf(stderr, "Creation fenetre a echoue\n");
        glfwTerminate();
        return 1;
    }
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);  // vsync

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::fprintf(stderr, "Chargement GLAD a echoue\n");
        return 1;
    }

    std::printf("OpenGL %s\n", glGetString(GL_VERSION));

    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();
        if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
            glfwSetWindowShouldClose(window, GLFW_TRUE);

        glClearColor(0.1f, 0.2f, 0.35f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glfwSwapBuffers(window);
    }

    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
EOF

# ---------------------------------------------------------------------------
step "Termine."
# ---------------------------------------------------------------------------
echo
ok "Projet '$PROJECT_NAME' pret."
echo
echo "Prochaines etapes :"
echo "  1. Recharge ton shell pour VCPKG_ROOT :  source ~/.zshrc"
echo "  2. Configure le build (vcpkg telecharge glfw3/glad/glm, ~quelques minutes la 1re fois) :"
echo "       cmake -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=\$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
echo "  3. Build :"
echo "       cmake --build build"
echo "  4. Lance :"
echo "       ./build/$PROJECT_NAME"
echo
echo "  Dans VS Code (installe les extensions 'CMake Tools' et 'C/C++') :"
echo "       code .        puis  Cmd+Shift+P -> CMake: Configure -> CMake: Build -> Run"