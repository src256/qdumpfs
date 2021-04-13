# coding: utf-8
require "qdumpfs/version"
require "qdumpfs/win32"
require "qdumpfs/util"
require "qdumpfs/option"
require 'find'
require 'optparse'
require 'date'
require 'fileutils'


module Qdumpfs
 
  class Command
    include QdumpfsUtils
    
    def self.run(argv)
      STDOUT.sync = true
      opts = {}
      opt = OptionParser.new(argv)
      opt.version = VERSION
      opt.banner = "Usage: #{opt.program_name} [options] <source> <dest>"
      opt.separator('Options')
      opt.on_head('-h', '--help', 'show this message') do |v|
        puts opt.help
        exit
      end
      opt.on('-v', '--verbose', 'verbose message') {|v| opts[:v] = v}
      opt.on('-r', '--report', 'report message') {|v| opts[:r] = v}
      opt.on('-n', '--dry-run', "don't actually run any commands") {|v| opts[:n] = v}
      opt.on('-e PATTERN', '--exclude=PATTERN', 'exclude files/directories matching PATTERN') {|v|
        opts[:ep] = [] if opts[:ep].nil?
        opts[:ep] << Regexp.new(v)
      }
      opt.on('-s SIZE', '--exclude-by-size=SIZE', 'exclude files larger than SIZE') {|v| opts[:es] = v }
      opt.on('-w GLOB', '--exclude-by-glob=GLOB', 'exclude files matching GLOB') {|v| opts[:ep] = v }
      commands = ['backup', 'sync', 'list', 'expire', 'verify', 'delete']
      opt.on('-c COMMAND', '--command=COMMAND', commands, commands.join('|')) {|v| opts[:c] = v}
      opt.on('-l HOURS', '--limit=HOURS', 'limit hours') {|v| opts[:limit] = v}
      opt.on('-k KEEPARG', '--keep=KEEPARG', 'ex: --keep 100Y12M12W30D (100years, 12months, 12weeks, 30days, default)') {|v| opts[:keep] = v}
      opt.on('--logdir=LOGDIR', 'logdir') {|v| opts[:logdir] = v}
      opt.on('--delete-from=YYYYMMDD', 'delete backup from YYYY/MM/DD') {|v|
        opts[:delete_from] = Date.parse(v)
      }
      opt.on('--delete-to=YYYYMMDD', 'delete backup to YYYY/MM/DD') {|v|
        opts[:delete_to] = Date.parse(v)
      }
      opt.on('--delete-dir=DIRS', 'relative path from the snapshot root of the backup. ex: --delete-dir=foo,home/bar') {|v|
        opts[:delete_dirs] = v.split(/,/)
      }      
      opt.on('--backup-at=YYYYMMDD', 'backup at YYYY/MM/DD') {|v|
        opts[:backup_at] = Date.parse(v)
      }
      opt.on('-d', '--debug', 'debug mode') {|v| opts[:d] = v }
      opt.parse!(argv)
      option = Option.new(opts, argv)
      if opts[:v]
        puts "<<<<< qdumpfs options >>>>> "
        puts "logdir: #{option.logdir}"
        puts "logpath: #{option.logpath}"
        puts "verifypath: #{option.verifypath}"
        puts 
      end
      begin
        command = Command.new(option)
        command.run
      rescue => e
        if option.debug
          p e.message
          p e.backtrace
        end
        puts opt.help
        exit        
      end
    end
    
    def initialize(opt)
      @opt = opt
    end
    
    def run
      if @opt.cmd == 'backup'
        backup
      elsif @opt.cmd == 'sync'
        sync
      elsif @opt.cmd == 'list'
        list
      elsif @opt.cmd == 'expire'
        delete('expire')
      elsif @opt.cmd == 'verify'
        verify
      elsif @opt.cmd == 'delete'
        delete('delete')
      else
        raise RuntimeError, "unknown command: #{@opt.cmd}"
      end
    end
    
    private
    def log_result(src, today, elapsed)
      time  = Time.now.strftime("%Y-%m-%dT%H:%M:%S")
      bytes = convert_bytes(@written_bytes)
      msg = sprintf("%s: %s -> %s (in %.2f sec, %s written)\n", time, src, today, elapsed, bytes)
      log(msg)
      log("error files:\n")
      i = 1
      @error_files.each do |filename, reason|
        msg = "#{i}. #{filename}\t#{reason}\n"
        log(msg)
        i += 1
      end
    end

    def log(msg, console = true)
      @opt.log(msg, console)
    end

    def report(type, file_name)
      @opt.report(type, file_name)
    end

    def report_error(file_name, reason)
      @opt.report_error(file_name, reason)
    end

    def update_file(src, latest, today)
      type = detect_type(src, latest)
      report(type, src)
      return if @opt.dry_run
      case type
      when "directory"
        FileUtils.mkpath(today)
      when "unchanged"
        File.force_link(latest, today)
      when "updated"
        copy(src, today)
      when "new_file"
        copy(src, today)
      when "symlink"
        File.force_symlink(File.readlink(src), today)
      when "unsupported"
        # just ignore it
      else
        raise "#{type}: shouldn't be reached here"
      end
      chown_if_root(type, src, today)
    end
    
    def filecount(dir)
      result = '0'
      if windows? 
        pscmd = 'Get-ChildItem -Recurse -File | Measure-Object | %{$_.Count}'
        cmd = "powershell -Command \"#{pscmd}\""
        result = nil
        Dir.chdir(dir) do
          result = `#{cmd}`
          result.chomp!
        end
      else
        result = `find #{dir} | wc -l`
        result.chomp!
      end
      result.to_i
    end

    def do_verify(src, dst)
      src_count = filecount(src)
      dst_count= filecount(dst)
      return src_count, dst_count
    end

    def update_snapshot(src, latest, today)
      # バックアップの差分コピーを実行
      # src: コピー元ディレクトリ ex) i:/from/home
      # latest: 最新のバックアップディレクトリ ex)j:/to/backup1/2019/05/09/home
      # today: 差分バックアップ先ディレクトリ ex)j:/to/backup1/2019/05/10/home
      dirs = {};
      QdumpfsFind.find(@opt.logger, src) do |s|      # path of the source file
        if @opt.matcher.exclude?(s)
          if File.lstat(s).directory? then Find.prune() else next end
        end
        # バックアップ元ファイルのパスからディレクトリ部分を削除
        r = make_relative_path(s, src)
        # 既存バックアップファイルのパス
        l = File.join(latest, r)  # path of the latest  snapshot
        # 新規バックアップファイルのパス
        t = File.join(today, r)   # path of the today's snapshot
        begin
          # ファイルのアップデート
          update_file(s, l, t)
          dirs[t] = File.stat(s) if File.ftype(s) == "directory"
        rescue => e
          report_error(s, e.message)
          @error_files << [s, e.message]          
          next
        end
      end
      return if @opt.dry_run
      restore_dir_attributes(dirs)
    end

    def recursive_copy(src, dst)
      dirs = {}
      QdumpfsFind.find(@opt.logger, src) do |s|
        if @opt.matcher.exclude?(s)
          if File.lstat(s).directory? then Find.prune() else next end
        end
        r = make_relative_path(s, src)
        t = File.join(dst, r)
        begin
          type = detect_type(s)
          report(type, s)
          next if @opt.dry_run
          case type
          when "directory"
            FileUtils.mkpath(t)
          when "new_file"
            copy(s, t)
          when "symlink"
            File.force_symlink(File.readlink(s), t)
          when "unsupported"
            # just ignore it
          else
            raise "#{type}: shouldn't be reached here"
        end
          chown_if_root(type, s, t)
          dirs[t] = File.stat(s) if File.ftype(s) == "directory"
        rescue => e
          report_error(s, e.message)
          @error_files << [s, e.message]
          next
        end
      end
      restore_dir_attributes(dirs) unless @opt.dry_run
    end
        
    def sync_latest(src, dst, base = nil)
      # pdumpfsのバックアップフォルダを同期する
      
      #コピー元のスナップショット
      src_snapshots = BackupDir.scan_backup_dirs(src)
      @opt.detect_expire_dirs(src_snapshots)
      
      # コピー先の最新スナップショット
      dst_snapshots = BackupDir.scan_backup_dirs(dst)
      dst_snapshot = dst_snapshots[-1]
      
      # コピー元フォルダの決定
      src_snapshot = nil
      src_snapshots.each do |snapshot|
        next if dst_snapshot && snapshot.date <= dst_snapshot.date
        if snapshot.keep
          src_snapshot = snapshot
          break
        end
      end
      
      if src_snapshot.nil?
        return false, nil, nil
      end

      # 今回コピーするフォルダの名前
      src = src_snapshot.path
      today =  File.join(dst, datedir(src_snapshot.date))
      latest = dst_snapshot ? File.join(dst_snapshot.path) : nil
      
      # src: j: /to/backup1/2019/05/10/home/"
      # latest: 
      # today: j:/sync/backup1/2019/05/10/home"
      log("sync_latest src=#{src} latest=#{latest} today=#{today}")

      if latest
        log("update_snapshot #{src} #{latest} #{today}")
        # バックアップがすでに存在する場合差分コピー
        update_snapshot(src, latest, today)
      else
        log("recursive_copy #{src}=>#{today}")
        # 初回は単純に再帰コピー
        recursive_copy(src, today)
      end

      return true, src, today
    end
    
    def latest_snapshot(start_time, src, dst, base)
      # バックアップ先の日付ディレクトリを取得
      # 現在の日付より過去のもののなかで最新を取得する(なければnil。現在の日付しかなくてもnil)
      dd   = "[0-9][0-9]"
      dddd = dd + dd
      # FIXME: Y10K problem.
      glob_path = File.join(dst, dddd, dd, dd)
      Dir.glob(glob_path).sort {|a, b| b <=> a }.find {|dir|
        day, month, year = File.split_all(dir).reverse.map {|x| x.to_i }
        path = File.join(dir, base)
        if File.directory?(path) and Date.valid_date?(year, month, day) and
          past_date?(year, month, day, start_time)
          return path
        end
      }
      return nil
    end
    
    def backup
      #####  オリジナルのバックアップルーチン
      @opt.validate_directories(2)
      
      log("##### backup start #####")
      
      @written_bytes = 0
      @error_files = []
      start_time = Time.now
      if @opt.backup_at
        start_time = to_time(@opt.backup_at)
      end
      src = @opt.src
      dst = @opt.dst
      
      # Windowsの場合
      if windows?
        src  = expand_special_folders(src)
        dst = expand_special_folders(dst)
      end
      
      # 指定されたディレクトリの整合性チェック
      if same_directory?(src, dst) or sub_directory?(src, dst)
        raise "cannot copy a directory, `#{src}', into itself, `#{dst}'"
      end
      
      # Ruby 1.6.xではbasename(src) == ''となるため最後の'/'を除去
      src  = src.sub(%r!/+$!, "") unless src == '/' #'
      base = File.basename(src)
      dirname = File.dirname(src)
      raise RuntimeError unless FileTest.exist?(dirname + '/' + base)
      
      # 存在するバックアップの最新を取得
      latest = latest_snapshot(start_time, src, dst, base)
      # 現在の日付フォルダを取得j:/to/backup1/2019/05/10/home
      today  = File.join(dst, datedir(start_time), base)
      File.umask(0077)
      FileUtils.mkpath(today) unless @opt.dry_run
      if windows?
        src = src.sub( /^[A-Za-z]:$/, src + "/" )
      end
      if latest
        # バックアップがすでに存在する場合差分コピー
        log("## update_snapshot #{src} #{latest}=>#{today} ##")
        update_snapshot(src, latest, today)
      else
        # 初回は単純に再帰コピー
        log("## recursive_copy #{src}=>#{today} ##")
        recursive_copy(src, today)
      end
      unless @opt.dry_run
        create_latest_symlink(dst, today)
        elapsed = Time.now - start_time
        log_result(src, today, elapsed)
      end
      log("##### backup end #####")
    end
    
    def sync
      #####  バックアップフォルダの同期ルーチン(バックアップディスクを他のディスクと同じ状態にする)
      @opt.validate_directories(2)
      
      start_time = Time.now
      @written_bytes = 0
      @error_files = []
      src = @opt.src
      dst = @opt.dst
      
      # 制限時間まで繰り返す(指定がない場合1回で終了)
      limit_time = start_time + (@opt.limit_sec)
      log("##### sync start #{fmt(start_time)} => limit_time=#{fmt(limit_time)} #####")
      count = 0
      last_sync_complete = false
      while true
        count += 1
        log("## sync_latest count=#{count} ##")
        latest_start = Time.now
        sync_result, from, to = sync_latest(src, dst)
        latest_end = Time.now
        
        log("## sync_latest result=#{sync_result} from=#{from} to=#{to} ##")
        unless sync_result
          # 同期結果がtrueでない場合ここで終了。ただしsync_result=falseになるのはコピー元フォルダが存在しない場合なので、
          # 中途半端な結果にはならない
          last_sync_complete = true
          break
        end
        
        from_count, to_count = do_verify(from, to)
        log("## from_count=#{from_count} to_count=#{to_count} equals=#{from_count == to_count} ##") 
        unless from_count == to_count
          # ファイル数が同じでない場合ここで終了
          last_sync_complete = false
          break        
        end
        
        # 次回同期にかかる時間を最終同期時間の半分と予想
        next_sync = (latest_end - latest_start) / 2
        
        cur_time = Time.now
        in_limit = (cur_time + next_sync) < limit_time
        log("## cur_time=#{fmt(cur_time)} + next_sync=#{next_sync} <  limit_time=#{fmt(limit_time)} in_limit=#{in_limit} ## ")
        unless in_limit
          # 指定時間内ではない場合ここで終了(ただし最終同期は成功)
          last_sync_complete = true
          break                
        end
      end
      
      end_time = Time.now
      diff = time_diff(start_time, end_time)

      elapsed = Time.now - start_time
      log_result(src, dst, elapsed)
        
      log("##### sync end #{fmt(end_time)} diff=#{diff} last_sync_complete=#{last_sync_complete} #####")
    end
      
    def verify
      file = @opt.open_verifyfile
    
      start_time = Time.now
      add_log("##### verify start #{fmt(start_time)} #####")
    
      src_count, dst_count = do_verify(src, dst)
    
      fputs(file, "#{src}: #{src_count}")
      fputs(file, "#{dst}: #{dst_count}")
      result = src_count == dst_count
      fputs(file, "result=#{result}")
      
      end_time = Time.now
      diff = time_diff(start_time, end_time)
      add_log("##### list end #{fmt(end_time)} diff=#{diff} #####")
      
      file.close 
    end
  
    def list
      file = @opt.open_listfile
      
      start_time = Time.now
      log("##### list start #{fmt(start_time)} #####")
      
      src = @opt.src
      QdumpfsFind.find(@opt.logger, src) do |path|
        short_path = path.sub(/^#{src}/, '.')
        log("#{File.ftype(path)} #{path}")
        if FileTest.file?(path)
          file.puts short_path
        end
      end
      
      end_time = Time.now
      diff = time_diff(start_time, end_time)
      log("##### list end #{fmt(end_time)} diff=#{diff} #####")
      
      file.close 
    end
    
    def delete(cmd)
      @opt.validate_directories(1)
      start_time = Time.now
      limit_time = start_time + (@opt.limit_sec)
      log("##### #{cmd} delete-from=#{@opt.delete_from} delete-to=#{@opt.delete_to} start #{fmt(start_time)} => limit_time=#{fmt(limit_time)} #####")
      @opt.dirs.each do |target_dir|
        
        target_start = Time.now        
        delete_target_dir(cmd, target_dir)
        target_end = Time.now
        
        # 次回expireにかかる時間を最終expire時間の半分と予想
        next_expire = (target_end - target_start) / 2
        
        cur_time = Time.now
        in_limit = (cur_time + next_expire) < limit_time
        
        log("## cur_time=#{fmt(cur_time)} + next_expire=#{next_expire} <  limit_time=#{fmt(limit_time)} in_limit=#{in_limit} ## ")
        unless in_limit
          break
        end
      end
      log("##### #{cmd} end #####")
    end

    def rm_dir(path)
      can_delete = true
      if @opt.dry_run
        can_delete = false
      elsif !FileTest.directory?(path)
        can_delete = false
      end
      msg = can_delete ? "...ok..." : "...ng..."
      print "Deleting #{path} #{msg}"

      return unless can_delete

      #それ以外は日付バックアップディレクトリ全体を削除
      if windows?
        # Windowsの場合
        win_backup_path = to_win_path(path)
        system("rmdir /S /Q #{win_backup_path}")
      else
        # Linux/macOSの場合
        system("rm -rf #{path}")
      end
    end

    def delete_target_dir(cmd, target_dir)
      target_dir = to_unix_path(target_dir)
      puts "<<<<< Target dir: #{target_dir} >>>>>"
      
      snapshots = BackupDir.scan_backup_dirs(target_dir)
      if cmd == 'expire'
        @opt.detect_expire_dirs(snapshots)
      elsif cmd == 'delete'
        @opt.detect_delete_dirs(snapshots, @opt.delete_from, @opt.delete_to) 
      else
        raise RuntimeError, "unknown command: #{cmd}"
      end
    
      snapshots.each do |snapshot|
        next if snapshot.keep
        t_start = Time.now

        if @opt.delete_dirs.size > 0
          #削除するディレクトリが指定されている場合日付バックアップディレクトリの下そのディレクトリを削除
          @opt.delete_dirs.each do |delete_dir|
            delete_path = File.join(snapshot.path, delete_dir)
            rm_dir(delete_path)
          end
        else
          #それ以外はバックアップディレクトリ全体が対象
          rm_dir(snapshot.path)
        end
        
        t_end = Time.now
        diff = (t_end - t_start).to_i
        diff_hours = diff / 3600
        puts " done[#{diff} seconds = #{diff_hours} hours]."
      end
      
      Dir.glob("#{target_dir}/[0-9][0-9][0-9][0-9]/[0-1][0-9] #{target_dir}/[0-9][0-9][0-9][0-9]").each do |dir|
        if File.directory?(dir) && Dir.entries(dir).size <= 2
          win_dir = to_win_path(dir)
          print "Deleting #{win_dir} ..."
          Dir.rmdir(win_dir)  unless @opt.dry_run
          puts " done."
        end
      end
      
      puts "Keep dirs:"
      snapshots.each do |snapshot|
        puts snapshot.path if snapshot.keep
      end      
    end

    
  end

end
