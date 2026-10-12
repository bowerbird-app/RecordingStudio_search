SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id uuid NOT NULL,
    blob_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.folders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, COALESCE((title)::text, ''::text))) STORED
);


--
-- Name: pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    title character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    body text,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector('english'::regconfig, COALESCE((title)::text, ''::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, COALESCE(body, ''::text)), 'D'::"char"))) STORED
);


--
-- Name: recording_studio_access_constraints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_access_constraints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action character varying NOT NULL,
    allowed_audiences character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_access_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_access_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recording_id uuid NOT NULL,
    email character varying NOT NULL,
    role character varying NOT NULL,
    token_digest character varying(64) NOT NULL,
    manager_actor_type character varying NOT NULL,
    manager_actor_id uuid NOT NULL,
    accepted_by_actor_type character varying,
    accepted_by_actor_id uuid,
    expires_at timestamp(6) without time zone NOT NULL,
    last_sent_at timestamp(6) without time zone NOT NULL,
    accepted_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT access_invitations_not_accepted_and_revoked CHECK (((accepted_at IS NULL) OR (revoked_at IS NULL)))
);


--
-- Name: recording_studio_access_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_access_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action character varying NOT NULL,
    audience character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_accesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_accesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid NOT NULL,
    actor_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    role character varying DEFAULT 'view'::character varying NOT NULL,
    depends_on_recording_id uuid
);


--
-- Name: recording_studio_attachable_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_attachable_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description text,
    attachment_kind character varying NOT NULL,
    original_filename character varying NOT NULL,
    content_type character varying NOT NULL,
    byte_size bigint NOT NULL,
    root_recording_id uuid,
    caption text,
    credit text,
    alt_text text
);


--
-- Name: recording_studio_attachable_libraries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_attachable_libraries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying DEFAULT 'default'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_attachable_placements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_attachable_placements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    attachment_recording_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action character varying NOT NULL,
    actor_id uuid,
    actor_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    idempotency_key character varying,
    impersonator_id uuid,
    impersonator_type character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    previous_recordable_id uuid,
    previous_recordable_type character varying,
    recordable_id uuid NOT NULL,
    recordable_type character varying NOT NULL,
    recording_id uuid NOT NULL
);


--
-- Name: recording_studio_recordings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_recordings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    parent_recording_id uuid,
    recordable_id uuid NOT NULL,
    recordable_type character varying NOT NULL,
    root_recording_id uuid,
    trashed_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_root_switchable_selections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_root_switchable_selections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id character varying,
    actor_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    device_browser character varying,
    device_key character varying NOT NULL,
    device_label character varying,
    device_platform character varying,
    device_type character varying,
    last_used_at timestamp(6) without time zone NOT NULL,
    root_recording_id uuid NOT NULL,
    scope_key character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent text
);


--
-- Name: recording_studio_search_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_search_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    searchable_type character varying NOT NULL,
    searchable_id uuid NOT NULL,
    recording_id uuid,
    embedding public.vector(8),
    embedding_at timestamp(6) without time zone,
    embedding_model character varying,
    content_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_search_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_search_queries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    keyword character varying NOT NULL,
    embedding jsonb NOT NULL,
    embedding_model character varying NOT NULL,
    embedding_at timestamp(6) without time zone NOT NULL,
    hit_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_user_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_user_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    provider character varying NOT NULL,
    uid character varying NOT NULL,
    email character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_user_otp_challenges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_user_otp_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    purpose character varying NOT NULL,
    code_digest character varying NOT NULL,
    delivery_code_ciphertext text,
    expires_at timestamp(6) without time zone NOT NULL,
    attempts_count integer DEFAULT 0 NOT NULL,
    verified_at timestamp(6) without time zone,
    consumed_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    delivery_requested_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_user_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_user_people (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recording_studio_user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_studio_user_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying,
    time_zone character varying DEFAULT 'UTC'::character varying,
    additional_profile_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    remember_created_at timestamp(6) without time zone,
    reset_password_sent_at timestamp(6) without time zone,
    reset_password_token character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying,
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, ((COALESCE((name)::text, ''::text) || ' '::text) || COALESCE((email)::text, ''::text)))) STORED,
    registered_with character varying DEFAULT 'password'::character varying NOT NULL,
    confirmation_token character varying,
    confirmed_at timestamp(6) without time zone,
    confirmation_sent_at timestamp(6) without time zone,
    unconfirmed_email character varying,
    CONSTRAINT users_registered_with_check CHECK (((registered_with)::text = ANY (ARRAY[('password'::character varying)::text, ('otp'::character varying)::text])))
);


