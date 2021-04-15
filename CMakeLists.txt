cmake_minimum_required(VERSION 3.10)

# set the project name
project(BR-Nib)

# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# add the executable
add_executable(mol2filter src/mol2filter.cpp)
add_executable(mol2split src/mol2split.cpp)
add_executable(smiles2train src/smiles2train.cpp)

install(TARGETS mol2filter mol2split smiles2train DESTINATION bin)
install(PROGRAMS brutenib.sh DESTINATION bin)
