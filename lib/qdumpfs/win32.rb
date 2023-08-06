# coding: utf-8

def windows?
  /mswin32|cygwin|mingw|bccwin/.match(RUBY_PLATFORM)
end

