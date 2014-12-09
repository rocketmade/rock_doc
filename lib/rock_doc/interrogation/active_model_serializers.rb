class RockDoc
  module Interrogation
    class ActiveModelSerializers
      def self.interrogate_resources rock_doc
        Dir[Rails.root.join("app/serializers/**/*_serializer.rb")].each do |f|
          require f
        end
        ActiveModel::Serializer.descendants.map do |klass|
          Configuration::Resource.new.tap do |r|
            r.resource_class = klass.model_class
            r.serializer = klass
            r.configuration_name = klass.name.underscore.gsub(/_serializer$/, '')
          end
        end
      end
    end
  end
end
