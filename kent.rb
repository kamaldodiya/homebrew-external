# Creates the Kent Source with libraries and include paths

class Kent < Formula
  desc "UCSC Genome Browser source tree"
  homepage "https://genome.ucsc.edu/"
  url "https://github.com/ucscGenomeBrowser/kent/archive/v335_base.tar.gz"
  version "v335"
  sha256 "19816b701e3fa947a80714a80197d5148f2f699d56bfa4c1d531c28d9b859748"
  revision 1

  # tag origin homebrew-science
  # tag derived

  option "with-connector-c", "Build with connector-c dependency. Otherwise we depend on mysql-client"
  option "with-web-patches", "Build with Ensembl Web patches. Bio::DB::BigFile needs patching too if it is going to use this kent installation. For more information, see: https://github.com/Ensembl/homebrew-web/tree/master/patches/kent"



  depends_on "ncurses"
  
  # we use the Ensembl mysql-client compile. You can use 
  # mysql-connector-c brings in the MySQL libs for less effort. YMMV
  
  if build.with? "connector-c"
    depends_on "mysql-connector-c"
  else
    depends_on "kamaldodiya/external/percona-client"
  end
  
  depends_on "libpng"
  depends_on "openssl" 


  patch :DATA


  if build.with? "web-patches"
    patch do
      url "https://raw.githubusercontent.com/Ensembl/homebrew-web/master/patches/kent/build.patch"
      sha256 "3bb1aef9e8ca01812310e61044a0a59c6b437af161bfbfeb0b843ea1690cadf8"
    end

    patch do
      url "https://raw.githubusercontent.com/Ensembl/homebrew-web/master/patches/kent/main.patch"
      sha256 "e8a26152d0a99d7112ffda274768fae39085541654295365b21331e86e19e9bc"
    end
  end


  def install
    libpng = Formula["libpng"]
    if build.with? "connector-c"
      mysql = Formula["mysql-connector-c"]
    else
      mysql = Formula["kamaldodiya/external/percona-client"]
    end
    openssl = Formula["openssl"]

    machtype = `uname -m`.chomp

    args = ["BINDIR=#{bin}", "SCRIPTS=#{bin}", "PREFIX=#{prefix}", "USE_SSL=1", "SSL_DIR=#{openssl.opt_prefix}"]
    args << "MACHTYPE=#{machtype}"
    args << "CFLAGS=-fPIC"
    args << "PNGLIB=-L#{libpng.opt_lib} -lpng -lz"
    args << "PNGINCL=-I#{libpng.opt_include}"

    if mysql.installed?
      args << "MYSQLINC=#{mysql.opt_include}/mysql"
      args << "MYSQLLIBS=-lmysqlclient -lz"
    end

    inreplace "src/inc/common.mk", "CFLAGS=", "CFLAGS=-fPIC"
    #inreplace "src/htslib/sam.c", "int magic_len; // has_EOF;", "int magic_len, has_EOF;"

    cd build.head? ? "src" : "src" do
      system "make", "userApps", *args
      system "make", "install", *args
    end

    cd "src/utils/cpgIslandExt" do
      system "make", "compile"
      bin.install "cpg_lh"
    end

    cd "src/hg/mouseStuff/axtBest" do
      system "make", "compile"
      bin.install 'axtBest'
    end

    cd "src/utils/faToNib" do
      system "make", "compile"
      bin.install 'faToNib'
    end
    
    cd bin do
      mv "calc", "kent-tools-calc"
    end

    kent_bash = (etc+'kent.bash')
    File.delete(kent_bash) if File.exist?(kent_bash)
    (kent_bash).write <<~EOF
      export MACHTYPE=#{machtype}
      export KENT_SRC=#{prefix}
    EOF
  end

  
  test do
    (testpath/"test.fa").write <<~EOF
      >test
      ACTG
    EOF
    system "#{bin}/faOneRecord test.fa test > out.fa"
    compare_file "test.fa", "out.fa"
  end

end
__END__
diff --git a/src/makefile b/src/makefile
index bb2d162..849c687 100644
--- a/src/makefile
+++ b/src/makefile
@@ -187,3 +187,13 @@ doc-beta: ${DOCS_LIST:%=%.docbeta}
 doc-install: ${DOCS_LIST:%=%.docinstall}
 %.docinstall:
 	cd $* && $(MAKE) install
+
+.PHONY: install
+install:
+ifndef PREFIX
+	$(error PREFIX is not set)
+endif
+	${MKDIR} $(PREFIX)/inc
+	${MKDIR} $(PREFIX)/lib/${MACHTYPE}
+	cp inc/*.h $(PREFIX)/inc/.
+	cp lib/${MACHTYPE}/*.a $(PREFIX)/lib/${MACHTYPE}/.
