require_relative 'test_helper'

module Plasma
  class ArchiveTest < TestCase
    def test_loads_the_full_catalogue
      assert_equal Archive::CATEGORY_COUNT, archive.categories.length
      assert_equal 96, archive.recordings.length
      assert(archive.categories.all? { |c| c.recordings.length == 8 })
    end

    def test_every_category_carries_a_non_textual_identity
      # The interface must be navigable without reading, so icon and tone are
      # load-bearing, not decoration.
      archive.categories.each do |category|
        refute_empty category.icon, "#{category.name} has no icon"
        assert_operator category.tone_hz, :>, 0, "#{category.name} has no tone"
      end
    end

    def test_category_icons_are_all_distinct
      # Icons are the primary way categories are told apart, so a duplicate
      # would leave two of them indistinguishable to someone who cannot read.
      icons = archive.categories.map(&:icon)
      assert_equal icons.length, icons.uniq.length
    end

    def test_category_tones_are_all_distinct
      # Two categories sharing a tone would be indistinguishable by ear.
      tones = archive.categories.map(&:tone_hz)
      assert_equal tones.length, tones.uniq.length
    end

    def test_recording_ids_are_unique_and_addressable
      ids = archive.recordings.map(&:id)
      assert_equal ids.length, ids.uniq.length

      archive.recordings.each do |recording|
        assert_same recording, archive.recording(recording.id)
      end
    end

    def test_recording_lookup_rejects_malformed_ids
      [nil, '', 'abc', '0', '0-', '-0', '0-0-0', '12-0', '0-8', '-1-0', 0].each do |id|
        assert_nil archive.recording(id), "expected #{id.inspect} to resolve to nothing"
      end
    end

    def test_shared_archives_requires_at_least_two_tags
      assert_empty archive.recordings_tagged_with([])
      assert_empty archive.recordings_tagged_with([3])
    end

    def test_shared_archives_returns_only_recordings_carrying_every_tag
      results = archive.recordings_tagged_with([0, 1])

      refute_empty results
      results.each do |recording|
        assert_includes recording.tag_indices, 0
        assert_includes recording.tag_indices, 1
      end
    end

    def test_shared_archives_rejects_unknown_tags
      assert_empty archive.recordings_tagged_with([0, 99])
    end

    def test_every_recording_is_tagged_with_its_own_category
      archive.categories.each do |category|
        category.recordings.each do |recording|
          assert_includes recording.tag_indices, category.index
        end
      end
    end
  end
end
