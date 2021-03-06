module Editor::Controllers::Document
  class ManagePublications
    include Editor::Action
    include Noteshare::Core::NSPublication

    def call(params)
      @screen_name = current_user2.screen_name
      record_id = params['id']
      command_string = request.query_string
      NSPublication.execute_command(command_string, record_id)
      redirect_to '/admin/publications'
    end
  end
end
