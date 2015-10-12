require 'spec_helper'
require_relative '../../../../apps/web/controllers/documents/index'

describe Web::Controllers::Documents::Index do
  let(:action) { Web::Controllers::Documents::Index.new }
  let(:params) { Hash[] }

  it "is successful" do
    response = action.call(params)
    response[0].must_equal 200
  end
end
