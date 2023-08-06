@echo off

call uru 306p216

set bundle_dir=./vendor/bundle

IF EXIST "vendor/bundle/" (
   echo update
   rmdir /s /q vendor\bundle
   bundle update    	
) ELSE (
   echo install
   bundle install --path %bundle_dir%
)
