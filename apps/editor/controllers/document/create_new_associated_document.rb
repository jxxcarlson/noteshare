require_relative '../../../../lib/noteshare/interactors/create_associated_document'

module Editor::Controllers::Document
  class CreateNewAssociatedDocument
    include Editor::Action

    expose :active_item

    def call(params)
      @active_item = 'editor'
      result = CreateAssociatedDocument.new(params).call
      if result.error
        redirect_to "/error/0?#{result.error}"
      else
        redirect_to "/editor/document/#{result.current_document.root_document.id}"
      end
    end

  end
end
