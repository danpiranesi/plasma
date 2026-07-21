module Plasma
  # A community annotation: a tagged time range on a recording, optionally
  # carrying a voice note.
  #
  # Modelled on the W3C Web Annotation fragment selector (`t=start,end`) so the
  # archive stays interoperable rather than trapped in a bespoke schema.
  #
  # Validation is strict and happens here, not at the route, because annotations
  # arrive from phones that have been offline for days: a client that queued a
  # bad write should learn it is bad on sync, not silently corrupt the archive.
  class Annotation
    # A fragment shorter than this is almost certainly a mis-tap on a phone
    # rather than a deliberate selection.
    MIN_FRAGMENT_SECONDS = 0.5

    attr_reader :id, :recording_id, :start_seconds, :end_seconds,
                :tag_indices, :note, :voice_note_path, :created_at

    def initialize(recording_id:, start_seconds:, end_seconds:, tag_indices:,
                   note: nil, voice_note_path: nil, id: nil, created_at: nil)
      @id = id
      @recording_id = recording_id
      @start_seconds = start_seconds
      @end_seconds = end_seconds
      @tag_indices = tag_indices
      @note = note
      @voice_note_path = voice_note_path
      @created_at = created_at
    end

    # Returns [] when valid, otherwise a list of human-readable problems.
    # Every problem is reported at once so a syncing client can fix them in a
    # single round trip instead of one per attempt.
    def errors(archive)
      problems = []
      recording = archive.recording(recording_id)

      problems << 'recording_id does not match any recording in the archive' if recording.nil?
      problems.concat(fragment_errors(recording))
      problems.concat(tag_errors(archive))
      problems
    end

    def valid?(archive)
      errors(archive).empty?
    end

    def duration_seconds
      end_seconds - start_seconds
    end

    # W3C Media Fragments URI syntax.
    def fragment_selector
      "t=#{format('%.2f', start_seconds)},#{format('%.2f', end_seconds)}"
    end

    def to_h
      {
        id: id,
        recording_id: recording_id,
        start_seconds: start_seconds,
        end_seconds: end_seconds,
        duration_seconds: duration_seconds,
        fragment_selector: fragment_selector,
        tag_indices: tag_indices,
        note: note,
        voice_note_path: voice_note_path,
        created_at: created_at
      }
    end

    private

    def fragment_errors(recording)
      problems = []

      unless numeric?(start_seconds) && numeric?(end_seconds)
        return ['start_seconds and end_seconds must both be numbers']
      end

      problems << 'start_seconds cannot be negative' if start_seconds.negative?
      problems << 'end_seconds must be greater than start_seconds' if end_seconds <= start_seconds

      if end_seconds > start_seconds && duration_seconds < MIN_FRAGMENT_SECONDS
        problems << "fragment must be at least #{MIN_FRAGMENT_SECONDS}s long"
      end

      if recording && end_seconds > recording.duration_seconds
        problems << "fragment ends past the end of the recording (#{recording.duration_seconds}s)"
      end

      problems
    end

    def tag_errors(archive)
      return ['at least one tag is required'] unless tag_indices.is_a?(Array) && !tag_indices.empty?

      unknown = tag_indices.reject { |t| archive.valid_tag_index?(t) }
      return ["unknown tag indices: #{unknown.inspect}"] unless unknown.empty?

      return ['tag_indices contains duplicates'] if tag_indices.uniq.length != tag_indices.length

      []
    end

    def numeric?(value)
      value.is_a?(Numeric)
    end
  end
end
