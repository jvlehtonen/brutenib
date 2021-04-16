// MIT License
//
// Copyright (c) 2020 Jukka V. Lehtonen (jukka.lehtonen@abo.fi)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

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
