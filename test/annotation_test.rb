require_relative 'test_helper'

module Plasma
  class AnnotationTest < TestCase
    def test_a_well_formed_annotation_validates
      assert_empty build_annotation.errors(archive)
    end

    def test_requires_a_real_recording
      errors = build_annotation(recording_id: '99-99').errors(archive)
      assert_includes errors.join, 'does not match any recording'
    end

    def test_requires_at_least_one_tag
      # An untagged fragment is invisible to the Explore view, so it is not a
      # useful contribution to the archive.
      assert_includes build_annotation(tag_indices: []).errors(archive).join, 'at least one tag'
      assert_includes build_annotation(tag_indices: nil).errors(archive).join, 'at least one tag'
    end

    def test_rejects_unknown_tags
      assert_includes build_annotation(tag_indices: [1, 99]).errors(archive).join, 'unknown tag'
    end

    def test_rejects_duplicate_tags
      assert_includes build_annotation(tag_indices: [1, 1]).errors(archive).join, 'duplicates'
    end

    def test_rejects_inverted_and_empty_ranges
      assert_includes build_annotation(start_seconds: 60, end_seconds: 30).errors(archive).join,
                      'greater than start_seconds'
      assert_includes build_annotation(start_seconds: 30, end_seconds: 30).errors(archive).join,
                      'greater than start_seconds'
    end

    def test_rejects_negative_start
      assert_includes build_annotation(start_seconds: -5, end_seconds: 30).errors(archive).join,
                      'cannot be negative'
    end

    def test_rejects_non_numeric_bounds
      assert_includes build_annotation(start_seconds: 'nope', end_seconds: 30).errors(archive).join,
                      'must both be numbers'
      assert_includes build_annotation(start_seconds: nil, end_seconds: nil).errors(archive).join,
                      'must both be numbers'
    end

    def test_rejects_a_fragment_shorter_than_a_deliberate_tap
      assert_includes build_annotation(start_seconds: 10.0, end_seconds: 10.1).errors(archive).join,
                      'at least'
    end

    def test_rejects_a_fragment_past_the_end_of_the_recording
      recording = archive.recording('0-0')
      errors = build_annotation(start_seconds: 10, end_seconds: recording.duration_seconds + 60).errors(archive)
      assert_includes errors.join, 'past the end'
    end

    def test_reports_every_problem_at_once
      # A phone syncing after days offline should learn everything wrong with a
      # queued annotation in one round trip, not one problem per attempt.
      errors = build_annotation(start_seconds: -1, end_seconds: -5, tag_indices: [99]).errors(archive)
      assert_operator errors.length, :>=, 2
    end

    def test_fragment_selector_uses_w3c_media_fragment_syntax
      annotation = build_annotation(start_seconds: 15.0, end_seconds: 65.5)
      assert_equal 't=15.00,65.50', annotation.fragment_selector
    end

    def test_duration_is_the_span_of_the_fragment
      assert_in_delta 50.0, build_annotation(start_seconds: 15.0, end_seconds: 65.0).duration_seconds, 1e-9
    end
  end
end
