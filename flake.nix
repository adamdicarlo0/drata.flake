{
  description = "The Drata Agent is a lightweight tray application that runs in the background, reporting read-only data to Drata about the machine's state for compliance tracking.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;

        pname = "drata-agent";
        version = "3.9.0";
      in
      {
        packages.${pname} = with pkgs; stdenv.mkDerivation rec {
          inherit pname version;

          src = if isDarwin then
            fetchurl {
              url = "https://github.com/drata/agent-releases/releases/download/${version}/Drata-Agent-mac.dmg";
              hash = "sha256-GjElyxMjCXD6ruqrs0X/QyfUTH1MgIa2igieaYP6PtM=";
            }
          else 
            fetchurl {
              url = "https://github.com/drata/agent-releases/releases/download/${version}/Drata-Agent-linux.deb";
              hash = "sha256-eNs+iHsUAkz1uxJ8zA84lSGlYsS6jKxYf+FaB2qiSiw=";
            };

          nativeBuildInputs = [
            makeWrapper
          ] ++ pkgs.lib.optionals isDarwin [
            undmg
          ] ++ pkgs.lib.optionals isLinux [
              autoPatchelfHook
              dpkg
            ];

          buildInputs = pkgs.lib.optionals isLinux [
            alsa-lib
            at-spi2-atk
            at-spi2-core
            atk
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            gdk-pixbuf
            glib
            gsettings-desktop-schemas
            gtk3
            hicolor-icon-theme
            libappindicator-gtk3
            libdbusmenu
            libdbusmenu-gtk3
            libdrm
            libnotify
            libxkbcommon
            mesa
            nspr
            nss
            pango
            systemd
            xdg-utils
            libx11
            libxscrnsaver
            libxcomposite
            libxcursor
            libxdamage
            libxext
            libxfixes
            libxi
            libxrandr
            libxrender
            libxtst
            libxcb
            libxshmfence
          ];

          sourceRoot = if isDarwin then "." else null;

          unpackPhase = if isDarwin then ''
            undmg $src
          '' else ''
              dpkg-deb -x $src .
          '';

          installPhase = if isDarwin then ''
            mkdir -p $out/Applications
            cp -r "Drata Agent.app" $out/Applications/

            mkdir -p $out/bin
            makeWrapper "$out/Applications/Drata Agent.app/Contents/MacOS/Drata Agent" \
              $out/bin/drata-agent
          '' else ''
            mkdir -p $out/bin
            cp -r opt/Drata\ Agent $out/lib
            cp -r usr/share $out/share || true

            makeWrapper "$out/lib/drata-agent" $out/bin/drata-agent \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
              --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}" \
              --set-default XDG_DATA_DIRS "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS" \
              --suffix XDG_DATA_DIRS : "$out/share" \
              --suffix XDG_DATA_DIRS : "${pkgs.hicolor-icon-theme}/share"

            if [ -f $out/share/applications/drata-agent.desktop ]; then
              substituteInPlace $out/share/applications/drata-agent.desktop \
                --replace "/opt/Drata Agent/drata-agent" "$out/bin/drata-agent"
            fi
          '';

          meta = with pkgs.lib; {
            description = "Lightweight tray application for compliance tracking (unofficial binary release)";
            homepage = "https://github.com/drata/drata-agent";
            license = licenses.asl20;
            platforms = [ "x86_64-linux" ];
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
          };
        };

        packages.default = self.packages.${system}.${pname};
      });
}
