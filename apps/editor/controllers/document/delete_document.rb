  module Editor::Controllers::Document
  class DeleteDocument
    include Editor::Action

    expose :active_item

    def call(params)
      redirect_if_not_signed_in('editor, document, DeleteDocument')
      puts "controler DeleteDocument".red

      @active_item = 'editor'
      user = current_user(session)
      control =  params['document']['destroy']
      doc_id =  params[:id]
      @delete_mode = params['document']['delete_mode']
      puts "DELETE MODE #{@delete_mode}".red
      @document = DocumentRepository.find doc_id

      parent_id = @document.parent_document.id if @document.parent_document
      document_id = @document.id


      redirect_to '/error/666' if Permission.new(user, :delete,  @document).grant == false
      message = ''

      if control != 'destroy'
        message << "You did not say 'destroy'"
        redirect_to "/editor/document/#{doc_id}"
      end


      if @delete_mode == 'section'
        puts "HERE (5a)".red
        @document.delete
        node = user.node
        node.update_docs_for_owner
        message << "#{@document.title} has been deleted."
        if parent_id != document_id
          redirect_to "/editor/document/#{parent_id}"
        else
          redirect_to "/node/user/#{current_user(session).id}"
        end
      end

      if @delete_mode == 'tree'
        puts "HERE (5b)"
        DocumentRepository.destroy_tree @document.id, [:verbose, :kill]
        message << "#{@document.title} and it entrie document tree has been deleted."
        redirect_to "/node/user/#{current_user(session).id}"
      end

    end
  end
end
