cmake_minimum_required(VERSION 3.10)

# set the project name
project(BR-Nib)

# specify the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_CXX_EXTENSIONS False)
set(CMAKE_BUILD_TYPE Release)

# add the executable
add_executable(mol2filter src/mol2filter.cpp)
add_executable(mol2split src/mol2split.cpp)
add_executable(smiles2train src/smiles2train.cpp)

install(TARGETS mol2filter mol2split smiles2train DESTINATION bin)
install(PROGRAMS brutenib br_oneshot br_nibscore.sh br_run_rocker.sh DESTINATION bin)
install(FILES br_trim-shaep.awk DESTINATION bin)
