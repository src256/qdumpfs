# coding: utf-8

require 'fileutils'

def wprintf(format, *args)
  STDERR.printf("pdumpfs: " + format + "\n", *args)
end

#https://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
# Cross-platform way of finding an executable in the $PATH.
#
#   which('ruby') #=> /usr/bin/ruby
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

class File
  def self.real_file?(path)
    FileTest.file?(path) and not FileTest.symlink?(path)
  end

  def self.anything_exist?(path)
    FileTest.exist?(path) or FileTest.symlink?(path)
  end

  def self.real_directory?(path)
    FileTest.directory?(path) and not FileTest.symlink?(path)
  end

  def self.force_symlink(src, dest)
    begin
      File.unlink(dest) if File.anything_exist?(dest)
      File.symlink(src, dest)
    rescue => e      
      puts "force_symlink fails #{src} #{dest} #{e.message}"
#      puts "File.symlink('#{src}', '#{dest}')"
    end
  end

  def self.force_link(src, dest)
    File.unlink(dest) if File.anything_exist?(dest)
    File.link(src, dest)
  end

  def self.readable_file?(path)
    FileTest.file?(path) and FileTest.readable?(path)
  end

  def self.split_all(path)
    parts = []
    while true
      dirname, basename = File.split(path)
      break if path == dirname
      parts.unshift(basename) unless basename == "."
      path = dirname
    end
    return parts
  end
end


module QdumpfsFind
  def find(logger, *paths)
    block_given? or return enum_for(__method__, *paths)
    paths.collect!{|d|
      raise Errno::ENOENT unless File.exist?(d)
      d.dup
    }
    while (file = paths.shift)
      catch(:prune) do
        yield file.dup.taint
        begin
          s = File.lstat(file)
        rescue => e
          logger.print("File.lstat path=#{file} error=#{e.message}")
          next
        end
        if s.directory?
          begin
            fs = Dir.entries(file, :encoding=>'UTF-8')
          rescue => e
            logger.print("Dir.entries path=#{file} error=#{e.message}")
            next
          end
          fs.sort!
          fs.reverse_each {|f|
            next if f == "." or f == ".."
            f = File.join(file, f)
            paths.unshift f.untaint
          }
        end
      end
    end
  end
  
  def prune
    throw :prune
  end
  
  module_function :find, :prune
end


module QdumpfsUtils

  # We don't use File.copy for calling @interval_proc.
  def copy_file(src, dest)
    # begin
    #   File.open(src, 'rb') {|r|
    #     File.open(dest, 'wb') {|w|
    #       block_size = (r.stat.blksize or 8192)
    #       i = 0
    #       while true
    #         block = r.sysread(block_size)
    #         w.syswrite(block)
    #         i += 1
    #         @write_bytes += block.size
    #       end
    #     }
    #   }
    # rescue EOFError
    #   # この実装だとファイルサイズがblock_sizeより小さい場合にEOFErrorが発生する
    #   # それはしかたがないので無視する
    #   #       puts e.message
    # end
    FileUtils.cp(src, dest)
    unless FileTest.file?(dest)
      raise "copy_file fails #{dest}"
    else
      @write_bytes +=  File.size(src)
    end
  end 
  
  # incomplete substitute for cp -p
  def copy(src, dest)
    stat = File.stat(src)
    copy_file(src, dest)
    File.chmod(0200, dest) if windows?
    File.utime(stat.atime, stat.mtime, dest)
    File.chmod(stat.mode, dest) # not necessary. just to make sure
  end

  def link(src, dest)
    @link_bytes += File.size(src)
    File.force_link(src, dest)
  end
    
  def convert_bytes(bytes)
    if bytes < 1024
      sprintf("%dB", bytes)
    elsif bytes < 1024 * 1000 # 1000kb
      sprintf("%.1fKB", bytes.to_f / 1024)
    elsif bytes < 1024 * 1024 * 1000  # 1000mb
      sprintf("%.1fMB", bytes.to_f / 1024 / 1024)
    else
      sprintf("%.1fGB", bytes.to_f / 1024 / 1024 / 1024)
    end
  end
  
  def same_file?(f1, f2)
    #    File.real_file?(f1) and File.real_file?(f2) and
    #    File.size(f1) == File.size(f2) and File.mtime(f1) == File.mtime(f2)
    real_file = File.real_file?(f1) and File.real_file?(f2)
    same_size = File.size(f1) == File.size(f2)
    
    #    mtime1 = File.mtime(f1).strftime('%F %T.%N')
    #    mtime2 = File.mtime(f2).strftime('%F %T.%N')
    same_mtime = File.mtime(f1).to_i == File.mtime(f2).to_i
    #    p "#{real_file} #{same_size} #{same_mtime}(#{mtime1}<=>#{mtime2})"
    real_file and same_size and same_mtime
  end
  
  def detect_type(src, latest = nil)
    type = "unsupported"
    if File.real_directory?(src)
      type = "directory"
    else
      if latest and File.real_file?(latest)
        case File.ftype(src)
        when "file"
          same_file = same_file?(src, latest)
