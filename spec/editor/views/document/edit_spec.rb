require 'spec_helper'
require_relative '../../../../apps/editor/views/document/edit'

describe Editor::Views::Document::Edit do
  let(:exposures) { Hash[foo: 'bar'] }
  let(:template)  { Lotus::View::Template.new('apps/editor/templates/document/edit.html.erb') }
  let(:view)      { Editor::Views::Document::Edit.new(template, exposures) }
  let(:rendered)  { view.render }

  it "exposes #foo" do
    view.foo.must_equal exposures.fetch(:foo)
  end
end
