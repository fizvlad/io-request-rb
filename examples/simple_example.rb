require "io_request"

r1, w1 = IO.pipe
r2, w2 = IO.pipe

client_1 = IORequest::Client.new read: r1, write: w2
client_2 = IORequest::Client.new read: r2, write: w1

# Use
# Set up responders
# Authorization
client_2.respond type: "auth" do |request|
  puts "Client 2: Authorization attempt as #{request.data[:username].inspect}"
  sleep 2 # Some processing
  { type: "auth_success" }
end

# Default
client_2.respond do |request|
  puts "Client 2: #{request.data.inspect}"
  { type: "success" }
end

# Send requests
auth = false
auth_request = client_1.request(
  data: { type: "auth", username: "mymail@example.com", password: "let's pretend password hash is here" },
  sync: true
) do |response|
  unless response.data[:type] == "auth_success"
    puts "Client 1: Authorization failed. Response: #{response.data.inspect}"
    next
  end

  auth = true
  # Do something
end
exit unless auth
puts "Client 1: Authorized!"

message = client_1.request(
  data: { type: "message", message: "Hello!" },
  sync: true
) do |response|
  puts "Client 1: Message responded"
end

# Close
r1.close
w1.close
r2.close
w2.close
