require 'faye/websocket'

#
# Rack app that handles WebSocket connections for a relay server.
#
# The relay server is responsible for relaying messages between clients
# connected to the same channel. Since the channel is managed in memory, it is
# not possible to have more than one relay server running at the same time. To
# scale the app, you would need to use a shared database to store the channels.
#
# The server expects the following query parameters:
# - channel_id: The ID of the channel to connect to
# - existing: Whether the client is opening an existing channel
#
class RelayServer
  KEEPALIVE_TIME = 15 # in seconds

  def initialize
    # Map of channels, keyed by channel ID
    @channels = {}
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      initialize_connection(env)
    else
      # Bad request
      [400, {}, ["Not a WebSocket request"]]
    end
  end

private

  def initialize_connection(env)
    websocket = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })
    client_id = websocket.object_id

    # Log the origin of the connection
    log("New connection", origin: websocket.env['HTTP_ORIGIN'], client_id:)

    # Parse the client ID from the query string
    query = Rack::Utils.parse_query(env['QUERY_STRING'])
    # Channel ID
    channel_id = query['channel_id']
    # Whether the client is opening the channel
    existing = query['existing'] == 'true'

    # Close the connection if the channel ID is missing
    if channel_id.nil? || channel_id.empty?
      websocket.close(4000, 'Channel ID is required')
      log("Invalid connection, missing channel_id", client_id: client_id)
      return websocket.rack_response
    end

    websocket.on :open do
      if existing
        add_client(channel_id, websocket)
      else
        create_channel(channel_id, websocket)
      end
    end

    websocket.on :message do |event|
      relay_message(channel_id, websocket, event.data)
    end

    websocket.on :close do
      remove_client(channel_id, websocket)
      websocket = nil # Allow websocket to be garbage collected
    end

    # Return async Rack response
    websocket.rack_response
  end

  # Create a new channel if it doesn't exist adn add the client to it
  def create_channel(channel_id, websocket)
    if @channels.key?(channel_id)
      websocket.close(4000, 'Channel already open')
      log("Channel already open", channel_id:, client_id: websocket.object_id)
      return
    end

    @channels[channel_id] = Set.new
    @channels[channel_id] << websocket
    log("Opened channel", channel_id:, client_id: websocket.object_id)
  end

  # Add a client to an existing channel
  def add_client(channel_id, websocket)
    if !@channels.key?(channel_id)
      websocket.close(4000, 'Channel not found')
      log("Channel not found", channel_id:, client_id: websocket.object_id)
      return
    end

    @channels[channel_id] << websocket
    log("Connected to channel", channel_id:, client_id: websocket.object_id)
  end

  # Relay a message to all clients in a channel except the sender
  def relay_message(channel_id, websocket, message)
    @channels[channel_id].each do |peer|
      next if peer == websocket
      peer.send(message)
    end
  end

  # Remove a client from a channel and close the channel if it's empty
  def remove_client(channel_id, websocket)
    channel = @channels[channel_id]
    return unless channel

    channel.delete(websocket)
    log("Closed connection", channel_id:, client_id: websocket.object_id)

    if channel.empty?
      @channels.delete(channel_id)
      log("Closed channel", channel_id:)
    end
  end

  # Log a message with key/value attributes
  def log(message, attrs = {})
    attr_list = JSON.generate(attrs) if attrs.any?
    puts "#{message} #{attr_list}"
  end

end
