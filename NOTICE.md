# Rights Notice

Copyright (c) 2026 JuYang. All rights reserved.

This repository is source-available for inspection. No open-source license or other permission is granted at this time. You may not copy, modify, distribute, sublicense, or commercially use the code unless you have received separate written permission from the copyright holder or applicable law expressly permits it.

Third-party dependencies remain governed by their respective licenses. No source code from the private/unlicensed `cc.zip` reference archive is copied into this repository.

## CI signing tool

The TrollStore candidate workflow downloads an unmodified ProcursusTeam `ldid` binary at the pinned tag `v2.1.5-procursus7` and verifies its architecture and SHA-256 before use. `ldid` is licensed under AGPL-3.0 by its respective copyright holders. It is used only as a CI build tool and is not committed to this repository, embedded in `CangJie.app`, or uploaded with the IPA artifact.
