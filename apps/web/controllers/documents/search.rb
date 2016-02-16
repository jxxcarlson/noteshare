module Web::Controllers::Documents
  class Search
    include Web::Action
'
'
    expose :documents, :nodes
    expose :active_item

    def call(params)
      @active_item = 'reader'
      search_key = params['search']['search']
      cu = current_user(session)
      search_scope = cu.dict2['search_scope'] || 'all'
      search_mode = cu.dict2['search_mode'] || 'document'

      if cu == nil
        puts 'DOING SEARCH FOR ALL'.red
        @documents = DocumentRepository.basic_search(nil, search_key, 'document', 'all').select{ |item| item.acl_get(:world) =~ /r/ }.sort_by { |item| item.title }
      else
        @documents = DocumentRepository.basic_search(cu, search_key, search_mode, search_scope).sort_by { |item| item.title }
      end
      @nodes = NSNodeRepository.search(search_key).sort_by { |item| item.name }
    end

  end
end

# search_local(user, key, limit: 20)