#          puts "same_file? #{src} #{latest} result=#{same_file}"
          if same_file
            type = "unchanged"
          else
            type = "updated"
          end
        when "link"
          # the latest backup file is a real file but the
          # current source file is changed to symlink.
          type = "symlink"
        end
      else
 #       puts "latest=#{latest}"
        case File.ftype(src)
        when "file"
          type = "new_file"
        when "link"
          type = "symlink"
        end
      end
    end
    return type
  end
  
  def fmt(time)
    time.strftime('%Y/%m/%d %H:%M:%S')
  end
  
  def chown_if_root(type, src, today)
    return unless Process.uid == 0 and type != "unsupported"
    if type == "symlink"
      if File.respond_to?(:lchown)
        stat = File.lstat(src)
        File.lchown(stat.uid, stat.gid, today)
      end
    else
      stat = File.stat(src)
      File.chown(stat.uid, stat.gid, today)
    end
  end
  
  def restore_dir_attributes(dirs)
    dirs.each {|dir, stat|
      File.utime(stat.atime, stat.mtime, dir)
      File.chmod(stat.mode, dir)
    }
  end    
  
  def make_relative_path(path, base)
    pattern = sprintf("^%s%s?", Regexp.quote(base), File::SEPARATOR)
    path.sub(Regexp.new(pattern), "")
  end
  
  def fputs(file, msg)
    puts msg
    file.puts msg
  end
  
  def time_diff(start_time, end_time)
    seconds_diff = (start_time - end_time).to_i.abs
    
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600
    
    minutes = seconds_diff / 60
    seconds_diff -= minutes * 60
    
    seconds = seconds_diff
    
    '%02d:%02d:%02d' % [hours, minutes, seconds]
  end
  
  def create_latest_symlink(dest, today)
    # 最新のバックアップに"latest"というシンボリックリンクをはる(Windowsだと動かない)
    latest_day = File.dirname(make_relative_path(today, dest))
      latest_symlink = File.join(dest, "latest")
    #      puts "force_symlink #{latest_day} #{latest_symlink}"
    File.force_symlink(latest_day, latest_symlink)
  end
  
  def same_directory?(src, dest)
    src  = File.expand_path(src)
    dest = File.expand_path(dest)
    return src == dest
  end
  
  def sub_directory?(src, dest)
    src  = File.expand_path(src)
    dest = File.expand_path(dest)
    src  += File::SEPARATOR unless /#{File::SEPARATOR}$/.match(src)
    return /^#{Regexp.quote(src)}/.match(dest)
  end
  
  def datedir(date)
    s = File::SEPARATOR
    sprintf "%d%s%02d%s%02d", date.year, s, date.month, s, date.day
  end
  
  def past_date?(year, month, day, t)
    ([year, month, day] <=> [t.year, t.month, t.day]) < 0
  end
  
  def to_win_path(path)
    path.gsub(/\//, '\\')
  end
  
  def to_unix_path(path)
    path.gsub(/\\/, '/')
  end

  def to_time(date)
    Time.local(date.year, date.month, date.day)
  end
end

