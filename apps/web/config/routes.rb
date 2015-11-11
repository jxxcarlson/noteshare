
get '/about', to: 'home#about'


get '/', to: 'home#index'

get '/document/:id', to: 'documents#show'
get '/compiled/:id', to: 'documents#show_compiled'

get '/documents', to: 'documents#index'

post '/search', to: 'documents#search'

# Configure your routes here
# See: http://www.rubydoc.info/gems/lotus-router/#Usage

