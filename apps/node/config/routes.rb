post '/create', to: 'admin#create'
get '/new', to: 'admin#new'

get '/public', to: 'public#list'

get '/settings', to: 'settings#edit'
get '/admin', to: 'admin#list'
get '/user/:id', to: 'user#show'
get '/:id', to: 'public#show'

# Configure your routes here
# See: http://www.rubydoc.info/gems/lotus-router/#Usage