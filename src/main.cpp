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
