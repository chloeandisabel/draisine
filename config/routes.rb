Draisine::Engine.routes.draw do
  post '/sf_soap/delete' => 'draisine/soap#delete'
  post '/sf_soap/*klass' => 'draisine/soap#update'
end
