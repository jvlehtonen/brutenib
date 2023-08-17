// MIT License
//
// Copyright (c) 2019,2023 Jukka V. Lehtonen (jukka.lehtonen@abo.fi)
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
#include <sstream>
#include <iostream>
#include <string>
#include <filesystem>

namespace fs = std::filesystem;

void write( const std::string& name, const std::string& entry, const std::string&  outdir )
{
  const std::string prefix = outdir.empty() ? name : outdir + "/" + name;
  std::ofstream part( prefix + ".mol2" );
  part << entry << '\n';
}

void singular( std::istream& base, const std::string&  outdir )
{
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
          write( name, data, outdir );
          entry.str( "" );
        }
      }
      if ( 1 == count ) name = line;
      entry << line << '\n';
    }

    auto last = entry.str();
    if ( ! last.empty() )
    {
      write( name, last, outdir );
    }
}


void chunks( std::istream& base, int X, const std::string&  outdir )
{
  const std::string prefix = outdir.empty() ? "part" : outdir + "/part";
  const std::string ext = ".mol2";
  size_t N {1};
  std::ofstream part( prefix + std::to_string(N) + ext );
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
        part.open( prefix + std::to_string(N) + ext );
      }
    }
    part << line << '\n';
  }
  part.close();
}


void chunks_sdf( std::istream& base, int X, const std::string&  outdir )
{
  const std::string prefix = outdir.empty() ? "part" : outdir + "/part";
  const std::string ext = ".sdf";
  size_t N {1};
  std::ofstream part( prefix + std::to_string(N) + ext );
  std::string line;
  int count = -1;
  while ( std::getline( base, line ) )
  {
    part << line << '\n';
    if ( std::string::npos != line.find( "$$$$" ) )
    {
      ++count;
      if ( count == X )
      {
        count = 0;
        ++N;
        part.close();
        part.open( prefix + std::to_string(N) + ext );
      }
    }
  }
  part.close();
}


void chunks_mae( std::istream& base, int X, const std::string&  outdir )
{
  const std::string prefix = outdir.empty() ? "part" : outdir + "/part";
  const std::string ext = ".mae";
  size_t N {1};
  std::ofstream part( prefix + std::to_string(N) + ext );
  std::string line;
  int count = -1;
  while ( std::getline( base, line ) )
  {
    if ( std::string::npos != line.find( "f_m_ct " ) )
    {
      ++count;
      if ( count == X )
      {
        count = 0;
        ++N;
        part.close();
        part.open( prefix + std::to_string(N) + ext );
      }
    }
    part << line << '\n';
  }
  part.close();
}


int main( int argc, char ** argv )
{
  // argv[1]: input filename
  // argv[2]: number of molecules per output file
  // argv[3]: optional, directory to write output to
  if ( argc < 3 )
  {
    std::cout << "Usage: mol2split filename number outputdir\n\n";
    std::cout << "Reads from file 'filename'\n";
    std::cout << "Writes molecules to files, 'number' per file.\n";
    std::cout << "Name of output file is 'partN.mol2', where N starts from 1.\n";
    std::cout << "If extension of 'filename' is '.sdf', then format is assumed\n"
      "to be MDL SD file and output files will have extension '.sdf'.\n";
    std::cout << "If extension of 'filename' is '.mae', then format is assumed\n"
      "to be Scrödinger Maestro's MAE and output files will have extension '.mae'.\n";
    std::cout << "If number is 1, then output (mol2) files are named with name of molecule in it.\n";
    std::cout << "The 'outputdir' is optional, defaults to current dir.\n";
    std::cout << "Output files are written to outputdir.\n\n";
  }
  else
  {
    fs::path input = argv[1];
    fs::file_status fstat( fs::status(input) );
    if ( ! fs::exists(fstat) ||
         ! (fstat.type() == fs::file_type::regular ||
            fstat.type() == fs::file_type::symlink) )
    {
      std::cerr << "Input file '" << argv[1] << "' does not exist\n";
      return 1;
    }

    std::string outdir;
    if ( argc == 4 )
    {
      outdir = argv[3];
      fs::path list = outdir;
      fs::file_status liststat( fs::status(list) );
      if ( fs::exists(liststat) )
      {
        if ( liststat.type() != fs::file_type::directory )
        {
          std::cerr << "The '" << outdir << "' is not a directory\n";
          return 2;
        }
      }
      else
      {
        std::error_code ec;
        if ( ! fs::create_directory( list, ec ) )
        {
          std::cerr << "Creation of directory '" << outdir << "' did fail with:\n";
          std::cerr << ec.message() << '\n';
          return 3;
        }
      }
    }

    constexpr size_t SizeOfIOStreamBuffer = 1'000'000;
    static char ioBuffer [SizeOfIOStreamBuffer];
    std::ifstream base( input );
    base.rdbuf()->pubsetbuf( ioBuffer, SizeOfIOStreamBuffer );

    int X = std::stoi( argv[2], nullptr, 10 );
    if ( X < 1 ) X = 1;

    // default input is mol2-format, but extension ".sdf" is assumed to be
    // in SDF-format
    const auto extension = input.extension();
    if ( extension == ".sdf" )
    {
      chunks_sdf( base, X, outdir );
    }
    if ( extension == ".mae" )
    {
      chunks_mae( base, X, outdir );
    }
    else
    {
      if ( X == 1 )
      {
        singular( base, outdir );
      }
      else
      {
        chunks( base, X, outdir );
      }
    }
  }
}
