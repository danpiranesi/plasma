require_relative 'test_helper'

module Plasma
  class RecordingTest < TestCase
    def test_duration_label_is_zero_padded
      recording = Recording.new(category_index: 0, index: 0, title: 'Ragi harvest at Gudibande')
      assert_match(/\A\d+:\d{2}\z/, recording.duration_label)
    end

    def test_every_recording_has_a_plausible_duration
      archive.recordings.each do |recording|
        assert_operator recording.duration_seconds, :>, 60, "#{recording.title} is implausibly short"
        assert_operator recording.duration_seconds, :<, 600, "#{recording.title} is implausibly long"
        assert_equal recording.duration_seconds,
                     recording.duration_label.split(':').then { |m, s| m.to_i * 60 + s.to_i }
      end
    end

    def test_media_type_is_always_audio_or_video
      assert_empty(archive.recordings.map(&:media_type).uniq - %w[audio video])
    end

    def test_archive_is_predominantly_audio
      # Audio is the primary medium; video is the exception. If a change ever
      # flips that balance the interface's assumptions no longer hold.
      video = archive.recordings.count(&:video?)
      assert_operator video.to_f / archive.recordings.length, :<, 0.5
    end

    def test_waveform_peaks_are_normalised
      recording = archive.recording('0-0')
      peaks = recording.waveform

      assert_equal Waveform::DEFAULT_RESOLUTION, peaks.length
      peaks.each do |peak|
        assert_operator peak, :>=, Waveform::FLOOR
        assert_operator peak, :<=, Waveform::CEILING
      end
    end

    def test_waveform_is_deterministic
      assert_equal archive.recording('0-3').waveform, archive.recording('0-3').waveform
    end

    def test_waveform_differs_between_recordings
      refute_equal archive.recording('0-0').waveform, archive.recording('0-1').waveform
    end

    def test_waveform_resolution_is_configurable
      # Lower resolution is how a weak link gets a cheaper seekbar.
      assert_equal 40, archive.recording('0-0').waveform(40).length
    end

    def test_seeded_annotations_fall_inside_the_recording
      archive.recordings.each do |recording|
        recording.seeded_annotations.each do |annotation|
          assert_operator annotation[:position], :>, 0.0
          assert_operator annotation[:position], :<, 1.0
          assert_includes 0...Archive::CATEGORY_COUNT, annotation[:category_index]
          assert_includes Recording::ANNOTATION_LABELS, annotation[:label]
        end
      end
    end

    def test_tag_indices_are_unique_and_sorted
      archive.recordings.each do |recording|
        tags = recording.tag_indices
        assert_equal tags.uniq, tags, "#{recording.id} has duplicate tags"
        assert_equal tags.sort, tags, "#{recording.id} tags are unsorted"
      end
    end
  end
end
