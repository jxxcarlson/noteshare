class Publications
  include Lotus::Entity
  attributes :id, :node_id, :document_id

  def self.add_documents_for_node(node)
    node.documents_as_hash.each do |title, doc_id|
      publication = Publications.new(node_id: node.id, document_id: doc_id)
      puts "#{title} => #{node.name}".red
      PublicationsRepository.create publication
    end
  end

  def self.for_node(node)
    PubicationsRepository.documents_for_node(node)
  end

  def self.for_document(document)
    PubicationsRepository.nodes_for_document(document)
  end


end