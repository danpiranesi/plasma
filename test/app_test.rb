require_relative 'test_helper'
require_relative '../app'

module Plasma
  class AppTest < TestCase
    include Rack::Test::Methods

    def app
      Plasma::App
    end

    def setup
      @tmpdir = Dir.mktmpdir('plasma-app-test')
      # Point the running app at a throwaway database for each test.
      Plasma::App.set :store, AnnotationStore.new(File.join(@tmpdir, 'test.sqlite3'), archive: archive)
    end

    def body
      JSON.parse(last_response.body)
    end

    def post_annotation(payload)
      post '/api/annotations', JSON.generate(payload), 'CONTENT_TYPE' => 'application/json'
    end

    def valid_payload(**overrides)
      {
        'client_id' => 'phone-a:1',
        'recording_id' => '0-0',
        'start_seconds' => 15.0,
        'end_seconds' => 65.0,
        'tag_indices' => [1, 4]
      }.merge(overrides.transform_keys(&:to_s))
    end

    # ── Shell ────────────────────────────────────────────────────────────

    def test_serves_the_shell_at_the_root
      get '/'
      assert last_response.ok?
      assert_includes last_response.body, 'PLASMA'
    end

    def test_the_shell_makes_no_external_network_requests
      # The deployment target is a village mesh with no internet. Any external
      # host in the shell is a hard failure in the field, not a slow load.
      get '/'
      external = last_response.body.scan(%r{https?://[^"'\s)]+})
                                   .reject { |url| url.start_with?('http://www.w3.org/') }
      assert_empty external, "shell depends on external hosts: #{external.uniq.inspect}"
    end

    # ── Health ───────────────────────────────────────────────────────────

    def test_health_reports_archive_size
      get '/api/health'
      assert last_response.ok?
      assert_equal 'ok', body['status']
      assert_equal 96, body['recordings']
    end

    # ── Writing annotations ──────────────────────────────────────────────

    def test_accepts_a_valid_annotation
      post_annotation(valid_payload)

      assert_equal 201, last_response.status
      assert_equal '0-0', body['annotation']['recording_id']
      assert_equal 't=15.00,65.00', body['annotation']['fragment_selector']
    end

    def test_replayed_sync_returns_the_stored_annotation_without_duplicating
      post_annotation(valid_payload)
      first_id = body['annotation']['id']

      post_annotation(valid_payload)
      assert_equal 200, last_response.status, 'a replay should not report a new resource'
      assert_equal first_id, body['annotation']['id']

      get '/api/sync'
      assert_equal 1, body['count']
    end

    def test_rejects_an_annotation_with_no_tags
      post_annotation(valid_payload(tag_indices: []))

      assert_equal 422, last_response.status
      assert_includes body['errors'].join, 'at least one tag'
    end

    def test_rejects_an_annotation_for_an_unknown_recording
      post_annotation(valid_payload(recording_id: '99-99'))
      assert_equal 422, last_response.status
    end

    def test_rejects_an_annotation_with_no_client_id
      post_annotation(valid_payload.tap { |p| p.delete('client_id') })

      assert_equal 422, last_response.status
      assert_includes body['errors'].join, 'client_id'
    end

    def test_rejects_a_malformed_request_body
      post '/api/annotations', 'not json at all', 'CONTENT_TYPE' => 'application/json'
      assert_equal 400, last_response.status
    end

    def test_a_rejected_annotation_is_not_stored
      post_annotation(valid_payload(tag_indices: []))

      get '/api/sync'
      assert_equal 0, body['count']
    end

    # ── Reading annotations ──────────────────────────────────────────────

    def test_returns_seeded_and_community_annotations_for_a_recording
      post_annotation(valid_payload)

      get '/api/recordings/0-0/annotations'
      assert last_response.ok?
      refute_empty body['seeded']
      assert_equal 1, body['community'].length
      assert_equal 'Ragi harvest at Gudibande', body['recording']['title']
    end

    def test_unknown_recording_returns_404
      get '/api/recordings/99-99/annotations'
      assert_equal 404, last_response.status
    end

    # ── Sync ─────────────────────────────────────────────────────────────

    def test_sync_returns_only_annotations_newer_than_the_given_timestamp
      post_annotation(valid_payload(client_id: 'c:1', created_at: '2026-01-01T00:00:00Z'))
      post_annotation(valid_payload(client_id: 'c:2', created_at: '2026-06-01T00:00:00Z'))

      get '/api/sync', since: '2026-03-01T00:00:00Z'
      assert_equal 1, body['count']
    end

    def test_unknown_route_returns_json_not_html
      get '/api/nope'
      assert_equal 404, last_response.status
      assert_equal 'not found', body['error']
    end
  end
end
