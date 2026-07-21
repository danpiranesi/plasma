require_relative 'test_helper'

module Plasma
  class AnnotationStoreTest < TestCase
    def test_persists_and_reads_back_an_annotation
      record = store.create(build_annotation, client_id: 'phone-a:1')

      assert_predicate record.id, :positive?
      assert_equal '0-0', record.recording_id
      assert_equal [1, 4], record.tag_indices
      assert_equal 1, store.count
    end

    def test_stamps_created_at_when_the_client_did_not
      record = store.create(build_annotation, client_id: 'phone-a:1')
      refute_nil record.created_at
      assert Time.parse(record.created_at)
    end

    def test_preserves_a_client_supplied_created_at
      # A phone that recorded an annotation while offline knows when it
      # happened; the server must not overwrite that with the sync time.
      recorded_at = '2026-03-01T09:15:00Z'
      record = store.create(build_annotation(created_at: recorded_at), client_id: 'phone-a:1')
      assert_equal recorded_at, record.created_at
    end

    def test_syncing_the_same_annotation_twice_does_not_duplicate_it
      # The mesh is lossy enough that a phone often cannot tell whether its
      # write landed, so it retries. That must be safe.
      first  = store.create(build_annotation, client_id: 'phone-a:1')
      second = store.create(build_annotation(note: 'changed'), client_id: 'phone-a:1')

      assert_equal 1, store.count
      assert_equal first.id, second.id
      assert_nil second.note, 'a replayed sync must not overwrite the stored row'
    end

    def test_distinct_clients_can_annotate_the_same_fragment
      store.create(build_annotation, client_id: 'phone-a:1')
      store.create(build_annotation, client_id: 'phone-b:1')

      assert_equal 2, store.count
    end

    def test_refuses_to_store_an_invalid_annotation
      error = assert_raises(ArgumentError) do
        store.create(build_annotation(tag_indices: []), client_id: 'phone-a:1')
      end
      assert_includes error.message, 'at least one tag'
      assert_equal 0, store.count
    end

    def test_requires_a_client_id
      [nil, '', '   '].each do |bad|
        assert_raises(ArgumentError) { store.create(build_annotation, client_id: bad) }
      end
      assert_equal 0, store.count
    end

    def test_lists_annotations_for_a_recording_in_playback_order
      store.create(build_annotation(start_seconds: 90, end_seconds: 120), client_id: 'c:3')
      store.create(build_annotation(start_seconds: 10, end_seconds: 40),  client_id: 'c:1')
      store.create(build_annotation(start_seconds: 50, end_seconds: 80),  client_id: 'c:2')

      starts = store.for_recording('0-0').map(&:start_seconds)
      assert_equal [10.0, 50.0, 90.0], starts
    end

    def test_scopes_annotations_to_their_own_recording
      store.create(build_annotation(recording_id: '0-0'), client_id: 'c:1')
      store.create(build_annotation(recording_id: '1-2'), client_id: 'c:2')

      assert_equal 1, store.for_recording('0-0').length
      assert_empty store.for_recording('5-5')
    end

    def test_sync_returns_only_what_is_newer_than_the_clients_last_pull
      store.create(build_annotation(created_at: '2026-01-01T00:00:00Z'), client_id: 'c:1')
      store.create(build_annotation(created_at: '2026-06-01T00:00:00Z'), client_id: 'c:2')

      recent = store.since('2026-03-01T00:00:00Z')
      assert_equal 1, recent.length
      assert_equal '2026-06-01T00:00:00Z', recent.first.created_at
    end

    def test_tag_indices_survive_a_round_trip_through_storage
      record = store.create(build_annotation(tag_indices: [0, 5, 11]), client_id: 'c:1')
      assert_equal [0, 5, 11], store.find(record.id).tag_indices
    end

    def test_find_returns_nothing_for_an_unknown_id
      assert_nil store.find(12_345)
      assert_nil store.find_by_client_id('never-synced')
    end
  end
end
