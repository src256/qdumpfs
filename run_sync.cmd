@echo off

call uru 306p216

bundle exec ruby exe/qdumpfs  -d --command sync --keep=2Y0M1W0D r:/pc1/pdumpfs/opt v:/pc1/pdumpfs/opt

