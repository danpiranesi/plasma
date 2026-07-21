module Plasma
  # A single oral recording in the archive.
  #
  # Identified by "<category_index>-<recording_index>", matching the coordinates
  # the dial already navigates by. Stable, human-readable in logs, and needs no
  # ID generator on a device that may be offline for days.
  class Recording
    # Labels a facilitator can attach to a fragment. Deliberately short and
    # concrete -- these become spoken Kannada cues, not written text.
    ANNOTATION_LABELS = [
      'starts singing', 'mentions water tank', 'elder speaks up',
      'place name given', 'second voice', 'crowd joins in',
      'crop name', 'ancestor reference', 'seasonal marker', 'tool described',
      'laughter', 'song begins', 'prayer ends', 'name of person'
    ].freeze

    attr_reader :category_index, :index, :title

    def initialize(category_index:, index:, title:)
      @category_index = category_index
      @index = index
      @title = title
    end

    def id
      "#{category_index}-#{index}"
    end

    # Roughly 30% of the archive is video. Derived from the title rather than
    # stored so the catalogue stays a flat list of titles; replaced by a real
    # MIME check once actual media lands.
    def media_type
      hash = (title[0].ord * 7 + title[1].ord * 13 + title.length * 3) % 10
      hash < 3 ? 'video' : 'audio'
    end

    def video?
      media_type == 'video'
    end

    def duration_seconds
      (2 + (title.length % 3)) * 60 + ((title[0].ord * 13) % 60)
    end

    def duration_label
      format('%d:%02d', duration_seconds / 60, duration_seconds % 60)
    end

    def waveform(resolution = Waveform::DEFAULT_RESOLUTION)
      Waveform.generate(resolution, seed)
    end

    # Annotations the archive ships with, standing in for work already done by
    # the community. Real facilitator annotations live in AnnotationStore.
    def seeded_annotations
      seed_value = index * 17 + category_index * 5
      count = 2 + (seed_value % 3)

      Array.new(count) do |i|
        {
          position: ((seed_value * (i + 1) * 11) % 82 + 8) / 100.0,
          category_index: (category_index + i * 4 + 1) % Archive::CATEGORY_COUNT,
          label: ANNOTATION_LABELS[(seed_value + i * 3) % ANNOTATION_LABELS.length]
        }
      end
    end

    # Every tag on this recording: its own category, plus whatever the seeded
    # annotations point at. This is what the Explore view intersects on.
    def tag_indices
      ([category_index] + seeded_annotations.map { |a| a[:category_index] }).uniq.sort
    end

    def to_h
      {
        id: id,
        title: title,
        category_index: category_index,
        media_type: media_type,
        duration_seconds: duration_seconds,
        duration_label: duration_label,
        tag_indices: tag_indices
      }
    end

    private

    # Matches the prototype's `genWave(120, storyIdx + 1)` so the peaks the
    # server computes and the peaks the shell draws are the same waveform.
    def seed
      index + 1
    end
  end
end
