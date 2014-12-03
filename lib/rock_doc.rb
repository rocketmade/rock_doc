class RockDoc
  ControllerConfigurator = Struct.new(:controller, :resource_name,
                                      :resource_class, :controller_class,
                                      :serializer_class, :routes,
                                      :json_representation, :permitted_params,
                                      :notes, :final_markdown
                                     )

  RouteConfigurator = Struct.new(:action, :description, :verb, :pathspec,
                                 :controller_config, :notes, :final_markdown,
                                 :scopes
                                )


  class << self
    attr_accessor :controllers
    attr_accessor :actions
    attr_accessor :global_block
  end


  def self.configure &block
    instance_eval &block
  end

  def self.controller name, &block
    self.controllers ||= {}
    self.controllers[name] = block
  end

  def self.action name, &block
    self.actions ||= {}
    self.actions[name] = block
  end

  def self.global &block
    self.global_block = block.call
  end

  delegate :global_block, :actions, :controllers, to: :class

  def configuration_strings
    {
      namespace: "api/",
      app_name:  Rails.application.class.parent.name
    }
  end

  def t key, options={}
    I18n.t key, options.merge(scope: "api_doc")
  end

  def t! key, options={}
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
    keys = ["controllers.#{config.controller}.actions.#{action}", "actions.#{action}", "controllers.#{config.controller}.actions.default", "actions.default"]
    try_translations keys, resource: config.resource_name, resources: config.resource_name.pluralize, controller: config.controller, action: action.capitalize
  end

  def scope_description config: required, scope: scope, default: nil, type: nil
    keys = ["controllers.#{config.controller}.scopes.#{scope}", "scopes.#{scope}", "controllers.#{config.controller}.scopes.default", "scopes.default"]
    try_translations keys, resource: config.resource_name, resources: config.resource_name.pluralize, controller: config.controller, scope_name: scope, scope_default: default, type: type
  end

  def required
    method = caller_locations(1,1)[0].label
    raise ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
  end

  def controller_block controller: required, routes: required, config: required
    config.controller    = controller
    config.routes        = routes
    config.resource_name = controller.gsub(/^#{configuration_strings[:namespace]}/, '').camelcase.singularize

    config.controller_class = begin
                                Rails.application.routes.dispatcher("").send(:controller_reference, config.controller)
                              rescue NameError
                                nil
                              end

    config.resource_class   = begin
                                config.resource_name.constantize
                              rescue NameError
                                nil
                              end

    config.serializer_class = config.resource_class.active_model_serializer if config.resource_class.present? && config.resource_class < ActiveRecord::Base
    json_representation = nil

    if config.serializer_class
      attributes = config.serializer_class.schema[:attributes].dup
      associations = config.serializer_class.schema.fetch(:associations, {}).reduce({}) { |memo, kvp|
        key = config.resource_class.reflect_on_association(kvp.first).class_name

        if kvp.last.keys.include? :has_many
          memo[kvp.first] = t("json.resource_array", resource: key, resources: key.pluralize)
        else
          memo[kvp.first] = t("json.resource_object", resource: key, resources: key.pluralize)
        end
        memo
      }

      attributes.merge! associations

      json_representation = JSON.pretty_generate attributes
      json_representation.gsub!(/"(\[|\{)/, '\1')
      json_representation.gsub!(/(\]|\})"/, '\1')

      json_representation.gsub!(/:\ "\w*"/).each do |match|
        ": #{match.gsub(':', '').gsub('"', '').strip.capitalize}"
      end

    end

    config.json_representation = json_representation

    permitted_params = nil

    if config.controller_class && config.controller_class.permitted_params
      params_hash = config.controller_class.permitted_params
      params_hash[params_hash.keys.first] = params_hash[params_hash.keys.first].map do |attribute|
        type = config.resource_class.columns_hash[attribute].type.to_s.capitalize rescue "String"
        [attribute, type]
      end.to_h
      permitted_params = JSON.pretty_generate params_hash
      permitted_params.gsub!(/:\ "\w*"/).each do |match|
        match.gsub('"', '')
      end
    end

    config.permitted_params = permitted_params

    if controllers[controller]
      config.instance_eval &controllers[controller]
    end

    @toc << "- [#{config.resource_name}](##{config.controller})"
    unless config.final_markdown.present?
      md = []
      md << "<a name=\"#{config.controller}\" />"
      md << "## #{config.resource_name}"
      if config.json_representation.present?
        md << <<JSON
#### JSON
````
#{config.json_representation}
````
JSON
      end

      if config.permitted_params.present?
        md << <<PARAMS

#### Permitted Parameters (for POST/PUT/PATCH requests)
````
#{config.permitted_params}
````

PARAMS
      end
      config.final_markdown = md.join("\n")
    end

    config.final_markdown unless config.final_markdown == ":nodoc:"
  end

  def route_block controller_config: required, route: required, config: required
    config.action = route.defaults.fetch(:action, '')
    config.description = action_description config: controller_config, action: config.action
    config.verb = route.verb.source.gsub(/[$^]/, '')
    config.pathspec = route.path.spec.to_s.gsub(/\(?.:format\)?/, '.json')
    config.controller_config = controller_config

    if config.action.to_s == "index"
      scopes = controller_config.controller_class.scopes_configuration
      config.scopes = scopes.reduce({}) do |memo, kvp|
        key = kvp.first
        value = kvp.last
        if value[:type] == :hash
          value[:using].each do |sub_key|
            memo["#{key}[#{sub_key}]"] = scope_description scope: "#{key}[#{sub_key}]", config: controller_config, default: value[:default], type: value[:type]
          end
        else
          memo[key.to_s] = scope_description scope: key, config: controller_config, default: value[:default], type: value[:type]
        end

        memo
      end
    end

    if actions["#{controller_config.controller}##{config.action}"]
      config.instance_eval &actions["#{controller_config.controller}##{config.action}"]
    end

    @toc << "  - [#{config.description}](##{controller_config.controller}.#{config.action})"
    md = []
    md << "<a name=\"#{controller_config.controller}.#{config.action}\" />"
    md << "### #{config.description}"
    md << "**#{config.verb} #{config.pathspec}**"

    if config.scopes.present?
      md << "\n\n##### GET parameters supported:"
      config.scopes.each do |k, v|
        scope = "* `#{k}`"
        scope += ": #{v}" if v.present?
        md << scope
      end
      md << "\n"
    end

    if config.notes.present?
      md << ''
      md << "##### Notes"
      md << config.notes
      md << "\n"
    end

    config.final_markdown = md.join("\n") unless config.final_markdown.present?

    config.final_markdown unless config.final_markdown == ":nodoc:"

  end

  def generate
    @toc = []

    controllers = Rails.application.routes.routes.reduce({}) { |memo, route|
      if route.defaults.fetch(:controller, '').starts_with? configuration_strings[:namespace]
        memo[route.defaults[:controller]] ||= []
        memo[route.defaults[:controller]] << route
      end
      memo
    }

    controller_blocks = []
    controllers.each do |controller, routes|
      controller_config = ControllerConfigurator.new

      controller_blocks << controller_block(controller: controller, routes: routes, config: controller_config)

      routes.each do |route|
        route_config = RouteConfigurator.new
        controller_blocks << route_block(controller_config: controller_config, config: route_config, route: route)
      end
      controller_blocks << ''
    end


    md = []
    md << global_block || "# " + t("global_header", app_name: configuration_strings[:app_name])
    md << "\n"
    md += @toc
    md << "\n"
    md += controller_blocks
    md.join("\n")
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
