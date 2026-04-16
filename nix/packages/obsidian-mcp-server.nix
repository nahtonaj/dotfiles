{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "obsidian-mcp-server";
  version = "2.0.7";

  src = fetchFromGitHub {
    owner = "cyanheads";
    repo = "obsidian-mcp-server";
    rev = "v${version}";
    hash = "sha256-uis9pk9OnXIja8aSEaOdXhTnVzi1i+rlr6BrdOiJSDE=";
  };

  npmDepsHash = lib.fakeHash;

  npmConfigRegistry = "https://npm-proxy.dev.databricks.com/";

  buildPhase = ''
    runHook preBuild
    npx tsc
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/${pname}
    cp -r dist package.json node_modules $out/lib/node_modules/${pname}/
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/${pname}/dist/index.js $out/bin/${pname}
    chmod +x $out/lib/node_modules/${pname}/dist/index.js
    runHook postInstall
  '';

  meta = with lib; {
    description = "Obsidian Knowledge-Management MCP server for AI agents";
    homepage = "https://github.com/cyanheads/obsidian-mcp-server";
    license = licenses.asl20;
    mainProgram = "obsidian-mcp-server";
  };
}
