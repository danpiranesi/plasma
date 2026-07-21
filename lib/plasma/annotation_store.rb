require 'sqlite3'
require 'json'
require 'time'

module Plasma
  # SQLite-backed persistence for community annotations.
  #
  # SQLite because the deployment target is a Raspberry Pi on a village mesh:
  # one file, no daemon, no tuning, and it survives the power cuts that a
  # separate database server would not.
  #
  # Writes carry a client-supplied `client_id` so a phone that queued
  # annotations while offline can sync them repeatedly without creating
  # duplicates -- the mesh is lossy enough that a client often cannot tell
  # whether its write landed.
  class AnnotationStore
    def initialize(path = 'db/plasma.sqlite3', archive: Archive.default)
      @archive = archive
      @db = SQLite3::Database.new(path)
      @db.results_as_hash = true
      # Survives an unclean shutdown mid-write, which on a Pi with no UPS is
      # a routine event rather than an edge case.
      @db.execute('PRAGMA journal_mode = WAL')
      @db.execute('PRAGMA foreign_keys = ON')
      migrate!
    end

    def migrate!
      @db.execute_batch(<<~SQL)
        CREATE TABLE IF NOT EXISTS annotations (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id       TEXT    NOT NULL UNIQUE,
          recording_id    TEXT    NOT NULL,
          start_seconds   REAL    NOT NULL,
          end_seconds     REAL    NOT NULL,
          tag_indices     TEXT    NOT NULL,
          note            TEXT,
          voice_note_path TEXT,
          created_at      TEXT    NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_annotations_recording
          ON annotations (recording_id);
      SQL
    end

    # Persists an annotation. Raises ArgumentError if it does not validate --
    # callers are expected to have checked, and a bad write reaching this far
    # is a bug rather than user error.
    #
    # Idempotent on client_id: re-syncing an already-stored annotation returns
    # the existing row untouched instead of inserting a second copy.
    def create(annotation, client_id:)
      problems = annotation.errors(@archive)
      raise ArgumentError, "invalid annotation: #{problems.join('; ')}" unless problems.empty?
      raise ArgumentError, 'client_id is required' if client_id.nil? || client_id.to_s.strip.empty?

      existing = find_by_client_id(client_id)
      return existing if existing

      created_at = annotation.created_at || Time.now.utc.iso8601

      @db.execute(<<~SQL, [
        INSERT INTO annotations
          (client_id, recording_id, start_seconds, end_seconds, tag_indices,
           note, voice_note_path, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      SQL
                    client_id.to_s,
                    annotation.recording_id,
                    annotation.start_seconds.to_f,
                    annotation.end_seconds.to_f,
                    JSON.generate(annotation.tag_indices),
                    annotation.note,
                    annotation.voice_note_path,
                    created_at
                  ])

      find(@db.last_insert_row_id)
    end

    def find(id)
      row = @db.get_first_row('SELECT * FROM annotations WHERE id = ?', [id])
      row && hydrate(row)
    end

    def find_by_client_id(client_id)
      row = @db.get_first_row('SELECT * FROM annotations WHERE client_id = ?', [client_id.to_s])
      row && hydrate(row)
    end

    def for_recording(recording_id)
      @db.execute(
        'SELECT * FROM annotations WHERE recording_id = ? ORDER BY start_seconds ASC',
        [recording_id]
      ).map { |row| hydrate(row) }
    end

    def all
      @db.execute('SELECT * FROM annotations ORDER BY created_at ASC').map { |row| hydrate(row) }
    end

    def count
      @db.get_first_value('SELECT COUNT(*) FROM annotations')
    end

    # Everything recorded since a given ISO8601 timestamp -- the pull half of
    # mesh sync, letting a phone catch up on what other phones contributed
    # while it was away.
    def since(timestamp)
      @db.execute(
        'SELECT * FROM annotations WHERE created_at > ? ORDER BY created_at ASC',
        [timestamp.to_s]
      ).map { |row| hydrate(row) }
    end

    def close
      @db.close
    end

    private

    def hydrate(row)
      Annotation.new(
        id: row['id'],
        recording_id: row['recording_id'],
        start_seconds: row['start_seconds'],
        end_seconds: row['end_seconds'],
        tag_indices: JSON.parse(row['tag_indices']),
        note: row['note'],
        voice_note_path: row['voice_note_path'],
        created_at: row['created_at']
      )
    end
  end
end
