{ debugImport ? false }:

let
  debugPath = p: if debugImport then builtins.trace "using config '${p}'" p else p;
  isAbs = p: (builtins.substring 0 1 p) == "/";
  toAbs = p: if isAbs p then p else (builtins.getEnv "PWD") + "/" + p;
  okPath = p: p != "" && builtins.pathExists (toAbs p);

  buildersFile = builtins.getEnv "NIX_BUILDERS_CONFIG";
  searchBuildersFile = builtins.tryEval <builders-config>;
  xdgBuildersFile =
    let
      homeDir = builtins.getEnv "HOME";
      xdgConfig = builtins.getEnv "XDG_CONFIG_HOME";
      xdgConfig' = if (isAbs xdgConfig && okPath xdgConfig) then xdgConfig else homeDir + "/.config";
    in
    toAbs (xdgConfig' + "/nixb/builders.nix");
in
if okPath buildersFile
then import (debugPath (toAbs buildersFile))
else
  if searchBuildersFile.success
  then import (debugPath (toString searchBuildersFile.value)) # toString to avoid copying file into the store
  else
    if okPath xdgBuildersFile
    then import (debugPath xdgBuildersFile)
    else [ ]
