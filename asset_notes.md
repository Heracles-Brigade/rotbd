
### Root Paths
* `src` game ingestable source files
* `dev` non-game-ingestable files and leftovers
* `src15` files needed for 1.5 compatibility (omit from Redux build)

"Universal mission files" should not be altered because they are used by both the crude port and redux.
Any customizations should be done with a new file.

### Sub-Paths
> Note, some file descriptions in sub-path might apply to files in `dev`, but most are for files in `src`.
* `asset_overrides` Replacements for stock assets
    * `compat` 1.5 compatibility
    * `improved_terrain_normals` Improved normal maps for stock terrain textures
    * `replace_earth` Moved to 1.5 only asset pool
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
        * `bvrecy`
            * `bvrecy22.odf` [rbdnew01]
        * `bvmuf`
            * `bvmuf22.odf` [rbdnew01] (new custom to solve build list order issues)
        * `bvcnst`
            * `bvcnst22.odf` [rbdnew01] (matches stock even though it shouldn't?)
    * `soviet`
        * `svmtnk` Mammoth
            * `svmamm.odf` Possibly vestigian, listed in `b_rbdsov.odf` but nowhere else? (consider repurposing for extra-large version)
            * `smm*.geo` *core*
            * `svmtnk*` *core*
            * `mammoth.lua` old mammoth script, needs rewrite if used
        * `sbspow`
            * `sbspowg.*` Special power for `rbdnew01`
        * `sbtowe`
            * `sbtowerb` Blast Gun Tower [rbdnew01]
        * `sbhang`
            * `sbhangrb.*` Hanger with Mammoth info  [rbdnew03]
        * `sbhqcp`
            * `sbhqcpa.*` Shield Control [rbdnew03]
        * `sspilo`
            * `bsuserco.odf` Black Dog pilot in CCA suit [rbdnew03]
    * `hadean`
        * `hvngrd` Vanguard
        * `hbbird` Relic: Stymphalian Bird (Sigma3)
        * `hbcham` Relic: Hadean Chamber (Tuggable)
        * `hbcore` Relic: Hadean Data Core (Tuggable)
        * `hbgate` Relic: Hadean Gateway
        * `hblaba` Relic: Hadean Labs A
        * `hbdata` Relic: (Tuggable) [rbdnew01]
    * `other`
        * `apcamr`
            * `apcmri` Unkillable (why? we can do this with script)
        * `apwrck`
            * `apwrckz` 200 cost 2000000 damage
        * `sdome`
            * `sdome.odf` Shield dome effect [rbdnew03]
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
    * `rbd01` Universal mission files
        * `debriefing`
            * `bdmisn21ls.des` [rbdnew01]
            * `bdmisn21wn.des`
        * `objectives`
            * `bdmisn211.otf` [rbdnew01]
            * `bdmisn212.otf` [rbdnew01]
            * `bdmisn213.otf` [rbdnew01]
            * `bdmisn214.otf` [rbdnew01]
            * `bdmisn215.otf` [rbdnew01]
    * `rbd02` Universal mission files
        * `debriefing`
            * `bdmisn22l1.des`
            * `bdmisn22l2.des` [rbdnew01]
            * `bdmisn22wn.des` [rbdnew01]
        * `objectives`
            * `bdmisn2201.otf` [rbdnew01]
            * `bdmisn2202.otf` [rbdnew01]
            * `bdmisn2203.otf` [rbdnew01]
            * `bdmisn2204.otf` [rbdnew01]
            * `bdmisn2205.otf` [rbdnew01]
            * `bdmisn2206.otf` [rbdnew01]
            * `bdmisn2207.otf` [rbdnew01]
            * `bdmisn2208.otf` [rbdnew01]
            * `bdmisn2209.otf` [rbdnew01]
    * `rbd05` Universal mission files
        * `debriefing`
        * `objectives`
    * `rbd06` Universal mission files
        * `debriefing`
        * `objectives`
    * `rbd07` Universal mission files
        * `debriefing`
        * `objectives`
    * `rbd08` Universal mission files
        * `debriefing`
        * `objectives`
    * `rbd09` Universal mission files
        * `debriefing`
        * `objectives`
    * `rbd10` Universal mission files
        * `debriefing`
        * `objectives`
    * `rbdnew01`
        * `debriefing`
            * `rbdnew01l1.des` (for some reason these aren't used yet)
            * `rbdnew01l2.des` (for some reason these aren't used yet)
            * `rbdnew01w.des` (for some reason these aren't used yet)
    * `rbdnew03`
        * `debriefing`
            * `rbdnew03l1.des` [rbdnew03]
            * `rbdnew03l2.des` [rbdnew03]
            * `rbdnew03l3.des` [rbdnew03]
            * `rbdnew03l4.des` [rbdnew03]
            * `rbdnew03l5.des` [rbdnew03]
            * `rbdnew03wn.des` [rbdnew03]
        * `objectives`
            * `rbdnew0300.otf` [rbdnew03]
            * `rbdnew0301.otf` [rbdnew03]
            * `rbdnew0302.otf` [rbdnew03]
            * `rbdnew0303.otf` [rbdnew03]
            * `rbdnew0304.otf` [rbdnew03]
            * `rbdnew0305.otf` [rbdnew03]
            * `rbdnew0306.otf` [rbdnew03]
            * `rbdnew0307.otf` [rbdnew03]
            * `rbdnew0308.otf` [rbdnew03]
    * `rbdnew04`
        * `debriefing`
            * `rbdnew04l1.des` [rbdnew04]
            * `rbdnew04wn.des` [rbdnew04]
        * `objectives`
            * `rbdnew0401.otf` [rbdnew04]
            * `rbdnew0402.otf` [rbdnew04]
            * `rbdnew0403.otf` [rbdnew04]
            * `rbdnew0404.otf` [rbdnew04]
            * `rbdnew0405.otf` [rbdnew04]
            * `rbdnew0406.otf` [rbdnew04]
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
