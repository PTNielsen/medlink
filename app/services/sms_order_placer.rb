class SMSOrderPlacer < SMSResponder
  def valid?
    true # This is our fallback catch-all handler
  end

  def respond
    if unrecognized_shortcodes.any?
      error! "sms.unrecognized_shortcodes",
        { codes: unrecognized_shortcodes }, condense: :code
    end

    if unavailable_supplies.any?
      error! "sms.invalid_for_country",
        { codes: unavailable_supplies, country: user.country.name}, condense: :code
    end

    if duplicate
      Rails.logger.info "Sending response for sms #{sms}, duplicate of #{duplicate}"
      error! "sms.duplicate_order", {
        supplies: supply_names,
        due_date: Request.due_date(duplicate.request.created_at)
      }, condense: :supply
    end

    create_orders
    send_response confirmation_message
  rescue PresentableError => e
    send_response e.message
  end

private

  def parsed
    @_parsed ||= SMS::Parser.new(message).tap &:run!
  rescue SMS::Parser::ParseError => e
    # :nocov:
    error! "sms.unparseable"
    # :nocov:
  end

  def create_orders
    rc = RequestCreator.new(user, supplies: found_supplies, request: {
      message_id:        sms.id,
      user_id:           user.id,
      text:              parsed.instructions
    })
    rc.save
    sms.update request: rc.request
  end

  def supply_names
    @_supply_names ||= found_supplies.map { |s| "#{s.name} (#{s.shortcode})" }
  end

  def duplicate
    @_duplicate ||= sms.last_duplicate within: 1.hour
  end

  def confirmation_message
    SMS::Condenser.new("sms.confirmation", :supply,
      supplies: supply_names,
      due_date: Request.due_date(sms.created_at)
    ).message
  end

  def shortcodes
    @_shortcodes ||= parsed.shortcodes.map(&:upcase)
  end

  def found_supplies
    @_found_supplies ||= Supply.where(shortcode: shortcodes)
  end

  def unrecognized_shortcodes
    shortcodes - found_supplies.map(&:shortcode)
  end

  def unavailable_supplies
    shortcodes - user.country.supplies.map(&:shortcode)
  end
end
