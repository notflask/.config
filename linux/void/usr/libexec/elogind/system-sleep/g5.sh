#!/bin/sh
# Nach dem Standby CPU-Limit, Energieprofil und GPU-Mindesttakt neu setzen
# (unter NixOS: post-resume.target, performance.nix/nvidia.nix). elogind
# ruft das mit pre|post und suspend|hibernate|… auf.
case $1 in
  post) /usr/bin/sv restart g5-tuning >/dev/null 2>&1 ;;
esac
exit 0
