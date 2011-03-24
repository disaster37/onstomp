# -*- encoding: utf-8 -*-

# This class encapsulates a client connection to a message broker through the
# Stomp protocol.
class OnStomp::Client
  include OnStomp::Interfaces::ClientConfigurable
  include OnStomp::Interfaces::FrameMethods
  include OnStomp::Interfaces::ClientEvents
  include OnStomp::Interfaces::ReceiptManager
  include OnStomp::Interfaces::SubscriptionManager
  
  attr_reader :uri, :ssl, :connection
  
  # The protocol versions to allow for this connection
  # @return [Array<String>]
  attr_configurable_protocols :versions
  
  # The client-side heartbeat settings to allow for this connection
  # @return [Array<Fixnum>]
  attr_configurable_client_beats :heartbeats
  
  # The host header value to send to the broker when connecting. This allows
  # the client to inform the server which host it wishes to connect with
  # when multiple brokers may share an IP address through virtual hosting.
  # @return [String]
  attr_configurable_str :host, :default => 'localhost', :uri_attr => :host
  
  # The login header value to send to the broker when connecting.
  # @return [String]
  attr_configurable_str :login, :default => '', :uri_attr => :user
  
  # The passcode header value to send to the broker when connecting.
  # @return [String]
  attr_configurable_str :passcode, :default => '', :uri_attr => :password
  
  # The class to use when instantiating a new IO processor for the connection.
  # Defaults to {OnStomp::Components::ThreadedProcessor}
  # @return [Class]
  attr_configurable_processor :processor
  
  def initialize(uri, options={})
    @uri = uri.is_a?(::URI) ? uri : ::URI.parse(uri)
    @ssl = options.delete(:ssl)
    configure_configurable options
    configure_subscription_management
    configure_receipt_management
    on_disconnect do |f, con|
      close unless f[:receipt]
    end
  end
  
  def connect(headers={})
    @connection = OnStomp::Connections.connect self, headers,
      { :'accept-version' => @versions.join(','), :host => @host,
        :'heart-beat' => @heartbeats.join(','), :login => @login,
        :passcode => @passcode }, pending_connection_events
    processor_inst.start
  end
  alias :open :connect
  
  def disconnect_with_flush(headers={})
    disconnect_without_flush(headers).tap do
      processor_inst.join
    end
  end
  alias :disconnect_without_flush :disconnect
  alias :disconnect :disconnect_with_flush
  
  def connected?
    connection && connection.connected?
  end
  
  def close!
    close
    processor_inst.stop
  end
  
  def transmit(frame, cbs={})
    frame.tap do
      register_callbacks frame, cbs
      trigger_before_transmitting frame
      connection.write_frame_nonblock frame
    end
  end
  
  def dispatch_received frame
    trigger_before_receiving frame
    trigger_after_receiving frame
  end
  
  def dispatch_transmitted frame
    trigger_after_transmitting frame
  end
  
  private
  def register_callbacks f, cbs
    cbs[:subscribe] && add_subscription(f, cbs[:subscribe])
    cbs[:receipt] && add_receipt(f, cbs[:receipt])
  end
  
  def processor_inst
    @processor_inst ||= processor.new(self)
  end
  
  def close
    connection && connection.close
    clear_subscriptions
    clear_receipts
  end
end
