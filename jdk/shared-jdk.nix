# TODO find a way of directly overriding from https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/compilers/openjdk/darwin/11.nix

{ stdenv, fetchurl, unzip, setJavaClassPath, freetype, jdk-name, jdk-sha }:
let
  jce-policies = fetchurl {
    # Ugh, unversioned URLs... I hope this doesn't change often enough to cause pain before we move to a Darwin source build of OpenJDK!
    url    = "http://cdn.azul.com/zcek/bin/ZuluJCEPolicies.zip";
    sha256 = "0nk7m0lgcbsvldq2wbfni2pzq8h818523z912i7v8hdcij5s48c0";
  };

  jdk = stdenv.mkDerivation rec {
    name = "${jdk-name}";

    src = fetchurl {
      url = "https://cdn.azul.com/zulu/bin/${name}-macosx_x64.tar.gz";
      sha256 = "${jdk-sha}";
      curlOpts = "-H Referer:https://www.azul.com/downloads/zulu/zulu-mac/";
    };

    buildInputs = [ unzip freetype ];

    installPhase = ''
      mkdir -p $out
      mv * $out

      unzip ${jce-policies}
      mv -f ZuluJCEPolicies/*.jar $out/lib/security/

      # jni.h expects jni_md.h to be in the header search path.
      ln -s $out/include/darwin/*_md.h $out/include/

      if [ -f $out/LICENSE ]; then
        install -D $out/LICENSE $out/share/zulu/LICENSE
        rm $out/LICENSE
      fi
    '';

    preFixup = ''
      # Propagate the setJavaClassPath setup hook from the JDK so that
      # any package that depends on the JDK has $CLASSPATH set up
      # properly.
      mkdir -p $out/nix-support
      printWords ${setJavaClassPath} > $out/nix-support/propagated-build-inputs

      install_name_tool -change /usr/X11/lib/libfreetype.6.dylib ${freetype}/lib/libfreetype.6.dylib $out/lib/libfontmanager.dylib

      # Set JAVA_HOME automatically.
      cat <<EOF >> $out/nix-support/setup-hook
      if [ -z "\$JAVA_HOME" ]; then export JAVA_HOME=$out; fi
      EOF
    '';

    passthru = {
      home = jdk;
    };

    meta.platforms = stdenv.lib.platforms.darwin;

  };
in jdk

