// Copyright 2019 Jukka Lehtonen
// GPL-3.0-or-later

#include <fstream>
#include <string>

int main( int argc, char ** argv )
{
  if ( argc == 3 )
  {
    int X = std::stoi( argv[2], nullptr, 10 );
    if ( X < 1 ) X = 1;
    std::ifstream base( argv[1] );
    size_t N {1};
    std::ofstream part( std::string("part") + std::to_string(N) + ".mol2" );
    std::string line;
    int count = -1;
    while ( std::getline( base, line ) )
    {
      if ( std::string::npos != line.find( "MOLECULE" ) )
      {
        ++count;
        if ( count == X )
        {
          count = 0;
          ++N;
          part.close();
          part.open( std::string("part") + std::to_string(N) + ".mol2" );
        }
      }
      part << line << '\n';
    }
  }
}
