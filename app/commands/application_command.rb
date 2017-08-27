class ApplicationCommand
  include ActiveModel::Model

  # Application Command
  #
  # CQRS and EventSourcing for Rails
  #
  # This abstraction allows us to integrate more seamlessly with smart contracts
  # that run on the Ethereum Blockchain.  (referred to as the Ethereum API)
  #
  # In this scheme, the core data abstraction is the EventStore, an append-only
  # datastructure implemented as a PostgresQL Table.  Each record in the
  # EventStore is called an EventLine (see `models/event_line`)
  #
  # How it works:
  # - Commands operate like AR models (using `ActiveModel`)
  # - Commands are composed of sub-objects (standard Rails models)
  # - Commands can save an event to the EventStore
  # - Commands can be initialized from the EventStore
  # - Commands can generate `projections` (DDD parlance...)
  #
  # - use for forms - edit and create commands - anything that updates the DB
  #   - single-model updates
  #   - multi-model transactions
  # - creates event store
  #   - events are the ultimate source of truth
  #   - events are signed as in a merkle chain
  #   - events can be generated by commands OR come from Solidity contracts
  #   - events can have one or more projections
  #   - events can be replayed

  # - using commands from controllers
  #    `Command.new(params).save_event.project`
  # - using commands to replay events
  #    `Command.from_event(event).project`

  # form handling inspired by
  # http://blog.sundaycoding.com/blog/2016/01/08/contextual-validations-with-form-objects

  # ----- configuration methods

  # define an attr_accessor for each subobject
  # define a method `subobject_symbols` that returns the list of subobjects
  def self.attr_subobjects(*klas_list)
    attr_accessor(*klas_list)
    define_method 'subobject_symbols' do
      klas_list
    end
  end

  # delegate all fields of a subobject to the subobject
  def self.attr_delegate_fields(*klas_list)
    klas_list.each do |sym|
      klas = sym.to_s.camelize.constantize
      getters = klas.attribute_names.map(&:to_sym)
      setters = klas.attribute_names.map { |x| "#{x}=".to_sym }
      delegate *getters, to: sym
      delegate *setters, to: sym
    end
  end

  # ----- template methods - override in subclass

  def self.from_event(_event)
    raise "from_event: override in subclass"
  end

  def event_data
    {}
  end

  def transact_before_project
    # override in subclass
  end

  # ----- persistence methods

  def save
    raise "NOT ALLOWED - USE #save_event and/or #project"
  end

  def save_event
    valid?
    puts errors.inspect unless valid?
    if valid?
      base = {klas: self.class.name}
      data = {data: self.event_data}
      EventLine.new(data.merge(base)).save
    end
    self
  end

  # pro*jekt* - create a projection - an aggregate data view
  def project
    valid?
    puts errors.inspect unless valid?
    if valid?
      transact_before_project # perform a transaction, if any
      subs.each(&:save)       # save all subobjects
      self
    else
      false
    end
  end

  # ----- validation predicates

  # validations can live in the Command or the Sub-Object (or both!)
  def valid?
    if super && subs.map(&:valid?).all?
      true
    else
      subs.each do |object|
        object.valid?                        # populate the subobject errors
        object.errors.each do |field, error| # transfer the error messages
          errors.add(field, error)
        end
      end
      false
    end
  end

  def invalid?
    !valid?
  end

  private

  def subobjects
    subobject_symbols.map { |el| self.send(el) }
  end

  alias_method :subs, :subobjects

end
