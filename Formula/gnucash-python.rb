class GnucashPython < Formula
  desc "GnuCash engine library with Python bindings, without the GUI"
  homepage "https://www.gnucash.org/"
  url "https://github.com/Gnucash/gnucash/releases/download/5.17/gnucash-5.17.tar.bz2"
  sha256 "3d18a88f5b8230f01e04c2d2d73bf95e7dcd3bf8d8cee6ffa54bb24dee58b85f"
  license "GPL-2.0-or-later"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    root_url "https://github.com/allen-ziegenfus/homebrew-gnucash/releases/download/gnucash-python-5.17"
    rebuild 1
    sha256 arm64_tahoe: "912eaaa70c1c277764f396adb910ca42c1b21c5a27db4fc2f706a7b8fe43b356"
  end

  # The official GnuCash.app cannot ship the Python bindings (Apple's
  # notarization will not link a libpython from outside the bundle), and
  # Homebrew's `gnucash` cask is that app. This builds only libgnucash and
  # the `gnucash` Python module, which read and write the same XML books as
  # the app. WITH_GNUCASH=OFF is what keeps GTK and WebKitGTK out of it.

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "swig" => :build
  depends_on "bdw-gc"
  depends_on "boost"
  depends_on "gettext"
  depends_on "glib"
  depends_on "guile"
  depends_on "icu4c@78"
  depends_on "libxml2"
  depends_on "libxslt"
  # Linux distributions already ship these bindings (python3-gnucash).
  depends_on :macos
  depends_on "python@3.13"

  uses_from_macos "zlib"

  # GnuCash compiles googletest from SOURCE and refuses to configure without
  # it, even when the tests are not run.
  resource "googletest" do
    url "https://github.com/google/googletest/archive/refs/tags/v1.15.2.tar.gz"
    sha256 "7b42b4d6ed48810c5362c265a17faebe90dc2373c885e5216439d37927f02926"
  end

  def python3
    formula_opt_libexec("python@3.13")/"bin/python"
  end

  def install
    # Extension modules must not link libpython itself: the interpreter
    # that imports them provides those symbols, and a hard link ties the
    # module to one exact Python build.
    inreplace "bindings/python/CMakeLists.txt", "${Python3_LIBRARIES}",
              "-Wl,-undefined,dynamic_lookup"

    # GnuCash joins its two library directories with ":" into ONE rpath,
    # which macOS reads as a single nonexistent directory. Give it two.
    inreplace "CMakeLists.txt",
              'set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_FULL_LIBDIR}:${CMAKE_INSTALL_FULL_LIBDIR}/gnucash")',
              "set(CMAKE_INSTALL_RPATH \"#{opt_lib};#{opt_lib}/gnucash\")"

    (buildpath/"googletest").install resource("googletest")
    ENV["GTEST_ROOT"] = buildpath/"googletest"
    icu = Formula["icu4c@78"]

    args = %W[
      -DWITH_GNUCASH=OFF
      -DWITH_PYTHON=ON
      -DWITH_SQL=OFF
      -DWITH_AQBANKING=OFF
      -DWITH_OFX=OFF
      -DPython3_EXECUTABLE=#{python3}
      -DGTEST_ROOT=#{buildpath}/googletest
      -DCMAKE_PREFIX_PATH=#{icu.opt_prefix}
      -DCMAKE_C_FLAGS=-I#{icu.opt_include}
      -DCMAKE_CXX_FLAGS=-I#{icu.opt_include}
    ]
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  def caveats
    <<~EOS
      The `gnucash` module is installed for Homebrew's Python 3.13:
        #{formula_opt_bin("python@3.13")}/python3.13 -c "import gnucash"

      Open a book only while the GnuCash app has it closed. To keep saved
      books compressed as the app does, before opening a session:
        import gnucash._sw_core_utils as cu
        cu.gnc_prefs_set_file_save_compressed(True)
    EOS
  end

  test do
    (testpath/"roundtrip.py").write <<~PY
      from gnucash import Session, SessionOpenMode, Account
      url = "xml://#{testpath}/test.gnucash"
      with Session(url, SessionOpenMode.SESSION_NEW_STORE) as s:
          book = s.book
          root = book.get_root_account()
          usd = book.get_table().lookup("CURRENCY", "USD")
          acct = Account(book)
          acct.SetName("Checking")
          acct.SetCommodity(usd)
          acct.SetNotes("closed: 2026-08-07")
          root.append_child(acct)
          s.save()
      with Session(url, SessionOpenMode.SESSION_READ_ONLY) as s:
          a = s.book.get_root_account().lookup_by_name("Checking")
          assert a.GetNotes() == "closed: 2026-08-07", a.GetNotes()
      print("ok")
    PY
    assert_match "ok", shell_output("#{python3} #{testpath}/roundtrip.py")
  end
end
