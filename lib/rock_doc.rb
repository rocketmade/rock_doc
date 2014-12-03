class RockDoc
  GlobalConfigurator = Struct.new(:title, :toc, :global_block, :namespaces, :app_name)

  ControllerConfigurator = Struct.new(:controller, :resource_name,
                                      :resource_class, :controller_class,
                                      :serializer_class, :routes,
                                      :json_representation, :permitted_params,
                                      :notes, :final_markdown, :attributes_for_json,
                                      :attributes_for_permitted_params, :action_blocks
                                     ) do
    def action name, &block
      self.action_blocks[name] = block
    end

    def action_blocks
      @action_blocks ||= {}.with_indifferent_access
    end
  end

  RouteConfigurator = Struct.new(:action, :description, :verb, :pathspec,
                                 :controller_config, :notes, :final_markdown,
                                 :scopes
                                )

  ControllerConfigBlock = Struct.new(:namespace, :block)


  class << self
    attr_accessor :controllers
    attr_accessor :global_config
  end

  def self.global_config
    @global_config ||= GlobalConfigurator.new.tap do |gc|
      gc.namespaces = [:api]
      gc.app_name = Rails.application.class.parent.name
    end
  end

  def self.controllers
    @controllers ||= {}.with_indifferent_access
  end

  def self.current_namespaces
    @namespaces ||= []
  end

  def self.namespace space, &block
    current_namespaces << space
    instance_exec &block
    current_namespaces.pop
  end

  def self.configure &block
    instance_exec &block
  end

  def self.controller name, &block
    path = (current_namespaces + [name]).join('/')
    self.controllers[path] = ControllerConfigBlock.new(path, block)
  end

  def self.global &block
    block.call self.global_config
  end

  delegate :global_config, :controllers, to: :class

  def supported_json_types
    %w(String Integer Decimal Datetime Text Boolean)
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

  def present_json hash
    json = JSON.pretty_generate(hash)

    json.gsub!(/"(\[|\{)/, '\1')
    json.gsub!(/(\]|\})"/, '\1')

    json.gsub!(/:\ "(#{supported_json_types.join('|').downcase})"/i).each do |match|
      ": #{match.gsub(':', '').gsub('"', '').strip.capitalize}"
    end
    json
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
    config.resource_name = controller.gsub(/^(#{global_config.namespaces.join('|')})\//, '').camelcase.singularize

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
      config.attributes_for_json = attributes

    end

    if config.controller_class && config.controller_class.permitted_params
      params_hash = config.controller_class.permitted_params
      params_hash[params_hash.keys.first] = params_hash[params_hash.keys.first].map do |attribute|
        type = config.resource_class.columns_hash[attribute].type.to_s.capitalize rescue "String"
        [attribute, type]
      end.to_h
      config.attributes_for_permitted_params = params_hash
    end

    ## Hook for app code
    if controllers[controller]
      config.instance_exec config, &controllers[controller].block
    end

    if config.json_representation.blank? && config.attributes_for_json.present?
      config.json_representation = present_json attributes
    end

    if config.permitted_params.blank? && config.attributes_for_permitted_params.present?
      config.permitted_params = present_json config.attributes_for_permitted_params
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

    if controller_config.action_blocks[config.action]
      config.instance_exec config, &controller_config.action_blocks[config.action]
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
    @toc = Array(global_config.toc).dup
    controllers = Rails.application.routes.routes.reduce({}) { |memo, route|
      if global_config.namespaces.any? { |ns| route.defaults.fetch(:controller, '').starts_with? "#{ns}/" }
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

    title = global_config.title
    title = "# " + t("global_header", app_name: global_config.app_name) if title.blank?

    md = [title]
    md << "\n"
    md += @toc
    md << "\n"
    if global_config.global_block.present?
      md << global_config.global_block
      md << "\n"
    end
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
