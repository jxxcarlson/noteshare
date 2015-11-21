require_relative '../../ext/core'
require_relative '../../../lib/noteshare/modules/tools'
require_relative '../modules/toc_item'

# require_relative '../modules/render'


# An instance of the Document class has *content*, a block of text,
# various metadata -- *title*, *author*, *tags* etc. -- and a set
# of links.  First, there is *subdoc_refs*, an array of *id's*
# of Documents.  The idea is that the text of document is composed of
# its content plus the content of it subdocuments. Subdocuments
# can have their own subdocuments, and so on. The *compile* method
# assembles the content of a document, its subdocuments, etc.,
# in the proper order.   Second, there is
# *doc_refs*, which is a hash that could look like this:
#
# { 'previous': 124, 'next': 201, 'comments': 444, 'summary': 555 }
#
# The *previous* and *next* keys are used by an editor for navigation.
# Keys like *comment* and *summary* point to little documents that
# may or may not not be compiled into the main text.  There is
# also a set of special pointers, *parent_id* and *index_in_parent*.
# Suppose that document 123 refers to document 555 via the  element
# of index two in its *subdoc_refs* array, e.g.,
#
#    subdoc_refs = [21, 19, 555, 56]
#
# Then the parent_id of document 555 is 123 and the value of
# index_in_parent is 2.
#
# The subdoc array is populated by the method *insert*.
# To illustrate, suppose we have documents @article,
# @section1, @section2, and @section3.  The succession of
# method calls
#
#    @section1.insert(0, @article)
#    @section2.insert(1, @article)
#    @section2.insert(2, @article)
#
# builds up the subdoc array of @article and manages
# the pointers parent_id, index_in_parent, previous
# and next.
#
#    CONTENTS
#
#       1. REQUIRE, INCLUDE, AND INITIALIZE
#
class NSDocument

  ###################################################
  #
  #     CONTENTS
  #
  #     1. REQUIRE, INCLUDE, AND INITIALIZE
  #     2. MANAGE SUBDOCUMENTS
  #     3. ASSOCIATED DOCUMENTS
  #     4. UPDATE, COMPILE & RENDER
  #     5. TABLE OF CONTENTS
  #
  ###################################################

  require_relative '../modules/ns_document_setup'
  require_relative '../modules/ns_document_presentation'

  include Lotus::Entity
  attributes :id, :author_id, :author, :author_identifier, :author_credentials, :title, :identifier, :tags, :type, :area, :meta,
    :created_at, :modified_at, :content, :rendered_content, :compiled_and_rendered_content, :render_options,
    :parent_ref, :root_ref, :parent_id, :index_in_parent, :root_document_id, :visibility,
    :subdoc_refs,  :doc_refs, :toc, :content_dirty, :compiled_dirty, :toc_dirty


  include NSDocument::Presentation
  include NSDocument::Setup
  include Noteshare::Tools
  include Noteshare


  # When initializing an NSDocument, ensure that certain fields
  # have a standard non-nil value
  # The hash should follow this model
  #
  #  {title: 'Introduction to Chemistry', author_credentials{ id: 0, first_name: 'Linus', last_name: 'Pauling', identifier: 'abcd1234'}}


  def initialize(hash)

    hash.each { |name, value| instance_variable_set("@#{name}", value) }

    @subdoc_refs = [] if @subdoc_refs.nil?
    @toc ||= []
    @doc_refs = {} if @doc_refs.nil?
    @render_options ||= { 'format'=> 'adoc' }
    @root_document_id ||= 0
    @parent_id ||= 0

    # @toc_dirty ||= true

  end

  def display(label, args)

    puts
    puts label.red
    args.each do |field|
      begin
        puts "#{field.to_s}: #{self.send(field)}"
      rescue
        puts "#{field.to_s}: ERROR".red
      end
    end
    puts

  end

  def self.info(id)
    doc = DocumentRepository.find(id)
    doc.display('Document', [:title, :identifier, :author_credentials, :parent_ref, :root_ref, :toc])
  end

  # Return TOC object corresponding to the toc
  # field in the database
  def table_of_contents
    TOC.new(self).table
  end

  # Create a document given a hash.
  # The hash must define both the title and the author credentials,
  # as in the example below;
  #
  #   @author_credentials = { id: 0, first_name: 'Linus', last_name: 'Pauling', identifier: 'abcd1234'}
  #
  #   @article = NSDocument.create(title: 'A. Quantum Mechanics', author_credentials: @author_credentials)
  #
  # The hash may contain any other valid keys.
  #
  # NOTES: a document is recognized as a root document if its root_id
  # is zero.  If a document has no parent, its parent_id is nil
  # All documents begin life as root documents with no parent.
  #
  def self.create(hash)
    doc = NSDocument.new(hash)
    doc.author_credentials = Tools.symbolize_keys(hash[:author_credentials])
    doc.author = doc.author_credentials[:first_name] + ' ' + doc.author_credentials[:last_name]
    doc.identifier = Noteshare::Identifier.new().string
    doc.root_ref = { 'id'=> 0, 'title' => ''}
    DocumentRepository.create doc
  end


  def set_author_by_id(author_id)
    root_document
  end

  def set_author_credentials(credentials)
    self.author_credentials = JSON.generate(credentials)
  end

  def get_author_credentials
    puts "#{self.author_credentials.to_s}.magenta"
    JSON.parse(self.author_credentials)
  end

  def set_identifier
    self.identifier = Noteshare::Identifier.new().string
  end

  def set_identifier!
    set_identifier
    DocumentRepository.update self
    self.identifier
  end

  def set_author_identifier
    author_obj = UserRepository.find self.author_id
    if author_obj
      self.author_identifier = author_obj.identifier
    end
  end

  def set_author_identifier!
    set_author_identifier
    DocumentRepository.update self
    self.author_identifier
  end

  ###################################################
  #
  #     2. MANAGE SUBDOCUMENTS
  #
  ###################################################

  # @section(k, @article) makes @section the k-th subdocument
  # of @article.  The subdocuments that were in position
  # k and above are shifted to the right.  This method
  # updates all links: parent, index_in_parent,
  # amd the relevant next and previous links                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
  def insert(k, parent_document)

    # puts "Insert #{self.id} (#{self.title}) at k = #{k}"

    # Insert the TOCItem of the current document (receiver)
    # in the toc array of the parent document.
    # Note the index of the TOCItem and copy that index
    # into self.index_in_parent.  Thus, at the
    # the end of these operations, the parent
    # references the child (the subdocument),
    # and vice versa.
    parent_toc = TOC.new(parent_document)
    new_toc_item = TOCItem.new(self.id, self.title, self.identifier, false)
    parent_toc.insert(k, new_toc_item)
    parent_toc.save!
    self.index_in_parent =  k
    self.parent_ref = {id: parent_document.id, title: parent_document.title, identifier: parent_document.identifier, has_subdocs:true }
    self.parent_id = parent_document.id
    puts "IN INSERT: parent_document.id = #{parent_document.id}".magenta
    puts "IN INSERT: self.parent_id = #{self.parent_id}".red

    root_doc = find_root_document
    if root_doc
      self.root_document_id = root_doc.id
      self.root_ref = {id: root_doc.id, title: root_doc.title, identifier: root_doc.identifier, has_subdocs:true }
    else
      self.root_ref = {id: 0, title: '', identifier: '', has_subdocs:false }
    end

      # Inherit the render_option from the root document
    if root_doc and root_doc != self
      self.render_options = root_doc.render_options
    end

    # update index_in_parent for subdocuments
    # that were shifted to the right
    # puts "Shifting ..."
    # puts "parent_document.subdoc_refs.tail(k+1): #{parent_document.subdoc_refs.tail(k)}"
    TOC.new(parent_document).table.tail(k).each do |item|
      doc = DocumentRepository.find item.id
      doc.index_in_parent = doc.index_in_parent + 1
      DocumentRepository.update(doc )
    end

    DocumentRepository.update(self)
    DocumentRepository.update(parent_document)

    # update_neighbors

  end

  # Used by #insert to preserve the
  # validity of the previous and next
  # links of subdocuments.
  def update_neighbors
    self.set_previous_doc
    self.set_next_doc

    if previous_document
      previous_document.set_next_doc
    end

    if next_document
      next_document.set_previous_doc
    end
  end


  # @section.add_to(@article) makes @section
  # the last subdocument of @article
  def add_to(parent_document)
    puts "ADD: #{self.title} TO: #{parent_document.title}".green
    new_index = parent_document.toc.length
    insert(new_index, parent_document)
  end



  # @foo.remove_from_parent removes
  # @foo as a subdocument of its parent.
  # It oes not delete @foo.
  # Fixme: it is intended tht a document have at most one parent.
  # However, this is not yet enforced.
  def remove_from_parent
    k = index_in_parent
    p = parent_document
    pd = previous_document
    nd_id = next_document.id
    p.subdoc_refs.delete_at(k)
    DocumentRepository.persist(p)

    # update index_in_parent for subdocuments
    # that were shifted to the left
    # puts "Shifting ..."
    # puts "parent_document.subdoc_refs.tail(k+1): #{parent_document.subdoc_refs.tail(k)}"
    p.subdoc_refs.tail(k-1).each do |id|
      doc = DocumentRepository.find id
      doc.index_in_parent = doc.index_in_parent - 1
      DocumentRepository.persist(doc )
    end

    if pd
      pd.set_next_doc
    end

    nd =  DocumentRepository.find nd_id
    if nd
      nd.set_previous_doc
    end
  end

  # @foo.move_to(7) moves @foo in its
  # parent document to position 7.
  # Subdocuments that were in position 7 and up
  # are moved up.
  def move_to(new_position)
    remove_from_parent
    insert(new_position, parent)
  end



  # Return title and id of NSDocument
  def info
    "#{self.title}:: id: #{self.id}"
  end

  # Return title, id, an ids of previous and next documents
  def status
    "#{self.title}:: id: #{self.id}, parent_document: #{self.parent.id }, back: #{self.doc_refs['previous']}, next: #{@self.doc_refs['next']}"
  end



  #########################################
  #
  #     SECTION??
  #
  #########################################N

  def parent_item
    return if parent_ref == nil
    # TOCItem.new( parent_ref['id'], parent_ref['title'], parent_ref['identifier'], parent_ref['has_subdocs'] )
    # TOCItem.new( parent_ref[:id], parent_ref[:title], parent_ref[:identifier], parent_ref[:has_subdocs] )
    TOCItem.from_hash(parent_ref)
  end

  def root_item
    return if root_ref == nil
    # TOCItem.new( root_ref['id'], root_ref['title'], root_ref['identifier'], root_ref['has_subdocs'] )
    #TOCItem.new( root_ref[:id], root_ref[:title], root_ref[:identifier], root_ref[:has_subdocs] )
    TOCItem.from_hash(root_ref)
  end

  def previous_toc_item
    table = TOC.new(parent_document).table
    index_of_previous_toc_item = index_in_parent - 1
    return table[index_of_previous_toc_item] if index_of_previous_toc_item > -1
  end

  def next_toc_item
    return if parent_document == nil
    table = TOC.new(parent_document).table
    index_of_next_toc_item = index_in_parent + 1
    return table[index_of_next_toc_item] if index_of_next_toc_item < table.count
  end


  # Return next NSDocument.  That is, if @foo, @bar, and @baz
  # are subcocuments in order of @article, then @bar.next_document = @baz
  def previous_document
    return if parent_document == nil
    table = TOC.new(parent_document).table
    index_in_parent ?  _id = table[index_in_parent-1].id : return
    DocumentRepository.find(_id) if _id
  end


  # Return previous NSDocument.  That is, if @foo, @bar, and @baz
  # are subcocuments in order of @article, then @bar.previous_document = @foo
  def next_document
    return if parent_document == nil
    table = TOC.new(parent_document).table
    index_in_parent && index_in_parent + 1 < table.count ?  _id = table[index_in_parent+1].id : return
    DocumentRepository.find(_id) if _id
  end

  # Use the information in self.parent.subdoc_refs
  # to set the previous document link.  Thus,
  # if @foo and @bar are subdocuments in order
  # of @article, then after the call @bar.set_previous_doc,
  # @bar.previous_doc == @foo.
  def set_previous_doc
    self.doc_refs['previous'] = previous_id
    DocumentRepository.persist(self)
  end

  # Use the information in self.parent.subdoc_refs
  # to set the previous document link.  Thus,
  # if @foo and @bar are subdocuments in order
  # of @article, then after the call @foo.set_next_doc,
  # @foo.next_doc == @bar.
  def set_next_doc
    self.doc_refs['next'] = next_id
    DocumentRepository.persist(self)
  end

  # *doc.parent* returns nil or the parent object
  def parent_document
    pi =  parent_item
    return if pi == nil
    pi_id = pi.id
    return if pi_id == nil
    DocumentRepository.find(pi_id)
  end


  def parent_title
    if parent_document
      parent_document.title
    else
      ''
    end
  end


  def ancestor_ids
    cursor = self
    list = []
    while cursor.parent_document != nil
      list << cursor.parent_document.id
      cursor = cursor.parent_document
    end
    list
  end

  def next_oldest_ancestor
    noa = self
    return self if noa == root_document
    while noa.parent_document != root_document
      noa = noa.parent_document
    end
    noa
  end


  # *doc.subdocment(k)* returns the k-th
  # subdocument of *doc*
  def subdocument(k)
    _id = table_of_contents[k].id
    if _id
      DocumentRepository.find(_id)
    end
  end

  # The root_document is what you get by
  # following parent_document links to their
  # source. If the root_document_id is zero,
  # then the document is a root document.
  # Otherwise, the root_document_id is the
  # id of the root_documment.
  def root_document
    ri =  root_item
    return self if ri == nil # i.e, if it is a root document
    ri_id = ri.id
    return if ri_id == nil
    DocumentRepository.find(ri_id)
  end


  # Find the root document by finding
  # the parent of the parent of ...
  def find_root_document
    cursor = self
    while cursor.parent_document
      cursor = cursor.parent_document
    end
    cursor
  end

  def ref
    TOCItem.new( self.id, self.title, self.identifier )
  end

  def set_root_document
    rd = find_root_document
    # Need the follwing for DocumentRepository.root_documents
    # Fixme: index root_document_id
    rd.root_document_id = 0
    self.root_document_id = rd.id
    self.root_ref = { id: rd.id, title: rd.title, identifier: rd.identifier}
  end

  def set_root_document!
    set_root_document
    DocumentRepository.update self
  end

  def is_root_document?
    self == find_root_document
  end

  # The level is the length of path from the root
  # to the give node (self)
  def level
    length = 0
    cursor = self
    while cursor.parent_document
      length += 1
      cursor = cursor.parent_document
    end
    length
  end


  ###################################################
  #
  #      3. ASSOCIATED DOCUMENTS
  #
  ###################################################

  # @foo.associate_to(@bar, 'summary',)
  # associates @foo to @bar as a 'summary'.
  # It can be retrieved as @foo.associated_document('summary')
  def associate_to(doc, type)
    doc.doc_refs[type] = self.id
    self.parent_id = doc.id
    self.root_document_id = doc.id
    DocumentRepository.update(doc)
  end

  # @foo.associatd_document('summary')
  # retrieve the document associated to
  # @foo which is of type 'summary'
  def associated_document(type)
    DocumentRepository.find(self.doc_refs[type])
  end

  ###################################################
  #
  #      4. UPDATE CONTENT, COMPILE & RENDER
  #
  ###################################################

  # If input is nil, render the content
  # and save it in rendered_content.  Otherwise,
  # Replace #content by str, render it
  # and save itl. .
  def update_content(input=nil)

    render_by_identity = dict_lookup('render') == 'identity'
    if render_by_identity
      rendered_content =  content
    end

    dirty = self.content_dirty
    dirty = true if dirty.nil?

    if dirty == true
      puts "update_content (dirty), id = #{self.id}, title = #{self.title}".magenta
      if input == nil
        str = self.content || ''
      else
        str = input
        self.content = str
      end
      renderer = Render.new(texmacros + str)
      self.rendered_content = renderer.convert
      self.content_dirty = false
      DocumentRepository.update self
    else
      puts "update_content (clean), id = #{self.id}, title = #{self.title}".blue
    end

  end

  def texmacros
    rd = root_document || self
    if rd and rd.doc_refs['texmacros']
      macro_text = rd.associated_document('texmacros').content
      macro_text = macro_text.gsub(/^=*= .*$/,'')
      macro_text = "\n\n[env.texmacro]\n--\n#{macro_text}\n--\n\n"
      puts macro_text.magenta
      macro_text
    else
      puts 'NO MACROS'.magenta
      ''
    end
  end

  # *doc.compile* concatenates the contents
  # of *doc* with the compiled text of
  # each section of *doc*.  The sections
  # array is determined by #part, which is
  # a persistent array of integers which
  # represent the id's of the sections of
  # *doc*.
  def compile_aux
    table = table_of_contents
    if table == []
      return content
    else
      text = content + "\n\n" || ''
      table.each do |item|
        section = DocumentRepository.find(item.id)
        text  << section.compile_aux << "\n\n"
      end
      return text
    end
  end

  def compile
    texmacros + compile_aux
  end


  def render_lazily
    if content_dirty
      render
    end
  end


  # NSDocument#render is the sole connection between class NSDocument and
  # module Render.  It updates self.rendered_content by applying
  # Asciidoctor.convert to self.content with the provided options.
  def render

    format = @render_options['format']

    case format
      when 'adoc'
        render_option = {}
      when 'adoc-latex'
        render_option = {backend: 'html5'}
      else
        render_option = {}
    end

    renderer = Render.new(self.compile, render_option )
    self.rendered_content = renderer.convert
    self.content_dirty = false
    DocumentRepository.update(self)

  end


  def compile_with_render_lazily(option={})
    if compiled_dirty
      compile_with_render(option)
    end
  end


  def get_render_option
    format = self.render_options['format']

    case format
      when 'adoc'
        render_option = {}
      when 'adoc-latex'
        render_option = {backend: 'html5'}
      else
        render_option = {}
    end

  end

  # Compile the receiver, render it, and store the
  # rendered text in self.compiled_and_rendered_content
  def compile_with_render(option={})

    renderer = Render.new(self.compile, get_render_option )
    self.compiled_and_rendered_content = renderer.convert
    self.compiled_dirty = false
    DocumentRepository.update(self)

  end

  def export
    header = '= ' << title << "\n"
    header << author << "\n"
    header << ":numbered:" << "\n"
    header << ":toc2:" << "\n\n\n"

    renderer = Render.new(header + texmacros + self.compile, get_render_option )
    renderer.rewrite_urls
    file_name = self.title.normalize
    path = "outgoing/#{file_name}.adoc"
    IO.write(path, renderer.source)
    export_html(get_render_option)

  end

  def export_html(format)

    file_name = self.title.normalize
    path = "outgoing/#{file_name}.adoc"
    format = self.render_options['format']

    case format
      when 'adoc'
        cmd = "asciidoctor #{path}"
      when 'adoc-latex'
        cmd = "asciidoctor-latex -b html #{path}"
      else
        cmd =  "asciidoctor #{path}"
    end

    system cmd

  end


  #########################################################
  #
  #  TABLE OF CONTENTS
  #
  #########################################################


  def set_toc_dirty
    self.toc_dirty = true
    self.root_document.toc_dirty = true
  end

  def set_toc_clean
    self.toc_dirty = false
    self.root_document.toc_dirty = false
  end

  def toc_is_dirty
    self.root_document.toc_dirty
  end



  # A table of contents is an array of hashes,
  # where the key-value pairs are like
  #
  #    hash['id'] = 23
  #    hash['title'] = 'Long Journey'
  #    hash['subdocs'] = true
  #
  # The metnod  #update_table_of_contents
  # creates this structure from scratch, then stores
  # it as jsonb in the toc field of the database
  def update_table_of_contents(arg = {force: false})

  end

  def update_toc_at_root
    root_document.update_table_of_contents
  end

  ##################################

  def dict_set(new_dict)
    if meta
      metadata = JSON.parse self.meta
    else
      metadata = {}
    end
    metadata['dict'] = new_dict
    self.meta = JSON.generate metadata
    puts self.class.name.green
    DocumentRepository.update self
    new_dict
  end


  # Example: @foo.dict_update 'children': 5
  def dict_update(entry)
    metadata = JSON.parse self.meta
    dict = metadata['dict'] || { }
    dict[entry.keys[0]] = entry.values[0]
    metadata['dict'] = dict
    self.meta = JSON.generate metadata
    DocumentRepository.update self
    entry
  end

  def dict_lookup(key)
    return nil if meta == nil
    metadata = JSON.parse self.meta
    dict = metadata['dict'] || { }
    dict[key]
  end

  def dict_list
    if meta == nil
      puts 'empty'
      return ''
    end
    metadata = JSON.parse self.meta
    dict = metadata['dict'] || { }
    dict.each do |key, value|
      puts "#{key} => #{value}"
    end
  end

  def dict_delete(key)
    metadata = JSON.parse self.meta
    dict = metadata['dict'] || { }
    dict[key] = nil
    metadata['dict'] = dict
    self.meta = JSON.generate metadata
    DocumentRepository.update self
    key
  end

  def dict_clear
    metadata = JSON.parse self.meta
    metadata['dict'] = {}
    self.meta = JSON.generate metadata
    DocumentRepository.update self
    key
  end

  ##################################

  private
  # Assume that receiver is subdocument k of parent_document.
  # Return the id of subdocument k - 1 or nil
  def previous_id
    p = parent_document
    puts "IN: previous_id, parentof #{self.title} (#{self.id})  = #{parent_title} (#{parent_id})".magenta
    return nil if p == nil
    return nil if index_in_parent == nil
    return nil if index_in_parent-1 < 0
    table = TOC.new(p).table
                                                                         S
    puts "  -- and index_in_parent = #{index_in_parent}".cyan
    puts "  -- toc_item: #{table[index_in_parent]}".red
    puts "  -- previous toc_item: #{table[index_in_parent-1]}".red
    puts "Class: #{table[index_in_parent-1].class.name}"
    return table[index_in_parent-1].id
  end

  # Assume that receiver is subdocument k of parent.
  # Return the id of subdocuemnt k + 1 or nil
  def next_id
    p = parent_document
    puts "IN: next_id, parent = #{parent_document.title} (#{parent_document.id})".magenta
    return nil if p == nil
    return nil if index_in_parent == nil
    return nil if index_in_parent+1 > p.subdoc_refs.length
    table = TOC.new(p).table


    puts "  -- and index_in_parent = #{index_in_parent}".cyan
    puts "  -- toc_item: #{table[index_in_parent]}".red
    puts "  -- next toc_item: #{table[index_in_parent+1]}".red
    puts "Class: #{table[index_in_parent+1].class.name}"
    return toc[index_in_parent+1].id
  end





end
