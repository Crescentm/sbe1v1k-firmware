{
  description = "SBE1V1K firmware build environment (FHS shell for the OpenWrt/ImmortalWrt build system)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Nix's binutils does not load GCC's LTO plugin, so archives of -flto
      # objects (e.g. host apk) end up without a symbol index and fail to
      # link. Wrap ar/nm/ranlib to always pass the plugin.
      ltoPlugin = "${pkgs.gcc.cc}/libexec/gcc/x86_64-unknown-linux-gnu/${pkgs.gcc.cc.version}/liblto_plugin.so";
      binutils-lto = pkgs.symlinkJoin {
        name = "binutils-lto";
        paths = [ pkgs.binutils ];
        postBuild = ''
          for t in ar nm ranlib; do
            rm $out/bin/$t
            printf '#!%s\nexec %s --plugin %s "$@"\n' \
              ${pkgs.runtimeShell} ${pkgs.binutils-unwrapped}/bin/$t ${ltoPlugin} \
              > $out/bin/$t
            chmod +x $out/bin/$t
          done
        '';
      };

      # The OpenWrt build system expects a conventional /usr layout, so run it
      # inside an FHS environment instead of a plain dev shell.
      openwrt-env = pkgs.buildFHSEnv {
        name = "openwrt-env";
        targetPkgs = pkgs: with pkgs; [
          bash binutils-lto bison bzip2 ccache coreutils diffutils file findutils
          flex gawk gcc gettext git gnugrep gnumake gnupatch gnused gnutar
          gzip libxslt ncurses ncurses.dev openssl openssl.dev perl pkg-config
          procps python3 python3Packages.pyelftools python3Packages.setuptools
          quilt rsync swig time unzip util-linux wget which xz zlib zlib.dev
          zstd elfutils curl
        ];
        extraOutputsToInstall = [ "dev" ];
        # Nix's hardening flags break several of OpenWrt's host tools.
        profile = ''
          export NIX_HARDENING_ENABLE=
          export FORCE_UNSAFE_CONFIGURE=1
        '';
        runScript = "bash";
      };
    in {
      packages.${system}.default = openwrt-env;
      apps.${system}.default = {
        type = "app";
        program = "${openwrt-env}/bin/openwrt-env";
      };
    };
}
