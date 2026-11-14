# frozen_string_literal: true

module RecordingStudioSearch
  # Who a search is for. +unscoped+ skips Accessible. Otherwise +actor+ and
  # +root+ are required and hits stay inside recordings that actor can view.
  Access = Struct.new(:actor, :root, :root_recording_id, :unscoped, keyword_init: true) do
    def unscoped?
      unscoped == true
    end

    def vector_root_id
      return root_recording_id if root_recording_id.present?
      return root.id if root.respond_to?(:id)

      nil
    end
  end
end
