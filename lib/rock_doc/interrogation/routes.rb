class RockDoc
  module Interrogation
    class Routes
      def self.interrogate_routes doc: nil
        global_configuration = doc.global_configuration

        Rails.application.routes.routes.reduce([]) do |memo, route|

          if global_configuration.namespaces.any? { |ns| route.defaults.fetch(:controller, '').starts_with? "#{ns}/" }
            memo << Configuration::Route.new.tap do |r|
              r.controller_path = route.defaults[:controller]
              r.action          = route.defaults.fetch(:action, '')
              r.verb            = route.verb.source.gsub(/[$^]/, '')
              r.path            = route.path.spec.to_s
            end
          end
          memo
        end
      end
    end
  end
end
