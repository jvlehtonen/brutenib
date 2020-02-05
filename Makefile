CPPFLAGS=-std=c++11 -Wall -Wextra

all          : mol2split smiles2train
smiles2train : smiles2train.cpp
mol2split    : mol2split.cpp
