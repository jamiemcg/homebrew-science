class Nglib < Formula
  desc "C++ Library of NETGEN's tetrahedral mesh generator"
  homepage "https://sourceforge.net/projects/netgen-mesher/"
  url "https://downloads.sourceforge.net/project/netgen-mesher/netgen-mesher/5.3/netgen-5.3.1.tar.gz"
  sha256 "cb97f79d8f4d55c00506ab334867285cde10873c8a8dc783522b47d2bc128bf9"
  revision 1

  bottle do
    cellar :any
    rebuild 1
    sha256 "89dcf7bde5bec5a03f8c6810cfb5848082c64f68bcdd816714f0f925b98fd3b5" => :sierra
    sha256 "6eb7f3cf7a00c68f351816970408f780264855d7d86365a427d19c81e803d606" => :el_capitan
    sha256 "60161c1f084017f4ff9ece29807988924137150e979f176d2ad4ebad3e0fd64c" => :yosemite
  end

  # These two conflict with each other, so we'll have at most one.
  depends_on "opencascade" => :recommended
  depends_on "oce" => :optional

  # Patch two main issues:
  #   Makefile - remove TCL scripts that aren't reuquired without NETGEN.
  #   Partition_Loop2d.cxx - Fix PI that was used rather than M_PI
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/20850ac/nglib/define-PI-and-avoid-tcl-install.diff"
    sha256 "1f97e60328f6ab59e41d0fa096acbe07efd4c0a600d8965cc7dc5706aec25da4"
  end

  # OpenCascase 7.x compatibility patches
  if build.with? "opencascade"
    patch do
      url "https://raw.githubusercontent.com/Homebrew/formula-patches/20850ac/nglib/occt7.x-compatibility-patches.diff"
      sha256 "c3f222b47c5da2cf8f278718dbc599fab682546380210a86a6538c3f2d9f1b27"
    end
  end

  def install
    ENV.cxx11 if build.with? "opencascade"

    cad_kernel = Formula[build.with?("opencascade") ? "opencascade" : "oce"]

    # Set OCC search path to Homebrew prefix
    inreplace "configure" do |s|
      s.gsub!(%r{(OCCFLAGS="-DOCCGEOMETRY -I\$occdir/inc )(.*$)}, "\\1-I#{cad_kernel.opt_include}/#{cad_kernel}\"")
      s.gsub!(/(^.*OCCLIBS="-L.*)( -lFWOSPlugin")/, "\\1\"") if build.with? "opencascade"
      s.gsub!(%r{(OCCLIBS="-L\$occdir/lib)(.*$)}, "\\1\"") if OS.mac?
    end

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --disable-gui
      --enable-nglib
    ]

    if build.with?("opencascade") || build.with?("oce")
      args << "--enable-occ"

      if build.with? "opencascade"
        args << "--with-occ=#{cad_kernel.opt_prefix}"

      else
        args << "--with-occ=#{cad_kernel.opt_prefix}/include/oce"

        # These fix problematic hard-coded paths in the netgen make file
        args << "CPPFLAGS=-I#{cad_kernel.opt_prefix}/include/oce"
        args << "LDFLAGS=-L#{cad_kernel.opt_prefix}/lib/"
      end
    end

    system "./configure", *args

    system "make", "install"

    # The nglib installer doesn't include some important headers by default.
    # This follows a pattern used on other platforms to make a set of sub
    # directories within include/ to contain these headers.
    subdirs = ["csg", "general", "geom2d", "gprim", "include", "interface",
               "linalg", "meshing", "occ", "stlgeom", "visualization"]
    subdirs.each do |subdir|
      (include/"netgen"/subdir).mkpath
      (include/"netgen"/subdir).install Dir.glob("libsrc/#{subdir}/*.{h,hpp}")
    end
  end

  test do
    (testpath/"test.cpp").write <<-EOS.undent
      #include<iostream>
      namespace nglib {
          #include <nglib.h>
      }
      int main(int argc, char **argv) {
          nglib::Ng_Init();
          nglib::Ng_Mesh *mesh(nglib::Ng_NewMesh());
          nglib::Ng_DeleteMesh(mesh);
          nglib::Ng_Exit();
          return 0;
      }
    EOS
    system ENV.cxx, "-Wall", "-o", "test", "test.cpp",
           "-I#{include}", "-L#{lib}", "-lnglib", "-lTKIGES"
    system "./test"
  end
end
