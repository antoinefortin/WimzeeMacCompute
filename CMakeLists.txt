cmake_minimum_required(VERSION 3.21)
project(WimzeeMacCompute CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(glfw3 CONFIG REQUIRED)
find_package(glad CONFIG REQUIRED)
find_package(glm CONFIG REQUIRED)

add_executable(${PROJECT_NAME} src/main.cpp)

target_link_libraries(${PROJECT_NAME} PRIVATE
    glfw
    glad::glad
    glm::glm
)

if(APPLE)
    target_link_libraries(${PROJECT_NAME} PRIVATE "-framework OpenGL")
endif()
