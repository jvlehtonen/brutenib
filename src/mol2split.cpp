// MIT License
//
// Copyright (c) 2019 Jukka V. Lehtonen (jukka.lehtonen@abo.fi)
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
