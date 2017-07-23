ActiveRecord::Base.establish_connection(:adapter => "postgresql", :pool => "1", :timeout => "5000", :checkout_timeout => "30", :host => "localhost", :encoding => "unicode", :database => "sso_thread_development", :username => "baldor", :password => "baldor123")


(curl -H "Content-Type: application/json" -X POST -d '{"email":"jignesh@mailinator.com","password":"Password123"}' http://localhost:3000/login)

# LOCAL
for i in {1..10}; do (curl -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d '{"email":"jignesh@mailinator.com","password":"Password123"}' "http://localhost:3000/login" &); done

# Production
for i in {1..10}; do (curl -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d '{"email":"jignesh@mailinator.com","password":"Password123"}' "https://sso-multi-threaded.herokuapp.com/login" &); done


for i in {1..10}; do (curl "http://localhost:3000/thread_safety/simple" &); done



User.transaction do
  user = User.find(9)
  user.lock!
  user.first_name = "Agent1"
  sleep(20)
  user.save!
end

user = User.find(9)
user.update(first_name: "Agent2")

User.transaction do
  user = User.find(9)
  user.lock!
  user.first_name = "Agent2"
  # sleep(10)
  user.save!
end
