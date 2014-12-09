class RockDoc
  autoload :Rendering, "rock_doc/rendering"
  autoload :Interrogation, "rock_doc/interrogation"
  autoload :Configuration, "rock_doc/configuration"

  delegate :global_config, :app_controller_blocks, :app_serializer_blocks, :t, :t!, to: :class
  delegate :renderer, to: :global_config
  delegate :present_json, to: :renderer

  def self.global_config
    @global_config ||= Configuration::Global.new.tap do |gc|
      gc.namespaces = [:api]
      gc.toc = []
      gc.app_name = Rails.application.class.parent.name
      gc.renderer = Rendering::Markdown.new
      gc.title = t("global_header", app_name: gc.app_name)
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
    block.call self.global_config
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

  def action_description config: required, action: required
    keys = ["controllers.#{config.path}.actions.#{action}", "actions.#{action}", "controllers.#{config.path}.actions.default", "actions.default"]
    try_translations keys, resource: config.resource_name, resources: config.resource_name.pluralize, controller: config.path, action: action.capitalize
  end

  def scope_description config: required, scope: scope, default: nil, type: nil
    keys = ["controllers.#{config.path}.scopes.#{scope}", "scopes.#{scope}", "controllers.#{config.path}.scopes.default", "scopes.default"]
    try_translations keys, resource: config.resource_name, resources: config.resource_name.pluralize, controller: config.path, scope_name: scope, scope_default: default, type: type
  end

  def required
    method = caller_locations(1,1)[0].label
    raise ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
  end

  def configure_serializer resource_config: required, config: required
    global_config.interrogators[:serialization].each do |interrogator|
      interrogator.interrogate_serialization self, resource_config, config
    end

    ## Hook for app code
    if app_serializer_blocks[config.configuration_name]
      config.instance_exec config, &app_serializer_blocks[config.configuration_name]
    end

    config.json_representation ||= present_json config.attributes_for_json

    config
  end

  def configure_controller path: required, routes: required, config: required, serializer_configs: required
    global_config.interrogators[:controller].each do |interrogator|
      interrogator.interrogate_controller self, path, routes, serializer_configs, config
    end

    ## Hook for app code
    if app_controller_blocks[path]
      config.instance_exec config, &app_controller_blocks[path].block
    end

    if config.json_representation.blank?
      if config.attributes_for_json.present?
        config.json_representation = present_json config.attributes_for_json
      elsif serializer_config
        begin
          config.json_representation = present_json serializer_config.attributes_for_json
        rescue NoMethodError
        end
      end
    end

    if config.permitted_params.blank? && config.attributes_for_permitted_params.present?
      config.permitted_params = present_json config.attributes_for_permitted_params
    end

    config.action_configs = routes.map do |route|
      Configuration::Action.new.tap do |action_config|
        configure_action(controller_config: config, config: action_config, route: route)
      end
    end.reject &:nodoc

    config
  end

  def configure_action controller_config: required, route: required, config: required
    global_config.interrogators[:action].each do |interrogator|
      interrogator.interrogate_action self, controller_config, route, config
    end

    if controller_config.action_blocks[config.action]
      config.instance_exec config, &controller_config.action_blocks[config.action]
    end

    config
  end

  def generate
    serializers = global_config.interrogators[:resources].map do |interrogator|
      interrogator.interrogate_resources self
    end.flatten.uniq.map do |resource|
      Configuration::Serializer.new.tap do |config|
        configure_serializer resource_config: resource, config: config
      end
    end.reject &:nodoc

    routes = global_config.interrogators[:routes].map do |interrogator|
      interrogator.interrogate_routes self
    end.flatten.uniq

    controller_configs = routes.map(&:controller_path).uniq.map do |path|
      Configuration::Controller.new.tap do |config|
        config.path = path
        route_set = routes.select { |r| r.controller_path == path }
        configure_controller(path: path, routes: route_set, config: config, serializer_configs: serializers)
      end
    end.reject &:nodoc

    renderer.render global: global_config, controllers: controller_configs, serializers: serializers
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
