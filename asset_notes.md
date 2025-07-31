
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
        * `avartl`
            * `avartlf.odf` [rbdnew08]
        * `avmuf`
            * `avmuff.odf` [rbdnew08]
        * `abstor`
            * `abstorsp.*` [rbdnew09]
    * `bdog`
        * `bvapc`
            * `bvapc26.odf` [rbdnew05]
            * `bvapc09.odf` [rbdnew09]
        * `bvmtnk` Goliath
            * `bdm*.geo` *core*
            * `bvmtnk*` *core*
            * `bvmtnk30` [rbdnew10]
        * `bvrecy`
            * `bvrecy22.odf` [rbdnew01]
            * `bvrecx.odf` [rbdnew05]
            * `bvrecz.odf` [rbdnew05]
            * `bvrecy7.odf` [rbdnew07]
            * `bvrecy30.odf` [rbdnew10]
        * `bvmuf`
            * `bvmuf22.odf` [rbdnew01] (new custom to solve build list order issues)
            * `bvmuf7.odf` [rbdnew07]
            * `bvmuf30.odf` [rbdnew10]
        * `bvslf`
            * `bvslfz.odf` [rbdnew05]
            * `bvslf30.odf` [rbdnew10]
        * `bvcnst`
            * `bvcnst22.odf` [rbdnew01] (matches stock even though it shouldn't?)
            * `bvcnst7.odf` [rbdnew07]
            * `bvcnst30.odf` [rbdnew10]
        * `bblpad`
            * `ablpadx.odf` [rbdnew10]
        * `bvhaul`
            * `bvhaul30.odf` [rbdnew10]
    * `soviet`
        * `svmtnk` Mammoth
            * `svmamm.odf` Possibly vestigian, listed in `b_rbdsov.odf` but nowhere else? (consider repurposing for extra-large version)
            * `smm*.geo` *core*
            * `svmtnk*` *core* [rbdnew04]
            * `svmtnkd.*` Decoy Mammoth (only difference is a pilotName field, why?) [rbdnew04]
            * `mammoth.lua` old mammoth script, needs rewrite if used
        * `sbspow`
            * `sbspowg.*` 1500 meter range [rbdnew01]
            * `sbspow09.*` 1900 meter range [rbdnew09]
        * `sbtowe`
            * `sbtowerb` Blast Gun Tower [rbdnew01]
        * `sbhang`
            * `sbhangrb.*` Hanger with Mammoth info  [rbdnew03]
        * `sbhqcp`
            * `sbhqcpa.*` Shield Control [rbdnew03]
        * `sspilo`
            * `bsuserco.odf` Black Dog pilot in CCA suit [rbdnew03]
        * `svmuf`
            * `svmuff.odf` [rbdnew08]
        * `svartl`
            * `svartlf.odf` [rbdnew08]
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
        * `xbmbblnd`
            * `xbmbblnd.odf` Decoy Mammoth Explosion [rbdnew04]
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
            * `bdmisn21ls.des` [rbdnew01] Your orders were to investigate the Command Tower, not destroy it!
            * `bdmisn21wn.des` Well done soldier. Stopped weapon research.
        * `objectives`
            * `bdmisn211.otf` [rbdnew01]
            * `bdmisn212.otf` [rbdnew01]
            * `bdmisn213.otf` [rbdnew01]
            * `bdmisn214.otf` [rbdnew01]
            * `bdmisn215.otf` [rbdnew01]
    * `rbd02` Universal mission files
        * `debriefing`
            * `bdmisn22l1.des` You strayed too far from your base.
            * `bdmisn22l2.des` You allowed your recycler to be destroyed.
            * `bdmisn22wn.des` Excellent work. We have a base on the moon.
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
            * `bdmisn26l1.des` [rbdnew05]
            * `bdmisn26l2.des` [rbdnew05]
            * `bdmisn26wn.des` [rbdnew05]
        * `objectives`
            * `bdmisn2601.otf` [rbdnew05]
            * `bdmisn2602.otf` [rbdnew05]
            * `bdmisn2603.otf` [rbdnew05]
    * `rbd07` Universal mission files
        * `debriefing`
            * `rbd07l02.des` [rbdnew07]
            * `rbd07l03.des` [rbdnew07]
            * `rbd07l04.des` [rbdnew07]
            * `rbd07los.des` [rbdnew07]
            * `rbd07win.des` [rbdnew07]
        * `objectives`
            * `rbd0701.otf` [rbdnew07]
            * `rbd0702.otf` [rbdnew07]
            * `rbd0703.otf` [rbdnew07]
            * `rbd0704.otf` [rbdnew07]
            * `rbd0705.otf` [rbdnew07]
            * `rbd0706.otf` [rbdnew07]
            * `rbd07ob1.otf` [rbdnew07]
    * `rbd08` Universal mission files
        * `debriefing`
            * `rbd08l01.des` [rbdnew08]
            * `rbd08l05.des` [rbdnew08]
            * `rbd08w01.des` [rbdnew08]
            * `rbd08w02.des` [rbdnew08]
        * `objectives`
            * `rbd0801.otf` [rbdnew08]
            * `rbd0801i.otf` [rbdnew08]
            * `rbd0802.otf` [rbdnew08]
            * `rbd0802i.otf` [rbdnew08]
            * `rbd0803.otf` [rbdnew08]
            * `rbd0804.otf` [rbdnew08]
    * `rbd09` Universal mission files
        * `debriefing`
            * `rbd09l01.des` [rbdnew09]
            * `rbd09l02.des` [rbdnew09]
            * `rbd09wn.des` [rbdnew09]
        * `objectives`
            * `rbd0901.otf` [rbdnew09]
            * `rbd0902.otf` [rbdnew09]
            * `rbd0902b.otf` [rbdnew09]
            * `rbd0903.otf` [rbdnew09]
            * `rbd0904.otf` [rbdnew09]
            * `rbd0905.otf` [rbdnew09]
            * `rbd0906.otf` [rbdnew09]
    * `rbd10` Universal mission files
        * `debriefing`
            * `rbd10l01.des` [rbdnew10]
            * `rbd10l02.des` [rbdnew10]
            * `rbd10l03.des` [rbdnew10]
            * `rbd10l04.des` [rbdnew10]
            * `rbd10l05.des` [rbdnew10]
            * `rbd10w01.des` [rbdnew10]
        * `objectives`
            * `rbd1001.otf` [rbdnew10]
            * `rbd1002.otf` [rbdnew10]
            * `rbd1003.otf` [rbdnew10]
    * `rbdnew01`
        * `debriefing`
            * `rbdnew01l1.des` Command Tower Destroyed, not defended
            * `rbdnew01l2.des` [rbdnew01] You allowed your recycler to be destroyed.
            * `rbdnew01w.des` [rbdnew01] Well done, new closing
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
        * `debriefing`
            * `rbdnew15l1.des` [rbdnew05]
            * `rbdnew15l2.des` [rbdnew05]
            * `rbdnew15l3.des` [rbdnew05]
            * `rbdnew15l4.des` [rbdnew05]
            * `rbdnew15w.des` [rbdnew05]
        * `objectives`
            * `rbd0521.otf` [rbdnew05]
            * `rbd0522.otf` [rbdnew05]
            * `rbd0523.otf` [rbdnew05]
            * `rbd0524.otf` [rbdnew05]
            * `rbd0525.otf` [rbdnew05]
            * `rbd0530.otf` [rbdnew05]
            * `rbd0531.otf` [rbdnew05]
            * `rbd0532.otf` [rbdnew05]
            * `rbd0533.otf` [rbdnew05]
            * `rbd0534.otf` [rbdnew05]
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
