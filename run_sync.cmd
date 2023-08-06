@echo off

call uru 306p216

bundle exec ruby exe/qdumpfs  --command sync --keep=10Y0M0W0D r:/pc1/pdumpfs/opt v:/pc1/pdumpfs/opt

