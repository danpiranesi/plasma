ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'json'
require 'tmpdir'

require_relative '../lib/plasma'

module Plasma
  class TestCase < Minitest::Test
    def archive
      @archive ||= Archive.load
    end

    # A store backed by a throwaway database file per test, so tests never see
    # each other's writes and never touch the real archive.
    def store
      @store ||= begin
        @tmpdir = Dir.mktmpdir('plasma-test')
        AnnotationStore.new(File.join(@tmpdir, 'test.sqlite3'), archive: archive)
      end
    end

    def teardown
      @store&.close
      FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    end

    # A valid annotation on a known recording, for tests that want to vary one
    # field at a time.
    def build_annotation(**overrides)
      defaults = {
        recording_id: '0-0',
        start_seconds: 15.0,
        end_seconds: 65.0,
        tag_indices: [1, 4]
      }
      Annotation.new(**defaults.merge(overrides))
    end
  end
end