--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: folders folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.folders
    ADD CONSTRAINT folders_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: pages pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pages
    ADD CONSTRAINT pages_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_access_constraints recording_studio_access_constraints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_access_constraints
    ADD CONSTRAINT recording_studio_access_constraints_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_access_invitations recording_studio_access_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_access_invitations
    ADD CONSTRAINT recording_studio_access_invitations_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_access_rules recording_studio_access_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_access_rules
    ADD CONSTRAINT recording_studio_access_rules_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_accesses recording_studio_accesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_accesses
    ADD CONSTRAINT recording_studio_accesses_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_attachable_attachments recording_studio_attachable_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_attachable_attachments
    ADD CONSTRAINT recording_studio_attachable_attachments_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_attachable_libraries recording_studio_attachable_libraries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_attachable_libraries
    ADD CONSTRAINT recording_studio_attachable_libraries_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_attachable_placements recording_studio_attachable_placements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_attachable_placements
    ADD CONSTRAINT recording_studio_attachable_placements_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_events recording_studio_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_events
    ADD CONSTRAINT recording_studio_events_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_recordings recording_studio_recordings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_recordings
    ADD CONSTRAINT recording_studio_recordings_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_root_switchable_selections recording_studio_root_switchable_selections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_root_switchable_selections
    ADD CONSTRAINT recording_studio_root_switchable_selections_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_search_documents recording_studio_search_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_search_documents
    ADD CONSTRAINT recording_studio_search_documents_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_search_queries recording_studio_search_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_search_queries
    ADD CONSTRAINT recording_studio_search_queries_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_user_identities recording_studio_user_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_identities
    ADD CONSTRAINT recording_studio_user_identities_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_user_otp_challenges recording_studio_user_otp_challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_otp_challenges
    ADD CONSTRAINT recording_studio_user_otp_challenges_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_user_people recording_studio_user_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_people
    ADD CONSTRAINT recording_studio_user_people_pkey PRIMARY KEY (id);


--
-- Name: recording_studio_user_profiles recording_studio_user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_profiles
    ADD CONSTRAINT recording_studio_user_profiles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: idx_on_attachment_kind_d683071625; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_attachment_kind_d683071625 ON public.recording_studio_attachable_attachments USING btree (attachment_kind);


--
-- Name: idx_on_attachment_recording_id_76c6286907; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_attachment_recording_id_76c6286907 ON public.recording_studio_attachable_placements USING btree (attachment_recording_id);


--
-- Name: idx_on_user_id_purpose_2b7c2a59c4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_user_id_purpose_2b7c2a59c4 ON public.recording_studio_user_otp_challenges USING btree (user_id, purpose);


--
-- Name: idx_rs_access_invitations_one_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rs_access_invitations_one_active ON public.recording_studio_access_invitations USING btree (recording_id, email) WHERE ((accepted_at IS NULL) AND (revoked_at IS NULL));


--
-- Name: idx_rs_access_invitations_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rs_access_invitations_token_digest ON public.recording_studio_access_invitations USING btree (token_digest);


--
-- Name: idx_rs_attachable_kind_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_attachable_kind_type ON public.recording_studio_attachable_attachments USING btree (attachment_kind, content_type);


--
-- Name: idx_rs_attachable_parent_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_attachable_parent_active ON public.recording_studio_recordings USING btree (parent_recording_id) WHERE (((recordable_type)::text = 'RecordingStudioAttachable::Attachment'::text) AND (trashed_at IS NULL));


--
-- Name: idx_rs_attachable_root_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_attachable_root_active ON public.recording_studio_recordings USING btree (root_recording_id) WHERE (((recordable_type)::text = 'RecordingStudioAttachable::Attachment'::text) AND (trashed_at IS NULL));


--
-- Name: idx_rs_root_switchable_actor_device_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rs_root_switchable_actor_device_scope ON public.recording_studio_root_switchable_selections USING btree (actor_type, actor_id, device_key, scope_key) WHERE (actor_id IS NOT NULL);


--
-- Name: idx_rs_root_switchable_anonymous_device_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rs_root_switchable_anonymous_device_scope ON public.recording_studio_root_switchable_selections USING btree (device_key, scope_key) WHERE (actor_id IS NULL);


