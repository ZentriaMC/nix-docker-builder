{ builders ? null, throwIfNone ? false, debugImport ? false, noImpure ? false }:

let
  mkBuilder =
    let
      nullOr = e: v: if v == null then e else v;
      dash = v: if v == null then "-" else toString v;
      dashList = v: if (v == null || v == [ ]) then "-" else builtins.concatStringsSep "," v;
    in
    { hostName
    , system ? null
    , systems ? null
    , sshUser ? null
    , sshKey ? null
    , maxJobs ? null
    , speedFactor ? null
    , mandatoryFeatures ? null
    , supportedFeatures ? null
    , publicHostKey ? null
    }:
      assert (hostName != null && hostName != "");
      builtins.concatStringsSep " " [
        (if sshUser != null then "${sshUser}@${hostName}" else hostName)
        (nullOr (dashList systems) system)
        (dash sshKey)
        (toString (nullOr 1 maxJobs))
        (toString (nullOr 1 speedFactor))
        (dashList ((nullOr [ ] supportedFeatures) ++ (nullOr [ ] mandatoryFeatures)))
        (dashList mandatoryFeatures)
        (dash publicHostKey)
      ];

  importedBuilders =
    if (builtins.isPath builders || builtins.isString builders)
    then import builders
    else
      if builtins.isAttrs builders
      then builders
      else
        if noImpure
        then [ ]
        else import ./impure-import.nix { inherit debugImport; };

  builders' =
    if (importedBuilders == [ ] && throwIfNone)
    then throw "Unable to find builders to import"
    else importedBuilders;
in
builtins.concatStringsSep "; " (map mkBuilder builders')
