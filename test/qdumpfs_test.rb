require "test_helper"

class QdumpfsTest < Minitest::Test
  DATA_DIR = File.expand_path('../../test/fixtures/data', __FILE__)
  SRC_DIR = File.expand_path('../../test/fixtures/src', __FILE__)
  DST_DIR = File.expand_path('../../test/fixtures/dst', __FILE__)

  def test_that_it_has_a_version_number
    refute_nil ::Qdumpfs::VERSION
  end


  def setup
    cleanup
  end

  def teardown
    cleanup
  end

  def test_backup
    ##    puts DATA_PATH
    #puts "Hello world"

    FileUtils.cp_r(DATA_DIR, SRC_DIR)
    FileUtils.mkdir(DST_DIR)
    qdumpfs_backup(SRC_DIR, DST_DIR)

    dst_today = File.join(DST_DIR, Time.now.strftime("%Y/%m/%d/src"))
    result = `diff -r #{SRC_DIR} #{dst_today}`
    assert_equal("", result)
  end

  def test_backup_one_file_system
    skip "hdiutilが必要(macOSのみ)" unless system('which hdiutil > /dev/null 2>&1')

    FileUtils.cp_r(DATA_DIR, SRC_DIR)
    mnt = File.join(SRC_DIR, 'mnt')
    FileUtils.mkdir(mnt)
    Dir.mktmpdir do |tmp|
      # 別ファイルシステムをバックアップ元の中にマウント
      image = File.join(tmp, 'other.dmg')
      assert system("hdiutil create -quiet -size 1m -fs HFS+ -volname qdumpfs_test #{image}")
      assert system("hdiutil attach -quiet -nobrowse -mountpoint #{mnt} #{image}")
      begin
        File.write(File.join(mnt, 'other.txt'), 'other')

        # --one-file-systemなし: 境界をまたいでコピーし、警告を出す
        FileUtils.mkdir(DST_DIR)
        log = File.join(tmp, 'cross.log')
        capture_io { run_qdumpfs(['--logpath', log, SRC_DIR, DST_DIR]) }
        dst_today = File.join(DST_DIR, Time.now.strftime("%Y/%m/%d/src"))
        assert File.exist?(File.join(dst_today, 'mnt', 'other.txt'))
        assert_includes File.read(log), "warn: crossing filesystem boundary path=#{mnt}"

        # --one-file-systemあり: マウントポイント配下はコピーしない
        FileUtils.rm_rf(DST_DIR)
        FileUtils.mkdir(DST_DIR)
        log = File.join(tmp, 'skip.log')
        capture_io { run_qdumpfs(['-x', '--logpath', log, SRC_DIR, DST_DIR]) }
        refute File.exist?(File.join(dst_today, 'mnt'))
        assert_includes File.read(log), "skip other filesystem path=#{mnt}"
      ensure
        system("hdiutil detach -quiet #{mnt}")
      end
    end

    # 同じファイルシステム上のファイルはコピーされる
    FileUtils.rmdir(mnt)
    dst_today = File.join(DST_DIR, Time.now.strftime("%Y/%m/%d/src"))
    result = `diff -r #{SRC_DIR} #{dst_today}`
    assert_equal("", result)
  end

  private

  def qdumpfs_backup_args(from, to)
    args = []
    args << '-q'
    args << from
    args << to
    args
  end

  def run_qdumpfs(args)
    Qdumpfs::Command.run(args)
  end

  def qdumpfs_backup(from, to)
    args = qdumpfs_backup_args(from, to)
    run_qdumpfs(args)
  end

  def cleanup
    FileUtils.rm_rf([SRC_DIR, DST_DIR])
  end
end
