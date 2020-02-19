#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <regex>

int main( int argc, char ** argv )
{
  if ( argc == 3 )
  {
    const std::regex query( argv[2], std::regex::extended );
    std::ifstream base( argv[1] );
    std::string line;
    int count = -1;
    std::ostringstream entry;
    std::string name;
    while ( std::getline( base, line ) )
    {
      ++count;
      if ( std::string::npos != line.find( "MOLECULE" ) )
      {
        count = 0;
        auto data = entry.str();
        if ( ! data.empty() )
        {
          if ( std::regex_search( name, query ) ) std::cout << data;
          entry.str( "" );
        }
      }
      if ( 1 == count ) name = line;
      entry << line << '\n';
    }

    auto last = entry.str();
    if ( ! last.empty() )
    {
      if ( std::regex_search( name, query ) ) std::cout << last;
    }
  }
  else
  {
    std::cout << "Usage: mol2filter filename query\n";
    std::cout << "Reads from 'filename' mol2 file\n";
    std::cout << "Writes to stdout entries that match 'query'\n";
    std::cout << "query uses extended POSIX grammar\n";
  }
}
