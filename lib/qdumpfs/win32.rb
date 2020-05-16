# coding: utf-8

def windows?
  /mswin32|cygwin|mingw|bccwin/.match(RUBY_PLATFORM)
end

if windows?
  # http://www.virtuouscode.com/2011/08/25/temporarily-disabling-warnings-in-ruby/
  
  # https://stackoverflow.com/questions/39051793/can-i-hide-the-warning-message-dl-is-deprecated-please-use-fiddle-in-ruby
  original_verbose = $VERBOSE
  $VERBOSE = nil
  
  require 'Win32API'
  require "win32ole"
  
  $VERBOSE = original_verbose

  if RUBY_VERSION < "1.8.0"
    CreateHardLinkA = Win32API.new("kernel32", "CreateHardLinkA", "ppl", 'i')
    def File.link(l, t)
      result = CreateHardLinkA.call(t, l, 0)

      raise Errno::EACCES  if result == 0
    end
  end

  def expand_special_folders(dir)
    specials = %w[(?:AllUsers)?(?:Desktop|Programs|Start(?:Menu|up)) Favorites
    Fonts MyDocuments NetHood PrintHood Recent SendTo Templates]

    pattern = Regexp.compile(sprintf('^@(%s)', specials.join('|')))

    dir.sub(pattern) do |match|
      WIN32OLE.new("WScript.Shell").SpecialFolders(match)
    end.tr('\\', File::SEPARATOR)
  end

  GetVolumeInformation = Win32API.new("kernel32", "GetVolumeInformation", "PPLPPPPL", "I")
  def get_filesystem_type(path)
    return nil unless(FileTest.exist?(path))

    drive = File.expand_path(path)[0..2]
    buff = "\0" * 1024
    GetVolumeInformation.call(drive, nil, 0, nil, nil, nil, buff, 1024)

    buff.sub(/\000+/, '')
  end

  def ntfs?(dir)
    get_filesystem_type(dir) == "NTFS"
  end

  GetLocaltime = Win32API.new("kernel32", "GetLocalTime", "P", 'V')
  SystemTimeToFileTime = Win32API.new("kernel32", "SystemTimeToFileTime", "PP", 'I')
  def get_file_time(time)
    pSYSTEMTIME = ' ' * 2 * 8     # 2byte x 8
    pFILETIME = ' ' * 2 * 8       # 2byte x 8

    GetLocaltime.call(pSYSTEMTIME)
    t1 = pSYSTEMTIME.unpack("S8")
    t1[0..1] = time.year, time.month
    t1[3..6] = time.day, time.hour, time.min, time.sec

    SystemTimeToFileTime.call(t1.pack("S8"), pFILETIME)

    pFILETIME
  end

  GENERIC_WRITE   = 0x40000000
  OPEN_EXISTING = 3
  FILE_FLAG_BACKUP_SEMANTICS =  0x02000000

  class << File
    alias_method(:utime_orig, :utime)
  end

  CreateFile  = Win32API.new("kernel32", "CreateFileA","PLLLLLL", "L")
  SetFileTime = Win32API.new("kernel32", "SetFileTime", "LPPP", "I")
  CloseHandle = Win32API.new("kernel32", "CloseHandle", "L", "I")

  def File.utime(a, m, dir)
    File.utime_orig(a, m, dir)  unless(File.directory?(dir))

    atime = get_file_time(a.dup.utc)
    mtime = get_file_time(m.dup.utc)

    hDir = CreateFile.Call(dir.dup, GENERIC_WRITE, 0, 0, OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS, 0)
    SetFileTime.call(hDir, 0, atime, mtime)
    CloseHandle.Call(hDir)

    return 0
  end

  LOCALE_USER_DEFAULT    = 0x400
  LOCALE_SABBREVLANGNAME = 3
  LOCALE_USE_CP_ACP      = 0x40000000
  GetLocaleInfo = Win32API.new("kernel32", "GetLocaleInfo", "IIPI", "I")

  def get_locale_name
    locale_name = " " * 32
    status = GetLocaleInfo.call(LOCALE_USER_DEFAULT,
    LOCALE_SABBREVLANGNAME | LOCALE_USE_CP_ACP,
    locale_name, 32)
    if status == 0
      return nil
    else
      return locale_name.split("\x00").first
    end
  end

  SW_HIDE                = 0
  SW_SHOWNORMAL          = 1

  ShellExecute      = Win32API.new("shell32",  "ShellExecute", "LPPPPL", 'L')
  LoadIcon          = Win32API.new("user32",   "LoadIcon", "II", "I")
  GetModuleFileName = Win32API.new("kernel32", "GetModuleFileName","IPI","I")

  def get_exe_file_name
    path = "\0" * 1024
    length = GetModuleFileName.call(0 ,path, path.length)
    return path[0, length].tr('\\', File::SEPARATOR)
  end

  def get_program_file_name
    exe_file_name = get_exe_file_name
    if File.basename(exe_file_name) == "ruby.exe"
      return File.expand_path($0).gsub('\\', File::SEPARATOR)
    else
      return exe_file_name
    end
  end

  def get_program_directory
    program_file_name = get_program_file_name
    return File.dirname(program_file_name)
  end

  def init
    locale_name = get_locale_name
    #    $KCODE = "SJIS" if locale_name == "JPN"
  end
  
  init
end