# -*- encoding: utf-8 -*-

# Mixin for {OnStomp::Client clients} to provide methods that create
# and transmit STOMP {OnStomp::Components::Frame frames}.
module OnStomp::Interfaces::FrameMethods
  # I'm using @api tags in here to provide a bit of data, here's the format:
  # gem:<major version>[,<major version>,...] STOMP:<version>[,<version>,...]
  # The first chunk indicates the MAJOR versions of the OnStomp gem that support
  # the method. The second chunk indicates the STOMP protocol versions that
  # support the frame generated by this method. A single '*' after the STOMP
  # versions indicates that there are minor changes between protocols
  # (eg: new acceptable values for an optional header.) A single '!' after
  # the STOMP versions indicates that there are major changes between protocols
  # (eg: a new header is required, as with ACK) indicating that some ways of
  # calling the method may produce errors with newer versions of the STOMP
  # protocol. All other text after the severity markers is for my own reference
  # to remind me of the changes. These API tags will be queried and put into
  # a document to provide a quick reference of changes between protocols or
  # major gem versions for end users.
  
  # @api gem:1 STOMP:1.0,1.1
  # Transmits a SEND frame generated by the client's connection
  # @param [String] dest destination for the frame
  # @param [String] body body of the frame
  # @param [{#to_sym => #to_s}] headers additional headers to include in
  #   the frame
  # @return [OnStomp::Components::Frame] SEND frame
  # @yield [receipt] block to invoke when a RECEIPT frame is received for the
  #   transmitted SEND frame
  # @yieldparam [OnStomp::Components::Frame] receipt RECEIPT for the frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   SEND frames
  # @option headers [String] :'content-type' The content type of the SEND
  #   frame's body. If the body is text (ie: has a non-binary `encoding`)
  #   `onstomp` will set the :'content-type' header to 'text/plain' if it
  #   has not been set. See {file:docs/Encodings.md Encodings} for more
  #   details.
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @option headers [String] :transaction The ID of an existing transaction
  #   to add this frame to.
  # @option headers [String] :'content-length' If you set this header, it
  #   will be overwritten, so save your fingers from a few keystrokes by not
  #   setting it.  All SEND frames generated by `onstomp` will have a
  #   :'content-length' header.
  # @example
  #   # Transmit a simple SEND frame to the broker
  #   client.send '/queue/example', 'Hello STOMP'
  #   
  #   # Everything's better with umlauts.
  #   client.send '/topic/example', "Hëllo Wörld",
  #     :'content-type' => 'text/plain;charset=UTF-8'
  #
  #   # Get a receipt for the SEND frame
  #   client.send '/queue/example', "Did you get that thing I sent you?" do |r|
  #     puts "The broker received our SEND frame"
  #   end
  def send dest, body, headers={}, &cb
    transmit connection.send_frame(dest, body, headers), :receipt => cb
  end
  alias :puts :send

  # @api gem:1 STOMP:1.0,1.1* [+ack:client-individual]
  # Transmits a SUBSCRIBE frame generated by the client's connection. Depending
  # upon the connection, a subscription can be set to various MESSAGE
  # acknowledgement modes by setting the +:ack+ header.
  # STOMP 1.0 and STOMP 1.1 connections support:
  # * :ack => 'auto'
  #   The broker assumes that MESSAGE frames received through the
  #   subscription have been properly received, the client should NOT attempt
  #   to ACK (or NACK) any of the messages.
  # * :ack => 'client'
  #   The broker assumes that MESSAGE frames should be acknowledged by the
  #   client through the use of ACK frames.
  # STOMP 1.1 connections support:
  # * :ack => 'client-individual'
  #   Upon receiving an ACK frame for a MESSAGE frame, some brokers will
  #   mark the MESSAGE frame and all those sent to the client before it
  #   as acknowledged. This mode indicates that each MESSAGE frame must
  #   be acknowledged by its own ACK frame for the broker can assume the
  #   MESSAGE frame has been received by the client.
  # @param [String] dest destination for the frame
  # @param [{#to_sym => #to_s}] headers additional headers to include in
  #   the frame
  # @return [OnStomp::Components::Frame] SUBSCRIBE frame
  # @yield [message] block to invoke for every MESSAGE frame received on the
  #   subscription
  # @yieldparam [OnStomp::Components::Frame] message MESSAGE frame received on
  #  the subscription
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   SUBSCRIBE frames
  # @see #unsubscribe
  # @see #ack
  # @see #nack
  # @option headers [String] :id A unique ID for the subscription. If you
  #   do not set this header, an subscription ID will be automatically
  #   generated ensuring that all `onstomp` SUBSCRIBE frames have an ID.
  # @option headers [String] :ack ('auto') The ack mode to use with this
  #   subscription. A value of 'auto' means MESSAGE frames are assumed
  #   received and no ACK frame is necessary. A value of 'client' or
  #   'client-individual' means all MESSAGE frames should be acknowledged
  #   with an ACK (or un-acknowledged with a NACK.)
  # @option headers [String] :selector A SQL style filter to use against
  #   MESSAGE frames (the form and availability of this will vary by
  #   broker.)
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @example
  #   # A basic subscription
  #   client.subscribe '/queue/example' do |m|
  #     puts "Got a MESSAGE: #{m.body}"
  #   end
  #   
  #   # ACK our MESSAGE frames
  #   client.subscribe '/queue/example', :ack => 'client' do |m|
  #     client.ack m
  #     puts "Got (and ACK'd) a MESSAGE: #{m.body}"
  #   end
  def subscribe dest, headers={}, &cb
    transmit connection.subscribe_frame(dest, headers), :subscribe => cb
  end
  
  # @api gem:1 STOMP:1.0,1.1
  # Transmits an UNSUBSCRIBE frame generated by the client's connection.
  # @overload unsubscribe(subscribe_frame, headers={})
  #   Generates an UNSUBSCRIBE frame to match the given SUBSCRIBE frame
  #   @param [OnStomp::Components::Frame] subscribe_frame
  #   @param [{#to_sym => #to_s}] headers optional headers to include in
  #     the UNSUBSCRIBE frame
  #   @example
  #     sub = client.subscribe('/queue/test') { |m| ... }
  #     client.unsubscribe sub
  # @overload unsubscribe(id, headers={})
  #   Generates an UNSUBSCRIBE frame with the given id
  #   @param [String] id
  #   @param [{#to_sym => #to_s}] headers optional headers to include in
  #     the UNSUBSCRIBE frame
  #   @example
  #     client.subscribe('/queue/test', :id => 's-1234') { |m| ... }
  #     client.unsubscribe 's-1234'
  # @return [OnStomp::Components::Frame] UNSUBSCRIBE frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   UNSUBSCRIBE frames
  # @see #subscribe
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  def unsubscribe frame_or_id, headers={}
    transmit connection.unsubscribe_frame(frame_or_id, headers)
  end

  # @api gem:1 STOMP:1.0,1.1
  # Transmits a BEGIN frame generated by the client's connection to start
  # a transaction.
  # @param [String] tx_id identifier for the transaction
  # @param [{#to_sym => #to_s}] headers additional headers to include in
  #   the frame
  # @return [OnStomp::Components::Frame] BEGIN frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   BEGIN frames
  # @see #abort
  # @see #commit
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @example
  #   client.begin 't-1234'
  #   client.send '/queue/test', 'hello transaction!', :transaction => 't-1234'
  #   client.commit 't-1234'
  def begin tx_id, headers={}
    transmit connection.begin_frame(tx_id, headers)
  end

  # @api gem:1 STOMP:1.0,1.1
  # Transmits an ABORT frame generated by the client's connection to rollback
  # a transaction.
  # @param [String] tx_id identifier for the transaction
  # @param [{#to_sym => #to_s}] headers additional headers to include in
  #   the frame
  # @return [OnStomp::Components::Frame] ABORT frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   ABORT frames
  # @see #begin
  # @see #commit
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @example
  #   client.begin 't-1234'
  #   client.send '/queue/test', 'hello transaction!', :transaction => 't-1234'
  #   client.abort 't-1234'
  def abort tx_id, headers={}
    transmit connection.abort_frame(tx_id, headers)
  end

  # @api gem:1 STOMP:1.0,1.1
  # Transmits a COMMIT frame generated by the client's connection to complete
  # a transaction.
  # @param [String] tx_id identifier for the transaction
  # @param [{#to_sym => #to_s}] headers additional headers to include in
  #   the frame
  # @return [OnStomp::Components::Frame] COMMIT frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   COMMIT frames
  # @see #abort
  # @see #begin
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @example
  #   client.begin 't-1234'
  #   client.send '/queue/test', 'hello transaction!', :transaction => 't-1234'
  #   client.commit 't-1234'
  def commit tx_id, headers={}
    transmit connection.commit_frame(tx_id, headers)
  end

  # @api gem:1 STOMP:1.0,1.1* [DISCONNECTs are now always RECEIPTable]
  # Transmits a DISCONNECT frame generated by the client's connection to end
  # the STOMP session.
  # @param [{#to_sym => #to_s}] headers additional headers to include in
  #   the frame
  # @return [OnStomp::Components::Frame] DISCONNECT frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   DISCONNECT frames
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @example
  #   client.connect
  #   client.send '/queue/test', 'a quick message'
  #   client.disconnect
  def disconnect headers={}
    transmit connection.disconnect_frame headers
  end

  # @api gem:1 STOMP:1.0,1.1! [+subscription:id]
  # Transmits an ACK frame generated by the client's connection.
  # @overload ack(message_frame, headers={})
  #   @api gem:1 STOMP:1.0,1.1
  #   @note Users should use this form whenever possible as it will work
  #     with STOMP 1.0 and 1.1 connections.
  #   @param [OnStomp::Components::Frame] message_frame the MESSAGE frame to
  #     acknowledge.
  #   @param [{#to_sym => #to_s}] headers additional headers to include in
  #     the frame
  #   @example
  #     client.subscribe '/queue/test', :ack => 'client' do |m|
  #       if m[:'x-of-interest-to-me'] == 'hells yes'
  #         client.ack m
  #       end
  #     end
  # @overload ack(message_id, headers={})
  #   @api gem:1 STOMP:1.0
  #   @note This form will raise an `ArgumentError` with STOMP 1.1 connections
  #     as a subscription ID is also required to ACK a received MESSAGE.
  #   @param [String] message_id +message-id+ header of MESSAGE frame to
  #     acknowledge.
  #   @param [{#to_sym => #to_s}] headers additional headers to include in
  #     the frame
  #   @example
  #     client.subscribe '/queue/test', :ack => 'client' do |m|
  #       if m[:'x-of-interest-to-me'] == 'hells yes'
  #         client.ack m[:'message-id']
  #       end
  #     end
  # @overload ack(message_id, subscription_id, headers={})
  #   @api gem:1 STOMP:1.0,1.1
  #   @note This form should be used with STOMP 1.1 connections when it is
  #     not possible to provide the actual MESSAGE frame.
  #   @param [String] message_id +message-id+ header of MESSAGE frame to
  #     acknowledge.
  #   @param [String] subscription_id `subscription` header of MESSAGE frame to
  #     acknowledge.
  #   @param [{#to_sym => #to_s}] headers additional headers to include in
  #     the frame
  #   @example
  #     client.subscribe '/queue/test', :ack => 'client' do |m|
  #       if m[:'x-of-interest-to-me'] == 'hells yes'
  #         client.ack m[:'message-id'], m[:subscription]
  #       end
  #     end
  # @return [OnStomp::Components::Frame] ACK frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   ACK frames
  # @see #nack
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @option headers [String] :transaction The ID of an existing transaction
  #   to add this frame to.
  def ack *args
    transmit connection.ack_frame(*args)
  end

  # @api gem:1 STOMP:1.1
  # Transmits a NACK frame generated by the client's connection.
  # @overload nack(message_frame, headers={})
  #   Generates a NACK frame for the given MESSAGE frame.
  #   @param [OnStomp::Components::Frame] message_frame the MESSAGE frame to
  #     un-acknowledge.
  #   @param [{#to_sym => #to_s}] headers additional headers to include in
  #     the frame
  #   @example
  #     client.subscribe '/queue/test', :ack => 'client' do |m|
  #       if m[:'x-of-interest-to-me'] == 'hells no!'
  #         client.nack m
  #       end
  #     end
  # @overload nack(message_id, subscription_id, heders={})
  #   @param [String] message_id +message-id+ header of MESSAGE frame to
  #     un-acknowledge.
  #   @param [String] subscription_id `subscription` header of MESSAGE frame to
  #     un-acknowledge.
  #   @param [{#to_sym => #to_s}] headers additional headers to include in
  #     the frame
  #   @example
  #     client.subscribe '/queue/test', :ack => 'client' do |m|
  #       if m[:'x-of-interest-to-me'] == 'hells no!'
  #         client.nack m[:'message-id'], m[:subscription]
  #       end
  #     end
  # @return [OnStomp::Components::Frame] NACK frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   NACK frames
  # @see #ack
  # @option headers [String] :receipt A receipt ID for the frame, this
  #   will be matched by the :'receipt-id' header in the broker's RECEIPT
  #   response.
  # @option headers [String] :transaction The ID of an existing transaction
  #   to add this frame to.
  def nack *args
    transmit connection.nack_frame(*args)
  end

  # @api gem:1 STOMP:1.1
  # Transmits a client heartbeat frame generated by the client's connection.
  # @return [OnStomp::Components::Frame] heartbeat frame
  # @raise OnStomp::UnsupportedCommandError if the connection does not support
  #   heartbeat frames
  # @example
  #   # If it's been a while since you've sent any data to the broker:
  #   client.beat
  #   # Now the broker knows you're still listening, nay hanging on its every
  #   # every word.
  def beat
    transmit connection.heartbeat_frame
  end
end
