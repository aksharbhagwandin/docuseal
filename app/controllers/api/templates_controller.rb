# frozen_string_literal: true

module Api
  class TemplatesController < ApiBaseController
    load_and_authorize_resource :template

    def index
      templates = filter_templates(@templates, params)

      templates = paginate(templates.preload(:author, documents_attachments: :blob))

      render json: {
        data: templates.as_json(serialize_params),
        pagination: {
          count: templates.size,
          next: templates.last&.id,
          prev: templates.first&.id
        }
      }
    end

    def show
      render json: @template.as_json(serialize_params)
    end

    def update
      if (folder_name = params[:folder_name] || params.dig(:template, :folder_name))
        @template.folder = TemplateFolders.find_or_create_by_name(current_user, folder_name)
      end

      archived = params.key?(:archived) ? params[:archived] : params.dig(:template, :archived)

      if archived.in?([true, false])
        @template.archived_at = archived == true ? Time.current : nil
      end

      @template.update!(template_params)

      render json: @template.as_json(only: %i[id updated_at])
    end

    def destroy
      if params[:permanently] == 'true' && !Docuseal.multitenant?
        @template.destroy!
      else
        @template.update!(archived_at: Time.current)
      end

      render json: @template.as_json(only: %i[id archived_at])
    end

    private

    def filter_templates(templates, params)
      templates = Templates.search(templates, params[:q])
      templates = params[:archived] ? templates.archived : templates.active
      templates = templates.where(external_id: params[:application_key]) if params[:application_key].present?
      templates = templates.where(external_id: params[:external_id]) if params[:external_id].present?
      templates = templates.joins(:folder).where(folder: { name: params[:folder] }) if params[:folder].present?

      templates
    end

    def serialize_params
      {
        methods: %i[application_key],
        include: { author: { only: %i[id email first_name last_name] },
                   documents: { only: %i[id uuid], methods: %i[url preview_image_url filename] } }
      }
    end

    def template_params
      permit_params = [
        :name,
        { schema: [%i[attachment_uuid name]],
          submitters: [%i[name uuid]],
          fields: [[:uuid, :submitter_uuid, :name, :type, :required, :readonly, :default_value,
                    { preferences: {},
                      options: [%i[value uuid]],
                      areas: [%i[x y w h cell_w attachment_uuid option_uuid page]] }]] }
      ]

      if params.key?(:template)
        params.require(:template).permit(*permit_params)
      else
        params.permit(*permit_params)
      end
    end
  end
end
