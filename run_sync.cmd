@echo off

call uru system

bundle exec ruby exe/qdumpfs  -d --command sync --keep=2Y0M0W0D r:/pc1/pdumpfs/opt v:/pc1/pdumpfs/opt

