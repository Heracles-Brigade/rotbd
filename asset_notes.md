
### Root Paths
* `src` game ingestable source files
* `dev` non-game-ingestable files and leftovers
* `src15` files needed for 1.5 compatibility (omit from Redux build)

### Sub-Paths
> Note, some file descriptions in sub-path might apply to files in `dev`, but most are for files in `src`.
* `asset_overrides` Replacements for stock assets
  * `improved_terrain_normals` Improved normal maps for stock terrain textures
  * `replace_earth` todo: confirm if we want to do this, new image is lower quality
  * `skeletons`
    * `bvslf.skeleton` todo: investigate why, (should it be in BZR patch?)
    * `bvtank.skeleton` todo: investigate why, (should it be in BZR patch?)
  * `textures`
    * `bbbarr_d.dds` Vastly improved BDog Barracks (NSDF Style) texture (should this be in BZR patch?)
* `world`
  * `jupiter`
    * `io`
      * `iojovian.*` new sky sprite for Jupiter from Io
* `objects`
  * `american`
    * `abtowe`
      * `abtowe02.inf` missing from stock
      * `abtowe03.inf` missing from stock
    * `abbarr`
      * `abbarx.*` *?*
  * `bdog`
    * `bvmtnk` Goliath
      * `bdm*.geo` *core*
      * `bvmtnk*` *core*
  * `soviet`
    * `svmtnk` Mammoth
      * `svmamm.odf` Possibly vestigian, listed in `b_rbdsov.odf` but nowhere else? (consider repurposing for extra-large version)
      * `smm*.geo` *core*
      * `svmtnk*` *core*
      * `mammoth.lua` old mammoth script, needs rewrite if used
    * `sbspow`
      * `sbspowg.*` Special power for `rbdnew01`
  * `hadean`
    * `hvngrd` Vanguard
    * `hbbird` Relic: Stymphalian Bird (Sigma3)
    * `hbcham` Relic: Hadean Chamber (Tuggable)
    * `hbcore` Relic: Hadean Data Core (Tuggable)
    * `hbgate` Relic: Hadean Gateway
    * `hblaba` Relic: Hadean Labs A
  * `other`
    * `apcamr`
      * `apcmri` Unkillable (why? we can do this with script)
    * `apwrck`
      * `apwrckz` 200 cost 2000000 damage
* `weapons`
  * `mammoth` Vestigial? Mammoth Weapons
    * `gXinigun.odf` Minigun
    * `gXinisov.odf` Soviet Minigun (used by `svmamm`)
    * `gXlast.odf` Blast
    * `gXolt.odf` Bolt Buddy
    * `gXtstab.odf` AT-Stabber (used by `svmamm`)
    * `gXummy.odf` Paintball
  * `cannon`
    * `fireball` Fireball Plasma Bomb
    * `rpg` RPG (Only used in "baseline" build, kept here for now)
    * `vangbolt` Ripper Bolt Cannon
* `mission`
  * `rbdnew01`
  * `rbdnew03`
  * `rbdnew04`
  * `rbdnew05`
  * `rbdnew07`
  * `rbdnew08`
  * `rbdnew09`
  * `rbdnew10`
* `interface`
  * `build_lists`
    * `build.odf` Stock build list override
    * `build_bd.odf` RotBD Build List
    * `b_rbdnt.odf` Misc
    * `b_rbddog.odf` Shaw's Dogs
    * `b_rbdsov.odf` Soviet
    * `b_rbdamr.odf` American
    * `b_rbdhad.odf` Hadean
  * `msnbrfbd_center.png` Campaign Background


### Aside
`rotbd.sta` has a reticule for a rocket that is used by the pilot `buser23` which is only used in the baseline maps `bdmisn23` and `bdmisn24`