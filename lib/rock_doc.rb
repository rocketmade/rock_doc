class RockDoc
  autoload :Rendering,     "rock_doc/rendering"
  autoload :Interrogation, "rock_doc/interrogation"
  autoload :Configuration, "rock_doc/configuration"

  delegate :global_configuration, :app_controller_blocks, :app_serializer_blocks, :t, :t!, to: :class
  delegate :renderer, to: :global_configuration
  delegate :present_json, to: :renderer

  # Global Configurations
  def self.global_configuration
    @global_configuration ||= Configuration::Global.new.tap do |gc|
      gc.namespaces = [:api]
      gc.toc        = []
      gc.app_name   = Rails.application.class.parent.name
      gc.renderer   = Rendering::Markdown.new
      gc.title      = t("global_header", app_name: gc.app_name)

      gc.interrogators = {
        # Generates the list of controllers/actions we are going to interrogate
        routes:        [Interrogation::Routes],

        # Generates the list of models to render in the serializers section
        resources:     [Interrogation::ActiveModelSerializers],

        # Generates the configuration for a serializer
        serialization: [Interrogation::ActiveModelSerializer],

        # Generates the configuration for a controller
        controller:    [Interrogation::Controller, Interrogation::ActiveModelSerializer],

        # Generates the configuration for an action
        action:        [Interrogation::Action]
      }
    end
  end

  def self.app_controller_blocks
    @app_controller_blocks ||= {}.with_indifferent_access
  end

  def self.app_serializer_blocks
    @app_serializer_blocks ||= {}.with_indifferent_access
  end

  def self.current_namespaces
    @namespaces ||= []
  end

  def self.configure &block
    instance_exec &block
  end

  def self.namespace space, &block
    current_namespaces << space
    instance_exec &block
    current_namespaces.pop
  end

  def self.controller name, &block
    path = (current_namespaces + [name]).join('/')
    self.app_controller_blocks[path] = Configuration::AppControllerConfiguration.new(path, block)
  end

  def self.serializer name, &block
    self.app_serializer_blocks[name] = block
  end

  def self.global &block
    block.call self.global_configuration
  end

  def self.t key, options={}
    I18n.t key, options.merge(scope: "api_doc")
  end

  def self.t! key, options={}
    I18n.t! key, options.merge(scope: "api_doc")
  end

  def try_translations keys, options
    keys.map do |key|
      begin
        t! key, options
      rescue I18n::MissingTranslationData => e
        nil
      end
    end.compact.first
  end

  def action_description configuration: required, action: required
    keys = ["controllers.#{configuration.path}.actions.#{action}", "actions.#{action}", "controllers.#{configuration.path}.actions.default", "actions.default"]
    try_translations keys, resource: configuration.resource_name, resources: configuration.resource_name.pluralize, controller: configuration.path, action: action.capitalize
  end

  def scope_description configuration: required, scope: scope, default: nil, type: nil
    keys = ["controllers.#{configuration.path}.scopes.#{scope}", "scopes.#{scope}", "controllers.#{configuration.path}.scopes.default", "scopes.default"]
    try_translations keys, resource: configuration.resource_name, resources: configuration.resource_name.pluralize, controller: configuration.path, scope_name: scope, scope_default: default, type: type
  end

  def required
    method = caller_locations(1,1)[0].label
    raise ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
  end

  def configure_serializer resource_configuration: required, configuration: required
    global_configuration.interrogators[:serialization].each do |interrogator|
      interrogator.interrogate_serialization doc: self, resource_configuration: resource_configuration, configuration: configuration
    end

    ## Hook for app code
    if app_serializer_blocks[configuration.configuration_name]
      configuration.instance_exec configuration, &app_serializer_blocks[configuration.configuration_name]
    end

    configuration.json_representation ||= present_json configuration.attributes_for_json

    configuration
  end

  def configure_controller path: required, routes: required, configuration: required, serializer_configurations: required
    global_configuration.interrogators[:controller].each do |interrogator|
      interrogator.interrogate_controller doc: self, path: path, route_configurations: routes, serializer_configurations: serializer_configurations, configuration: configuration
    end

    ## Hook for app code
    if app_controller_blocks[path]
      configuration.instance_exec configuration, &app_controller_blocks[path].block
    end

    if configuration.json_representation.blank?
      if configuration.attributes_for_json.present?
        configuration.json_representation = present_json configuration.attributes_for_json
      elsif configuration.serializer_configuration
        begin
          configuration.json_representation = present_json configuration.serializer_configuration.attributes_for_json
        rescue NoMethodError
        end
      end
    end

    if configuration.permitted_params.blank? && configuration.attributes_for_permitted_params.present?
      configuration.permitted_params = present_json configuration.attributes_for_permitted_params
    end

    configuration.action_configurations = routes.map do |route|
      Configuration::Action.new.tap do |action_configuration|
        configure_action(controller_configuration: configuration, configuration: action_configuration, route: route)
      end
    end.reject &:nodoc

    configuration
  end

  def configure_action controller_configuration: required, route: required, configuration: required
    global_configuration.interrogators[:action].each do |interrogator|
      interrogator.interrogate_action doc: self, controller_configuration: controller_configuration, route: route, configuration: configuration
    end

    if controller_configuration.action_blocks[configuration.action]
      configuration.instance_exec configuration, &controller_configuration.action_blocks[configuration.action]
    end

    configuration
  end

  # Generates documentation by running interrogation, configuration blocks and the renderer
  def generate
    serializers = global_configuration.interrogators[:resources].map do |interrogator|
      interrogator.interrogate_resources doc: self
    end.flatten.uniq.map do |resource|
      Configuration::Serializer.new.tap do |configuration|
        configure_serializer resource_configuration: resource, configuration: configuration
      end
    end.reject &:nodoc

    routes = global_configuration.interrogators[:routes].map do |interrogator|
      interrogator.interrogate_routes doc: self
    end.flatten.uniq

    controller_configurations = routes.map(&:controller_path).uniq.map do |path|
      Configuration::Controller.new.tap do |configuration|
        configuration.path = path
        route_set = routes.select { |r| r.controller_path == path }
        configure_controller(path: path, routes: route_set, configuration: configuration, serializer_configurations: serializers)
      end
    end.reject &:nodoc

    renderer.render doc: self, controller_configurations: controller_configurations, serializer_configurations: serializers
  end

  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/rock_doc_tasks.rake"
    end

    initializer 'rock_doc_translations' do |app|
      I18n.load_path += Dir[File.join(File.dirname(__FILE__), "locales/*.yml")]
    end
  end
end
