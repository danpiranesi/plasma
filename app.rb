require 'sinatra/base'
require 'json'
require_relative 'lib/plasma'

module Plasma
  # The PLASMA server.
  #
  # Deliberately small. The read path is *not* here: the archive catalogue is
  # inlined into the shell at boot so a phone can browse, play and explore with
  # zero network requests. Round trips, not bytes, are what fail on a village
  # mesh, and browsing must not depend on one.
  #
  # What the server owns is the write path -- annotations arriving from phones,
  # possibly days late, possibly more than once -- plus sync and the shell itself.
  class App < Sinatra::Base
    set :public_folder, File.expand_path('public', __dir__)
    set :static, true
    set :show_exceptions, false
    set :raise_errors, false

    configure do
      set :archive, Archive.default
      set :store, AnnotationStore.new(ENV.fetch('PLASMA_DB', 'db/plasma.sqlite3'))
    end

    helpers do
      def archive
        settings.archive
      end

      def store
        settings.store
      end

      def json(payload, status_code = 200)
        status status_code
        content_type :json
        JSON.generate(payload)
      end

      def parsed_body
        body = request.body.read
        return {} if body.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        halt 400, json(error: 'request body is not valid JSON')
      end
    end

    # ── Shell ────────────────────────────────────────────────────────────
    # index.html carries the whole archive inline and is fully usable offline.

    get '/' do
      send_file File.join(settings.public_folder, 'index.html')
    end

    # ── Health ───────────────────────────────────────────────────────────
    # Used by the mesh to tell "the Pi is up" from "the Pi is reachable".

    get '/api/health' do
      json(
        status: 'ok',
        version: VERSION,
        recordings: archive.recordings.length,
        annotations: store.count
      )
    end

    # ── Annotations: the write path ──────────────────────────────────────

    post '/api/annotations' do
      payload = parsed_body

      annotation = Annotation.new(
        recording_id: payload['recording_id'],
        start_seconds: payload['start_seconds'],
        end_seconds: payload['end_seconds'],
        tag_indices: payload['tag_indices'],
        note: payload['note'],
        voice_note_path: payload['voice_note_path'],
        created_at: payload['created_at']
      )

      problems = annotation.errors(archive)
      return json({ errors: problems }, 422) unless problems.empty?

      client_id = payload['client_id']
      return json({ errors: ['client_id is required'] }, 422) if client_id.nil? || client_id.to_s.strip.empty?

      # A client re-syncing a queued annotation gets 200 and the stored row;
      # a genuinely new one gets 201. Either way it can safely drop its copy.
      existing = store.find_by_client_id(client_id)
      record = existing || store.create(annotation, client_id: client_id)

      json({ annotation: record.to_h }, existing ? 200 : 201)
    end

    get '/api/recordings/:id/annotations' do
      recording = archive.recording(params['id'])
      halt 404, json(error: 'no such recording') unless recording

      json(
        recording: recording.to_h,
        seeded: recording.seeded_annotations,
        community: store.for_recording(recording.id).map(&:to_h)
      )
    end

    # ── Sync ─────────────────────────────────────────────────────────────
    # The pull half: what has the archive learned since I was last online?

    get '/api/sync' do
      since = params['since']
      records = since ? store.since(since) : store.all
      json(annotations: records.map(&:to_h), count: records.length)
    end

    # ── Errors ───────────────────────────────────────────────────────────

    not_found do
      json({ error: 'not found' }, 404)
    end

    error do
      json({ error: env['sinatra.error'].message }, 500)
    end
  end
end
