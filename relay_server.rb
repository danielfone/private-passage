require 'faye/websocket'

#
# Rack middleware that handles WebSocket connections for a relay server.
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

  def initialize(app)
    @app = app
    # Map of channels, keyed by channel ID
    @channels = {}
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      initialize_connection(env)
    else
      @app.call(env)
    end
  end

private

  def initialize_connection(env)
    ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })
    client_id = ws.object_id

    # Log the origin of the connection
    log "New connection", origin: ws.env['HTTP_ORIGIN'], client_id:

    # Parse the client ID from the query string
    query = Rack::Utils.parse_query(env['QUERY_STRING'])
    # Channel ID
    channel_id = query['channel_id']
    # Whether the client is opening the channel
    existing = query['existing'] == 'true'

    # Close the connection if the channel ID is missing
    if channel_id.nil? || channel_id.empty?
      ws.close(4000, 'Channel ID is required')
      log "Invalid connection, missing channel_id", client_id: client_id
      return ws.rack_response
    end

    ws.on :open do |event|
      if existing
        add_client(channel_id, ws)
      else
        create_channel(channel_id, ws)
      end
    end

    ws.on :message do |event|
      relay_message(channel_id, ws, event.data)
    end

    ws.on :close do |event|
      remove_client(channel_id, ws)
      ws = nil # Allow ws to be garbage collected
    end

    # Return async Rack response
    ws.rack_response
  end

  # Create a new channel if it doesn't exist adn add the client to it
  def create_channel(channel_id, ws)
    if @channels.key?(channel_id)
      ws.close(4000, 'Channel already open')
      log "Channel already open", channel_id:, client_id: ws.object_id
      return
    end

    @channels[channel_id] = Set.new
    @channels[channel_id] << ws
    log "Opened channel", channel_id:, client_id: ws.object_id
  end

  # Add a client to an existing channel
  def add_client(channel_id, ws)
    if !@channels.key?(channel_id)
      ws.close(4000, 'Channel not found')
      log "Channel not found", channel_id:, client_id: ws.object_id
      return
    end

    @channels[channel_id] << ws
    log "Connected to channel", channel_id:, client_id: ws.object_id
  end

  # Relay a message to all clients in a channel except the sender
  def relay_message(channel_id, ws, message)
    @channels[channel_id].each do |peer|
      next if peer == ws
      peer.send(message)
    end
  end

  # Remove a client from a channel and close the channel if it's empty
  def remove_client(channel_id, ws)
    channel = @channels[channel_id]
    return unless channel

    channel.delete(ws)
    log "Closed connection", channel_id:, client_id: ws.object_id

    if channel.empty?
      @channels.delete(channel_id)
      log "Closed channel", channel_id:
    end
  end

  # Log a message with key/value attributes
  def log(message, attrs = {})
    attr_list = attrs.map { |k, v| "#{k}=#{v}" }.join(' ')
    puts "#{message} #{attr_list}"
  end

end
