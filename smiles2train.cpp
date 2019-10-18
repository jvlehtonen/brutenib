#include <fstream>
#include <iostream>
#include <random>
#include <chrono>
#include <string>
#include <vector>
#include <algorithm>

int main( int argc, char ** argv )
{
  if ( argc >= 3 )
  {
    double P = std::stod( argv[2], nullptr );
    if ( P < 0.0 or 100.0 < P ) return 1;

    std::vector<std::string> data;
    if ( argc >= 4 ) data.reserve( std::stoi( argv[3], nullptr, 10 ) );

    std::string base( argv[1] );
    std::ifstream input( base );
    std::string line;
    while ( std::getline( input, line ) )
    {
      data.emplace_back( line );
    }

    // obtain a seed from the system clock:
    unsigned seed1 = std::chrono::system_clock::now().time_since_epoch().count();
    std::mt19937 generator( seed1 );  // mt19937 is a standard mersenne_twister_engine
    // seeding MT with only one unsigned integer is flawed, but we accept that

    std::shuffle( data.begin(), data.end(), generator );

    const size_t limit = P * 0.01 * data.size();
    if ( 0 < limit )
    {
      std::ofstream train( base + "_train" );
      for ( size_t e=0; e < limit; ++e )
      {
        train << data[e]  << '\n';
      }
    }

    if ( limit < data.size() )
    {
      std::ofstream test( base + "_test" );
      for ( size_t e=limit; e < data.size(); ++e )
      {
        test << data[e]  << '\n';
      }
    }
  }
  else
  {
    std::cout << "Requires: " << argv[0] << " inputfile probability(0-100) [number of lines]\n";
  }
}
