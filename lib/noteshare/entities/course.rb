require_relative '../../../lib/noteshare/modules/text_parse'

class Course
  include Lotus::Entity
  attributes :id, :title, :author, :author_id, :tags, :area, :created_at, :modified_at, :content, :course_attributes

  include TextParse

  # Create an NSDcoument from a Noteshare document
  def to_document(screen_name)
    user = UserRepository.find_one_by_screen_name(screen_name)
    return if user == nil

    doc = NSDocument.create(title: self.title, author_credentials: user.credentials)
    doc.author_id = self.author_id
    doc.tags = self.tags
    doc.area = self.area
    doc.created_at = self.created_at
    doc.modified_at =  self.modified_at
    doc.content = self.content
    DocumentRepository.update(doc)

    return doc
  end

  def tex_macros
    grab text: course_attributes, ad_prefix: 'doc', ad_suffix: 'texmacros'
  end

  def associated_lessons
    LessonRepository.select_for_course(self.id)
  end

  # Add all of the lessons associated to a given course
  def create_master_document(screen_name)

    # Setup
    master = self.to_document(screen_name)
    master.content ||= ''
    lessons = self.associated_lessons
    lesson_count = lessons.count
    puts "Lessons to import: #{lesson_count}".red

    # Process tex macros if present
    _tex_macros = tex_macros
    if _tex_macros
      tex_macro_document =  NSDocument.create(title: 'Tex Macros', author_credentials: JSON.parse(master.author_credentials))
      tex_macro_document.content = "\\(" + _tex_macros + "\\)"
      DocumentRepository.update tex_macro_document
      tex_macro_document.associate_to(master, 'texmacros')
    end

    # stack of documents will manage the recursive block structure
    # of the master document.
    stack = []
    last_node = master
    count = 0
    lessons.all.each do |lesson|

      count = count + 1
      puts "\n\n#{count}: #{lesson.id}, #{lesson.title}".cyan

      begin

        section = lesson.to_document(screen_name)
        puts "1. section.asciidoc_level: #{section.asciidoc_level}".red
        stack == [] ?  delta = 2 : delta =  section.asciidoc_level - stack.last.asciidoc_level
        puts "2, delta = #{delta}.magenta"

        if delta >= 2
          stack.push(last_node)
        elsif delta <= 0
          stack.pop
        end
        puts "2.8. stack size = #{stack.count}".magenta
        puts "3. stack updated, will add doc to #{stack.last.title}".red



        section.add_to(stack.last)
        puts "4. document added to #{stack.last.title}".red
        last_node = section

        puts "  -- ok".blue

      rescue

        puts "Error in importing #{lesson.title} (#{lesson.id})".red

      end

    end
    return master
  end

  def create_master_document1(screen_name)

    master = self.to_document(screen_name)

    master.content ||= ''
    lessons = self.associated_lessons
    lesson_count = lessons.count

    _tex_macros = tex_macros
    if _tex_macros
      tex_macro_document =  NSDocument.create(title: 'Tex Macros', author_credentials: master.author_credentials)
      tex_macro_document.content = "\\(" + _tex_macros + "\\)"
      DocumentRepository.update tex_macro_document
      tex_macro_document.associate_to(master, 'texmacros')
    end

    stack = []
    last_node = master

    lessons.all.each do |lesson|
      section = lesson.to_document(screen_name)
      stack == [] ?  delta = 2 : delta =  section.asciidoc_level - stack.last.asciidoc_level
      if delta >= 2
        stack.push(last_node)
      elsif delta <= 0
        x = stack.pop
      end
      section.add_to(stack.last)
      last_node = section
    end
    return master
  end


end
