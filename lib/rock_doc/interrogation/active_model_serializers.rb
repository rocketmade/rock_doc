class RockDoc
  module Interrogation
    class ActiveModelSerializers
      def self.interrogate_resources doc: nil
        Dir[Rails.root.join("app/serializers/**/*_serializer.rb")].sort.each do |f|
          require f
        end
        if defined?(ActiveModel::Serializer)
          ActiveModel::Serializer.descendants.map do |klass|
            model_class = klass.model_class rescue nil
            next if model_class.nil?
            Configuration::Resource.new.tap do |r|
              r.resource_class     = model_class
              r.serializer         = klass
              r.configuration_name = klass.name.underscore.gsub(/_serializer$/, '')
            end
          end.compact
        else
          []
        end
      end
    end
  end
end
