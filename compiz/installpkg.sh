#!/bin/bash
cd "$(dirname "$0")"
chmod +x *.SlackBuild
./compiz.SlackBuild
installpkg /tmp/compiz-*.txz