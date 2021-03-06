require 'tilt/erb'

require 'rubygems'
require 'bundler/setup'
require 'lotus/setup'
require_relative '../lib/noteshare'
require_relative '../apps/processor/application'
require_relative '../apps/viewer/application'
require_relative '../apps/uploader/application'
require_relative '../apps/image_manager/application'
require_relative '../apps/session_manager/application'
require_relative '../apps/admin/application'
require_relative '../apps/editor/application'
require_relative '../apps/web/application'
require_relative '../apps/node/application'



Lotus::Container.configure do
  mount Processor::Application, at: '/processor'
  mount Viewer::Application, at: '/viewer'
  mount Uploader::Application, at: '/uploader'
  mount ImageManager::Application, at: '/image_manager'
  mount SessionManager::Application, at: '/session_manager'
  mount Node::Application, at: '/node'
  mount Admin::Application, at: '/admin'
  mount Editor::Application, at: '/editor'
  mount Web::Application, at: '/'
end
