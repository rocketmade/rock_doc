class RockDoc
  module Interrogation
    class ActiveModelSerializers
      def self.interrogate_resources doc: nil
        Dir[Rails.root.join("app/serializers/**/*_serializer.rb")].sort.each do |f|
          require f
        end

        if defined? ActiveModel::Serializer
          potential_serializers = ActiveModel::Serializer.descendants
          potential_serializers.reject! { |klass| doc.global_configuration.excluded_klasses.include? klass.to_s }

          potential_serializers.map do |klass|
            Configuration::Resource.new.tap do |r|
              r.resource_class     = klass.model_class
              r.serializer         = klass
              r.configuration_name = klass.name.underscore.gsub(/_serializer$/, '')
            end
          end
        else
          []
        end
      end
    end
  end
end
