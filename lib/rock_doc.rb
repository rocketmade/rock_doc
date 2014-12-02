module RockDoc
  ControllerConfigurator = Struct.new(:controller, :resource_name,
                                      :resource_class, :controller_class,
                                      :serializer_class, :routes,
                                      :json_representation, :permitted_params,
                                      :notes, :final_markdown
                                     )

  RouteConfigurator = Struct.new(:action, :description, :verb, :pathspec,
                                 :controller_config, :notes, :final_markdown
                                )


  def self.configure &block
    instance_eval &block
  end

  def self.controller name, &block
    @controllers ||= {}
    @controllers[name] = block
  end

  def self.action name, &block
    @actions ||= {}
    @actions[name] = block
  end

  def self.global &block
    @global = block.call
  end

  def self.configuration_strings
    {
      namespace: "api/",
      app_name:  Rails.application.class.parent.name,

      descriptions: { # TODO: move these to translations.
        index:     "List all :resources",
        show:      "Get one :resource details",
        create:    "Create a new :resource",
        update:    "Update a :resource",
        destroy:   "Destroy a :resource",

        me:        "Get the current :resource",
        update_me: "Update the current :resource"
      }
    }.with_indifferent_access
  end

  def self.required
    method = caller_locations(1,1)[0].label
    raise ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
  end

  def self.controller_block controller: required, routes: required, config: required
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
    json_representation = {}.to_json

    if config.serializer_class
      attributes = config.serializer_class.schema[:attributes].dup
      associations = config.serializer_class.schema.fetch(:associations, {}).reduce({}) { |memo, kvp|
        key = config.resource_class.reflect_on_association(kvp.first).class_name

        if kvp.last.keys.include? :has_many
          memo[kvp.first] = "[...{...#{key}...},{...#{key}...}...]"
        else
          memo[kvp.first] = "{...#{key}...}"
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

    permitted_params = {}.to_json

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

    if @controllers[controller]
      config.instance_eval &@controllers[controller]
    end


    unless config.final_markdown.present?
      md = []
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

  def self.route_block controller_config: required, route: required, config: required
    config.action = route.defaults.fetch(:action, '')
    config.description = configuration_strings[:descriptions].fetch(config.action, "#{config.action} :resources").gsub(':resource', controller_config.resource_name).gsub(":resources", controller_config.resource_name.pluralize)
    config.verb = route.verb.source.gsub(/[$^]/, '')
    config.pathspec = route.path.spec.to_s.gsub(/\(?.:format\)?/, '.json')
    config.controller_config = controller_config

    if @actions["#{controller_config.controller}##{config.action}"]
      config.instance_eval &@actions["#{controller_config.controller}##{config.action}"]
    end

    md = []
    md << "### #{config.description}"
    md << "#{config.verb} #{config.pathspec}"
    if config.notes.present?
      md << ''
      md << "#### Notes"
      md << config.notes
    end

    config.final_markdown = md.join("\n") unless config.final_markdown.present?

    config.final_markdown unless config.final_markdown == ":nodoc:"

  end

  def self.generate
    @controllers ||= {}
    @actions     ||= {}

    controllers = Rails.application.routes.routes.reduce({}) { |memo, route|
      if route.defaults.fetch(:controller, '').starts_with? configuration_strings[:namespace]
        memo[route.defaults[:controller]] ||= []
        memo[route.defaults[:controller]] << route
      end
      memo
    }

    md = [@global || "# API Documentation for #{configuration_strings[:app_name]}"]


    controllers.each do |controller, routes|
      controller_config = ControllerConfigurator.new

      md << controller_block(controller: controller, routes: routes, config: controller_config)


      routes.each do |route|
        route_config = RouteConfigurator.new
        md << route_block(controller_config: controller_config, config: route_config, route: route)
      end
      md << ''
    end

    md.join("\n")
  end

  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/rock_doc_tasks.rake"
    end

  end
end
