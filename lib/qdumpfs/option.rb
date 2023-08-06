# coding: utf-8
module Qdumpfs
  # 日毎のバックアップフォルダに対応
  class BackupDir
    def self.scan_backup_dirs(target_dir)
      backup_dirs = []
      Dir.glob("#{target_dir}/[0-9][0-9][0-9][0-9]/[0-1][0-9]/[0-3][0-9]").sort.each do |path|
        if  File.directory?(path) && path =~ /(\d\d\d\d)\/(\d\d)\/(\d\d)/
          #        puts "Backup dir: #{path}"
          backup_dir = BackupDir.new
          backup_dir.path = path
          backup_dir.date = Date.new($1.to_i, $2.to_i, $3.to_i)
          backup_dirs << backup_dir
        end
      end
      backup_dirs.sort_by!{|backup_dir| backup_dir.date}
      backup_dirs
    end
    
    def self.find(backup_dirs, from_date, to_date)
      backup_dirs.select{|backup_dir| backup_dir.date >= from_date && backup_dir.date <= to_date}
    end

    def self.dump(dirs)
      dirs.each do |dir|
        puts dir
      end
    end
    
    def initialize
      @keep = false
    end
    attr_accessor :path, :date, :keep

    def to_s
      "path=#{@path} date=#{@date} keep=#{@keep}"
    end
  end
  
  
  class NullLogger
    def close
    end    
    def print(msg)
    end
  end
  
  
  class SimpleLogger
    def initialize(filename)
      @file = File.open(filename, "a")
    end
    
    def close
      @file.close
    end
    
    def print(msg)
      @file.puts msg
    end
  end
  
  
  class Error < StandardError
  end
  
  
  class NullMatcher
    def initialize(options = {})
    end
    def exclude?(path)
      false
    end
  end
  
  
  class FileMatcher
    def initialize(options = {})
      @patterns = options[:patterns] || []
      @globs    = options[:globs] || []
      @size     = calc_size(options[:size])
    end
    
    def calc_size(size)
      table   = { "K" => 1, "M" => 2, "G" => 3, "T" => 4, "P" => 5 }
      pattern = table.keys.join('')
      case size
      when nil
        -1
      when /^(\d+)([#{pattern}]?)$/i
        num  = Regexp.last_match[1].to_i
        unit = Regexp.last_match[2]
        num * 1024 ** (table[unit] or 0)
      else
        raise "Invalid size: #{size}"
      end
    end
    
    def exclude?(path)
      stat = File.lstat(path)
      if @size >= 0 and stat.file? and stat.size >= @size
        return true
      elsif @patterns.find {|pattern| pattern.match(path) }
        return true
      elsif stat.file? and
        @globs.find {|glob| File.fnmatch(glob, File.basename(path)) }
        return true
      end
      return false
    end
  end

 
  class Option
    def initialize(opts, dirs)
      @opts = opts
      @dirs = dirs
      @src = dirs[0] if dirs.size > 0
      @dst = dirs[1] if dirs.size > 1
      @cmd = @opts[:c] || 'backup'
      
      #      @logger = NullLogger.new
      logfile = 'qdumpfs.log'
      #ログディレクトリの作成      
      @logdir = @opts[:logdir] || Dir.pwd
      Dir.mkdir(@logdir) unless FileTest.directory?(@logdir)
      @logpath = File.join(@logdir, logfile)
      @logger = SimpleLogger.new(@logpath)
      
      verifyfile = 'verify.txt'
      @verifypath = File.join(@logdir, verifyfile)

      @matcher = NullMatcher.new
      
      size = @opts[:es]
      globs = @opts[:eg]
      patterns = @opts[:ep]
      if size || globs || patterns
        @matcher = FileMatcher.new(:size => size, :globs => globs, :patterns => patterns)
      end      
      
      # 同期用のオプションは日常使いのpdumpfs-cleanのオプションより期間短めに設定      
      @limit = @opts[:limit]
      @keep_year = 100
      @keep_month = 12
      @keep_week = 12
      @keep_day = 30
      keep = @opts[:keep]
      @keep_year = $1.to_i if keep =~ /(\d+)Y/
      @keep_month = $1.to_i if keep =~ /(\d+)M/
      @keep_week = $1.to_i if keep =~ /(\d+)W/
      @keep_day = $1.to_i if keep =~ /(\d+)D/
      @delete_from = @opts[:delete_from]
      @delete_to = @opts[:delete_to]
      @delete_dirs = @opts[:delete_dirs] || []
      @backup_at = @opts[:backup_at]
      @today = Date.today
      @debug = @opts[:d]
    end
    attr_reader :dirs, :src, :dst, :cmd
    attr_reader :keep_year, :keep_month, :keep_week, :keep_day
    attr_reader :logdir, :logpath, :verifypath
    attr_reader :logger, :matcher, :reporter, :interval_proc
    attr_reader :delete_from, :delete_to, :delete_dirs, :backup_at
    attr_reader :debug

    def close
      @logger.close
    end
    
    def report(type, filename)
      if @opts[:v]
        stat = File.stat(filename)
        size = stat.size
        format_size = convert_bytes(size)
        msg = format_report_with_size(type, filename, size, format_size)        
      elsif @opts[:r]
        if type =~ /^new_file/
          stat = File.stat(filename)
          size = stat.size
          format_size = convert_bytes(size)
          msg = format_report_with_size(type, filename, size, format_size)
        end
      else
        # 何も指定されていない場合
        if type == 'new_file'
          stat = File.stat(filename)
          size = stat.size
          msg = format_report(type, filename, size)
        end
      end
      log(msg)
    end

    def report_error(filename, reason)
      msg = sprintf("err_file\t%s\t%s\n", filename, reason)
      log(msg)
    end
    
    def log(msg, console = true)
      return if (msg.nil? || msg == '')
      puts msg if console
      @logger.print(msg)
    end
    
    def dry_run
      @opts[:n]
    end

    def verbose
      @opts[:v]
    end
    
    def limit_sec
      @limit.to_i * 3600
    end
    
    def validate_directory(dir)
      if dir.nil? || !File.directory?(dir)
        raise ArgumentError, "No such directory: #{dir}"
      end
    end
      
    def validate_directories(min_count)
      @dirs.each do |dir|
        validate_directory(dir)
      end
      # if @dirs.size == 2 && windows?
      #   # ディレクトリが2つだけ指定されている場合、コピー先はntfsである必要がある
      #   unless ntfs?(dst)
      #     fstype = get_filesystem_type(dst)
      #     raise sprintf("only NTFS is supported but %s is %s.", dst, fstype)
      #   end      
      # end
      if @dirs.size < min_count
        raise "#{min_count} directories required."
      end
    end
    
    def detect_expire_dirs(backup_dirs)
      detect_year_keep_dirs(backup_dirs)
      detect_month_keep_dirs(backup_dirs)
      detect_week_keep_dirs(backup_dirs)
      detect_day_keep_dirs(backup_dirs)
    end

    def detect_delete_dirs(backup_dirs, delete_from, delete_to)
      
      backup_dirs.each do |backup_dir|
        backup_dir.keep = true
        if delete_from && delete_to
          if backup_dir.date >= delete_from && backup_dir.date <= delete_to
            backup_dir.keep = false
          end
        elsif delete_from
          if backup_dir.date >= delete_from
            backup_dir.keep = false
          end
        elsif delete_to
          if backup_dir.date <= delete_to
            backup_dir.keep = false
          end
        end
      end
    end
    
    def open_verifyfile
      if FileTest.file?(@verifypath)
        File.unlink(@verifypath)
      end
      File.open(@verifypath, 'a')
    end
    
    def open_listfile
      filename = File.join(@logdir, "list_" + @src.gsub(/[:\/]/, '_') + '.txt')
      if FileTest.file?(filename)
        File.unlink(filename)
      end
      File.open(filename, 'a')
    end
        
    private
    def format_report(type, filename, size)
      sprintf("%s\t%s\t%d\n", type, filename, size)
    end
    
    def format_report_with_size(type, filename, size, format_size)
      sprintf("%s\t%s\t%d\t%s\n", type, filename, size, format_size)
    end
    
    def format_report_with_size_as_csv(type, filename, size, format_size)
      sprintf("%s,%s,%d,%s\n", type, filename.encode('cp932', undef: :replace), size, format_size)
    end
    
    def format_report_as_csv(type, filename)
      sprintf("%s,%s\n", type, filename.encode('cp932', undef: :replace))
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
        
    def keep_dirs(backup_dirs, num)
      (num - 1).downto(0) do |i|
        from_date, to_date = yield(i)
        dirs = BackupDir.find(backup_dirs, from_date, to_date)
        dirs[0].keep = true if dirs.size > 0
      end
    end
  
    def detect_year_keep_dirs(backup_dirs)
      keep_dirs(backup_dirs, @keep_year) do |i|
      from_date = Date.new(@today.year - i, 1, 1)
        to_date = Date.new(@today.year - i, 12, 31)
        [from_date, to_date]
      end
    end
    
    def detect_month_keep_dirs(backup_dirs)
      keep_dirs(backup_dirs, @keep_month) do |i|
        base_date = @today <<  i
        from_date = Date.new(base_date.year, base_date.month, 1)
        to_date = from_date >> 1
        [from_date, to_date]
      end
    end
  
    def detect_week_keep_dirs(backup_dirs)
      keep_dirs(backup_dirs, @keep_week) do |i|
        base_date = @today  - 7 * i
        from_date = base_date - base_date.cwday # 1
        to_date = from_date + 6
        [from_date, to_date]
      end
    end
  
    def detect_day_keep_dirs(backup_dirs)
      keep_dirs(backup_dirs, @keep_day) do |i|
        base_date = @today - i
        from_date = base_date
        to_date = base_date
        [from_date, to_date]
      end
    end

  end
end
