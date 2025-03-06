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