--
-- Name: idx_rs_root_switchable_root_recording; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_root_switchable_root_recording ON public.recording_studio_root_switchable_selections USING btree (root_recording_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_notes_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_search_vector ON public.notes USING gin (search_vector);


--
-- Name: index_notes_on_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_title_trgm ON public.notes USING gin (title public.gin_trgm_ops);


--
-- Name: index_pages_on_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pages_on_body_trgm ON public.pages USING gin (body public.gin_trgm_ops);


--
-- Name: index_pages_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pages_on_search_vector ON public.pages USING gin (search_vector);


--
-- Name: index_pages_on_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pages_on_title_trgm ON public.pages USING gin (title public.gin_trgm_ops);


--
-- Name: index_recording_studio_access_constraints_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_access_constraints_on_action ON public.recording_studio_access_constraints USING btree (action);


--
-- Name: index_recording_studio_access_invitations_on_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_access_invitations_on_recording_id ON public.recording_studio_access_invitations USING btree (recording_id);


--
-- Name: index_recording_studio_access_rules_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_access_rules_on_action ON public.recording_studio_access_rules USING btree (action);


--
-- Name: index_recording_studio_accesses_on_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_accesses_on_actor ON public.recording_studio_accesses USING btree (actor_type, actor_id);


--
-- Name: index_recording_studio_accesses_on_actor_and_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_accesses_on_actor_and_role ON public.recording_studio_accesses USING btree (actor_type, actor_id, role);


--
-- Name: index_recording_studio_accesses_on_depends_on_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_accesses_on_depends_on_recording_id ON public.recording_studio_accesses USING btree (depends_on_recording_id);


--
-- Name: index_recording_studio_attachable_libraries_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_attachable_libraries_on_key ON public.recording_studio_attachable_libraries USING btree (key);


--
-- Name: index_recording_studio_events_on_recording_and_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recording_studio_events_on_recording_and_idempotency_key ON public.recording_studio_events USING btree (recording_id, idempotency_key) WHERE (idempotency_key IS NOT NULL);


--
-- Name: index_recording_studio_events_on_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_events_on_recording_id ON public.recording_studio_events USING btree (recording_id);


--
-- Name: index_recording_studio_recordings_on_parent_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_recordings_on_parent_recording_id ON public.recording_studio_recordings USING btree (parent_recording_id);


--
-- Name: index_recording_studio_recordings_on_recordable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_recordings_on_recordable ON public.recording_studio_recordings USING btree (recordable_type, recordable_id);


--
-- Name: index_recording_studio_recordings_on_recordable_parent_trashed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_recordings_on_recordable_parent_trashed ON public.recording_studio_recordings USING btree (recordable_type, recordable_id, parent_recording_id, trashed_at);


--
-- Name: index_recording_studio_user_identities_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recording_studio_user_identities_on_provider_and_uid ON public.recording_studio_user_identities USING btree (provider, uid);


--
-- Name: index_recording_studio_user_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_user_identities_on_user_id ON public.recording_studio_user_identities USING btree (user_id);


--
-- Name: index_recording_studio_user_identities_on_user_id_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recording_studio_user_identities_on_user_id_and_provider ON public.recording_studio_user_identities USING btree (user_id, provider);


--
-- Name: index_recording_studio_user_otp_challenges_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_user_otp_challenges_on_expires_at ON public.recording_studio_user_otp_challenges USING btree (expires_at);


--
-- Name: index_recording_studio_user_otp_challenges_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_user_otp_challenges_on_user_id ON public.recording_studio_user_otp_challenges USING btree (user_id);


--
-- Name: index_recording_studio_user_profiles_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recording_studio_user_profiles_on_user_id ON public.recording_studio_user_profiles USING btree (user_id);


--
-- Name: index_rs_attachable_attachments_on_root_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_attachable_attachments_on_root_recording_id ON public.recording_studio_attachable_attachments USING btree (root_recording_id);


--
-- Name: index_rs_events_on_action_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_events_on_action_and_occurred_at ON public.recording_studio_events USING btree (action, occurred_at);


--
-- Name: index_rs_events_on_actor_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_events_on_actor_and_occurred_at ON public.recording_studio_events USING btree (actor_type, actor_id, occurred_at);


--
-- Name: index_rs_events_on_recording_and_timeline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_events_on_recording_and_timeline ON public.recording_studio_events USING btree (recording_id, occurred_at DESC, created_at DESC);


--
-- Name: index_rs_recordings_on_root_and_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_recordings_on_root_and_parent ON public.recording_studio_recordings USING btree (root_recording_id, parent_recording_id);


--
-- Name: index_rs_recordings_on_root_and_recordable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_recordings_on_root_and_recordable ON public.recording_studio_recordings USING btree (root_recording_id, recordable_type, recordable_id);


--
-- Name: index_rs_recordings_on_root_recording; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rs_recordings_on_root_recording ON public.recording_studio_recordings USING btree (root_recording_id);


--
-- Name: index_rs_unique_root_recording_per_recordable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rs_unique_root_recording_per_recordable ON public.recording_studio_recordings USING btree (recordable_type, recordable_id) WHERE (parent_recording_id IS NULL);


--
-- Name: index_rss_documents_on_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rss_documents_on_embedding ON public.recording_studio_search_documents USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: index_rss_documents_on_recording_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rss_documents_on_recording_id ON public.recording_studio_search_documents USING btree (recording_id);


--
-- Name: index_rss_documents_on_recording_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rss_documents_on_recording_id_unique ON public.recording_studio_search_documents USING btree (recording_id) WHERE (recording_id IS NOT NULL);


--
-- Name: index_rss_documents_on_searchable; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rss_documents_on_searchable ON public.recording_studio_search_documents USING btree (searchable_type, searchable_id);


--
-- Name: index_rss_documents_on_type_and_recording; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rss_documents_on_type_and_recording ON public.recording_studio_search_documents USING btree (searchable_type, recording_id);


--
-- Name: index_rss_queries_on_keyword_and_model; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rss_queries_on_keyword_and_model ON public.recording_studio_search_queries USING btree (keyword, embedding_model);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_email_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email_trgm ON public.users USING gin (email public.gin_trgm_ops);


--
-- Name: index_users_on_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_name_trgm ON public.users USING gin (name public.gin_trgm_ops);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_search_vector ON public.users USING gin (search_vector);


--
-- Name: recording_studio_user_profiles fk_rails_19efa4e96e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_profiles
    ADD CONSTRAINT fk_rails_19efa4e96e FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: recording_studio_user_identities fk_rails_24997f0186; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_identities
    ADD CONSTRAINT fk_rails_24997f0186 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: recording_studio_recordings fk_rails_26012d5ca3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_recordings
    ADD CONSTRAINT fk_rails_26012d5ca3 FOREIGN KEY (parent_recording_id) REFERENCES public.recording_studio_recordings(id);


--
-- Name: recording_studio_access_invitations fk_rails_414646b380; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_access_invitations
    ADD CONSTRAINT fk_rails_414646b380 FOREIGN KEY (recording_id) REFERENCES public.recording_studio_recordings(id);


--
-- Name: recording_studio_user_otp_challenges fk_rails_5a5625bfeb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_user_otp_challenges
    ADD CONSTRAINT fk_rails_5a5625bfeb FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: recording_studio_events fk_rails_ff21937ccd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_events
    ADD CONSTRAINT fk_rails_ff21937ccd FOREIGN KEY (recording_id) REFERENCES public.recording_studio_recordings(id);


--
-- Name: recording_studio_recordings fk_rails_ffcd14a670; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_studio_recordings
    ADD CONSTRAINT fk_rails_ffcd14a670 FOREIGN KEY (root_recording_id) REFERENCES public.recording_studio_recordings(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261012044049'),
('20261012044048'),
('20261009101701'),
('20261009101700'),
('20261008061231'),
('20261008061230'),
('20261008061229'),
('20261008061228'),
('20261008061227'),
('20260911060100'),
('20260911033546'),
('20260911033524'),
('20260911033523'),
('20260911033522'),
('20260911033521'),
('20260911033520'),
('20260911033519'),
('20260911033518'),
('20260911000000'),
('20260910001005'),
('20260910001004'),
('20260910001003'),
('20260910001002'),
('20260910001001'),
('20260910001000'),
('20260821000000'),
('20260815120000'),
('20260815093000'),
('20260612000000'),
('20260505000001'),
('20260421000000'),
('20260217233016'),
('20260217072940'),
('20260217072923'),
('20260217072826'),
('20260217072825'),
('20260217072824'),
('20260217072823'),
('20260217072822'),
('20260217072821'),
('20260217072820'),
('20260217072819'),
('20260217072818'),
('20260217072817'),
('20260217072816'),
('20260217072815'),
('20250101000000');

