CPPFLAGS=-std=c++11 -Wall -Wextra

all          : mol2split mol2filter smiles2train
smiles2train : smiles2train.cpp
mol2split    : mol2split.cpp
mol2filter   : mol2filter.cpp
