=begin
require 'features_helper'

describe 'Show document' do
  before do
    DocumentRepository.clear
    DocumentRepository.create(Document.new(title: 'Laridimian Poetry', author: 'Luumus Dorr'))
  end

  visit '/document'
  assert page.has_css?('.document', count: 1), "Expected to find 1 document"

end
=end